package animation_editor

import k2 "../../libs/karl2d"

// ============================================================================
// Animation Preview
// ============================================================================

// Update the preview animation timer
preview_update :: proc(state: ^Editor_State, dt: f32) {
	if !state.preview_playing {
		return
	}

	if state.selected_anim < 0 || state.selected_anim >= len(state.animations) {
		return
	}

	anim := &state.animations[state.selected_anim]
	if len(anim.frames) == 0 {
		return
	}

	// Calculate frame duration
	frame_duration: f32
	if anim.fps > 0 {
		frame_duration = 1.0 / anim.fps
	} else {
		frame_duration = 1.0 / 8.0  // Default 8 fps
	}

	// Per-frame override
	frame := &anim.frames[state.preview_frame]
	if frame.duration_ms > 0 {
		frame_duration = frame.duration_ms / 1000.0
	}

	state.preview_elapsed += dt

	for state.preview_elapsed >= frame_duration {
		state.preview_elapsed -= frame_duration

		next := state.preview_frame + 1
		loop_mode := loop_modes[anim.loop_mode]

		switch loop_mode {
		case "once":
			if next >= len(anim.frames) {
				state.preview_playing = false
				state.preview_frame = len(anim.frames) - 1
				state.preview_elapsed = 0
				return
			}
			state.preview_frame = next

		case "loop":
			state.preview_frame = next % len(anim.frames)

		case "ping_pong":
			// Simple ping-pong: just loop for preview
			state.preview_frame = next % len(anim.frames)
		}

		// Get next frame's duration
		if state.preview_frame < len(anim.frames) {
			next_f := &anim.frames[state.preview_frame]
			if next_f.duration_ms > 0 {
				frame_duration = next_f.duration_ms / 1000.0
			}
		}
	}
}

// Render the preview sprite
preview_render :: proc(state: ^Editor_State, bounds: k2.Rect) {
	// Background
	k2.draw_rect(bounds, k2.Color{30, 30, 35, 255})
	k2.draw_rect_outline(bounds, 1, k2.Color{60, 60, 70, 255})

	if state.selected_anim < 0 || state.selected_anim >= len(state.animations) {
		return
	}

	anim := &state.animations[state.selected_anim]
	if len(anim.frames) == 0 || !state.texture_loaded {
		return
	}

	frame_idx := clamp(state.preview_frame, 0, len(anim.frames) - 1)
	frame := &anim.frames[frame_idx]

	if frame.src_rect.w <= 0 || frame.src_rect.h <= 0 {
		return
	}

	// Scale to fit within preview bounds with aspect ratio preservation
	scale := min(
		(bounds.w - 8) / frame.src_rect.w,
		(bounds.h - 8) / frame.src_rect.h,
	)
	dst_w := frame.src_rect.w * scale
	dst_h := frame.src_rect.h * scale

	dst := k2.Rect{
		bounds.x + (bounds.w - dst_w) / 2,
		bounds.y + (bounds.h - dst_h) / 2,
		dst_w,
		dst_h,
	}

	k2.draw_texture_ex(state.texture, frame.src_rect, dst, {}, 0, k2.WHITE)
}
