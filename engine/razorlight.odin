package razorlight

import k2 "../Libraries/karl2d"
import core "core"
import systems "systems"
import input "input"
import debug "debug"
import builtin "systems/builtin"
import physics "physics"

// Re-export commonly used types from core
Vec2 :: core.Vec2
Vec3 :: core.Vec3
Color :: core.Color
Transform :: core.Transform
Shape_Component :: core.Shape_Component
Shape_Type :: core.Shape_Type
Sprite_Component :: core.Sprite_Component
Engine_Config :: core.Engine_Config
World :: core.World
Time_State :: core.Time_State

// Re-export colors
WHITE       :: core.WHITE
BLACK       :: core.BLACK
RED         :: core.RED
GREEN       :: core.GREEN
BLUE        :: core.BLUE
YELLOW      :: core.YELLOW
ORANGE      :: core.ORANGE
PURPLE      :: core.PURPLE
MAGENTA     :: core.MAGENTA
LIGHT_BLUE  :: core.LIGHT_BLUE
LIGHT_GREEN :: core.LIGHT_GREEN
LIGHT_GRAY  :: core.LIGHT_GRAY
DARK_GRAY   :: core.DARK_GRAY
PINK        :: core.PINK
CYAN        :: core.CYAN

// Re-export utility functions
vec2_length    :: core.vec2_length
vec2_normalize :: core.vec2_normalize
vec2_distance  :: core.vec2_distance
vec2_lerp      :: core.vec2_lerp
color_alpha    :: core.color_alpha

// ============================================================================
// Engine
// ============================================================================

Engine :: struct {
	config:     Engine_Config,
	world:      ^World,
	scheduler:  ^systems.System_Scheduler,
	time:       ^Time_State,
	input:      ^input.Input_State,
	debug:      ^debug.Debug_Context,

	is_running: bool,
}

// ============================================================================
// Lifecycle
// ============================================================================

// Create and initialize the engine
engine_create :: proc(config := core.DEFAULT_ENGINE_CONFIG) -> ^Engine {
	engine := new(Engine)
	engine.config = config

	// Initialize karl2d
	k2.init(int(config.window_width), int(config.window_height), config.window_title)

	// Initialize subsystems
	engine.time = core.time_create(config.fixed_timestep)
	engine.input = input.input_create()
	engine.debug = debug.debug_context_create()
	engine.world = core.world_create(config)
	engine.scheduler = systems.scheduler_create()

	// Initialize profiler
	debug.profiler_init()

	engine.is_running = true

	// Register built-in systems
	engine_register_builtin_systems(engine)

	debug.log_info("RazorLight Engine initialized")
	debug.log_infof("Window: %dx%d", config.window_width, config.window_height)

	return engine
}

// Destroy the engine and free resources
engine_destroy :: proc(engine: ^Engine) {
	if engine == nil {
		return
	}

	debug.log_info("Shutting down RazorLight Engine")

	core.world_destroy(engine.world)
	systems.scheduler_destroy(engine.scheduler)
	core.time_destroy(engine.time)
	input.input_destroy(engine.input)
	debug.debug_context_destroy(engine.debug)
	debug.profiler_shutdown()

	k2.shutdown()

	free(engine)
}

// ============================================================================
// Main Loop
// ============================================================================

// Update the engine - returns false when the game should exit
engine_update :: proc(engine: ^Engine) -> bool {
	// Check for window close
	if !k2.update() || !engine.is_running {
		return false
	}

	// Begin frame profiling
	debug.profiler_begin_frame()
	systems.scheduler_begin_frame(engine.scheduler)

	// Get frame time
	dt := k2.get_frame_time()
	core.time_update(engine.time, dt)

	// Update input
	input.input_update(engine.input)

	// Run pre-update systems
	debug.profiler_begin("pre_update")
	systems.scheduler_run_phase(engine.scheduler, engine.world, engine.time.delta_time, .Pre_Update)
	debug.profiler_end("pre_update")

	// Run update systems
	debug.profiler_begin("update")
	systems.scheduler_run_phase(engine.scheduler, engine.world, engine.time.delta_time, .Update)
	debug.profiler_end("update")

	// Run fixed update systems (physics) with accumulator
	debug.profiler_begin("fixed_update")
	for core.time_should_fixed_update(engine.time) {
		systems.scheduler_run_phase(engine.scheduler, engine.world, engine.time.fixed_timestep, .Fixed_Update)
		core.time_consume_fixed_step(engine.time)
	}
	debug.profiler_end("fixed_update")

	// Run post-update systems
	debug.profiler_begin("post_update")
	systems.scheduler_run_phase(engine.scheduler, engine.world, engine.time.delta_time, .Post_Update)
	debug.profiler_end("post_update")

	return true
}

// Render the current frame
engine_render :: proc(engine: ^Engine) {
	debug.profiler_begin("render")

	k2.clear(engine.config.clear_color)

	// Run render systems
	systems.scheduler_run_render(engine.scheduler, engine.world)

	// Debug rendering
	debug.debug_render(engine.debug, engine.world)

	k2.present()

	debug.profiler_end("render")

	// End frame profiling
	systems.scheduler_end_frame(engine.scheduler)
	debug.profiler_end_frame()
}

// ============================================================================
// Built-in Systems Registration
// ============================================================================

@(private)
engine_register_builtin_systems :: proc(engine: ^Engine) {
	// Physics step (runs during Fixed_Update)
	systems.scheduler_add_system(
		engine.scheduler,
		"physics_step",
		.Fixed_Update,
		builtin.physics_step_system,
		priority = 0,  // Run first
	)

	// Physics sync (runs after physics step)
	systems.scheduler_add_system(
		engine.scheduler,
		"physics_sync",
		.Fixed_Update,
		builtin.physics_sync_system,
		priority = 10,  // Run after physics_step
	)
}

// ============================================================================
// Control
// ============================================================================

engine_quit :: proc(engine: ^Engine) {
	engine.is_running = false
}

engine_is_running :: proc(engine: ^Engine) -> bool {
	return engine.is_running
}

// ============================================================================
// Accessors
// ============================================================================

engine_get_world :: proc(engine: ^Engine) -> ^World {
	return engine.world
}

engine_get_scheduler :: proc(engine: ^Engine) -> ^systems.System_Scheduler {
	return engine.scheduler
}

engine_get_time :: proc(engine: ^Engine) -> ^Time_State {
	return engine.time
}

engine_get_input :: proc(engine: ^Engine) -> ^input.Input_State {
	return engine.input
}

engine_get_debug :: proc(engine: ^Engine) -> ^debug.Debug_Context {
	return engine.debug
}

// ============================================================================
// Convenience Functions
// ============================================================================

// Get delta time for current frame
engine_get_delta_time :: proc(engine: ^Engine) -> f32 {
	return engine.time.delta_time
}

// Get FPS
engine_get_fps :: proc(engine: ^Engine) -> f32 {
	return engine.time.fps
}

// Toggle debug visualization
engine_toggle_debug :: proc(engine: ^Engine) {
	engine.debug.enabled = !engine.debug.enabled
}

// Enable/disable debug visualization
engine_set_debug_enabled :: proc(engine: ^Engine, enabled: bool) {
	engine.debug.enabled = enabled
}

// Print profiler report to console
engine_print_profile :: proc(engine: ^Engine) {
	debug.profiler_print_report()
}

// ============================================================================
// World Helpers (Re-exported for convenience)
// ============================================================================

world_create_entity :: core.world_create_entity
world_remove_entity :: core.world_remove_entity
world_entity_exists :: core.world_entity_exists
world_add_component :: core.world_add_component
world_get_component :: core.world_get_component
world_create_static_box :: core.world_create_static_box
world_create_physics_box :: core.world_create_physics_box
world_create_physics_circle :: core.world_create_physics_circle
