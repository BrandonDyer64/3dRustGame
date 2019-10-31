use crate::vector::Vector3;

#[derive(Clone)]
pub struct Camera {
    pub pos: Vector3,
    pub dir: Vector3,
}
