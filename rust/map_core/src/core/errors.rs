use crate::core::data::{Door, Entrance, Hole, Position, Stair};

#[derive(Debug, Clone)]
pub enum MapError {
    EntranceOutOfWorld { entrance: Entrance },
    CellOutOfWorld { world_position: Position, cell: Position },
    CellOverlap { world_position: Position, cell: Position },
    DoorOutOfStructure { door: Door },
    DoorNotAtBoundary { door: Door },
    InnerWallOutOfStructure { wall: Door },
    InnerWallAtBoundary { wall: Door },
    StairOutOfStructure { stair: Stair },
    StairOverlap { stair: Stair },
    StairMoveOutOfLayer { stair: Stair },
    HoleOutOfStructure { hole: Hole },
    HoleMoveOutOfLayer { hole: Hole },
    HoleOutOfWorld { world_target: Position, hole: Hole },

    EntranceInEmpty { entrance: Entrance },
    DoorMismatch { world_door: Door },
    StairMismatch { world_stair: Stair },
    HoleMismatch { world_hole: Hole },
    HoleMovedMismatch { world_hole: Hole },

    UnknownStructureType { type_name: String },
    CorridorMissingCells,
    EmptyMap,
}

#[derive(Debug)]
pub struct MapErrors {
    errors: Vec<MapError>,
}

impl MapErrors {
    pub(crate) fn new() -> Self {
        Self {
            errors: Vec::new(),
        }
    }

    pub(crate) fn push(&mut self, e: MapError) {
        self.errors.push(e);
    }

    pub(crate) fn merge(&mut self, e: MapErrors) {
        self.errors.extend(e.errors);
    }

    pub(crate) fn is_empty(&self) -> bool {
        self.errors.is_empty()
    }

    pub fn errors(&self) -> impl Iterator<Item = &MapError> {
        self.errors.iter()
    }
}

impl From<MapError> for MapErrors {
    fn from(e: MapError) -> Self {
        let mut error = Self::new();
        error.push(e);
        error
    }
}
