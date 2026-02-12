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

Animation_Set_Handle :: distinct u32
INVALID_ANIMATION_SET :: Animation_Set_Handle(0)

Animation_Component :: struct {
	set_handle:        Animation_Set_Handle,  // Handle to animation set in registry
	animation_name:    string,                // Name of current animation (e.g., "idle", "run")
	current_frame:     int,
	elapsed:           f32,
	playing:           bool,
	speed:             f32,                   // 1.0 = normal
	direction:         i8,                    // +1 or -1 (for ping-pong)
	finished:          bool,
}

DEFAULT_ANIMATION_COMPONENT :: Animation_Component {
	set_handle     = INVALID_ANIMATION_SET,
	animation_name = "",
	speed          = 1.0,
	direction      = 1,
	playing        = false,
	finished       = false,
}
