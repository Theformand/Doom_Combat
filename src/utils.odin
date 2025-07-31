package main

import "core:math"
import linalg "core:math/linalg"
import rand "core:math/rand"
import rl "vendor:raylib"

norm :: proc(v: float3) -> float3 
{
  return linalg.vector_normalize0(v)
}

matrix_trs :: proc(position, scale: float3, rotation: quaternion) -> rl.Matrix 
{
  return rl.Matrix(linalg.matrix4_from_trs_f32(position, rotation, scale))
}

radians :: proc(angleDegrees: float) -> float 
{
  return linalg.to_radians(angleDegrees)
}


entity_fwd :: proc(e: ^Entity) -> float3 
{
  return linalg.mul(e.rotation, float3_fwd)
}

entity_right :: proc(e: ^Entity) -> float3 
{
  return linalg.mul(e.rotation, float3_right)
}


look_rot :: proc(start, lookDir, up: float3) -> quaternion 
{
  return linalg.quaternion_inverse((linalg.quaternion_look_at(start, lookDir, up)))
}

look_rot_test :: proc(start, lookDir, up: float3) -> quaternion 
{
  return linalg.quaternion_look_at(start, lookDir, up)
}

lookRot :: proc(start, lookDir, up: float3) -> quaternion 
{
  return rl.QuaternionFromMatrix(rl.MatrixLookAt(start, lookDir, float3_up))
}

rand_range :: proc(min, max: float) -> float 
{
  return rand.float32_range(min, max)
}

rand_range_int :: proc(min, max: int) -> int 
{
  return int(math.clamp(rand.int31_max(max + 1), min, max))
}

float3_rand :: proc() -> float3 
{
  return float3{rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)}
}

float3_rand_xz :: proc(radius: float = 1) -> float3 
{
  return float3{rand_range(-radius, radius), 0, rand_range(-radius, radius)}

}

float4_rand01 :: proc() -> float4 
{
  return float4{rand_range(0, 1), rand_range(0, 1), rand_range(0, 1), 1}
}

rand_color :: proc() -> rl.Color 
{
  return rl.Color{u8(rand.int31_max(255)), u8(rand.int31_max(255)), u8(rand.int31_max(255)), 255}
}


get_camera_rotation :: proc(camera: ^rl.Camera) -> quaternion 
{
  cam_mat := linalg.Matrix4f32(rl.GetCameraMatrix(camera^))
  return linalg.quaternion_from_matrix4_f32(cam_mat)
}

// ============== EASINGS ===============

ease_sine_out :: proc(x: float) -> float 
{
  return math.sin((x * math.PI) / 2)
}

ease_cubic_out :: proc(x: float) -> float 
{
  return 1 - math.pow(1 - x, 3)
}

ease_circ_out :: proc(x: float) -> float 
{
  return math.sqrt(1 - math.pow(x - 1, 2))
}

ease_cubic_in :: proc(x: float) -> float 
{
  return x * x * x
}
