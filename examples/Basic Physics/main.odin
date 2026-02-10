package demo

import rl "../RazorLight"
import "core:fmt"
import "core:math/rand"

// ============================================================================
// Bouncing Balls Demo
// ============================================================================
// Click to spawn random-colored balls that bounce around.
// ESC to quit, F1 to toggle debug visualization.

// Tag components
Ball_Tag :: struct {}
Wall_Tag :: struct {}

// Game state
Game :: struct {
	engine:      ^rl.Engine,
	ball_count:  int,
}

game: Game

main :: proc() {
	config := rl.Engine_Config{
		window_width     = 1280,
		window_height    = 720,
		window_title     = "RazorLight Demo - Bouncing Balls",
		fixed_timestep   = 1.0 / 60.0,
		physics_substeps = 4,
		gravity          = {0, 900},
		pixels_per_meter = 40,
		clear_color      = rl.Color{30, 30, 40, 255},
		design_width     = 1280,
		design_height    = 720,
		window_mode      = .Borderless_Fullscreen,
	}

	game.engine = rl.engine_create(config)
	defer rl.engine_destroy(game.engine)

	world := rl.engine_get_world(game.engine)
	sched := rl.engine_get_scheduler(game.engine)

	// Create boundaries
	create_boundaries(world)

	// Register custom systems
	rl.add_system(sched, "input", .Pre_Update, input_system)
	rl.add_render_system(sched, "hud", hud_render_system, priority = 100)

	// Main loop
	for rl.engine_update(game.engine) {
		rl.engine_render(game.engine)
	}
}

// ============================================================================
// Boundary Creation
// ============================================================================

create_boundaries :: proc(world: ^rl.World) {
	// Ground (static body — no Rigidbody needed)
	ground := rl.create_entity(world)
	rl.add_component(world, ground, rl.Transform{position = {640, 700}, scale = {1, 1}})
	rl.add_component(world, ground, rl.Collider{shape = rl.Box{1280, 40}})
	rl.add_component(world, ground, rl.Shape_Component{
		shape_type = .Rectangle,
		color      = rl.Color{80, 80, 80, 255},
		size       = {1280, 40},
		visible    = true,
	})
	rl.add_component(world, ground, Wall_Tag{})

	// Left wall
	left := rl.create_entity(world)
	rl.add_component(world, left, rl.Transform{position = {-20, 360}, scale = {1, 1}})
	rl.add_component(world, left, rl.Collider{shape = rl.Box{40, 720}})
	rl.add_component(world, left, rl.Shape_Component{
		shape_type = .Rectangle,
		color      = rl.Color{80, 80, 80, 255},
		size       = {40, 720},
		visible    = true,
	})
	rl.add_component(world, left, Wall_Tag{})

	// Right wall
	right := rl.create_entity(world)
	rl.add_component(world, right, rl.Transform{position = {1300, 360}, scale = {1, 1}})
	rl.add_component(world, right, rl.Collider{shape = rl.Box{40, 720}})
	rl.add_component(world, right, rl.Shape_Component{
		shape_type = .Rectangle,
		color      = rl.Color{80, 80, 80, 255},
		size       = {40, 720},
		visible    = true,
	})
	rl.add_component(world, right, Wall_Tag{})
}

// ============================================================================
// Input System
// ============================================================================

input_system :: proc(world_ptr: rawptr, dt: f32) {
	world := cast(^rl.World)world_ptr

	// ESC to quit
	if rl.key_went_down(.Escape) {
		rl.engine_quit(game.engine)
	}

	// F1 to toggle debug
	if rl.key_went_down(.F1) {
		rl.engine_toggle_debug(game.engine)
	}

	// Click to spawn ball
	if rl.mouse_went_down(.Left) {
		spawn_ball(world)
	}

	// Right click to spawn many balls
	if rl.mouse_is_held(.Right) {
		spawn_ball(world)
	}
}

// ============================================================================
// Ball Spawning
// ============================================================================

spawn_ball :: proc(world: ^rl.World) {
	pos := rl.engine_mouse_position(game.engine)

	// Random radius
	radius := rand.float32_range(10, 30)

	// Random bounciness
	restitution := rand.float32_range(0.3, 0.9)

	// Random color
	color := rl.Color{
		u8(rand.uint32() % 200 + 55),
		u8(rand.uint32() % 200 + 55),
		u8(rand.uint32() % 200 + 55),
		255,
	}

	// Create physics circle using composable components
	entity := rl.create_entity(world)
	rl.add_component(world, entity, rl.Transform{position = pos, scale = {1, 1}})
	rl.add_component(world, entity, rl.Rigidbody{body_type = .Dynamic, gravity_scale = 1.0})
	rl.add_component(world, entity, rl.Collider{
		shape       = rl.Circle{radius},
		density     = 1.0,
		friction    = 0.3,
		restitution = restitution,
	})
	rl.add_component(world, entity, rl.Shape_Component{
		shape_type = .Circle,
		color      = color,
		size       = {radius, radius},
		visible    = true,
	})
	rl.add_component(world, entity, Ball_Tag{})

	game.ball_count += 1
}

// ============================================================================
// HUD Render System
// ============================================================================

hud_render_system :: proc(world_ptr: rawptr) {
	// Draw ball count
	rl.draw_text(
		fmt.tprintf("Balls: %d", game.ball_count),
		{10, 10},
		20,
		rl.WHITE,
	)

	// Draw FPS
	rl.draw_text(
		fmt.tprintf("FPS: %.0f", rl.engine_get_fps(game.engine)),
		{10, 35},
		16,
		rl.LIGHT_GRAY,
	)

	// Draw instructions
	rl.draw_text("Click to spawn balls | Right-click to spray | F1: Debug | ESC: Quit",
		{10, f32(rl.engine_design_height(game.engine)) - 30},
		14,
		rl.Color{150, 150, 150, 255},
	)
}
