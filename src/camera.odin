package main

import "core:fmt"
import "core:math"
import "core:math/noise"
import rl "vendor:raylib"


CameraShakeType :: enum {
  small,
  medium,
  large,
}

CameraShakeData :: struct {
  duration: float,
  t:        float,
  power:    float,
  freq:     float,
}

camera: rl.Camera3D
active_cam_shake: CameraShakeData
shake_org: CameraShakeData
cam_shake_offset: float

@(rodata)
ShakeDatas := [CameraShakeType]CameraShakeData {
  .small = CameraShakeData{duration = 0.15, power = 0.19, freq = 20},
  .medium = CameraShakeData{duration = 0.35, power = 0.25, freq = 20},
  .large = CameraShakeData{duration = 0.3, power = 1, freq = 20},
}

noise_seed: i64
camera_offset_from_player :: float3{-10.0, 20.0, -10.0}


init_camera :: proc() 
{
  camera = rl.Camera3D{}
  camera.position = camera_offset_from_player
  camera.target = float3_zero
  camera.up = float3_up
  camera.fovy = 65.0
  camera.projection = .PERSPECTIVE

  append(&tick_procs, tick_camera)
  active_cam_shake = ShakeDatas[.small]
  active_cam_shake.duration = 0
  noise_seed = 1337
}

camera_shake :: proc(shakeType: CameraShakeType) 
{
  if active_cam_shake.duration <= 0 {
    active_cam_shake = ShakeDatas[shakeType]
    shake_org = ShakeDatas[shakeType]
  }
}

tick_camera :: proc() 
{
  if rl.IsKeyPressed(rl.KeyboardKey.T) {
    camera_shake(.small)
  }


  player := get_entity(player_handle)
  time := f64(now)

  if active_cam_shake.duration > 0 {
    active_cam_shake.duration -= dt
    active_cam_shake.duration = math.clamp(active_cam_shake.duration, 0, 1)

    active_cam_shake.t = active_cam_shake.duration / shake_org.duration
    power := math.lerp(float(0.0), shake_org.power, ease_cubic_out(active_cam_shake.t))
    active_cam_shake.power = power

    noiseParams := [2]f64{time * f64(active_cam_shake.freq), time}
    cam_shake_offset = noise.noise_2d(noise_seed, noiseParams) * power
  }

  offset_vec := float3{0, cam_shake_offset, 0}
  player_pos := player.position

  camera.position = player_pos + camera_offset_from_player + offset_vec
  camera.target = player_pos + offset_vec
  rl.UpdateCamera(&camera, .CUSTOM)
}
