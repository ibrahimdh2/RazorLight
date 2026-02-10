package game

import rl "../RazorLight"
import "core:fmt"
import "core:math"
import "core:math/rand"

// ============================================================================
// Top-Down Arena Survival
// ============================================================================
// Survive as long as possible while enemies chase you.
// WASD/Arrows to move, Space to dash, R to restart, ESC to quit.

// Tag components
Player_Tag :: struct {
	speed:         f32,
	dash_timer:    f32,
	dash_cooldown: f32,
}

Enemy_Tag :: struct {
	speed: f32,
}

Wall_Tag :: struct {}

// Game state
Game :: struct {
	engine:         ^rl.Engine,
	player:         rl.EntityID,
	spawn_timer:    f32,
	spawn_interval: f32,
	score:          f32,
	game_over:      bool,
	enemy_count:    int,
}

game: Game

ARENA_W :: 1280
ARENA_H :: 720
WALL_THICKNESS :: 40
PLAYER_SIZE :: 24
ENEMY_RADIUS :: 12
PLAYER_SPEED :: 300.0
DASH_SPEED :: 600.0
DASH_DURATION :: 0.2
DASH_COOLDOWN :: 1.0

main :: proc() {
	config := rl.Engine_Config{
		window_width     = ARENA_W,
		window_height    = ARENA_H,
		window_title     = "Arena Survival",
		fixed_timestep   = 1.0 / 60.0,
		physics_substeps = 4,
		gravity          = {0, 0},
		pixels_per_meter = 40,
		clear_color      = rl.Color{15, 15, 25, 255},
		design_width     = ARENA_W,
		design_height    = ARENA_H,
		window_mode      = .Borderless_Fullscreen,
	}

	game.engine = rl.engine_create(config)
	defer rl.engine_destroy(game.engine)

	world := rl.get_world(game.engine)
	sched := rl.get_scheduler(game.engine)

	// Set up arena
	create_walls(world)
	game.player = create_player(world)
	game.spawn_interval = 2.0

	// Register systems
	rl.add_system(sched, "input",     .Pre_Update,  input_system)
	rl.add_system(sched, "enemy_ai",  .Update,      enemy_ai_system)
	rl.add_system(sched, "spawner",   .Update,      spawn_system)
	rl.add_system(sched, "collision", .Post_Update,  collision_system)
	rl.add_render_system(sched, "hud", hud_system, priority = 100)

	for rl.engine_update(game.engine) {
		rl.engine_render(game.engine)
	}
}

// ============================================================================
// Entity Creation
// ============================================================================

create_player :: proc(world: ^rl.World) -> rl.EntityID {
	entity := rl.create_entity(world)
	rl.add_component(world, entity, rl.Transform{
		position = {f32(ARENA_W) / 2, f32(ARENA_H) / 2},
		scale    = {1, 1},
	})
	rl.add_component(world, entity, rl.Rigidbody{
		body_type      = .Dynamic,
		fixed_rotation = true,
		gravity_scale  = 0,
	})
	rl.add_component(world, entity, rl.Collider{
		shape   = rl.Box{f32(PLAYER_SIZE), f32(PLAYER_SIZE)},
		density = 1.0,
	})
	rl.add_component(world, entity, rl.Shape_Component{
		shape_type = .Rectangle,
		color      = rl.Color{80, 220, 100, 255},
		size       = {f32(PLAYER_SIZE), f32(PLAYER_SIZE)},
		visible    = true,
	})
	rl.add_component(world, entity, Player_Tag{
		speed = PLAYER_SPEED,
	})
	return entity
}

create_walls :: proc(world: ^rl.World) {
	W  :: f32(ARENA_W)
	H  :: f32(ARENA_H)
	TH :: f32(WALL_THICKNESS)

	wall_color := rl.Color{50, 50, 65, 255}

	// Top
	e := rl.create_entity(world)
	rl.add_component(world, e, rl.Transform{position = {W / 2, -TH / 2}, scale = {1, 1}})
	rl.add_component(world, e, rl.Collider{shape = rl.Box{W + TH * 2, TH}})
	rl.add_component(world, e, rl.Shape_Component{shape_type = .Rectangle, color = wall_color, size = {W + TH * 2, TH}, visible = true})
	rl.add_component(world, e, Wall_Tag{})

	// Bottom
	e = rl.create_entity(world)
	rl.add_component(world, e, rl.Transform{position = {W / 2, H + TH / 2}, scale = {1, 1}})
	rl.add_component(world, e, rl.Collider{shape = rl.Box{W + TH * 2, TH}})
	rl.add_component(world, e, rl.Shape_Component{shape_type = .Rectangle, color = wall_color, size = {W + TH * 2, TH}, visible = true})
	rl.add_component(world, e, Wall_Tag{})

	// Left
	e = rl.create_entity(world)
	rl.add_component(world, e, rl.Transform{position = {-TH / 2, H / 2}, scale = {1, 1}})
	rl.add_component(world, e, rl.Collider{shape = rl.Box{TH, H}})
	rl.add_component(world, e, rl.Shape_Component{shape_type = .Rectangle, color = wall_color, size = {TH, H}, visible = true})
	rl.add_component(world, e, Wall_Tag{})

	// Right
	e = rl.create_entity(world)
	rl.add_component(world, e, rl.Transform{position = {W + TH / 2, H / 2}, scale = {1, 1}})
	rl.add_component(world, e, rl.Collider{shape = rl.Box{TH, H}})
	rl.add_component(world, e, rl.Shape_Component{shape_type = .Rectangle, color = wall_color, size = {TH, H}, visible = true})
	rl.add_component(world, e, Wall_Tag{})
}

spawn_enemy :: proc(world: ^rl.World) {
	W :: f32(ARENA_W)
	H :: f32(ARENA_H)

	// Pick a random edge and position along it
	pos: rl.Vec2
	edge := rand.int31_max(4)
	switch edge {
	case 0: pos = {rand.float32_range(0, W), -f32(ENEMY_RADIUS)}           // top
	case 1: pos = {rand.float32_range(0, W), H + f32(ENEMY_RADIUS)}        // bottom
	case 2: pos = {-f32(ENEMY_RADIUS), rand.float32_range(0, H)}           // left
	case 3: pos = {W + f32(ENEMY_RADIUS), rand.float32_range(0, H)}        // right
	}

	speed := rand.float32_range(100, 180)
	r := u8(rand.uint32() % 80 + 175)
	g := u8(rand.uint32() % 60 + 30)
	b := u8(rand.uint32() % 60 + 30)

	entity := rl.create_entity(world)
	rl.add_component(world, entity, rl.Transform{position = pos, scale = {1, 1}})
	rl.add_component(world, entity, rl.Rigidbody{
		body_type      = .Dynamic,
		fixed_rotation = true,
		gravity_scale  = 0,
	})
	rl.add_component(world, entity, rl.Collider{
		shape   = rl.Circle{f32(ENEMY_RADIUS)},
		density = 1.0,
	})
	rl.add_component(world, entity, rl.Shape_Component{
		shape_type = .Circle,
		color      = rl.Color{r, g, b, 255},
		size       = {f32(ENEMY_RADIUS), f32(ENEMY_RADIUS)},
		visible    = true,
	})
	rl.add_component(world, entity, Enemy_Tag{speed = speed})

	game.enemy_count += 1
}

// ============================================================================
// Systems
// ============================================================================

input_system :: proc(world_ptr: rawptr, dt: f32) {
	world := cast(^rl.World)world_ptr

	if rl.key_went_down(.Escape) {
		rl.engine_quit(game.engine)
	}
	if rl.key_went_down(.F1) {
		rl.engine_toggle_debug(game.engine)
	}

	// Restart on R when game over
	if game.game_over {
		if rl.key_went_down(.R) {
			restart_game(world)
		}
		return
	}

	// Player movement
	player_tag := rl.get_component(world, game.player, Player_Tag)
	if player_tag == nil { return }

	// Dash
	if rl.key_went_down(.Space) && player_tag.dash_cooldown <= 0 {
		player_tag.dash_timer = DASH_DURATION
		player_tag.dash_cooldown = DASH_COOLDOWN
	}

	// Tick dash timers
	player_tag.dash_timer -= dt
	player_tag.dash_cooldown -= dt

	// Movement input
	dx: f32 = 0
	dy: f32 = 0
	if rl.key_is_held(.W) || rl.key_is_held(.Up)    { dy -= 1 }
	if rl.key_is_held(.S) || rl.key_is_held(.Down)   { dy += 1 }
	if rl.key_is_held(.A) || rl.key_is_held(.Left)   { dx -= 1 }
	if rl.key_is_held(.D) || rl.key_is_held(.Right)  { dx += 1 }

	// Normalize diagonal
	dir := rl.Vec2{dx, dy}
	len := math.sqrt(dir.x * dir.x + dir.y * dir.y)
	if len > 0 {
		dir = {dir.x / len, dir.y / len}
	}

	speed: f32 = PLAYER_SPEED if player_tag.dash_timer <= 0 else DASH_SPEED
	rl.set_velocity(world, game.player, {dir.x * speed, dir.y * speed})
}

enemy_ai_system :: proc(world_ptr: rawptr, dt: f32) {
	world := cast(^rl.World)world_ptr
	if game.game_over { return }

	// Get player position
	player_tf := rl.get_component(world, game.player, rl.Transform)
	if player_tf == nil { return }
	player_pos := player_tf.position

	// Each enemy chases the player
	it := rl.query2(world, rl.Transform, Enemy_Tag)
	for {
		entity, tf, enemy, ok := rl.query2_next(&it)
		if !ok { break }

		dx := player_pos.x - tf.position.x
		dy := player_pos.y - tf.position.y
		len := math.sqrt(dx * dx + dy * dy)
		if len > 0.1 {
			dir := rl.Vec2{dx / len, dy / len}
			rl.set_velocity(world, entity, {dir.x * enemy.speed, dir.y * enemy.speed})
		}
	}
}

spawn_system :: proc(world_ptr: rawptr, dt: f32) {
	world := cast(^rl.World)world_ptr
	if game.game_over { return }

	game.spawn_timer += dt
	if game.spawn_timer >= game.spawn_interval {
		game.spawn_timer -= game.spawn_interval
		spawn_enemy(world)

		// Increase spawn rate over time (min 0.5s)
		game.spawn_interval = max(0.5, game.spawn_interval - 0.05)
	}

	// Increment score
	game.score += dt
}

collision_system :: proc(world_ptr: rawptr, dt: f32) {
	world := cast(^rl.World)world_ptr
	if game.game_over { return }

	player_tf := rl.get_component(world, game.player, rl.Transform)
	if player_tf == nil { return }
	pp := player_tf.position

	threshold := f32(PLAYER_SIZE) / 2 + f32(ENEMY_RADIUS)

	it := rl.query2(world, rl.Transform, Enemy_Tag)
	for {
		_, tf, _, ok := rl.query2_next(&it)
		if !ok { break }

		dx := pp.x - tf.position.x
		dy := pp.y - tf.position.y
		dist := math.sqrt(dx * dx + dy * dy)
		if dist < threshold {
			game.game_over = true
			// Stop player
			rl.set_velocity(world, game.player, {0, 0})
			return
		}
	}
}

hud_system :: proc(world_ptr: rawptr) {
	W :: f32(ARENA_W)
	H :: f32(ARENA_H)

	if game.game_over {
		// Game over screen
		rl.draw_text("GAME OVER", {W / 2 - 120, H / 2 - 40}, 48, rl.RED)
		rl.draw_text(
			fmt.tprintf("Score: %.1f seconds", game.score),
			{W / 2 - 100, H / 2 + 20},
			24,
			rl.WHITE,
		)
		rl.draw_text(
			"Press R to restart",
			{W / 2 - 90, H / 2 + 60},
			20,
			rl.LIGHT_GRAY,
		)
		return
	}

	// Score
	rl.draw_text(fmt.tprintf("Score: %.1f", game.score), {10, 10}, 24, rl.WHITE)

	// Enemy count
	rl.draw_text(fmt.tprintf("Enemies: %d", game.enemy_count), {10, 40}, 18, rl.LIGHT_GRAY)

	// FPS
	rl.draw_text(
		fmt.tprintf("FPS: %.0f", rl.engine_get_fps(game.engine)),
		{W - 100, 10},
		16,
		rl.DARK_GRAY,
	)

	// Controls
	rl.draw_text(
		"WASD/Arrows: Move | Space: Dash | F1: Debug | ESC: Quit",
		{10, H - 25},
		14,
		rl.Color{100, 100, 100, 255},
	)

	// Dash indicator
	player_tag := rl.get_component(rl.get_world(game.engine), game.player, Player_Tag)
	if player_tag != nil {
		if player_tag.dash_timer > 0 {
			rl.draw_text("DASH!", {W / 2 - 30, 10}, 20, rl.CYAN)
		} else if player_tag.dash_cooldown > 0 {
			rl.draw_text(
				fmt.tprintf("Dash: %.1fs", player_tag.dash_cooldown),
				{W / 2 - 40, 10},
				16,
				rl.DARK_GRAY,
			)
		} else {
			rl.draw_text("Dash Ready", {W / 2 - 45, 10}, 16, rl.CYAN)
		}
	}
}

// ============================================================================
// Restart
// ============================================================================

restart_game :: proc(world: ^rl.World) {
	// Remove all enemies
	it := rl.query1(world, Enemy_Tag)
	enemies: [512]rl.EntityID
	count := 0
	for {
		entity, _, ok := rl.query1_next(&it)
		if !ok { break }
		if count < len(enemies) {
			enemies[count] = entity
			count += 1
		}
	}
	for i in 0..<count {
		rl.remove_entity(world, enemies[i])
	}

	// Reset player position
	player_tf := rl.get_component(world, game.player, rl.Transform)
	if player_tf != nil {
		player_tf.position = {f32(ARENA_W) / 2, f32(ARENA_H) / 2}
	}
	rl.set_velocity(world, game.player, {0, 0})

	// Reset player tag
	player_tag := rl.get_component(world, game.player, Player_Tag)
	if player_tag != nil {
		player_tag.dash_timer = 0
		player_tag.dash_cooldown = 0
	}

	// Reset game state
	game.spawn_timer = 0
	game.spawn_interval = 2.0
	game.score = 0
	game.game_over = false
	game.enemy_count = 0
}
