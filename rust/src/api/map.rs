use std::collections::HashSet;

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(o2o::o2o)]
#[map_owned(map_core::core::data::Layer)]
pub enum Layer {
    Basement,
    Ground,
    Second,
}

#[flutter_rust_bridge::frb(non_opaque)]
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
    pub fn dx(&self) -> i32 {
        <_ as Into<map_core::core::data::Direction>>::into(*self).dxy().0
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn dy(&self) -> i32 {
        <_ as Into<map_core::core::data::Direction>>::into(*self).dxy().1
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(o2o::o2o)]
#[map_owned(map_core::core::map::Cell)]
pub enum CellInfo {
    Empty,
    Structure {
        id: usize,
        is_corridor: bool,
        is_stair: bool,
        stair_is_up: bool,
        #[map(~.into_iter().map(Into::into).collect())]
        doors: HashSet<Direction>,
        #[map(~.into_iter().map(Into::into).collect())]
        inner_walls: HashSet<Direction>,
        #[map(~.into_iter().map(Into::into).collect())]
        holes: HashSet<Direction>,
    },
}

#[flutter_rust_bridge::frb(opaque)]
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

pub fn get_map_model() -> MapModel {
    MapModel(map_core::maps::construct())
}
