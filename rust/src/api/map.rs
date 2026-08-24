use std::collections::HashSet;

#[flutter_rust_bridge::frb(unignore, non_opaque)]
#[derive(o2o::o2o, Copy, Clone, Eq, PartialEq, Hash)]
#[map_owned(map_core::core::data::Layer)]
pub enum Layer {
    Basement,
    Ground,
    Second,
}

#[flutter_rust_bridge::frb(unignore, non_opaque)]
#[derive(o2o::o2o, Copy, Clone, Eq, PartialEq, Hash)]
#[map_owned(map_core::core::data::Rotation)]
pub enum Rotation {
    CW0,
    CW90,
    CW180,
    CW270,
}

#[flutter_rust_bridge::frb(unignore, non_opaque)]
#[derive(o2o::o2o, Copy, Clone, Eq, PartialEq, Hash)]
#[map_owned(map_core::core::data::Direction)]
pub enum Direction {
    North,
    East,
    South,
    West,
}

impl Direction {
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn dxy(&self) -> (i32, i32) {
        <_ as Into<map_core::core::data::Direction>>::into(*self).dxy()
    }
}

#[flutter_rust_bridge::frb(unignore, non_opaque)]
#[derive(o2o::o2o, Copy, Clone, Eq, PartialEq, Hash)]
#[map_owned(map_core::core::data::Position)]
pub struct Position {
    pub x: i32,
    pub y: i32,
}

impl Position {
    #[flutter_rust_bridge::frb(sync)]
    pub fn add(&self, x: i32, y: i32) -> Position {
        <_ as Into<map_core::core::data::Position>>::into(*self).add(x, y).into()
    }
}

#[flutter_rust_bridge::frb(unignore, non_opaque)]
#[derive(o2o::o2o, Copy, Clone, Eq, PartialEq, Hash)]
#[map_owned(map_core::core::data::Door)]
pub struct Door {
    #[map(~.into())]
    pub position: Position,
    #[map(~.into())]
    pub direction: Direction,
}

#[flutter_rust_bridge::frb(unignore, non_opaque)]
#[derive(o2o::o2o, Copy, Clone, Eq, PartialEq, Hash)]
#[map_owned(map_core::core::data::Entrance)]
pub struct Entrance {
    #[map(~.into())]
    pub layer: Layer,
    #[map(~.into())]
    pub position: Position,
}

#[flutter_rust_bridge::frb(unignore, non_opaque)]
#[derive(o2o::o2o, Copy, Clone, Eq, PartialEq, Hash)]
#[map_owned(map_core::core::data::StairTransport)]
pub enum StairTransport {
    Nothing,
    GoUp,
    GoDown,
}

#[flutter_rust_bridge::frb(unignore, non_opaque)]
#[derive(o2o::o2o, Copy, Clone, Eq, PartialEq, Hash)]
#[map_owned(map_core::core::data::Stair)]
pub struct Stair {
    #[map(~.into())]
    pub position: Position,
    #[map(~.into())]
    pub stair_transport: StairTransport,
}

#[flutter_rust_bridge::frb(unignore, non_opaque)]
#[derive(o2o::o2o, Copy, Clone, Eq, PartialEq, Hash)]
#[map_owned(map_core::core::data::Hole)]
pub struct Hole {
    #[map(~.into())]
    pub position: Position,
    #[map(~.into())]
    pub direction: Direction,
}

#[flutter_rust_bridge::frb(unignore, non_opaque)]
#[derive(o2o::o2o, Clone)]
#[map_owned(map_core::core::data::Structure)]
pub struct Structure {
    #[frb(non_final)]
    pub is_corridor: bool,
    #[map(~.into_iter().map(Into::into).collect())]
    pub cells: HashSet<Position>,
    #[map(~.into_iter().map(Into::into).collect())]
    pub doors: HashSet<Door>,
    #[map(~.into_iter().map(Into::into).collect())]
    pub inner_walls: HashSet<Door>,
    #[map(~.into_iter().map(Into::into).collect())]
    pub stairs: HashSet<Stair>,
    #[map(~.into_iter().map(Into::into).collect())]
    pub holes: HashSet<Hole>,
}

#[flutter_rust_bridge::frb(unignore, non_opaque)]
#[derive(o2o::o2o, Copy, Clone)]
#[map_owned(map_core::core::map::EdgeType)]
pub enum EdgeType {
    Nothing,
    Door,
    InnerWall,
    Hole,
}

#[flutter_rust_bridge::frb(unignore, non_opaque)]
#[derive(o2o::o2o, Copy, Clone)]
#[map_owned(map_core::core::map::Cell)]
pub enum CellInfo {
    Empty,
    Structure {
        id: usize,
        is_corridor: bool,
        #[map(~.map(Into::into))]
        is_stair: Option<StairTransport>,
        #[map(~.into())]
        edge_north: EdgeType,
        #[map(~.into())]
        edge_east: EdgeType,
        #[map(~.into())]
        edge_south: EdgeType,
        #[map(~.into())]
        edge_west: EdgeType,
    },
}

impl CellInfo {
    #[flutter_rust_bridge::frb(sync)]
    pub fn get_directions(&self, target: EdgeType) -> HashSet<Direction> {
        <_ as Into<map_core::core::map::Cell>>::into(*self).get_directions(target.into()).into_iter().map(Into::into).collect()
    }
}

#[flutter_rust_bridge::frb(unignore, opaque)]
pub struct MapModel(map_core::core::map::Map);

impl MapModel {
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn layers(&self) -> Vec<Layer> {
        self.0.map.keys().copied().map(Into::into).collect()
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn min_x(&self) -> i32 {
        self.0.min_x
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn max_x(&self) -> i32 {
        self.0.max_x
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn min_y(&self) -> i32 {
        self.0.min_y
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn max_y(&self) -> i32 {
        self.0.max_y
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn width(&self) -> usize {
        self.0.x_width
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn height(&self) -> usize {
        self.0.y_height
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn cell(&self, layer: Layer, x: i32, y: i32) -> Option<CellInfo> {
        self.0.cell(&layer.into(), x, y).map(|c| c.clone().into())
    }
}
