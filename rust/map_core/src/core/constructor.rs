use std::collections::{HashMap, HashSet};

use serde::{Deserialize, Serialize};

use crate::core::data::{Door, Layer, Position, Rotation, Structure};
use crate::core::errors::{MapError, MapErrors};
use crate::core::map::Map;

fn default_rotation() -> Rotation {
    Rotation::CW0
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct StructureInstance {
    #[serde(rename = "type")]
    pub type_name: String,
    pub layer: Layer,
    pub origin_x: i32,
    pub origin_y: i32,
    #[serde(default = "default_rotation")]
    pub rotation: Rotation,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub cells: Option<HashSet<Position>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub doors: Option<HashSet<Door>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub inner_walls: Option<HashSet<Door>>,
}

fn resolve_structure(
    instance: &StructureInstance,
    structures: &HashMap<String, Structure>,
) -> Result<Structure, MapError> {
    if instance.type_name == "corridor" {
        return Ok(Structure {
            is_corridor: true,
            cells: instance.cells.clone().ok_or(MapError::CorridorMissingCells)?,
            doors: instance.doors.clone().unwrap_or_default(),
            inner_walls: instance.inner_walls.clone().unwrap_or_default(),
            stairs: HashSet::new(),
            holes: HashSet::new(),
        });
    }
    match structures.get(&instance.type_name) {
        Some(structure) => Ok(structure.clone()),
        None => Err(MapError::UnknownStructureType { type_name: instance.type_name.to_string() }),
    }
}

pub fn construct_map(
    map: &[StructureInstance],
    structures: &HashMap<String, Structure>,
) -> Result<Map, MapErrors> {
    if map.is_empty() {
        return Err(MapError::EmptyMap.into());
    }

    let mut layers = HashSet::new();
    let mut min_x = i32::MAX;
    let mut max_x = i32::MIN;
    let mut min_y = i32::MAX;
    let mut max_y = i32::MIN;
    let mut errors = MapErrors::new();
    for instance in map {
        layers.insert(instance.layer);
        let structure = match resolve_structure(instance, structures) {
            Ok(s) => s,
            Err(e) => {
                errors.push(e);
                continue;
            }
        };
        for cell in &structure.cells {
            let world_position = cell.rotate(instance.rotation).add(instance.origin_x, instance.origin_y);
            min_x = min_x.min(world_position.x);
            max_x = max_x.max(world_position.x);
            min_y = min_y.min(world_position.y);
            max_y = max_y.max(world_position.y);
        }
    }
    if !errors.is_empty() {
        return Err(errors);
    }
    let mut world = Map::new(layers, min_x, max_x, min_y, max_y);

    for instance in map {
        let structure = resolve_structure(&instance, &structures).expect("checked above");
        match world.add_single_layer(
            instance.layer,
            instance.origin_x,
            instance.origin_y,
            structure,
            instance.rotation,
        ) {
            Ok(()) => {},
            Err(error) => errors.merge(error),
        }
    }
    match world.validate() {
        Ok(()) => {},
        Err(error) => errors.merge(error),
    }

    if errors.is_empty() { Ok(world) } else { Err(errors) }
}