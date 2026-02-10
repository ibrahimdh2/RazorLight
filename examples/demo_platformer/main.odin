package demo_platformer

import rl "../RazorLight"
import "core:fmt"

// ============================================================================
// Platformer Demo — CharacterBody2D Showcase
// ============================================================================
// Arrow keys / WASD to move, Space to jump.
// ESC to quit, F1 to toggle debug visualization.

// Tag to identify the player entity
Player_Tag :: struct {}

// Game state
Game :: struct {
	engine:         ^rl.Engine,
	player:         rl.EntityID,
	player_texture: rl.Texture,
}

game: Game

// Movement constants
MOVE_SPEED     :: f32(400)
JUMP_SPEED     :: f32(600)
GRAVITY        :: f32(1200)
PLAYER_WIDTH   :: f32(24)
PLAYER_HEIGHT  :: f32(48)

main :: proc() {
	config := rl.Engine_Config{
		window_width     = 1280,
		window_height    = 720,
		window_title     = "RazorLight - Platformer Demo",
		fixed_timestep   = 1.0 / 60.0,
		physics_substeps = 4,
		gravity          = {0, 900},
		pixels_per_meter = 40,
		clear_color      = rl.Color{20, 20, 30, 255},
		design_width     = 1280,
		design_height    = 720,
		window_mode      = .Borderless_Fullscreen,
	}

	game.engine = rl.engine_create(config)
	defer rl.engine_destroy(game.engine)

	game.player_texture = rl.load_texture_from_file("./player.png")

	world := rl.get_world(game.engine)
	sched := rl.get_scheduler(game.engine)

	// Create level
	create_platforms(world)

	// Create player
	game.player = create_player(world)

	// Register custom systems
	rl.add_system(sched, "player_input", .Pre_Update, player_input_system)
	rl.add_system(sched, "player_gravity", .Update, player_gravity_system)
	rl.add_render_system(sched, "hud", hud_render_system, priority = 100)

	// Main loop
	for rl.engine_update(game.engine) {
		rl.engine_render(game.engine)
	}
}

// ============================================================================
// Player Creation
// ============================================================================

create_player :: proc(world: ^rl.World) -> rl.EntityID {
	entity := rl.create_entity(world)
	rl.add_component(world, entity, rl.Transform{
		position = {200, 400},
		scale    = {1, 1},
	})
	rl.add_component(world, entity, rl.Character_Body{
		width  = PLAYER_WIDTH,
		height = PLAYER_HEIGHT,
	})
	rl.add_component(world, entity, rl.Sprite_Component{
		texture = game.player_texture,
		color   = rl.WHITE,
		origin  = {0.5, 0.5},
		visible = true,
	})
	rl.add_component(world, entity, Player_Tag{})
	return entity
}

// ============================================================================
// Platform Creation
// ============================================================================

create_platforms :: proc(world: ^rl.World) {
	// Ground
	make_platform(world, {640, 680}, {1280, 40}, rl.Color{80, 80, 80, 255})

	// Floating platforms
	make_platform(world, {300, 550}, {200, 20}, rl.Color{100, 80, 60, 255})
	make_platform(world, {640, 450}, {250, 20}, rl.Color{100, 80, 60, 255})
	make_platform(world, {950, 350}, {200, 20}, rl.Color{100, 80, 60, 255})
	make_platform(world, {640, 250}, {180, 20}, rl.Color{100, 80, 60, 255})
	make_platform(world, {300, 350}, {150, 20}, rl.Color{100, 80, 60, 255})

	// Walls
	make_platform(world, {-10, 360}, {20, 720}, rl.Color{60, 60, 60, 255})
	make_platform(world, {1290, 360}, {20, 720}, rl.Color{60, 60, 60, 255})
}

make_platform :: proc(world: ^rl.World, pos: [2]f32, size: [2]f32, color: rl.Color) {
	entity := rl.create_entity(world)
	rl.add_component(world, entity, rl.Transform{position = pos, scale = {1, 1}})
	rl.add_component(world, entity, rl.Collider{shape = rl.Box{size.x, size.y}})
	rl.add_component(world, entity, rl.Shape_Component{
		shape_type = .Rectangle,
		color      = color,
		size       = size,
		visible    = true,
	})
}

// ============================================================================
// Player Input System (Pre_Update)
// ============================================================================

player_input_system :: proc(world_ptr: rawptr, dt: f32) {
	world := cast(^rl.World)world_ptr

	// ESC to quit
	if rl.key_went_down(.Escape) {
		rl.engine_quit(game.engine)
	}

	// F1 to toggle debug
	if rl.key_went_down(.F1) {
		rl.engine_toggle_debug(game.engine)
	}

	if !rl.has_component(world, game.player, rl.Character_Body) { return }
	cb := rl.get_component(world, game.player, rl.Character_Body)

	// Horizontal movement
	move_x: f32 = 0
	if rl.key_is_held(.A) || rl.key_is_held(.Left)  { move_x -= 1 }
	if rl.key_is_held(.D) || rl.key_is_held(.Right) { move_x += 1 }
	cb.velocity.x = move_x * MOVE_SPEED

	// Jump (only when on floor)
	if cb.is_on_floor && (rl.key_went_down(.Space) || rl.key_went_down(.W) || rl.key_went_down(.Up)) {
		cb.velocity.y = -JUMP_SPEED  // Screen-space: negative Y = upward
	}
}

// ============================================================================
// Player Gravity System (Update)
// ============================================================================

player_gravity_system :: proc(world_ptr: rawptr, dt: f32) {
	world := cast(^rl.World)world_ptr

	if !rl.has_component(world, game.player, rl.Character_Body) { return }
	cb := rl.get_component(world, game.player, rl.Character_Body)

	// Apply gravity (screen-space: positive Y = downward)
	if !cb.is_on_floor {
		cb.velocity.y += GRAVITY * dt
	}
}

// ============================================================================
// HUD Render System
// ============================================================================

hud_render_system :: proc(world_ptr: rawptr) {
	world := cast(^rl.World)world_ptr

	// FPS
	rl.draw_text(
		fmt.tprintf("FPS: %.0f", rl.engine_get_fps(game.engine)),
		{10, 10},
		16,
		rl.LIGHT_GRAY,
	)

	if !rl.has_component(world, game.player, rl.Character_Body) { return }
	cb := rl.get_component(world, game.player, rl.Character_Body)

	// Velocity
	rl.draw_text(
		fmt.tprintf("Velocity: (%.0f, %.0f)", cb.velocity.x, cb.velocity.y),
		{10, 30},
		16,
		rl.WHITE,
	)

	// Floor state
	floor_text := "On Floor: YES" if cb.is_on_floor else "On Floor: NO"
	floor_color := rl.GREEN if cb.is_on_floor else rl.RED
	rl.draw_text(floor_text, {10, 50}, 16, floor_color)

	// Wall/ceiling
	if cb.is_on_wall {
		rl.draw_text("On Wall", {10, 70}, 16, rl.YELLOW)
	}
	if cb.is_on_ceiling {
		rl.draw_text("On Ceiling", {10, 70}, 16, rl.ORANGE)
	}

	// Instructions
	rl.draw_text(
		"WASD/Arrows: Move | Space: Jump | F1: Debug | ESC: Quit",
		{10, f32(rl.engine_design_height(game.engine)) - 30},
		14,
		rl.Color{150, 150, 150, 255},
	)
}
