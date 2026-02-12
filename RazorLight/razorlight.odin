package razorlight

import k2 "libs/karl2d"
import ecs "libs/yggsECS"
import core "core"
import systems "systems"
import input "input"
import debug "debug"
import builtin "systems/builtin"
import physics "physics"

// ============================================================================
// Re-export: Core Types
// ============================================================================

Vec2              :: core.Vec2
Vec3              :: core.Vec3
Color             :: core.Color
Transform         :: core.Transform
Shape_Component   :: core.Shape_Component
Shape_Type        :: core.Shape_Type
Sprite_Component  :: core.Sprite_Component
Engine_Config     :: core.Engine_Config
World             :: core.World
Time_State        :: core.Time_State
Window_Mode       :: core.Window_Mode

// ============================================================================
// Re-export: Animation Types
// ============================================================================

Animation              :: core.Animation
Animation_Frame        :: core.Animation_Frame
Animation_Set          :: core.Animation_Set
Animation_Component    :: core.Animation_Component
Animation_Loop_Mode    :: core.Animation_Loop_Mode

// ============================================================================
// Re-export: Colors
// ============================================================================

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

// ============================================================================
// Re-export: Utility Functions
// ============================================================================

vec2_length    :: core.vec2_length
vec2_normalize :: core.vec2_normalize
vec2_distance  :: core.vec2_distance
vec2_lerp      :: core.vec2_lerp
color_alpha    :: core.color_alpha

// ============================================================================
// Re-export: Drawing (from karl2d)
// ============================================================================

draw_rect           :: k2.draw_rect
draw_rect_ex        :: k2.draw_rect_ex
draw_rect_outline   :: k2.draw_rect_outline
draw_circle         :: k2.draw_circle
draw_circle_outline :: k2.draw_circle_outline
draw_line           :: k2.draw_line
draw_text           :: k2.draw_text
measure_text        :: k2.measure_text
draw_texture        :: k2.draw_texture

Rect    :: k2.Rect
Texture :: k2.Texture
Font    :: k2.Font
Camera  :: k2.Camera

load_texture_from_file :: k2.load_texture_from_file

// ============================================================================
// Re-export: Physics Types
// ============================================================================

Collider        :: physics.Collider
Collider_Shape  :: physics.Collider_Shape
Box             :: physics.Box
Circle          :: physics.Circle
Rigidbody       :: physics.Rigidbody
Body_Type       :: physics.Body_Type
BodyId          :: physics.BodyId
Raycast_Hit     :: physics.Raycast_Hit
Character_Body  :: physics.Character_Body
EntityID        :: ecs.EntityID

// ============================================================================
// Re-export: Physics Functions (low-level, for power users)
// ============================================================================

physics_apply_force        :: physics.physics_apply_force
physics_apply_impulse      :: physics.physics_apply_impulse
physics_set_velocity       :: physics.physics_set_velocity
physics_get_velocity       :: physics.physics_get_velocity
physics_get_position       :: physics.physics_get_position
physics_get_rotation       :: physics.physics_get_rotation
physics_raycast            :: physics.physics_raycast
physics_create_dynamic_body      :: physics.physics_create_dynamic_body
physics_create_static_body       :: physics.physics_create_static_body
physics_add_box_shape            :: physics.physics_add_box_shape
physics_add_circle_shape         :: physics.physics_add_circle_shape
screen_to_physics                :: physics.screen_to_physics
physics_to_screen                :: physics.physics_to_screen
character_body_move_and_slide    :: physics.character_body_move_and_slide
character_body_set_position      :: physics.character_body_set_position

// ============================================================================
// Re-export: Systems
// ============================================================================

System_Phase       :: systems.System_Phase
System_Update_Proc :: systems.System_Update_Proc
System_Render_Proc :: systems.System_Render_Proc
System_Scheduler   :: systems.System_Scheduler

add_system        :: systems.scheduler_add_system
add_render_system :: systems.scheduler_add_render_system
scheduler_set_enabled       :: systems.scheduler_set_enabled

// ============================================================================
// Re-export: Input Types
// ============================================================================

Keyboard_Key   :: input.Keyboard_Key
Mouse_Button   :: input.Mouse_Button
Gamepad_Button :: input.Gamepad_Button
Gamepad_Axis   :: input.Gamepad_Axis
Input_State    :: input.Input_State

// ============================================================================
// Re-export: Input Functions
// ============================================================================

key_is_held    :: input.input_key_held
key_went_down  :: input.input_key_pressed
key_went_up    :: input.input_key_released
mouse_is_held  :: input.input_mouse_held
mouse_went_down :: input.input_mouse_pressed
mouse_went_up  :: input.input_mouse_released

get_mouse_position   :: k2.get_mouse_position
get_mouse_delta      :: k2.get_mouse_delta
get_movement_vector  :: input.input_get_movement_vector

input_bind_keys        :: input.input_bind_keys
input_is_action_held   :: input.input_is_action_held
input_is_action_pressed :: input.input_is_action_pressed

// ============================================================================
// Re-export: Windowing
// ============================================================================

get_screen_width  :: k2.get_screen_width
get_screen_height :: k2.get_screen_height

// ============================================================================
// Re-export: Debug / Logging
// ============================================================================

log_info    :: debug.log_info
log_warn    :: debug.log_warn
log_error   :: debug.log_error
log_debug   :: debug.log_debug
log_infof   :: debug.log_infof
log_warnf   :: debug.log_warnf
log_errorf  :: debug.log_errorf

// ============================================================================
// Re-export: Animation Functions
// ============================================================================

Animation_Set_Handle            :: core.Animation_Set_Handle
INVALID_ANIMATION_SET           :: core.INVALID_ANIMATION_SET

animation_play                  :: core.animation_play
animation_start                 :: core.animation_start
animation_stop                  :: core.animation_stop
animation_pause                 :: core.animation_pause
animation_resume                :: core.animation_resume
animation_reset                 :: core.animation_reset
animation_set_speed             :: core.animation_set_speed
animation_set_frame             :: core.animation_set_frame
animation_is_finished           :: core.animation_is_finished
animation_get_current_frame     :: core.animation_get_current_frame
animation_get_texture           :: core.animation_get_texture

// Animation Registry (centralized storage for animation sets)
Animation_Registry              :: core.Animation_Registry
animation_registry_create       :: core.animation_registry_create
animation_registry_destroy      :: core.animation_registry_destroy
animation_registry_register     :: core.animation_registry_register
animation_registry_unregister   :: core.animation_registry_unregister
animation_registry_get          :: core.animation_registry_get
animation_registry_get_anim     :: core.animation_registry_get_anim
animation_registry_is_valid     :: core.animation_registry_is_valid

// ============================================================================
// Re-export: Animation I/O
// ============================================================================

animation_set_load              :: core.animation_set_load
animation_set_load_with_texture :: core.animation_set_load_with_texture
animation_set_save              :: core.animation_set_save
animation_set_destroy           :: core.animation_set_destroy

// ============================================================================
// Re-export: Hot-Reload Types
// ============================================================================

Game_API             :: core.Game_API
Game_Init_Proc       :: core.Game_Init_Proc
Game_Update_Proc     :: core.Game_Update_Proc
Game_Render_Proc     :: core.Game_Render_Proc
Game_Shutdown_Proc   :: core.Game_Shutdown_Proc
Game_On_Reload_Proc  :: core.Game_On_Reload_Proc
Game_State_Size_Proc :: core.Game_State_Size_Proc
Hot_Reload_Host      :: core.Hot_Reload_Host

// ============================================================================
// Re-export: Hot-Reload Functions
// ============================================================================

hot_reload_host_create  :: core.hot_reload_host_create
hot_reload_host_destroy :: core.hot_reload_host_destroy
hot_reload_load         :: core.hot_reload_load
hot_reload_check        :: core.hot_reload_check
hot_reload_reload       :: core.hot_reload_reload
hot_reload_get_api      :: core.hot_reload_get_api

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

	is_running:            bool,
	resolution_camera:     Camera,
	use_resolution_scaling: bool,
}
DefaultConfig := Engine_Config{
		window_width     = 1280,
		window_height    = 720,
		window_title     = "RazorLight",
		fixed_timestep   = 1.0 / 60.0,
		physics_substeps = 4,
		gravity          = {0, 900},
		pixels_per_meter = 40,
		clear_color      = Color{20, 20, 30, 255},
		design_width     = 1280,
		design_height    = 720,
		window_mode      = .Borderless_Fullscreen,
	}
// ============================================================================
// Lifecycle
// ============================================================================

// Create and initialize the engine
engine_create :: proc(config := core.DEFAULT_ENGINE_CONFIG) -> ^Engine {
	engine := new(Engine)
	engine.config = config

	// Initialize karl2d
	k2.init(int(config.window_width), int(config.window_height), config.window_title,
		options = k2.Init_Options{window_mode = k2.Window_Mode(config.window_mode)})

	// Set up resolution scaling if design resolution is specified
	if config.design_width > 0 && config.design_height > 0 {
		engine.use_resolution_scaling = true
	}

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

	update_resolution_camera(engine)
	k2.clear(engine.config.clear_color)

	if engine.use_resolution_scaling {
		k2.set_camera(engine.resolution_camera)
	}

	// Run render systems
	systems.scheduler_run_render(engine.scheduler, engine.world)

	// Debug rendering
	debug.debug_render(engine.debug, engine.world)

	if engine.use_resolution_scaling {
		k2.set_camera(nil)
	}

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

	// Character body sync (runs after physics sync)
	systems.scheduler_add_system(
		engine.scheduler,
		"character_body_sync",
		.Fixed_Update,
		builtin.character_body_sync_system,
		priority = 15,  // Run after physics_sync
	)

	// Animation update (runs during Update phase, after user logic)
	systems.scheduler_add_system(
		engine.scheduler,
		"animation_update",
		.Update,
		builtin.animation_update_system,
		priority = 90,  // Run after user game logic
	)

	// Built-in shape renderer (runs during Render phase)
	systems.scheduler_add_render_system(
		engine.scheduler,
		"shape_render",
		builtin.shape_render_system,
		priority = 0,  // Run first in render
	)

	// Built-in sprite renderer (runs during Render phase, after shapes)
	systems.scheduler_add_render_system(
		engine.scheduler,
		"sprite_render",
		builtin.sprite_render_system,
		priority = 5,  // Run after shape_render
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

get_world :: proc(engine: ^Engine) -> ^World {
	return engine.world
}

get_scheduler :: proc(engine: ^Engine) -> ^systems.System_Scheduler {
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
// Resolution Scaling
// ============================================================================

@(private)
update_resolution_camera :: proc(engine: ^Engine) {
	if !engine.use_resolution_scaling { return }

	design_w := f32(engine.config.design_width)
	design_h := f32(engine.config.design_height)
	actual_w := f32(k2.get_screen_width())
	actual_h := f32(k2.get_screen_height())

	scale := min(actual_w / design_w, actual_h / design_h)
	offset_x := (actual_w - design_w * scale) / 2
	offset_y := (actual_h - design_h * scale) / 2

	engine.resolution_camera = Camera{
		target = {0, 0},
		offset = {offset_x, offset_y},
		zoom   = scale,
	}
}

// Returns the design width if resolution scaling is active, otherwise the actual window width
engine_design_width :: proc(engine: ^Engine) -> i32 {
	if engine.use_resolution_scaling {
		return engine.config.design_width
	}
	return i32(k2.get_screen_width())
}

// Returns the design height if resolution scaling is active, otherwise the actual window height
engine_design_height :: proc(engine: ^Engine) -> i32 {
	if engine.use_resolution_scaling {
		return engine.config.design_height
	}
	return i32(k2.get_screen_height())
}

// Returns mouse position in design coordinates (accounts for resolution scaling)
engine_mouse_position :: proc(engine: ^Engine) -> Vec2 {
	raw := k2.get_mouse_position()
	if engine.use_resolution_scaling {
		return k2.screen_to_world(raw, engine.resolution_camera)
	}
	return {raw.x, raw.y}
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
// Entity Helpers (non-polymorphic, can be aliased)
// ============================================================================

create_entity  :: core.create_entity
remove_entity  :: core.remove_entity
entity_exists  :: core.world_entity_exists

// ============================================================================
// Entity-Based Physics (non-polymorphic, can be aliased)
// ============================================================================

set_velocity   :: core.set_velocity
get_velocity   :: core.get_velocity
apply_force    :: core.apply_force
apply_impulse  :: core.apply_impulse
set_position     :: core.set_position
get_position     :: core.get_position

// Physics initialization (call after adding all required components)
try_init_physics :: core.try_init_physics

// ============================================================================
// Polymorphic Component API (defined directly — cannot be aliased across packages)
// ============================================================================

// Add a component to an entity. Auto-initializes physics when Rigidbody, Collider, or Character_Body is added.
add_component :: proc(world: ^World, entity: ecs.EntityID, component: $T) {
	ecs.add_component(world.ecs, entity, component)
	when T == physics.Rigidbody || T == physics.Collider {
		core.try_init_physics(world, entity)
	}
	when T == physics.Character_Body || T == core.Transform {
		core.try_init_character_body(world, entity)
	}
}

// Get a mutable pointer to an entity's component
get_component :: proc(world: ^World, entity: ecs.EntityID, $T: typeid) -> ^T {
	return ecs.get(world.ecs, entity, T)
}

// Check if an entity has a component
has_component :: proc(world: ^World, entity: ecs.EntityID, $T: typeid) -> bool {
	return ecs.has_component(world.ecs, entity, T)
}

// Remove a component from an entity
remove_component :: proc(world: ^World, entity: ecs.EntityID, $T: typeid) {
	ecs.remove_component(world.ecs, entity, T)
}

// ============================================================================
// Query Wrappers (polymorphic — wraps ecs.iter* to accept ^World)
// ============================================================================

QueryIter1 :: ecs.QueryIter1
QueryIter2 :: ecs.QueryIter2
QueryIter3 :: ecs.QueryIter3
QueryIter4 :: ecs.QueryIter4

query1 :: proc(world: ^World, $A: typeid) -> ecs.QueryIter1(A) {
	return ecs.iter1(world.ecs, A)
}
query2 :: proc(world: ^World, $A, $B: typeid) -> ecs.QueryIter2(A, B) {
	return ecs.iter2(world.ecs, A, B)
}
query3 :: proc(world: ^World, $A, $B, $C: typeid) -> ecs.QueryIter3(A, B, C) {
	return ecs.iter3(world.ecs, A, B, C)
}
query4 :: proc(world: ^World, $A, $B, $C, $D: typeid) -> ecs.QueryIter4(A, B, C, D) {
	return ecs.iter4(world.ecs, A, B, C, D)
}

query1_next :: proc(it: ^ecs.QueryIter1($A)) -> (entity: ecs.EntityID, a: ^A, ok: bool) {
	return ecs.iter1_next(it)
}
query2_next :: proc(it: ^ecs.QueryIter2($A, $B)) -> (entity: ecs.EntityID, a: ^A, b: ^B, ok: bool) {
	return ecs.iter2_next(it)
}
query3_next :: proc(it: ^ecs.QueryIter3($A, $B, $C)) -> (entity: ecs.EntityID, a: ^A, b: ^B, c: ^C, ok: bool) {
	return ecs.iter3_next(it)
}
query4_next :: proc(it: ^ecs.QueryIter4($A, $B, $C, $D)) -> (entity: ecs.EntityID, a: ^A, b: ^B, c: ^C, d: ^D, ok: bool) {
	return ecs.iter4_next(it)
}

// ============================================================================
// Spawn/Build Pattern (polymorphic — wraps ecs builder with auto physics init)
// ============================================================================

Spawn_Builder :: struct {
	world:       ^World,
	ecs_builder: ecs.EntityBuilder,
}

spawn :: proc(world: ^World) -> Spawn_Builder {
	return {world = world, ecs_builder = ecs.spawn(world.ecs)}
}

with :: proc(builder: Spawn_Builder, component: $T) -> Spawn_Builder {
	return {world = builder.world, ecs_builder = ecs.with(builder.ecs_builder, component)}
}

build :: proc(builder: Spawn_Builder) -> ecs.EntityID {
	entity := ecs.build(builder.ecs_builder)
	core.try_init_physics(builder.world, entity)
	core.try_init_character_body(builder.world, entity)
	return entity
}
