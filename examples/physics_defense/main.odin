package physics_defense_example

import rl "../../engine"
import systems "../../engine/systems"
import physics "../../engine/physics"
import input "../../engine/input"
import debug "../../engine/debug"
import ecs "../../Libraries/yggsECS"
import k2 "../../Libraries/karl2d"
import "core:math/rand"
import "core:fmt"

// ============================================================================
// Game Components
// ============================================================================

Player :: struct {}
Enemy :: struct {
	spawn_time: f32,
}
Bullet :: struct {}
Ground :: struct {}

// ============================================================================
// Game State
// ============================================================================

player_entity: ecs.EntityID
score: int = 0
game_time: f32 = 0
enemies_destroyed: int = 0

// ============================================================================
// Main
// ============================================================================

main :: proc() {
	// Create engine with custom config
	config := rl.Engine_Config{
		window_width     = 1280,
		window_height    = 720,
		window_title     = "Physics Defense - RazorLight Engine",
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
	systems.scheduler_add_system(scheduler, "enemy_spawn", .Update, enemy_spawn_system)
	systems.scheduler_add_system(scheduler, "collision", .Post_Update, collision_system)
	systems.scheduler_add_system(scheduler, "cleanup", .Post_Update, cleanup_system, priority = 10)

	// Register render system
	systems.scheduler_add_render_system(scheduler, "game_render", render_system)

	// Initialize game
	setup_game(world)

	// Enable debug drawing
	rl.engine_set_debug_enabled(engine, true)

	debug.log_info("=== PHYSICS DEFENSE GAME ===")
	debug.log_info("Move mouse to control your circle")
	debug.log_info("Click or SPACE to shoot bullets")
	debug.log_info("Press F1 to toggle debug view")
	debug.log_info("Press F2 to print profiler report")

	// Game loop
	for rl.engine_update(engine) {
		game_time += rl.engine_get_delta_time(engine)

		// Toggle debug with F1
		if input.input_key_pressed(.F1) {
			rl.engine_toggle_debug(engine)
		}

		// Print profile with F2
		if input.input_key_pressed(.F2) {
			rl.engine_print_profile(engine)
		}

		// Quit with Escape
		if input.input_key_pressed(.Escape) {
			break
		}

		rl.engine_render(engine)
	}

	debug.log_info("=== GAME OVER ===")
	debug.log_infof("Final Score: %d", score)
	debug.log_infof("Enemies Destroyed: %d", enemies_destroyed)
	debug.log_infof("Time Survived: %.1f seconds", game_time)
}

// ============================================================================
// Game Setup
// ============================================================================

setup_game :: proc(world: ^rl.World) {
	// Create ground
	ground := rl.world_create_static_box(world, {640, 660}, 1280, 120)
	rl.world_add_component(world, ground, Ground{})
	rl.world_add_component(world, ground, rl.Shape_Component{
		shape_type = .Rectangle,
		color = rl.GREEN,
		size = {1280, 120},
	})

	// Create player
	player_entity = rl.world_create_physics_circle(world, {640, 360}, 30, 1000, 0.3)
	rl.world_add_component(world, player_entity, Player{})
	rl.world_add_component(world, player_entity, rl.Shape_Component{
		shape_type = .Circle,
		color = rl.BLUE,
		size = {30, 30},  // radius in x
	})

	// Spawn initial enemies
	for i in 0..<5 {
		spawn_enemy(world, f32(200 + i * 100), 100)
	}
}

// ============================================================================
// Entity Spawning
// ============================================================================

spawn_enemy :: proc(world: ^rl.World, x, y: f32) {
	entity := rl.world_create_physics_box(world, {x, y}, 50, 50, 1.0, 0.3)
	rl.world_add_component(world, entity, Enemy{spawn_time = game_time})
	rl.world_add_component(world, entity, rl.Shape_Component{
		shape_type = .Rectangle,
		color = rl.RED,
		size = {50, 50},
	})
}

spawn_bullet :: proc(world: ^rl.World, x, y: f32) {
	entity := rl.world_create_physics_circle(world, {x, y}, 8, 0.1, 0.0)
	rl.world_add_component(world, entity, Bullet{})
	rl.world_add_component(world, entity, rl.Shape_Component{
		shape_type = .Circle,
		color = rl.YELLOW,
		size = {8, 8},
	})

	// Get the physics body and set velocity upward
	if circle := rl.world_get_component(world, entity, physics.Circle_Collider); circle != nil {
		physics.physics_set_velocity(circle.body_id, {0, -800})
		physics.physics_set_gravity_scale(circle.body_id, 0)  // Bullets ignore gravity
	}
}

// ============================================================================
// Game Systems
// ============================================================================

player_input_system :: proc(world_ptr: rawptr, dt: f32) {
	world := cast(^rl.World)world_ptr

	// Get player physics body
	if circle := rl.world_get_component(world, player_entity, physics.Circle_Collider); circle != nil {
		// Move player to mouse position
		mouse_pos := k2.get_mouse_position()
		physics.physics_set_position(circle.body_id, {mouse_pos.x, mouse_pos.y})

		// Shooting
		if input.input_key_pressed(.Space) || input.input_mouse_pressed(.Left) {
			spawn_bullet(world, mouse_pos.x, mouse_pos.y - 40)
		}
	}
}

enemy_spawn_system :: proc(world_ptr: rawptr, dt: f32) {
	world := cast(^rl.World)world_ptr

	// Spawn new enemies every 3 seconds
	@(static) last_spawn_time: f32 = 0

	if game_time - last_spawn_time >= 3.0 {
		spawn_x := rand.float32_range(100, 1180)
		spawn_enemy(world, spawn_x, 50)
		last_spawn_time = game_time
	}
}

collision_system :: proc(world_ptr: rawptr, dt: f32) {
	world := cast(^rl.World)world_ptr

	entities_to_remove: [dynamic]ecs.EntityID
	defer delete(entities_to_remove)

	// Check bullet-enemy collisions
	for bullet_arch in ecs.query(world.ecs, ecs.has(Bullet), ecs.has(rl.Transform)) {
		bullet_transforms := ecs.get_table(world.ecs, bullet_arch, rl.Transform)
		bullet_entities := bullet_arch.entities[:]

		for bullet_pos, bullet_idx in bullet_transforms {
			for enemy_arch in ecs.query(world.ecs, ecs.has(Enemy), ecs.has(rl.Transform)) {
				enemy_transforms := ecs.get_table(world.ecs, enemy_arch, rl.Transform)
				enemy_entities := enemy_arch.entities[:]

				for enemy_pos, enemy_idx in enemy_transforms {
					distance := rl.vec2_distance(bullet_pos.position, enemy_pos.position)

					if distance < 35 {
						append(&entities_to_remove, enemy_entities[enemy_idx])
						append(&entities_to_remove, bullet_entities[bullet_idx])
						enemies_destroyed += 1
						score += 100
					}
				}
			}
		}
	}

	// Remove collided entities
	for entity in entities_to_remove {
		if rl.world_entity_exists(world, entity) {
			rl.world_remove_entity(world, entity)
		}
	}
}

cleanup_system :: proc(world_ptr: rawptr, dt: f32) {
	world := cast(^rl.World)world_ptr

	entities_to_remove: [dynamic]ecs.EntityID
	defer delete(entities_to_remove)

	// Remove bullets that are off screen
	for arch in ecs.query(world.ecs, ecs.has(Bullet), ecs.has(rl.Transform)) {
		transforms := ecs.get_table(world.ecs, arch, rl.Transform)
		entities := arch.entities[:]

		for pos, i in transforms {
			if pos.position.y < -100 || pos.position.y > 800 || pos.position.x < -100 || pos.position.x > 1380 {
				append(&entities_to_remove, entities[i])
			}
		}
	}

	// Remove enemies that fell off screen
	for arch in ecs.query(world.ecs, ecs.has(Enemy), ecs.has(rl.Transform)) {
		transforms := ecs.get_table(world.ecs, arch, rl.Transform)
		entities := arch.entities[:]

		for pos, i in transforms {
			if pos.position.y > 750 {
				append(&entities_to_remove, entities[i])
				score -= 50  // Penalty for missing
			}
		}
	}

	for entity in entities_to_remove {
		if rl.world_entity_exists(world, entity) {
			rl.world_remove_entity(world, entity)
		}
	}
}

// ============================================================================
// Render System
// ============================================================================

render_system :: proc(world_ptr: rawptr) {
	world := cast(^rl.World)world_ptr

	// Draw ground
	for arch in ecs.query(world.ecs, ecs.has(Ground), ecs.has(rl.Transform), ecs.has(rl.Shape_Component)) {
		transforms := ecs.get_table(world.ecs, arch, rl.Transform)
		shapes := ecs.get_table(world.ecs, arch, rl.Shape_Component)

		for i in 0..<len(transforms) {
			t := transforms[i]
			s := shapes[i]

			rect := k2.Rect{
				t.position.x - s.size.x / 2,
				t.position.y - s.size.y / 2,
				s.size.x,
				s.size.y,
			}
			k2.draw_rect(rect, s.color)
		}
	}

	// Draw enemies (boxes)
	for arch in ecs.query(world.ecs, ecs.has(Enemy), ecs.has(rl.Transform), ecs.has(rl.Shape_Component)) {
		transforms := ecs.get_table(world.ecs, arch, rl.Transform)
		shapes := ecs.get_table(world.ecs, arch, rl.Shape_Component)

		for i in 0..<len(transforms) {
			t := transforms[i]
			s := shapes[i]

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

	// Draw player and bullets (circles)
	for arch in ecs.query(world.ecs, ecs.has(rl.Transform), ecs.has(rl.Shape_Component)) {
		transforms := ecs.get_table(world.ecs, arch, rl.Transform)
		shapes := ecs.get_table(world.ecs, arch, rl.Shape_Component)

		for i in 0..<len(transforms) {
			t := transforms[i]
			s := shapes[i]

			if s.shape_type == .Circle {
				k2.draw_circle(k2.Vec2{t.position.x, t.position.y}, s.size.x, s.color)
			}
		}
	}

	// Draw UI
	score_text := fmt.tprintf("Score: %d  |  Destroyed: %d  |  Time: %.1f", score, enemies_destroyed, game_time)
	k2.draw_text(score_text, k2.Vec2{10, 10}, 24, rl.BLACK)

	fps_text := fmt.tprintf("FPS: %.0f", k2.get_frame_time() > 0 ? 1.0 / k2.get_frame_time() : 0)
	k2.draw_text(fps_text, k2.Vec2{10, 40}, 18, rl.DARK_GRAY)
}
