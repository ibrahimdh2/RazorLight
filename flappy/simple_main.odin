package main

import rl "../RazorLight"
import "core:fmt"
import "core:math"
import "core:math/rand"

// ============================================================================
// Game State
// ============================================================================

Game_State :: struct {
	// Game entities
	bird:        rl.EntityID,
	pipes:       [dynamic]Pipe,
	
	// Game state
	score:       int,
	timer:       f32,
	game_over:   bool,
	started:     bool,
	
	// Config
	pipe_spawn_time: f32,
	pipe_speed:      f32,
	pipe_gap:        f32,
	gravity:         f32,
	jump_force:      f32,
}

Pipe :: struct {
	top:       rl.EntityID,
	bottom:    rl.EntityID,
	x:         f32,
	passed:    bool,
}

SCREEN_WIDTH  :: 400
SCREEN_HEIGHT :: 600
BIRD_RADIUS   :: 12
BIRD_X        :: 100
PIPE_WIDTH    :: 60

// ============================================================================
// Main
// ============================================================================

main :: proc() {
	config := rl.Engine_Config{
		window_width     = 400,
		window_height    = 600,
		window_title     = "Flappy Bird",
		fixed_timestep   = 1.0 / 60.0,
		physics_substeps = 4,
		gravity          = {0, 900},
		pixels_per_meter = 40,
		clear_color      = rl.Color{100, 180, 255, 255},
	}

	engine := rl.engine_create(config)
	defer rl.engine_destroy(engine)
	
	state := init_game(engine)
	defer cleanup_game(&state, engine)

	for rl.engine_update(engine) {
		update_game(&state, engine)
		rl.engine_render(engine)
	}
}

// ============================================================================
// Game Functions
// ============================================================================

init_game :: proc(engine: ^rl.Engine) -> Game_State {
	state := Game_State{}
	state.pipes = make([dynamic]Pipe)
	state.pipe_spawn_time = 1.5
	state.pipe_speed = 150
	state.pipe_gap = 140
	state.gravity = 900
	state.jump_force = -280
	state.score = 0
	state.timer = 0
	state.game_over = false
	state.started = false
	
	create_bird(&state, engine)
	
	fmt.println("Flappy Bird initialized!")
	fmt.println("Press SPACE to flap!")
	
	return state
}

cleanup_game :: proc(state: ^Game_State, engine: ^rl.Engine) {
	delete(state.pipes)
}

update_game :: proc(state: ^Game_State, engine: ^rl.Engine) {
	world := rl.get_world(engine)
	dt := rl.engine_get_delta_time(engine)
	
	// Quit with Escape
	if rl.key_went_down(.Escape) {
		rl.engine_quit(engine)
		return
	}
	
	// Reset on R key
	if state.game_over && rl.key_went_down(.R) {
		reset_game(state, engine)
		return
	}
	
	// Jump on Space
	if rl.key_went_down(.Space) {
		if !state.started {
			state.started = true
		}
		if !state.game_over {
			jump(state, engine)
		}
	}
	
	if !state.started || state.game_over {
		render_game(state, engine)
		return
	}
	
	// Update pipes
	update_pipes(state, engine, dt)
	
	// Spawn new pipes
	state.timer += dt
	if state.timer >= state.pipe_spawn_time {
		state.timer = 0
		spawn_pipe_pair(state, engine)
	}
	
	// Check collisions and score
	check_collisions_and_score(state, engine)
	
	render_game(state, engine)
}

render_game :: proc(state: ^Game_State, engine: ^rl.Engine) {
	// Draw score
	score_text := fmt.tprintf("Score: %d", state.score)
	rl.draw_text(score_text, {10, 10}, 24, rl.WHITE)
	
	// Draw instructions
	if !state.started {
		rl.draw_text("Press SPACE to start!", {SCREEN_WIDTH / 2 - 110, SCREEN_HEIGHT / 2 - 20}, 20, rl.WHITE)
	}
	
	// Draw game over
	if state.game_over {
		rl.draw_text("GAME OVER", {SCREEN_WIDTH / 2 - 70, SCREEN_HEIGHT / 2 - 40}, 30, rl.RED)
		rl.draw_text("Press R to restart", {SCREEN_WIDTH / 2 - 85, SCREEN_HEIGHT / 2}, 20, rl.WHITE)
	}
}

create_bird :: proc(state: ^Game_State, engine: ^rl.Engine) {
	world := rl.get_world(engine)
	
	state.bird = rl.create_entity(world)
	rl.add_component(world, state.bird, rl.Transform{
		position = {BIRD_X, SCREEN_HEIGHT / 2},
		scale = {1, 1},
	})
	rl.add_component(world, state.bird, rl.Rigidbody{
		body_type = .Dynamic,
		gravity_scale = 1.0,
	})
	rl.add_component(world, state.bird, rl.Collider{
		shape = rl.Circle{radius = BIRD_RADIUS},
		density = 1.0,
		friction = 0.3,
		restitution = 0.0,
	})
	rl.add_component(world, state.bird, rl.Shape_Component{
		shape_type = .Circle,
		color = rl.YELLOW,
		size = {BIRD_RADIUS, BIRD_RADIUS},
		visible = true,
	})
}

jump :: proc(state: ^Game_State, engine: ^rl.Engine) {
	world := rl.get_world(engine)
	rl.set_velocity(world, state.bird, {0, state.jump_force})
}

spawn_pipe_pair :: proc(state: ^Game_State, engine: ^rl.Engine) {
	world := rl.get_world(engine)
	
	min_y := 100
	max_y := SCREEN_HEIGHT - 100 - int(state.pipe_gap)
	gap_y := f32(min_y + int(rand.float32() * f32(max_y - min_y)))
	
	pipe_x := f32(SCREEN_WIDTH + PIPE_WIDTH / 2)
	
	// Top pipe
	top_height := gap_y - state.pipe_gap / 2
	top := rl.create_entity(world)
	rl.add_component(world, top, rl.Transform{
		position = {pipe_x, top_height / 2},
	})
	rl.add_component(world, top, rl.Collider{
		shape = rl.Box{width = PIPE_WIDTH, height = top_height},
	})
	rl.add_component(world, top, rl.Shape_Component{
		shape_type = .Rectangle,
		color = rl.GREEN,
		size = {PIPE_WIDTH, top_height},
		visible = true,
	})
	
	// Bottom pipe
	bottom_y := gap_y + state.pipe_gap / 2
	bottom_height := SCREEN_HEIGHT - int(bottom_y)
	bottom := rl.create_entity(world)
	rl.add_component(world, bottom, rl.Transform{
		position = {pipe_x, bottom_y + f32(bottom_height) / 2},
	})
	rl.add_component(world, bottom, rl.Collider{
		shape = rl.Box{width = PIPE_WIDTH, height = f32(bottom_height)},
	})
	rl.add_component(world, bottom, rl.Shape_Component{
		shape_type = .Rectangle,
		color = rl.GREEN,
		size = {PIPE_WIDTH, f32(bottom_height)},
		visible = true,
	})
	
	append(&state.pipes, Pipe{
		top = top,
		bottom = bottom,
		x = pipe_x,
		passed = false,
	})
}

update_pipes :: proc(state: ^Game_State, engine: ^rl.Engine, dt: f32) {
	world := rl.get_world(engine)
	
	for &pipe in state.pipes {
		pipe.x -= state.pipe_speed * dt
		
		if rl.has_component(world, pipe.top, rl.Transform) {
			pos := rl.get_position(world, pipe.top)
			rl.set_position(world, pipe.top, {pipe.x, pos.y})
		}
		if rl.has_component(world, pipe.bottom, rl.Transform) {
			pos := rl.get_position(world, pipe.bottom)
			rl.set_position(world, pipe.bottom, {pipe.x, pos.y})
		}
	}
	
	i := 0
	for i < len(state.pipes) {
		if state.pipes[i].x < -PIPE_WIDTH {
			rl.remove_entity(world, state.pipes[i].top)
			rl.remove_entity(world, state.pipes[i].bottom)
			ordered_remove(&state.pipes, i)
		} else {
			i += 1
		}
	}
}

check_collisions_and_score :: proc(state: ^Game_State, engine: ^rl.Engine) {
	world := rl.get_world(engine)
	
	bird_pos := rl.get_position(world, state.bird)
	
	// Check ground/ceiling
	if bird_pos.y > SCREEN_HEIGHT - BIRD_RADIUS || bird_pos.y < BIRD_RADIUS {
		state.game_over = true
		return
	}
	
	// Check pipes
	for &pipe in state.pipes {
		pipe_half_width := f32(PIPE_WIDTH / 2)
		
		dx := math.abs(bird_pos.x - pipe.x)
		
		// Get pipe positions for collision
		top_pos := rl.get_position(world, pipe.top)
		bottom_pos := rl.get_position(world, pipe.bottom)
		
		// Simple AABB collision
		if dx < BIRD_RADIUS + pipe_half_width {
			// Check collision with top pipe
			if bird_pos.y < top_pos.y + BIRD_RADIUS {
				state.game_over = true
				return
			}
			// Check collision with bottom pipe
			if bird_pos.y > bottom_pos.y - BIRD_RADIUS {
				state.game_over = true
				return
			}
		}
		
		// Score
		if !pipe.passed && bird_pos.x > pipe.x {
			pipe.passed = true
			state.score += 1
			fmt.printf("Score: %d\n", state.score)
		}
	}
}

reset_game :: proc(state: ^Game_State, engine: ^rl.Engine) {
	world := rl.get_world(engine)
	
	for pipe in state.pipes {
		rl.remove_entity(world, pipe.top)
		rl.remove_entity(world, pipe.bottom)
	}
	clear(&state.pipes)
	
	rl.remove_entity(world, state.bird)
	
	state.score = 0
	state.timer = 0
	state.game_over = false
	state.started = false
	
	create_bird(state, engine)
}
