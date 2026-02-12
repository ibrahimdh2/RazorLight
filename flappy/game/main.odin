package flappy_game

import rl "../../RazorLight"
import ecs "../../RazorLight/libs/yggsECS"
import "core:fmt"
import "core:math"
import "core:math/rand"

// NOTE: Hot-reload with polymorphic types is problematic.
// Use the non-hot-reload version (../main.odin) for a working game.
// This file is kept for reference but may crash due to type identity issues
// between the host and shared library.

@(export)
game_state_size :: proc "c" () -> int {
	return size_of(Game_State)
}

@(export)
game_init :: proc "c" (state_ptr: rawptr, engine_ptr: rawptr) {
	context = {}
	state := cast(^Game_State)state_ptr
	engine := cast(^rl.Engine)engine_ptr
	
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
	
	create_bird(state, engine)
	
	fmt.println("Flappy Bird initialized!")
	fmt.println("Press SPACE to flap!")
}

@(export)
game_update :: proc "c" (state_ptr: rawptr, engine_ptr: rawptr, dt: f32) {
	context = {}
	state := cast(^Game_State)state_ptr
	engine := cast(^rl.Engine)engine_ptr
	
	if rl.key_went_down(.Escape) {
		rl.engine_quit(engine)
		return
	}
	
	if state.game_over && rl.key_went_down(.R) {
		reset_game(state, engine)
		return
	}
	
	if rl.key_went_down(.Space) {
		if !state.started {
			state.started = true
		}
		if !state.game_over {
			jump(state, engine)
		}
	}
	
	if !state.started || state.game_over {
		return
	}
	
	update_pipes(state, engine, dt)
	
	state.timer += dt
	if state.timer >= state.pipe_spawn_time {
		state.timer = 0
		spawn_pipe_pair(state, engine)
	}
	
	check_collisions_and_score(state, engine)
}

@(export)
game_render :: proc "c" (state_ptr: rawptr, engine_ptr: rawptr) {
	context = {}
	state := cast(^Game_State)state_ptr
	
	score_text := fmt.tprintf("Score: %d", state.score)
	rl.draw_text(score_text, {10, 10}, 24, rl.WHITE)
	
	if !state.started {
		rl.draw_text("Press SPACE to start!", {SCREEN_WIDTH / 2 - 110, SCREEN_HEIGHT / 2 - 20}, 20, rl.WHITE)
	}
	
	if state.game_over {
		rl.draw_text("GAME OVER", {SCREEN_WIDTH / 2 - 70, SCREEN_HEIGHT / 2 - 40}, 30, rl.RED)
		rl.draw_text("Press R to restart", {SCREEN_WIDTH / 2 - 85, SCREEN_HEIGHT / 2}, 20, rl.WHITE)
	}
}

@(export)
game_shutdown :: proc "c" (state_ptr: rawptr, engine_ptr: rawptr) {
	context = {}
	state := cast(^Game_State)state_ptr
	delete(state.pipes)
}

@(export)
game_on_reload :: proc "c" (state_ptr: rawptr, engine_ptr: rawptr) {
	context = {}
	fmt.println("Game library reloaded!")
}

create_bird :: proc(state: ^Game_State, engine: ^rl.Engine) {
	world := rl.get_world(engine)
	state.bird = rl.create_entity(world)
	
	// Using direct ECS calls to avoid polymorphic type issues with hot-reload
	ecs.add_component(world.ecs, state.bird, rl.Transform{
		position = {BIRD_X, SCREEN_HEIGHT / 2},
		scale = {1, 1},
	})
	ecs.add_component(world.ecs, state.bird, rl.Rigidbody{
		body_type = .Dynamic,
		gravity_scale = 1.0,
	})
	ecs.add_component(world.ecs, state.bird, rl.Collider{
		shape = rl.Circle{radius = BIRD_RADIUS},
		density = 1.0,
		friction = 0.3,
		restitution = 0.0,
	})
	ecs.add_component(world.ecs, state.bird, rl.Shape_Component{
		shape_type = .Circle,
		color = rl.YELLOW,
		size = {BIRD_RADIUS, BIRD_RADIUS},
		visible = true,
	})
	rl.try_init_physics(world, state.bird)
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
	ecs.add_component(world.ecs, top, rl.Transform{position = {pipe_x, top_height / 2}})
	ecs.add_component(world.ecs, top, rl.Collider{shape = rl.Box{width = PIPE_WIDTH, height = top_height}})
	ecs.add_component(world.ecs, top, rl.Shape_Component{
		shape_type = .Rectangle,
		color = rl.GREEN,
		size = {PIPE_WIDTH, top_height},
		visible = true,
	})
	rl.try_init_physics(world, top)
	
	// Bottom pipe
	bottom_y := gap_y + state.pipe_gap / 2
	bottom_height := SCREEN_HEIGHT - int(bottom_y)
	bottom := rl.create_entity(world)
	ecs.add_component(world.ecs, bottom, rl.Transform{position = {pipe_x, bottom_y + f32(bottom_height) / 2}})
	ecs.add_component(world.ecs, bottom, rl.Collider{shape = rl.Box{width = PIPE_WIDTH, height = f32(bottom_height)}})
	ecs.add_component(world.ecs, bottom, rl.Shape_Component{
		shape_type = .Rectangle,
		color = rl.GREEN,
		size = {PIPE_WIDTH, f32(bottom_height)},
		visible = true,
	})
	rl.try_init_physics(world, bottom)
	
	append(&state.pipes, Pipe{top = top, bottom = bottom, x = pipe_x, passed = false})
}

update_pipes :: proc(state: ^Game_State, engine: ^rl.Engine, dt: f32) {
	world := rl.get_world(engine)
	
	for &pipe in state.pipes {
		pipe.x -= state.pipe_speed * dt
		
		if ecs.has_component(world.ecs, pipe.top, rl.Transform) {
			transform := ecs.get(world.ecs, pipe.top, rl.Transform)
			transform.position.x = pipe.x
		}
		if ecs.has_component(world.ecs, pipe.bottom, rl.Transform) {
			transform := ecs.get(world.ecs, pipe.bottom, rl.Transform)
			transform.position.x = pipe.x
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
	
	bird_transform := ecs.get(world.ecs, state.bird, rl.Transform)
	bird_pos := bird_transform.position
	
	// Ground/ceiling collision
	if bird_pos.y > SCREEN_HEIGHT - BIRD_RADIUS || bird_pos.y < BIRD_RADIUS {
		state.game_over = true
		return
	}
	
	// Pipe collisions
	for &pipe in state.pipes {
		pipe_half_width := f32(PIPE_WIDTH / 2)
		dx := math.abs(bird_pos.x - pipe.x)
		
		top_transform := ecs.get(world.ecs, pipe.top, rl.Transform)
		bottom_transform := ecs.get(world.ecs, pipe.bottom, rl.Transform)
		
		if dx < BIRD_RADIUS + pipe_half_width {
			if bird_pos.y < top_transform.position.y + BIRD_RADIUS {
				state.game_over = true
				return
			}
			if bird_pos.y > bottom_transform.position.y - BIRD_RADIUS {
				state.game_over = true
				return
			}
		}
		
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
