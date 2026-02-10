package animation_editor

import k2 "../../libs/karl2d"
import ui "../ui"
import "core:fmt"

// ============================================================================
// Editor State
// ============================================================================

Editor_Mode :: enum {
	Sheet,           // Sprite sheet mode
	Image_Sequence,  // Individual images mode
}

// Represents one animation being edited
Editor_Animation :: struct {
	name:       [64]u8,
	name_len:   int,
	fps:        f32,
	loop_mode:  int,           // Index into LOOP_MODES
	frames:     [dynamic]Editor_Frame,
}

Editor_Frame :: struct {
	src_rect:    k2.Rect,      // Region in sprite sheet
	duration_ms: f32,          // Per-frame override (0 = use fps)
}

// Drag state for timeline frame reordering
Drag_State :: struct {
	active:       bool,
	frame_index:  int,
	start_x:      f32,
}

Editor_State :: struct {
	// Mode
	mode:            Editor_Mode,

	// Loaded sprite sheet
	texture:         k2.Texture,
	texture_path:    [256]u8,
	texture_path_len: int,
	texture_loaded:  bool,

	// Animation list
	animations:      [dynamic]Editor_Animation,
	selected_anim:   int,        // Index of currently selected animation

	// Frame selection
	selected_frame:  int,        // Index of selected frame in timeline

	// Sheet view state
	view_offset:     k2.Vec2,    // Pan offset
	view_zoom:       f32,        // Zoom level
	is_panning:      bool,
	pan_start:       k2.Vec2,

	// Grid mode
	grid_enabled:    bool,
	grid_cell_w:     int,
	grid_cell_h:     int,

	// Frame selection drag on sheet
	is_selecting:    bool,
	select_start:    k2.Vec2,
	select_end:      k2.Vec2,

	// Preview state
	preview_playing: bool,
	preview_frame:   int,
	preview_elapsed: f32,

	// Timeline drag
	drag:            Drag_State,

	// File path for save/load
	file_path:       [256]u8,
	file_path_len:   int,

	// Set name
	set_name:        [64]u8,
	set_name_len:    int,

	// UI context
	ui_ctx:          ^ui.UI_Context,
}

loop_modes := [3]string{"loop", "once", "ping_pong"}

// ============================================================================
// Lifecycle
// ============================================================================

editor_state_create :: proc() -> ^Editor_State {
	state := new(Editor_State)
	state.view_zoom = 1.0
	state.grid_cell_w = 32
	state.grid_cell_h = 32
	state.selected_anim = -1
	state.selected_frame = -1
	state.animations = make([dynamic]Editor_Animation)
	state.ui_ctx = ui.ui_context_create()

	// Default set name
	name := "untitled"
	for i in 0..<len(name) {
		state.set_name[i] = name[i]
	}
	state.set_name_len = len(name)

	return state
}

editor_state_destroy :: proc(state: ^Editor_State) {
	if state == nil {
		return
	}

	for &anim in state.animations {
		delete(anim.frames)
	}
	delete(state.animations)

	if state.ui_ctx != nil {
		ui.ui_context_destroy(state.ui_ctx)
	}

	free(state)
}

// ============================================================================
// Animation List Helpers
// ============================================================================

editor_add_animation :: proc(state: ^Editor_State) {
	anim := Editor_Animation{}
	anim.fps = 8
	anim.loop_mode = 0  // "loop"
	anim.frames = make([dynamic]Editor_Frame)

	// Default name
	name := fmt_anim_name(len(state.animations))
	for i in 0..<len(name) {
		anim.name[i] = name[i]
	}
	anim.name_len = len(name)

	append(&state.animations, anim)
	state.selected_anim = len(state.animations) - 1
	state.selected_frame = -1
}

editor_remove_animation :: proc(state: ^Editor_State, index: int) {
	if index < 0 || index >= len(state.animations) {
		return
	}

	delete(state.animations[index].frames)
	ordered_remove(&state.animations, index)

	if state.selected_anim >= len(state.animations) {
		state.selected_anim = len(state.animations) - 1
	}
	state.selected_frame = -1
}

editor_add_frame :: proc(state: ^Editor_State, rect: k2.Rect) {
	if state.selected_anim < 0 || state.selected_anim >= len(state.animations) {
		return
	}

	frame := Editor_Frame{
		src_rect = rect,
	}
	append(&state.animations[state.selected_anim].frames, frame)
	state.selected_frame = len(state.animations[state.selected_anim].frames) - 1
}

editor_remove_frame :: proc(state: ^Editor_State, frame_index: int) {
	if state.selected_anim < 0 || state.selected_anim >= len(state.animations) {
		return
	}

	anim := &state.animations[state.selected_anim]
	if frame_index < 0 || frame_index >= len(anim.frames) {
		return
	}

	ordered_remove(&anim.frames, frame_index)

	if state.selected_frame >= len(anim.frames) {
		state.selected_frame = len(anim.frames) - 1
	}
}

// ============================================================================
// Helpers
// ============================================================================

@(private)
fmt_anim_name :: proc(index: int) -> string {
	return fmt.tprintf("anim_%d", index)
}
