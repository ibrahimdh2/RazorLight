package editor_ui

import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import k2 "../../libs/karl2d"

// ============================================================================
// Label - Simple text display
// ============================================================================

ui_label :: proc(ctx: ^UI_Context, text: string, color: Color = {}) {
	text_color := color if color.a > 0 else ctx.theme.text_primary
	font_size := ctx.theme.font_size

	// Measure text (approximate)
	text_width := f32(len(text)) * font_size * 0.6
	text_height := font_size

	rect := layout_allocate(ctx, text_width, text_height)
	draw_text(ctx, text, Vec2{rect.x, rect.y}, text_color, font_size)
}

ui_label_secondary :: proc(ctx: ^UI_Context, text: string) {
	ui_label(ctx, text, ctx.theme.text_secondary)
}

// ============================================================================
// Button - Clickable button
// ============================================================================

ui_button :: proc(ctx: ^UI_Context, label: string) -> bool {
	id := ui_id(label)

	// Calculate size
	text_width := f32(len(label)) * ctx.theme.font_size * 0.6
	width := text_width + ctx.theme.padding * 2
	height := ctx.theme.button_height

	rect := layout_allocate(ctx, width, height)

	// Interaction
	hovered, held, pressed, released := ui_widget_behavior(ctx, id, rect)

	// Determine colors
	bg_color := ctx.theme.bg_tertiary
	if held {
		bg_color = ctx.theme.accent_active
	} else if hovered {
		bg_color = ctx.theme.bg_hover
	}

	// Draw
	draw_rect(ctx, rect, bg_color, ctx.theme.border_radius)
	draw_rect_outline(ctx, rect, ctx.theme.border, 1, ctx.theme.border_radius)

	// Center text
	text_x := rect.x + (rect.w - text_width) / 2
	text_y := rect.y + (rect.h - ctx.theme.font_size) / 2
	draw_text(ctx, label, Vec2{text_x, text_y}, ctx.theme.text_primary)

	return released
}

// Button with custom width
ui_button_sized :: proc(ctx: ^UI_Context, label: string, width: f32) -> bool {
	layout_push_width(ctx, width)
	result := ui_button(ctx, label)
	return result
}

// Primary (accent colored) button
ui_button_primary :: proc(ctx: ^UI_Context, label: string) -> bool {
	id := ui_id_with_parent(label, UI_ID(1))  // Different ID namespace

	text_width := f32(len(label)) * ctx.theme.font_size * 0.6
	width := text_width + ctx.theme.padding * 2
	height := ctx.theme.button_height

	rect := layout_allocate(ctx, width, height)

	hovered, held, pressed, released := ui_widget_behavior(ctx, id, rect)

	bg_color := ctx.theme.accent
	if held {
		bg_color = ctx.theme.accent_active
	} else if hovered {
		bg_color = ctx.theme.accent_hover
	}

	draw_rect(ctx, rect, bg_color, ctx.theme.border_radius)

	text_x := rect.x + (rect.w - text_width) / 2
	text_y := rect.y + (rect.h - ctx.theme.font_size) / 2
	draw_text(ctx, label, Vec2{text_x, text_y}, Color{255, 255, 255, 255})

	return released
}

// ============================================================================
// Checkbox - Boolean toggle
// ============================================================================

ui_checkbox :: proc(ctx: ^UI_Context, label: string, value: ^bool) -> bool {
	id := ui_id(label)

	box_size := ctx.theme.input_height
	text_width := f32(len(label)) * ctx.theme.font_size * 0.6
	total_width := box_size + ctx.theme.spacing + text_width

	rect := layout_allocate(ctx, total_width, box_size)

	// Checkbox box rect
	box_rect := Rect{rect.x, rect.y, box_size, box_size}

	hovered, held, pressed, released := ui_widget_behavior(ctx, id, rect)

	// Toggle on click
	changed := false
	if released {
		value^ = !value^
		changed = true
	}

	// Draw box
	box_bg := ctx.theme.bg_tertiary
	if hovered {
		box_bg = ctx.theme.bg_hover
	}
	draw_rect(ctx, box_rect, box_bg, ctx.theme.border_radius)
	draw_rect_outline(ctx, box_rect, ctx.theme.border, 1, ctx.theme.border_radius)

	// Draw checkmark if checked
	if value^ {
		// Fill with accent
		inner := rect_shrink(box_rect, 4)
		draw_rect(ctx, inner, ctx.theme.accent, ctx.theme.border_radius - 2)
	}

	// Draw label
	text_x := rect.x + box_size + ctx.theme.spacing
	text_y := rect.y + (box_size - ctx.theme.font_size) / 2
	draw_text(ctx, label, Vec2{text_x, text_y}, ctx.theme.text_primary)

	return changed
}

// ============================================================================
// Slider - Float value slider
// ============================================================================

ui_slider :: proc(ctx: ^UI_Context, label: string, value: ^f32, min_val, max_val: f32) -> bool {
	id := ui_id(label)

	height := ctx.theme.input_height
	rect := layout_allocate(ctx, 200, height)

	// Split into label and slider
	label_width := f32(len(label)) * ctx.theme.font_size * 0.6 + ctx.theme.spacing
	slider_rect := Rect{
		rect.x + label_width,
		rect.y,
		rect.w - label_width,
		rect.h,
	}

	hovered, held, pressed, released := ui_widget_behavior(ctx, id, slider_rect)

	changed := false

	// Handle dragging
	if held {
		// Calculate value from mouse position
		t := (ctx.mouse_pos.x - slider_rect.x) / slider_rect.w
		t = clamp(t, 0, 1)
		new_val := min_val + t * (max_val - min_val)
		if new_val != value^ {
			value^ = new_val
			changed = true
		}
	}

	// Draw label
	draw_text(ctx, label, Vec2{rect.x, rect.y + (height - ctx.theme.font_size) / 2}, ctx.theme.text_primary)

	// Draw track
	track_height: f32 = 4
	track_rect := Rect{
		slider_rect.x,
		slider_rect.y + (slider_rect.h - track_height) / 2,
		slider_rect.w,
		track_height,
	}
	draw_rect(ctx, track_rect, ctx.theme.bg_tertiary, track_height / 2)

	// Draw filled portion
	t := (value^ - min_val) / (max_val - min_val)
	filled_rect := Rect{
		track_rect.x,
		track_rect.y,
		track_rect.w * t,
		track_rect.h,
	}
	draw_rect(ctx, filled_rect, ctx.theme.accent, track_height / 2)

	// Draw thumb
	thumb_radius: f32 = 8
	thumb_x := slider_rect.x + slider_rect.w * t
	thumb_y := slider_rect.y + slider_rect.h / 2
	thumb_color := ctx.theme.accent_hover if (hovered || held) else ctx.theme.accent
	draw_circle(ctx, Vec2{thumb_x, thumb_y}, thumb_radius, thumb_color)

	// Draw value text
	value_text := fmt.tprintf("%.2f", value^)
	value_width := f32(len(value_text)) * ctx.theme.font_size_small * 0.6
	draw_text(ctx, value_text, Vec2{slider_rect.x + slider_rect.w + ctx.theme.spacing, rect.y + (height - ctx.theme.font_size_small) / 2}, ctx.theme.text_secondary, ctx.theme.font_size_small)

	return changed
}

// Integer slider
ui_slider_int :: proc(ctx: ^UI_Context, label: string, value: ^int, min_val, max_val: int) -> bool {
	f_val := f32(value^)
	changed := ui_slider(ctx, label, &f_val, f32(min_val), f32(max_val))
	if changed {
		value^ = int(f_val + 0.5)  // Round
	}
	return changed
}

// ============================================================================
// Text Input - Single line text entry
// ============================================================================

ui_text_input :: proc(ctx: ^UI_Context, label: string, buffer: []u8, buffer_len: ^int) -> bool {
	id := ui_id(label)
	state := get_widget_state(ctx, id)

	height := ctx.theme.input_height
	rect := layout_allocate(ctx, 200, height)

	// Label area
	label_width := f32(len(label)) * ctx.theme.font_size * 0.6 + ctx.theme.spacing
	input_rect := Rect{
		rect.x + label_width,
		rect.y,
		rect.w - label_width,
		rect.h,
	}

	hovered, held, pressed, released := ui_widget_behavior(ctx, id, input_rect)

	// Focus on click
	if released {
		ctx.focus_id = id
		// Place cursor at end
		state.cursor_pos = buffer_len^
	}

	is_focused := ctx.focus_id == id
	changed := false

	// Handle keyboard input when focused
	if is_focused {
		// Handle backspace
		if ctx.key_pressed[int(k2.Keyboard_Key.Backspace)] && state.cursor_pos > 0 {
			// Remove character before cursor
			for i := state.cursor_pos - 1; i < buffer_len^ - 1; i += 1 {
				buffer[i] = buffer[i + 1]
			}
			buffer_len^ -= 1
			state.cursor_pos -= 1
			changed = true
		}

		// Handle delete
		if ctx.key_pressed[int(k2.Keyboard_Key.Delete)] && state.cursor_pos < buffer_len^ {
			for i := state.cursor_pos; i < buffer_len^ - 1; i += 1 {
				buffer[i] = buffer[i + 1]
			}
			buffer_len^ -= 1
			changed = true
		}

		// Handle left/right
		if ctx.key_pressed[int(k2.Keyboard_Key.Left)] && state.cursor_pos > 0 {
			state.cursor_pos -= 1
		}
		if ctx.key_pressed[int(k2.Keyboard_Key.Right)] && state.cursor_pos < buffer_len^ {
			state.cursor_pos += 1
		}

		// Handle home/end
		if ctx.key_pressed[int(k2.Keyboard_Key.Home)] {
			state.cursor_pos = 0
		}
		if ctx.key_pressed[int(k2.Keyboard_Key.End)] {
			state.cursor_pos = buffer_len^
		}

		// Handle escape (unfocus)
		if ctx.key_pressed[int(k2.Keyboard_Key.Escape)] {
			ctx.focus_id = UI_ID_NONE
		}

		// Handle character input
		for r in ctx.text_input {
			if buffer_len^ < len(buffer) - 1 {
				// Insert character at cursor
				for i := buffer_len^; i > state.cursor_pos; i -= 1 {
					buffer[i] = buffer[i - 1]
				}
				buffer[state.cursor_pos] = u8(r)  // Simple ASCII for now
				buffer_len^ += 1
				state.cursor_pos += 1
				changed = true
			}
		}
	}

	// Draw label
	draw_text(ctx, label, Vec2{rect.x, rect.y + (height - ctx.theme.font_size) / 2}, ctx.theme.text_primary)

	// Draw input background
	bg_color := ctx.theme.bg_primary
	border_color := ctx.theme.border_focused if is_focused else ctx.theme.border
	draw_rect(ctx, input_rect, bg_color, ctx.theme.border_radius)
	draw_rect_outline(ctx, input_rect, border_color, 1, ctx.theme.border_radius)

	// Draw text
	text_str := string(buffer[:buffer_len^])
	text_x := input_rect.x + ctx.theme.padding_small
	text_y := input_rect.y + (input_rect.h - ctx.theme.font_size) / 2
	push_scissor(ctx, input_rect)
	draw_text(ctx, text_str, Vec2{text_x, text_y}, ctx.theme.text_primary)

	// Draw cursor if focused
	if is_focused {
		cursor_x := text_x + f32(state.cursor_pos) * ctx.theme.font_size * 0.6
		cursor_y1 := input_rect.y + ctx.theme.padding_small
		cursor_y2 := input_rect.y + input_rect.h - ctx.theme.padding_small

		// Blink cursor
		if int(ctx.frame_count / 30) % 2 == 0 {
			draw_line(ctx, Vec2{cursor_x, cursor_y1}, Vec2{cursor_x, cursor_y2}, ctx.theme.text_primary, 1)
		}
	}
	pop_scissor(ctx)

	return changed
}

// ============================================================================
// Dropdown - Selection from list
// ============================================================================

ui_dropdown :: proc(ctx: ^UI_Context, label: string, options: []string, selected: ^int) -> bool {
	id := ui_id(label)
	state := get_widget_state(ctx, id)

	height := ctx.theme.input_height
	rect := layout_allocate(ctx, 200, height)

	// Label area
	label_width := f32(len(label)) * ctx.theme.font_size * 0.6 + ctx.theme.spacing
	dropdown_rect := Rect{
		rect.x + label_width,
		rect.y,
		rect.w - label_width,
		rect.h,
	}

	hovered, held, pressed, released := ui_widget_behavior(ctx, id, dropdown_rect)

	// Toggle expanded on click
	if released {
		state.expanded = !state.expanded
	}

	changed := false

	// Draw label
	draw_text(ctx, label, Vec2{rect.x, rect.y + (height - ctx.theme.font_size) / 2}, ctx.theme.text_primary)

	// Draw dropdown button
	bg_color := ctx.theme.bg_hover if hovered else ctx.theme.bg_tertiary
	draw_rect(ctx, dropdown_rect, bg_color, ctx.theme.border_radius)
	draw_rect_outline(ctx, dropdown_rect, ctx.theme.border, 1, ctx.theme.border_radius)

	// Draw selected text
	selected_text := options[selected^] if selected^ >= 0 && selected^ < len(options) else ""
	text_x := dropdown_rect.x + ctx.theme.padding_small
	text_y := dropdown_rect.y + (dropdown_rect.h - ctx.theme.font_size) / 2
	draw_text(ctx, selected_text, Vec2{text_x, text_y}, ctx.theme.text_primary)

	// Draw arrow
	arrow_x := dropdown_rect.x + dropdown_rect.w - ctx.theme.padding - 8
	arrow_y := dropdown_rect.y + dropdown_rect.h / 2
	draw_text(ctx, "v", Vec2{arrow_x, arrow_y - ctx.theme.font_size / 2}, ctx.theme.text_secondary)

	// Draw dropdown list if expanded
	if state.expanded {
		list_rect := Rect{
			dropdown_rect.x,
			dropdown_rect.y + dropdown_rect.h + 2,
			dropdown_rect.w,
			f32(len(options)) * height,
		}

		// Background
		draw_rect(ctx, list_rect, ctx.theme.bg_secondary, ctx.theme.border_radius)
		draw_rect_outline(ctx, list_rect, ctx.theme.border, 1, ctx.theme.border_radius)

		// Options
		for opt, i in options {
			opt_rect := Rect{
				list_rect.x,
				list_rect.y + f32(i) * height,
				list_rect.w,
				height,
			}

			opt_hovered := rect_contains(opt_rect, ctx.mouse_pos)
			if opt_hovered {
				draw_rect(ctx, opt_rect, ctx.theme.selection)

				if ctx.mouse_pressed[0] {
					selected^ = i
					state.expanded = false
					changed = true
				}
			}

			opt_text_y := opt_rect.y + (opt_rect.h - ctx.theme.font_size) / 2
			draw_text(ctx, opt, Vec2{opt_rect.x + ctx.theme.padding_small, opt_text_y}, ctx.theme.text_primary)
		}

		// Close if clicked outside
		if ctx.mouse_pressed[0] && !rect_contains(list_rect, ctx.mouse_pos) && !rect_contains(dropdown_rect, ctx.mouse_pos) {
			state.expanded = false
		}
	}

	return changed
}

// ============================================================================
// Tree Node - Collapsible tree item
// ============================================================================

Tree_Flags :: bit_set[Tree_Flag]

Tree_Flag :: enum {
	Leaf,           // No expand arrow
	Default_Open,   // Start expanded
	Selected,       // Show as selected
}

ui_tree_node :: proc(ctx: ^UI_Context, label: string, flags: Tree_Flags = {}) -> bool {
	id := ui_id(label)
	state := get_widget_state(ctx, id)

	// Initialize expansion state
	if .Default_Open in flags && ctx.frame_count == 1 {
		state.expanded = true
	}

	height := ctx.theme.input_height
	rect := layout_allocate(ctx, 200, height)

	is_leaf := .Leaf in flags
	is_selected := .Selected in flags

	hovered, held, pressed, released := ui_widget_behavior(ctx, id, rect)

	// Toggle on click (if not leaf)
	if released && !is_leaf {
		state.expanded = !state.expanded
	}

	// Background for selected/hovered
	if is_selected {
		draw_rect(ctx, rect, ctx.theme.selection)
	} else if hovered {
		draw_rect(ctx, rect, ctx.theme.highlight)
	}

	// Draw expand arrow (if not leaf)
	arrow_x := rect.x + ctx.theme.padding_small
	arrow_y := rect.y + (height - ctx.theme.font_size) / 2
	if !is_leaf {
		arrow_text := ">" if !state.expanded else "v"
		draw_text(ctx, arrow_text, Vec2{arrow_x, arrow_y}, ctx.theme.text_secondary)
	}

	// Draw label
	text_x := rect.x + ctx.theme.padding_small + (ctx.theme.font_size if !is_leaf else 0) + ctx.theme.spacing_small
	draw_text(ctx, label, Vec2{text_x, arrow_y}, ctx.theme.text_primary)

	return state.expanded
}

// Indent for tree children
ui_tree_push :: proc(ctx: ^UI_Context) {
	layout_space(ctx, 0)
	if layout := current_layout(ctx); layout != nil {
		layout.cursor.x += ctx.theme.padding_large
	}
}

ui_tree_pop :: proc(ctx: ^UI_Context) {
	if layout := current_layout(ctx); layout != nil {
		layout.cursor.x -= ctx.theme.padding_large
	}
}

// ============================================================================
// Color Picker - RGBA color selection
// ============================================================================

ui_color_picker :: proc(ctx: ^UI_Context, label: string, color: ^Color) -> bool {
	id := ui_id(label)

	height := ctx.theme.input_height
	rect := layout_allocate(ctx, 200, height)

	// Label
	label_width := f32(len(label)) * ctx.theme.font_size * 0.6 + ctx.theme.spacing

	// Color preview
	preview_rect := Rect{
		rect.x + label_width,
		rect.y,
		height,
		height,
	}

	hovered, held, pressed, released := ui_widget_behavior(ctx, id, preview_rect)

	// Draw label
	draw_text(ctx, label, Vec2{rect.x, rect.y + (height - ctx.theme.font_size) / 2}, ctx.theme.text_primary)

	// Draw color preview
	draw_rect(ctx, preview_rect, color^, ctx.theme.border_radius)
	draw_rect_outline(ctx, preview_rect, ctx.theme.border, 1, ctx.theme.border_radius)

	// TODO: Expand into full color picker popup when clicked
	// For now, just show the preview

	return false
}

// ============================================================================
// Vec2 Field - Two float inputs
// ============================================================================

ui_vec2_field :: proc(ctx: ^UI_Context, label: string, value: ^Vec2) -> bool {
	layout_begin_row(ctx, ctx.theme.input_height)
	defer layout_end_row(ctx)

	changed := false

	// Label
	ui_label(ctx, label)

	layout_space(ctx, ctx.theme.spacing)

	// X field
	ui_label(ctx, "X:")
	layout_push_width(ctx, 60)
	if ui_float_field(ctx, fmt.tprintf("%s_x", label), &value.x) {
		changed = true
	}

	layout_space(ctx, ctx.theme.spacing)

	// Y field
	ui_label(ctx, "Y:")
	layout_push_width(ctx, 60)
	if ui_float_field(ctx, fmt.tprintf("%s_y", label), &value.y) {
		changed = true
	}

	return changed
}

// Single float input field
ui_float_field :: proc(ctx: ^UI_Context, label: string, value: ^f32) -> bool {
	id := ui_id(label)

	rect := layout_allocate(ctx, 60, ctx.theme.input_height)

	hovered, held, pressed, released := ui_widget_behavior(ctx, id, rect)

	// Focus on click
	if released {
		ctx.focus_id = id
	}

	is_focused := ctx.focus_id == id
	changed := false

	// Draw background
	bg_color := ctx.theme.bg_primary
	border_color := ctx.theme.border_focused if is_focused else ctx.theme.border
	draw_rect(ctx, rect, bg_color, ctx.theme.border_radius)
	draw_rect_outline(ctx, rect, border_color, 1, ctx.theme.border_radius)

	// Draw value
	value_text := fmt.tprintf("%.2f", value^)
	text_x := rect.x + ctx.theme.padding_small
	text_y := rect.y + (rect.h - ctx.theme.font_size) / 2
	draw_text(ctx, value_text, Vec2{text_x, text_y}, ctx.theme.text_primary)

	// TODO: Handle input editing

	return changed
}

// ============================================================================
// Progress Bar
// ============================================================================

ui_progress_bar :: proc(ctx: ^UI_Context, value: f32, label: string = "") {
	height := ctx.theme.input_height / 2
	rect := layout_allocate(ctx, 200, height)

	// Background
	draw_rect(ctx, rect, ctx.theme.bg_tertiary, height / 2)

	// Fill
	t := clamp(value, 0, 1)
	fill_rect := Rect{rect.x, rect.y, rect.w * t, rect.h}
	draw_rect(ctx, fill_rect, ctx.theme.accent, height / 2)

	// Label
	if len(label) > 0 {
		text_x := rect.x + (rect.w - f32(len(label)) * ctx.theme.font_size_small * 0.6) / 2
		text_y := rect.y + (rect.h - ctx.theme.font_size_small) / 2
		draw_text(ctx, label, Vec2{text_x, text_y}, ctx.theme.text_primary, ctx.theme.font_size_small)
	}
}

// ============================================================================
// Tooltip
// ============================================================================

ui_tooltip :: proc(ctx: ^UI_Context, text: string) {
	// Called after a widget to show tooltip on hover
	if ctx.hot_id != UI_ID_NONE {
		ctx.tooltip_id = ctx.hot_id
		ctx.tooltip_text = text
	}
}

// Draw tooltip (call at end of frame)
ui_draw_tooltip :: proc(ctx: ^UI_Context) {
	if ctx.tooltip_id == UI_ID_NONE || len(ctx.tooltip_text) == 0 {
		return
	}

	// Position tooltip near mouse
	text_width := f32(len(ctx.tooltip_text)) * ctx.theme.font_size * 0.6
	padding := ctx.theme.padding_small

	rect := Rect{
		ctx.mouse_pos.x + 16,
		ctx.mouse_pos.y + 16,
		text_width + padding * 2,
		ctx.theme.font_size + padding * 2,
	}

	// Keep on screen
	if rect.x + rect.w > ctx.screen_width {
		rect.x = ctx.screen_width - rect.w
	}
	if rect.y + rect.h > ctx.screen_height {
		rect.y = ctx.mouse_pos.y - rect.h - 4
	}

	draw_rect(ctx, rect, ctx.theme.bg_secondary, ctx.theme.border_radius)
	draw_rect_outline(ctx, rect, ctx.theme.border, 1, ctx.theme.border_radius)
	draw_text(ctx, ctx.tooltip_text, Vec2{rect.x + padding, rect.y + padding}, ctx.theme.text_primary)
}

// ============================================================================
// Header / Collapsing Header
// ============================================================================

ui_header :: proc(ctx: ^UI_Context, label: string) -> bool {
	id := ui_id(label)
	state := get_widget_state(ctx, id)

	height := ctx.theme.header_height
	rect := layout_allocate(ctx, 0, height)  // 0 width = full available

	hovered, held, pressed, released := ui_widget_behavior(ctx, id, rect)

	if released {
		state.expanded = !state.expanded
	}

	// Background
	draw_rect(ctx, rect, ctx.theme.bg_secondary)

	// Arrow
	arrow_x := rect.x + ctx.theme.padding
	arrow_y := rect.y + (height - ctx.theme.font_size) / 2
	arrow_text := "v" if state.expanded else ">"
	draw_text(ctx, arrow_text, Vec2{arrow_x, arrow_y}, ctx.theme.text_secondary)

	// Label
	text_x := arrow_x + ctx.theme.font_size + ctx.theme.spacing_small
	draw_text(ctx, label, Vec2{text_x, arrow_y}, ctx.theme.text_primary)

	return state.expanded
}

// ============================================================================
// Separator
// ============================================================================

ui_separator :: proc(ctx: ^UI_Context) {
	layout_separator(ctx)
}

// ============================================================================
// Spacing
// ============================================================================

ui_spacing :: proc(ctx: ^UI_Context, amount: f32 = 0) {
	space := amount if amount > 0 else ctx.theme.spacing
	layout_space(ctx, space)
}
