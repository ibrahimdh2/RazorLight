package test

import rl "../../engine"
import systems "../../engine/systems"
import physics "../../engine/physics"
import input "../../engine/input"
import debug "../../engine/debug"
import ecs "../../Libraries/yggsECS"
import k2 "../../Libraries/karl2d"
import "core:fmt"

// ============================================================================
// Game Components
// ============================================================================

Player :: struct {
	speed: f32,
}

// ============================================================================
// Game State
// ============================================================================

player_entity: ecs.EntityID

// ============================================================================
// Main
// ============================================================================

main :: proc() {
	// Create engine with custom config
	config := rl.Engine_Config{
		window_width     = 1280,
		window_height    = 720,
		window_title     = "test",
		fixed_timestep   = 1.0 / 60.0,
		physics_substeps = 4,
		gravity          = {0, 900},
		pixels_per_meter = 40,
		clear_color      = rl.LIGHT_BLUE,
	}

	engine := rl.engine_create(config)
	defer rl.engine_destroy(engine)

	world := rl.engine_get_world(engine)
	scheduler := rl.engine_get_scheduler(engine)

	// Register game systems
	systems.scheduler_add_system(scheduler, "player_input", .Pre_Update, player_input_system)

	// Register render system
	systems.scheduler_add_render_system(scheduler, "game_render", render_system)

	// Initialize game
	setup_game(world)

	debug.log_info("=== test ===")
	debug.log_info("Press F1 to toggle debug view")
	debug.log_info("Press Escape to quit")

	// Game loop
	for rl.engine_update(engine) {
		// Toggle debug with F1
		if input.input_key_pressed(.F1) {
			rl.engine_toggle_debug(engine)
		}

		// Quit with Escape
		if input.input_key_pressed(.Escape) {
			break
		}

		rl.engine_render(engine)
	}

	debug.log_info("Game ended")
}

// ============================================================================
// Game Setup
// ============================================================================

setup_game :: proc(world: ^rl.World) {
	// Create player
	player_entity = rl.world_create_physics_circle(world, {640, 360}, 30, 1.0, 0.3)
	rl.world_add_component(world, player_entity, Player{speed = 200})
	rl.world_add_component(world, player_entity, rl.Shape_Component{
		shape_type = .Circle,
		color = rl.BLUE,
		size = {30, 30},
	})

	// Create ground
	ground := rl.world_create_static_box(world, {640, 660}, 1280, 120)
	rl.world_add_component(world, ground, rl.Shape_Component{
		shape_type = .Rectangle,
		color = rl.GREEN,
		size = {1280, 120},
	})
}

// ============================================================================
// Game Systems
// ============================================================================

player_input_system :: proc(world_ptr: rawptr, dt: f32) {
	world := cast(^rl.World)world_ptr

	if player := rl.world_get_component(world, player_entity, Player); player != nil {
		if circle := rl.world_get_component(world, player_entity, physics.Circle_Collider); circle != nil {
			vel_x: f32 = 0
			vel_y: f32 = 0

			if input.input_key_held(.A) || input.input_key_held(.Left) {
				vel_x = -player.speed
			}
			if input.input_key_held(.D) || input.input_key_held(.Right) {
				vel_x = player.speed
			}
			if input.input_key_pressed(.Space) || input.input_key_pressed(.W) || input.input_key_pressed(.Up) {
				vel_y = -400  // Jump
			}

			current_vel := physics.physics_get_velocity(circle.body_id)
			physics.physics_set_velocity(circle.body_id, {vel_x, current_vel.y + vel_y})
		}
	}
}

// ============================================================================
// Render System
// ============================================================================

render_system :: proc(world_ptr: rawptr) {
	world := cast(^rl.World)world_ptr

	// Draw all shapes
	for arch in ecs.query(world.ecs, ecs.has(rl.Transform), ecs.has(rl.Shape_Component)) {
		transforms := ecs.get_table(world.ecs, arch, rl.Transform)
		shapes := ecs.get_table(world.ecs, arch, rl.Shape_Component)

		for i in 0..<len(transforms) {
			t := transforms[i]
			s := shapes[i]

			if s.shape_type == .Circle {
				k2.draw_circle(k2.Vec2{t.position.x, t.position.y}, s.size.x, s.color)
			} else {
				rect := k2.Rect{
					t.position.x - s.size.x / 2,
					t.position.y - s.size.y / 2,
					s.size.x,
					s.size.y,
				}
				origin := k2.Vec2{s.size.x / 2, s.size.y / 2}
				k2.draw_rect_ex(rect, origin, t.rotation, s.color)
			}
		}
	}

	// Draw UI
	fps_text := fmt.tprintf("FPS: %.0f", k2.get_frame_time() > 0 ? 1.0 / k2.get_frame_time() : 0)
	k2.draw_text(fps_text, k2.Vec2{10, 10}, 18, rl.BLACK)
}
