package razorlight_core

import k2 "../libs/karl2d"

// ============================================================================
// Animation Data Types
// ============================================================================

Animation_Frame :: struct {
	src_rect:    k2.Rect,   // Source rectangle in sprite sheet (or full image rect)
	duration_ms: f32,       // Per-frame duration override (0 = use animation fps)
}

Animation_Loop_Mode :: enum {
	Once,
	Loop,
	Ping_Pong,
}

Animation :: struct {
	name:      string,
	frames:    []Animation_Frame,
	fps:       f32,
	loop_mode: Animation_Loop_Mode,
	texture:   k2.Texture,          // Sprite sheet for this animation
}

Animation_Set :: struct {
	name:       string,
	texture:    k2.Texture,                // Shared sprite sheet (if sheet-based)
	animations: map[string]Animation,      // "idle", "run", "jump", etc.
}

Animation_Component :: struct {
	current_animation: ^Animation,
	animation_set:     ^Animation_Set,
	current_frame:     int,
	elapsed:           f32,
	playing:           bool,
	speed:             f32,         // 1.0 = normal
	direction:         i8,          // +1 or -1 (for ping-pong)
	finished:          bool,
}

DEFAULT_ANIMATION_COMPONENT :: Animation_Component {
	speed     = 1.0,
	direction = 1,
	playing   = false,
	finished  = false,
}
