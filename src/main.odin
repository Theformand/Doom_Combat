package main

import "core:c"
import "core:fmt"
import "core:log"
import linalg "core:math/linalg"
import "core:reflect"
import "core:time"
import rl "vendor:raylib"

manager: EntityManager

//ALIASES
float :: f32
float2 :: rl.Vector2
float3 :: rl.Vector3
float4 :: rl.Vector4
float4_one :: rl.Vector4{1, 1, 1, 1}
quaternion :: rl.Quaternion
float3_up :: float3{0, 1, 0}
float3_zero :: float3{}
float3_one :: float3{1, 1, 1}
float3_one_rl :: rl.Vector3{1, 1, 1}
float3_fwd :: float3{0, 0, 1}
float3_right :: float3{1, 0, 0}
quaternion_identity :: linalg.QUATERNIONF32_IDENTITY
int :: i32

SCREEN_WIDTH: int
SCREEN_HEIGHT: int

width_windowed: int = 1920
height_windowed: int = 1080
width_full: int = 2560
height_full: int = 1440

FULL_SCREEN: bool = false
PRINT_ENTITY_STRUCT: bool = false
PRINT_PERF_METRICS: bool = false

RAD_45: float
RAD_90: float
RAD_135: float
RAD_180: float
RAD_225: float
RAD_270: float

MAX_ENTITIES :: 10000

time_now: float
now_f64: f64
dt: float
update_procs: [dynamic]proc()
late_update_procs: [dynamic]proc()
draw_procs: [dynamic]proc()

render_target: rl.RenderTexture2D
bloom_shader: rl.Shader
sw: time.Stopwatch


main :: proc() 
{
  context.logger = log.create_console_logger(.Debug, log.Location_Header_Opts)

  SCREEN_WIDTH = FULL_SCREEN ? width_full : width_windowed
  SCREEN_HEIGHT = FULL_SCREEN ? height_full : height_windowed
  flags: rl.ConfigFlags = FULL_SCREEN ? {.MSAA_4X_HINT, .FULLSCREEN_MODE} : {.MSAA_4X_HINT}

  RAD_45 = radians(float(45))
  RAD_90 = radians(float(90))
  RAD_135 = radians(float(135))
  RAD_180 = radians(float(180))
  RAD_225 = radians(float(225))
  RAD_270 = radians(float(270))

  update_procs = make([dynamic]proc())
  late_update_procs = make([dynamic]proc())

  manager = init_entity_manager()
  defer destroy_entity_manager()

  if PRINT_ENTITY_STRUCT {
    log.debug("\n")
    log.debug("==================")
    log.debug("ENTITY STRUCT INFO")
    log.debug("\n")
    type_infos := reflect.struct_field_types(Entity)
    type_names := reflect.struct_field_names(Entity)
    for t, i in type_infos {
      log.debug("field: ", type_names[i], type_infos[i].size)
    }
    log.debug("entity size total: ", size_of(Entity))
  }


  rl.SetTraceLogLevel(.WARNING)
  rl.SetConfigFlags(flags)
  rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Entity System Test")

  if FULL_SCREEN {
    rl.SetWindowMonitor(0)
  }

  rl.SetTargetFPS(144)


  //============ INIT ============

  bloom_ctx: BloomContext
  init_bloom(&bloom_ctx, SCREEN_WIDTH, SCREEN_HEIGHT)
  defer cleanup_bloom(&bloom_ctx)

  init_lighting()
  init_input_handling()

  append(&update_procs, update_aabbs)
  append(&draw_procs, draw_aabbs)
  init_camera()
  init_player()
  init_projectiles()
  init_level_gen()
  init_enemies()
  init_knockback()


  //late stuff
  init_eventsystems()

  for !rl.WindowShouldClose() {
    time.stopwatch_reset(&sw)
    time.stopwatch_start(&sw)

    time_now = float(rl.GetTime())
    dt = rl.GetFrameTime()


    //tick
    for &p in update_procs {
      p()
    }

    //late tick
    for &p in late_update_procs {
      p()
    }


    //Render

    // Render scene to bloom buffer
    begin_bloom_scene(&bloom_ctx)

    rl.BeginMode3D(camera)
    //rl.DrawGrid(100, 1)

    for &p in draw_procs {
      p()
    }

    rl.EndMode3D()
    end_bloom_scene(&bloom_ctx)

    rl.BeginDrawing()
    rl.ClearBackground(rl.BLACK)
    render_bloom(&bloom_ctx)
    
    // PERF METRICS DISPLAY
    if (rl.IsKeyPressed(.F1)) {
      PRINT_PERF_METRICS = !PRINT_PERF_METRICS
    }
    if PRINT_PERF_METRICS {
      rl.DrawFPS(10, 10)
      dur := time.stopwatch_duration(sw)
      rl.DrawText(rl.TextFormat("CPU %.2f", dur), 10, 40, 18, rl.WHITE)
    }

    rl.EndDrawing()


    //REST TEMP ALLOC
    free_all(context.temp_allocator)
    time.stopwatch_stop(&sw)
  }

  log.debug("\n")
  log.debug("==================== SHUT DOWN ====================\n")
  rl.CloseWindow()
}
