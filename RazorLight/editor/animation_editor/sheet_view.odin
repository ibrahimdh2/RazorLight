package animation_editor

import k2 "../../libs/karl2d"
import "core:math"

// ============================================================================
// Sprite Sheet View - Center Panel
// ============================================================================

// Renders the sprite sheet canvas with pan/zoom, grid overlay, and frame selection
sheet_view_render :: proc(state: ^Editor_State, bounds: k2.Rect) {
	// Background
	k2.draw_rect(bounds, k2.Color{40, 40, 40, 255})

	// Handle pan and zoom input within bounds
	mouse := k2.get_mouse_position()
	in_bounds := mouse.x >= bounds.x && mouse.x < bounds.x + bounds.w &&
	             mouse.y >= bounds.y && mouse.y < bounds.y + bounds.h

	if in_bounds {
		// Zoom with scroll wheel
		scroll := k2.get_mouse_wheel_delta()
		if scroll != 0 {
			old_zoom := state.view_zoom
			state.view_zoom *= 1.0 + scroll * 0.1
			state.view_zoom = clamp(state.view_zoom, 0.1, 10.0)

			// Zoom toward mouse position
			mx := mouse.x - bounds.x - state.view_offset.x
			my := mouse.y - bounds.y - state.view_offset.y
			state.view_offset.x -= mx * (state.view_zoom / old_zoom - 1)
			state.view_offset.y -= my * (state.view_zoom / old_zoom - 1)
		}

		// Pan with middle mouse button
		if k2.mouse_button_went_down(.Middle) {
			state.is_panning = true
			state.pan_start = mouse
		}

		// Frame selection with left click-drag
		if k2.mouse_button_went_down(.Left) && !state.is_panning {
			state.is_selecting = true
			// Convert screen pos to sheet coords
			state.select_start = screen_to_sheet(state, mouse, bounds)
			state.select_end = state.select_start
		}
	}

	// Continue pan/select even if mouse leaves bounds
	if state.is_panning {
		delta := k2.get_mouse_delta()
		state.view_offset.x += delta.x
		state.view_offset.y += delta.y

		if !k2.mouse_button_is_held(.Middle) {
			state.is_panning = false
		}
	}

	if state.is_selecting {
		state.select_end = screen_to_sheet(state, mouse, bounds)

		if !k2.mouse_button_is_held(.Left) {
			state.is_selecting = false

			// Create frame from selection
			sel := normalize_selection(state.select_start, state.select_end)
			if sel.w > 1 && sel.h > 1 {
				// Snap to grid if enabled
				if state.grid_enabled {
					sel = snap_to_grid(sel, state.grid_cell_w, state.grid_cell_h)
				}
				editor_add_frame(state, sel)
			}
		}
	}

	if !state.texture_loaded {
		// Show placeholder text
		k2.draw_text("Load a sprite sheet to begin",
			k2.Vec2{bounds.x + bounds.w / 2 - 120, bounds.y + bounds.h / 2 - 10},
			16, k2.Color{150, 150, 150, 255})
		return
	}

	// Draw the sprite sheet
	tex := state.texture
	sheet_x := bounds.x + state.view_offset.x
	sheet_y := bounds.y + state.view_offset.y
	sheet_w := f32(tex.width) * state.view_zoom
	sheet_h := f32(tex.height) * state.view_zoom

	// Checkerboard background for transparency
	k2.draw_rect(k2.Rect{sheet_x, sheet_y, sheet_w, sheet_h}, k2.Color{60, 60, 60, 255})

	// Draw the texture
	src := k2.Rect{0, 0, f32(tex.width), f32(tex.height)}
	dst := k2.Rect{sheet_x, sheet_y, sheet_w, sheet_h}
	k2.draw_texture_ex(tex, src, dst, {}, 0, k2.WHITE)

	// Draw grid overlay
	if state.grid_enabled && state.grid_cell_w > 0 && state.grid_cell_h > 0 {
		grid_color := k2.Color{255, 255, 255, 40}
		cw := f32(state.grid_cell_w) * state.view_zoom
		ch := f32(state.grid_cell_h) * state.view_zoom

		// Vertical lines
		x := sheet_x
		for x <= sheet_x + sheet_w {
			k2.draw_line(k2.Vec2{x, sheet_y}, k2.Vec2{x, sheet_y + sheet_h}, 1, grid_color)
			x += cw
		}

		// Horizontal lines
		y := sheet_y
		for y <= sheet_y + sheet_h {
			k2.draw_line(k2.Vec2{sheet_x, y}, k2.Vec2{sheet_x + sheet_w, y}, 1, grid_color)
			y += ch
		}
	}

	// Draw existing frame rects for current animation
	if state.selected_anim >= 0 && state.selected_anim < len(state.animations) {
		anim := &state.animations[state.selected_anim]
		for fi in 0..<len(anim.frames) {
			frame := &anim.frames[fi]
			rect := sheet_to_screen_rect(state, frame.src_rect, bounds)

			outline_color := k2.Color{0, 255, 0, 180} if fi == state.selected_frame else k2.Color{255, 255, 0, 120}
			k2.draw_rect_outline(rect, 2, outline_color)
		}
	}

	// Draw current selection rect
	if state.is_selecting {
		sel := normalize_selection(state.select_start, state.select_end)
		sel_screen := sheet_to_screen_rect(state, sel, bounds)
		k2.draw_rect_outline(sel_screen, 2, k2.Color{0, 150, 255, 200})
		k2.draw_rect(sel_screen, k2.Color{0, 150, 255, 40})
	}
}

// ============================================================================
// Coordinate Conversion
// ============================================================================

// Convert screen position to sprite sheet coordinates
screen_to_sheet :: proc(state: ^Editor_State, screen_pos: k2.Vec2, bounds: k2.Rect) -> k2.Vec2 {
	return k2.Vec2{
		(screen_pos.x - bounds.x - state.view_offset.x) / state.view_zoom,
		(screen_pos.y - bounds.y - state.view_offset.y) / state.view_zoom,
	}
}

// Convert a sheet-space rect to screen-space rect
sheet_to_screen_rect :: proc(state: ^Editor_State, rect: k2.Rect, bounds: k2.Rect) -> k2.Rect {
	return k2.Rect{
		bounds.x + state.view_offset.x + rect.x * state.view_zoom,
		bounds.y + state.view_offset.y + rect.y * state.view_zoom,
		rect.w * state.view_zoom,
		rect.h * state.view_zoom,
	}
}

// Normalize a selection so w and h are positive
normalize_selection :: proc(start, end: k2.Vec2) -> k2.Rect {
	x := min(start.x, end.x)
	y := min(start.y, end.y)
	w := abs(end.x - start.x)
	h := abs(end.y - start.y)
	return k2.Rect{x, y, w, h}
}

// Snap a rectangle to the grid
snap_to_grid :: proc(rect: k2.Rect, cell_w, cell_h: int) -> k2.Rect {
	cw := f32(cell_w)
	ch := f32(cell_h)
	return k2.Rect{
		math.floor(rect.x / cw) * cw,
		math.floor(rect.y / ch) * ch,
		math.ceil(rect.w / cw) * cw,
		math.ceil(rect.h / ch) * ch,
	}
}
