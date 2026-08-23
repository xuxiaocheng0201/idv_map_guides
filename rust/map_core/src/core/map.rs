use std::collections::{HashMap, HashSet};

use serde::{Deserialize, Serialize};

use crate::core::data::{Direction, Door, Entrance, Hole, Layer, Position, Rotation, Stair, Structure};
use crate::core::errors::{MapError, MapErrors};

#[derive(Debug, Serialize, Deserialize, Clone, Eq, PartialEq)]
pub enum Cell {
    Empty,
    Structure {
        id: usize,
        is_corridor: bool,
        is_stair: bool,
        stair_is_up: bool,
        doors: HashSet<Direction>,
        inner_walls: HashSet<Direction>,
        holes: HashSet<Direction>,
    },
}

#[derive(Debug, Serialize, Deserialize, Clone, Eq, PartialEq)]
pub struct Map {
    pub x_width: usize,
    pub y_height: usize,
    pub origin_x: usize,
    pub origin_y: usize,
    pub map: HashMap<Layer, Vec<Vec<Cell>>>,
    pub entrances: HashSet<Entrance>,
    pub min_x: i32, pub max_x: i32, pub min_y: i32, pub max_y: i32,
    next_structure_id: usize,
}

impl Map {
    pub fn new(layers: HashSet<Layer>, min_x: i32, max_x: i32, min_y: i32, max_y: i32) -> Self {
        let width = (max_x - min_x + 1) as usize;
        let height = (max_y - min_y + 1) as usize;
        let origin_x = (-min_x) as usize;
        let origin_y = (-min_y) as usize;
        Self {
            x_width: width,
            y_height: height,
            origin_x, origin_y,
            map: layers.into_iter()
                .map(|layer| (layer, vec![vec![Cell::Empty; height]; width]))
                .collect(),
            entrances: HashSet::new(),
            min_x, max_x, min_y, max_y,
            next_structure_id: 0,
        }
    }

    fn is_out_of_world(&self, x: i32, y: i32) -> bool {
        x < self.min_x || self.max_x < x || y < self.min_y || self.max_y < y
    }

    pub fn cell(&self, layer: &Layer, x: i32, y: i32) -> Option<&Cell> {
        if self.is_out_of_world(x, y) {
            return None;
        }
        let x = (self.origin_x as i32 + x) as usize;
        let y = (self.origin_y as i32 + y) as usize;
        Some(&self.map.get(layer)?[x][y])
    }

    fn cell_mut(&mut self, layer: &Layer, x: i32, y: i32) -> Option<&mut Cell> {
        if self.is_out_of_world(x, y) {
            return None;
        }
        let x = (self.origin_x as i32 + x) as usize;
        let y = (self.origin_y as i32 + y) as usize;
        Some(&mut self.map.get_mut(layer)?[x][y])
    }

    pub fn add_entrance(&mut self, entrance: Entrance) -> Result<(), MapError> {
        if !self.map.contains_key(&entrance.layer) || self.is_out_of_world(entrance.position.x, entrance.position.y) {
            return Err(MapError::EntranceOutOfWorld { entrance, });
        }
        self.entrances.insert(entrance);
        Ok(())
    }

    pub fn add_single_layer(&mut self, layer: Layer, origin_x: i32, origin_y: i32, structure: Structure, rotation: Rotation) -> Result<(), MapErrors> {
        let Structure { is_corridor, cells, doors, inner_walls, stairs, holes } = structure;
        let mut errors = MapErrors::new();
        for cell in &cells {
            let world_position = cell.rotate(rotation).add(origin_x, origin_y);
            match self.cell(&layer, world_position.x, world_position.y) {
                Some(Cell::Empty) => {},
                Some(Cell::Structure { .. }) => errors.push(MapError::CellOverlap { world_position, cell: *cell, }),
                None => errors.push(MapError::CellOutOfWorld { world_position, cell: *cell, }),
            }
        }
        for door in &doors {
            if !cells.contains(&door.position) {
                errors.push(MapError::DoorOutOfStructure { door: *door, });
                continue;
            }
            if cells.contains(&door.opposite().position) {
                errors.push(MapError::DoorNotAtBoundary { door: *door, });
                continue;
            }
        }
        for inner_wall in &inner_walls {
            if !cells.contains(&inner_wall.position) {
                errors.push(MapError::InnerWallOutOfStructure { wall: *inner_wall, });
                continue;
            }
            if !cells.contains(&inner_wall.opposite().position) {
                errors.push(MapError::InnerWallAtBoundary { wall: *inner_wall, });
                continue;
            }
        }
        let mut placed_stairs = HashSet::with_capacity(stairs.len());
        for stair in &stairs {
            if !cells.contains(&stair.position) {
                errors.push(MapError::StairOutOfStructure { stair: *stair, });
                continue;
            }
            if stair.is_up && layer.up().map_or(true, |n| !self.map.contains_key(&n)) {
                errors.push(MapError::StairMoveOutOfLayer { stair: *stair, });
                continue;
            }
            if !stair.is_up && layer.down().map_or(true, |n| !self.map.contains_key(&n)) {
                errors.push(MapError::StairMoveOutOfLayer { stair: *stair, });
                continue;
            }
            if !placed_stairs.insert(stair.position) {
                errors.push(MapError::StairOverlap { stair: *stair, });
                continue;
            }
        }
        for hole in &holes {
            if !cells.contains(&hole.position) {
                errors.push(MapError::HoleOutOfStructure { hole: *hole, });
                continue;
            }
            if layer.down().map_or(true, |n| !self.map.contains_key(&n)) {
                errors.push(MapError::HoleMoveOutOfLayer { hole: *hole, });
                continue;
            }
            let hole_target = hole.target();
            let world_target = hole_target.rotate(rotation).add(origin_x, origin_y);
            if self.is_out_of_world(world_target.x, world_target.y) {
                errors.push(MapError::HoleOutOfWorld { world_target, hole: *hole, });
                continue;
            }
        }
        if !errors.is_empty() {
            return Err(errors);
        }
        let structure_id = self.next_structure_id;
        self.next_structure_id += 1;
        for cell in &cells {
            let world_position = cell.rotate(rotation).add(origin_x, origin_y);
            let cell = self.cell_mut(&layer, world_position.x, world_position.y).expect("checked above");
            *cell = Cell::Structure {
                id: structure_id,
                is_corridor,
                is_stair: false,
                stair_is_up: false,
                doors: HashSet::new(),
                inner_walls: HashSet::new(),
                holes: HashSet::new(),
            };
        }
        for door in &doors {
            let world_position = door.position.rotate(rotation).add(origin_x, origin_y);
            let Cell::Structure { doors, .. } = self.cell_mut(&layer, world_position.x, world_position.y).expect("checked above") else { panic!("set above"); };
            doors.insert(door.direction.rotate(rotation));
        }
        for inner_wall in &inner_walls {
            let world_position = inner_wall.position.rotate(rotation).add(origin_x, origin_y);
            let Cell::Structure { inner_walls, .. } = self.cell_mut(&layer, world_position.x, world_position.y).expect("checked above") else { panic!("set above"); };
            inner_walls.insert(inner_wall.direction.rotate(rotation));
            let inner_wall = inner_wall.opposite();
            let world_position = inner_wall.position.rotate(rotation).add(origin_x, origin_y);
            let Cell::Structure { inner_walls, .. } = self.cell_mut(&layer, world_position.x, world_position.y).expect("checked above") else { panic!("set above"); };
            inner_walls.insert(inner_wall.direction.rotate(rotation));
        }
        for stair in &stairs {
            let world_position = stair.position.rotate(rotation).add(origin_x, origin_y);
            let Cell::Structure { is_stair, stair_is_up, .. } = self.cell_mut(&layer, world_position.x, world_position.y).expect("checked above") else { panic!("set above"); };
            *is_stair = true;
            *stair_is_up = stair.is_up;
        }
        for hole in &holes {
            let world_position = hole.position.rotate(rotation).add(origin_x, origin_y);
            let Cell::Structure { holes, .. } = self.cell_mut(&layer, world_position.x, world_position.y).expect("checked above") else { panic!("set above"); };
            holes.insert(hole.direction.rotate(rotation));
        }
        Ok(())
    }

    pub fn validate(&self) -> Result<(), MapErrors> {
        let mut errors = MapErrors::new();
        for entrance in &self.entrances {
            let cell = self.cell(&entrance.layer, entrance.position.x, entrance.position.y).expect("checked placing");
            if let Cell::Empty = cell {
                errors.push(MapError::EntranceInEmpty { entrance: *entrance });
            }
        }
        for layer in self.map.keys() {
            for x in self.min_x..=self.max_x {
                for y in self.min_y..=self.max_y {
                    let cell = self.cell(layer, x, y).expect("should exist");
                    match cell {
                        Cell::Empty => {}
                        Cell::Structure {
                            doors,
                            is_stair,
                            stair_is_up,
                            holes,
                            ..
                        } => {
                            for door in doors {
                                let world_door = Door {
                                    position: Position { x, y },
                                    direction: *door,
                                };
                                let opposite = world_door.opposite();
                                let opposite_cell = self.cell(&layer, opposite.position.x, opposite.position.y); // opposite may out of bound
                                if let Some(Cell::Structure { doors, .. }) = opposite_cell && !doors.contains(&opposite.direction) {
                                    errors.push(MapError::DoorMismatch { world_door, });
                                }
                            }
                            if *is_stair {
                                let layer_moved = if *stair_is_up { layer.up() } else { layer.down() }.expect("checked placing");
                                let target_cell = self.cell(&layer_moved, x, y).expect("checked placing");
                                if let Cell::Structure { is_stair: target_is_stair, stair_is_up: target_is_up, .. } = target_cell && *target_is_stair && *target_is_up != *stair_is_up {
                                } else {
                                    errors.push(MapError::StairMismatch { world_stair: Stair {
                                        position: Position { x, y },
                                        is_up: *stair_is_up,
                                    }, });
                                }
                            }
                            for hole in holes {
                                let world_hole = Hole {
                                    position: Position { x, y },
                                    direction: *hole,
                                };
                                let layer_moved = layer.down().expect("checked placing");
                                let target = world_hole.target();
                                let target_cell = self.cell(&layer, target.x, target.y).expect("checked placing");
                                if let Cell::Structure { .. } = target_cell {
                                    errors.push(MapError::HoleMismatch { world_hole, });
                                }
                                let target_moved_cell = self.cell(&layer_moved, target.x, target.y).expect("checked placing");
                                if let Cell::Empty = target_moved_cell {
                                    errors.push(MapError::HoleMovedMismatch { world_hole, });
                                }
                            }
                        }
                    }
                }
            }
        }
        if errors.is_empty() { Ok(()) } else { Err(errors) }
    }
}
