package flappy_game

import rl "../../RazorLight"
import ecs "../../RazorLight/libs/yggsECS"

// ============================================================================
// Game State
// ============================================================================

Game_State :: struct {
	// Game entities
	bird:        ecs.EntityID,
	pipes:       [dynamic]Pipe,
	
	// Game state
	score:       int,
	timer:       f32,           // Pipe spawn timer
	game_over:   bool,
	started:     bool,          // Wait for first jump to start
	
	// Config
	pipe_spawn_time: f32,       // Seconds between pipe spawns
	pipe_speed:      f32,       // Pixels per second
	pipe_gap:        f32,       // Gap size between top and bottom pipes
	gravity:         f32,
	jump_force:      f32,
}

// Pipe pair (top and bottom)
Pipe :: struct {
	top:       ecs.EntityID,
	bottom:    ecs.EntityID,
	x:         f32,
	passed:    bool,
}

// Screen dimensions (design resolution)
SCREEN_WIDTH  :: 400
SCREEN_HEIGHT :: 600

// Bird settings
BIRD_RADIUS   :: 12
BIRD_X        :: 100

// Pipe settings
PIPE_WIDTH    :: 60
