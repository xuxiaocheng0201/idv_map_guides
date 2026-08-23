use std::collections::HashSet;

use serde::{Deserialize, Serialize};

// ```
//     ^ y
//     |
//     |
// ----+----> x
//     |
// ```

#[derive(Debug, Serialize, Deserialize, Copy, Clone, Eq, PartialEq, Hash)]
pub enum Layer {
    Basement,
    Ground,
    Second,
}

impl Layer {
    pub(crate) fn up(self) -> Option<Layer> {
        match self {
            Layer::Basement => Some(Layer::Ground),
            Layer::Ground => Some(Layer::Second),
            Layer::Second => None,
        }
    }

    pub(crate) fn down(self) -> Option<Layer> {
        match self {
            Layer::Basement => None,
            Layer::Ground => Some(Layer::Basement),
            Layer::Second => Some(Layer::Ground),
        }
    }
}

#[derive(Debug, Serialize, Deserialize, Copy, Clone, Eq, PartialEq, Hash)]
pub enum Rotation {
    CW0,
    CW90,
    CW180,
    CW270,
}

impl Rotation {
    pub(crate) fn times(self) -> usize {
        match self {
            Rotation::CW0 => 0,
            Rotation::CW90 => 1,
            Rotation::CW180 => 2,
            Rotation::CW270 => 3,
        }
    }
}

#[derive(Debug, Serialize, Deserialize, Copy, Clone, Eq, PartialEq, Hash)]
pub enum Direction {
    North, // ↑
    East, // →
    South, // ↓
    West, // ←
}

impl Direction {
    pub fn dxy(self) -> (i32, i32) {
        match self {
            Direction::North => (0, 1),
            Direction::East => (1, 0),
            Direction::South => (0, -1),
            Direction::West => (-1, 0),
        }
    }

    pub fn rotate(self, rotation: Rotation) -> Direction {
        let mut result = self;
        for _ in 0..rotation.times() {
            result = match result {
                Direction::North => Direction::East,
                Direction::East => Direction::South,
                Direction::South => Direction::West,
                Direction::West => Direction::North,
            }
        }
        result
    }
}

#[derive(Debug, Serialize, Deserialize, Copy, Clone, Eq, PartialEq, Hash)]
pub struct Position {
    pub x: i32,
    pub y: i32,
}

impl Position {
    pub fn add(&self, dx: i32, dy: i32) -> Position {
        Position {
            x: self.x + dx,
            y: self.y + dy,
        }
    }

    pub fn rotate(self, rotation: Rotation) -> Position {
        let mut result = self;
        for _ in 0..rotation.times() {
            result = Position {
                x: result.y,
                y: -result.x,
            }
        }
        result
    }
}

#[derive(Debug, Serialize, Deserialize, Copy, Clone, Eq, PartialEq, Hash)]
pub struct Door {
    pub position: Position,
    pub direction: Direction,
}

impl Door {
    pub fn opposite(&self) -> Door {
        let (dx, dy) = self.direction.dxy();
        Door {
            position: self.position.add(dx, dy),
            direction: self.direction.rotate(Rotation::CW180),
        }
    }
}

#[derive(Debug, Serialize, Deserialize, Copy, Clone, Eq, PartialEq, Hash)]
pub struct Entrance {
    pub layer: Layer,
    pub position: Position,
}

#[derive(Debug, Serialize, Deserialize, Copy, Clone, Eq, PartialEq, Hash)]
pub struct Stair {
    pub position: Position,
    pub is_up: bool, // true is go up, false is go down
}

#[derive(Debug, Serialize, Deserialize, Copy, Clone, Eq, PartialEq, Hash)]
pub struct Hole {
    pub position: Position,
    pub direction: Direction,
}

impl Hole {
    pub fn target(&self) -> Position {
        let (dx, dy) = self.direction.dxy();
        self.position.add(dx, dy)
    }
}

#[derive(Debug, Serialize, Deserialize, Clone, Eq, PartialEq)]
pub struct Structure {
    pub is_corridor: bool,
    pub cells: HashSet<Position>,
    pub doors: HashSet<Door>,
    pub inner_walls: HashSet<Door>,
    pub stairs: HashSet<Stair>,
    pub holes: HashSet<Hole>,
}
