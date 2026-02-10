package animation_editor

import k2 "../../libs/karl2d"
import "core:fmt"

// ============================================================================
// Timeline Panel - Bottom
// ============================================================================

FRAME_THUMB_SIZE :: 48
FRAME_SPACING    :: 4
TIMELINE_PADDING :: 8
CONTROLS_HEIGHT  :: 32

editor_render_timeline :: proc(state: ^Editor_State, bounds: k2.Rect) {
	// Background
	k2.draw_rect(bounds, k2.Color{35, 35, 40, 255})

	// Top border
	k2.draw_line(
		k2.Vec2{bounds.x, bounds.y},
		k2.Vec2{bounds.x + bounds.w, bounds.y},
		1,
		k2.Color{60, 60, 60, 255},
	)

	if state.selected_anim < 0 || state.selected_anim >= len(state.animations) {
		k2.draw_text("Select an animation to view timeline",
			k2.Vec2{bounds.x + 20, bounds.y + bounds.h / 2 - 8},
			14, k2.Color{120, 120, 120, 255})
		return
	}

	anim := &state.animations[state.selected_anim]

	// Controls row
	controls_y := bounds.y + TIMELINE_PADDING
	render_controls(state, anim, k2.Rect{bounds.x + TIMELINE_PADDING, controls_y, bounds.w - TIMELINE_PADDING * 2, CONTROLS_HEIGHT})

	// Frame thumbnails row
	frames_y := controls_y + CONTROLS_HEIGHT + TIMELINE_PADDING
	render_frame_strip(state, anim, k2.Rect{bounds.x + TIMELINE_PADDING, frames_y, bounds.w - TIMELINE_PADDING * 2, FRAME_THUMB_SIZE + 20})

	// Preview in bottom-right
	preview_size: f32 = bounds.h - CONTROLS_HEIGHT - TIMELINE_PADDING * 4
	preview_x := bounds.x + bounds.w - preview_size - TIMELINE_PADDING
	preview_y := controls_y
	preview_render(state, k2.Rect{preview_x, preview_y, preview_size, preview_size})
}

// ============================================================================
// Playback Controls
// ============================================================================

@(private)
render_controls :: proc(state: ^Editor_State, anim: ^Editor_Animation, bounds: k2.Rect) {
	mouse := k2.get_mouse_position()
	btn_w: f32 = 32
	btn_h: f32 = 24
	x := bounds.x
	y := bounds.y + 4

	// First frame button
	if draw_button(k2.Rect{x, y, btn_w, btn_h}, "|<", mouse) {
		state.preview_frame = 0
		state.preview_elapsed = 0
	}
	x += btn_w + 4

	// Previous frame
	if draw_button(k2.Rect{x, y, btn_w, btn_h}, "<", mouse) {
		if state.preview_frame > 0 {
			state.preview_frame -= 1
			state.preview_elapsed = 0
		}
	}
	x += btn_w + 4

	// Play/Pause toggle
	play_label := "||" if state.preview_playing else ">"
	if draw_button(k2.Rect{x, y, btn_w, btn_h}, play_label, mouse) {
		state.preview_playing = !state.preview_playing
	}
	x += btn_w + 4

	// Next frame
	if draw_button(k2.Rect{x, y, btn_w, btn_h}, ">", mouse) {
		if len(anim.frames) > 0 {
			state.preview_frame = (state.preview_frame + 1) % len(anim.frames)
			state.preview_elapsed = 0
		}
	}
	x += btn_w + 4

	// Last frame button
	if draw_button(k2.Rect{x, y, btn_w, btn_h}, ">|", mouse) {
		if len(anim.frames) > 0 {
			state.preview_frame = len(anim.frames) - 1
			state.preview_elapsed = 0
		}
	}
	x += btn_w + 16

	// Frame counter
	frame_text := fmt.tprintf("Frame: %d / %d", state.preview_frame + 1 if len(anim.frames) > 0 else 0, len(anim.frames))
	k2.draw_text(frame_text, k2.Vec2{x, y + 4}, 14, k2.Color{200, 200, 200, 255})
	x += 120

	// Add Frame button
	if draw_button(k2.Rect{x, y, 80, btn_h}, "+ Frame", mouse) {
		// Add an empty frame (user should select from sheet)
		if state.texture_loaded {
			editor_add_frame(state, k2.Rect{0, 0, f32(state.grid_cell_w), f32(state.grid_cell_h)})
		}
	}
}

// ============================================================================
// Frame Strip
// ============================================================================

@(private)
render_frame_strip :: proc(state: ^Editor_State, anim: ^Editor_Animation, bounds: k2.Rect) {
	mouse := k2.get_mouse_position()

	for fi in 0..<len(anim.frames) {
		frame := &anim.frames[fi]

		x := bounds.x + f32(fi) * (FRAME_THUMB_SIZE + FRAME_SPACING)
		y := bounds.y

		// Check if visible
		if x > bounds.x + bounds.w {
			break
		}
		if x + FRAME_THUMB_SIZE < bounds.x {
			continue
		}

		thumb_rect := k2.Rect{x, y, FRAME_THUMB_SIZE, FRAME_THUMB_SIZE}

		// Background
		bg_color: k2.Color
		if fi == state.selected_frame {
			bg_color = k2.Color{0, 120, 200, 255}
		} else if fi == state.preview_frame {
			bg_color = k2.Color{80, 80, 100, 255}
		} else {
			bg_color = k2.Color{50, 50, 55, 255}
		}
		k2.draw_rect(thumb_rect, bg_color)

		// Draw frame thumbnail if texture loaded
		if state.texture_loaded && frame.src_rect.w > 0 && frame.src_rect.h > 0 {
			// Scale source rect to fit thumbnail
			scale := min(FRAME_THUMB_SIZE / frame.src_rect.w, FRAME_THUMB_SIZE / frame.src_rect.h)
			dst_w := frame.src_rect.w * scale
			dst_h := frame.src_rect.h * scale
			dst := k2.Rect{
				x + (FRAME_THUMB_SIZE - dst_w) / 2,
				y + (FRAME_THUMB_SIZE - dst_h) / 2,
				dst_w,
				dst_h,
			}
			k2.draw_texture_ex(state.texture, frame.src_rect, dst, {}, 0, k2.WHITE)
		}

		// Border
		k2.draw_rect_outline(thumb_rect, 1, k2.Color{100, 100, 100, 255})

		// Frame number label
		label := fmt.tprintf("%d", fi)
		k2.draw_text(label, k2.Vec2{x + 2, y + FRAME_THUMB_SIZE + 2}, 10, k2.Color{160, 160, 160, 255})

		// Click to select
		if k2.mouse_button_went_down(.Left) {
			if mouse.x >= thumb_rect.x && mouse.x < thumb_rect.x + thumb_rect.w &&
			   mouse.y >= thumb_rect.y && mouse.y < thumb_rect.y + thumb_rect.h {
				state.selected_frame = fi
				state.preview_frame = fi
				state.preview_elapsed = 0
			}
		}
	}
}

// ============================================================================
// Simple Button Helper (draws directly via karl2d)
// ============================================================================

@(private)
draw_button :: proc(rect: k2.Rect, label: string, mouse: k2.Vec2) -> bool {
	hovered := mouse.x >= rect.x && mouse.x < rect.x + rect.w &&
	           mouse.y >= rect.y && mouse.y < rect.y + rect.h

	bg := k2.Color{70, 70, 80, 255} if hovered else k2.Color{55, 55, 65, 255}
	k2.draw_rect(rect, bg)
	k2.draw_rect_outline(rect, 1, k2.Color{90, 90, 100, 255})

	// Center text
	text_x := rect.x + rect.w / 2 - f32(len(label)) * 3.5
	text_y := rect.y + rect.h / 2 - 6
	k2.draw_text(label, k2.Vec2{text_x, text_y}, 12, k2.Color{220, 220, 220, 255})

	return hovered && k2.mouse_button_went_down(.Left)
}
