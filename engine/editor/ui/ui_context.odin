package editor_ui

import k2 "../../../Libraries/karl2d"
import "core:hash"
import "core:fmt"
import "core:strings"

// ============================================================================
// UI ID System - Unique widget identification
// ============================================================================

UI_ID :: distinct u64
UI_ID_NONE :: UI_ID(0)

// Generate a unique ID from a string label
ui_id :: proc(label: string) -> UI_ID {
	return UI_ID(hash.fnv64a(transmute([]u8)label))
}

// Generate a unique ID with parent context
ui_id_with_parent :: proc(label: string, parent: UI_ID) -> UI_ID {
	h := hash.fnv64a(transmute([]u8)label)
	h ~= u64(parent)
	return UI_ID(h)
}

// ============================================================================
// Basic Types
// ============================================================================

Vec2 :: [2]f32
Rect :: struct {
	x, y, w, h: f32,
}

rect_contains :: proc(r: Rect, p: Vec2) -> bool {
	return p.x >= r.x && p.x < r.x + r.w && p.y >= r.y && p.y < r.y + r.h
}

rect_intersects :: proc(a, b: Rect) -> bool {
	return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y
}

rect_expand :: proc(r: Rect, amount: f32) -> Rect {
	return Rect{r.x - amount, r.y - amount, r.w + amount * 2, r.h + amount * 2}
}

rect_shrink :: proc(r: Rect, amount: f32) -> Rect {
	return Rect{r.x + amount, r.y + amount, r.w - amount * 2, r.h - amount * 2}
}

// ============================================================================
// Draw Commands - Deferred rendering
// ============================================================================

Draw_Command :: union {
	Draw_Rect,
	Draw_Rect_Outline,
	Draw_Circle,
	Draw_Circle_Outline,
	Draw_Line,
	Draw_Text,
	Draw_Scissor_Push,
	Draw_Scissor_Pop,
}

Draw_Rect :: struct {
	rect:   Rect,
	color:  Color,
	radius: f32,   // Corner radius (0 = sharp corners)
}

Draw_Rect_Outline :: struct {
	rect:      Rect,
	color:     Color,
	thickness: f32,
	radius:    f32,
}

Draw_Circle :: struct {
	center: Vec2,
	radius: f32,
	color:  Color,
}

Draw_Circle_Outline :: struct {
	center:    Vec2,
	radius:    f32,
	color:     Color,
	thickness: f32,
}

Draw_Line :: struct {
	start:     Vec2,
	end:       Vec2,
	color:     Color,
	thickness: f32,
}

Draw_Text :: struct {
	text:      string,
	pos:       Vec2,
	color:     Color,
	font_size: f32,
}

Draw_Scissor_Push :: struct {
	rect: Rect,
}

Draw_Scissor_Pop :: struct {}

// ============================================================================
// Mouse Button State
// ============================================================================

Mouse_Button :: enum {
	Left   = 0,
	Right  = 1,
	Middle = 2,
}

// ============================================================================
// UI Context - Core state for the UI system
// ============================================================================

UI_Context :: struct {
	// Input state (updated each frame)
	mouse_pos:        Vec2,
	mouse_delta:      Vec2,
	mouse_down:       [3]bool,
	mouse_pressed:    [3]bool,
	mouse_released:   [3]bool,
	scroll_delta:     f32,

	// Keyboard input
	key_pressed:      [256]bool,
	key_held:         [256]bool,
	text_input:       [dynamic]rune,

	// Focus & interaction state
	hot_id:           UI_ID,      // Widget being hovered
	active_id:        UI_ID,      // Widget being interacted with
	focus_id:         UI_ID,      // Widget with keyboard focus
	last_active_id:   UI_ID,      // Active ID from previous frame

	// Drag state
	drag_start_pos:   Vec2,
	drag_offset:      Vec2,
	is_dragging:      bool,

	// Draw list
	draw_list:        [dynamic]Draw_Command,

	// Scissor stack
	scissor_stack:    [dynamic]Rect,

	// Theme
	theme:            ^Theme,
	default_theme:    Theme,

	// Screen size
	screen_width:     f32,
	screen_height:    f32,

	// Widget state storage (for text input, etc.)
	widget_state:     map[UI_ID]Widget_State,

	// Tooltip state
	tooltip_id:       UI_ID,
	tooltip_text:     string,
	tooltip_timer:    f32,

	// Current frame
	frame_count:      u64,

	// Layout system
	layout_stack:     Layout_Stack,
}

// Per-widget persistent state
Widget_State :: struct {
	// Text input state
	cursor_pos:       int,
	selection_start:  int,
	selection_end:    int,
	scroll_offset:    f32,

	// Tree node state
	expanded:         bool,

	// Scroll state
	scroll_x:         f32,
	scroll_y:         f32,

	// Animation state
	hover_amount:     f32,   // 0-1 for hover transition
}

// ============================================================================
// UI Context Lifecycle
// ============================================================================

ui_context_create :: proc() -> ^UI_Context {
	ctx := new(UI_Context)

	ctx.theme = &ctx.default_theme
	ctx.default_theme = theme_dark()

	ctx.draw_list = make([dynamic]Draw_Command)
	ctx.scissor_stack = make([dynamic]Rect)
	ctx.text_input = make([dynamic]rune)
	ctx.widget_state = make(map[UI_ID]Widget_State)

	ctx.screen_width = f32(k2.get_screen_width())
	ctx.screen_height = f32(k2.get_screen_height())

	return ctx
}

ui_context_destroy :: proc(ctx: ^UI_Context) {
	if ctx == nil do return

	delete(ctx.draw_list)
	delete(ctx.scissor_stack)
	delete(ctx.text_input)
	delete(ctx.widget_state)

	free(ctx)
}

// ============================================================================
// Frame Management
// ============================================================================

ui_begin_frame :: proc(ctx: ^UI_Context) {
	ctx.frame_count += 1

	// Update screen size
	ctx.screen_width = f32(k2.get_screen_width())
	ctx.screen_height = f32(k2.get_screen_height())

	// Update mouse state
	prev_pos := ctx.mouse_pos
	ctx.mouse_pos = k2.get_mouse_position()
	ctx.mouse_delta = ctx.mouse_pos - prev_pos

	// Mouse buttons
	for i in 0..<3 {
		prev_down := ctx.mouse_down[i]
		ctx.mouse_down[i] = k2.mouse_button_is_held(k2.Mouse_Button(i))
		ctx.mouse_pressed[i] = ctx.mouse_down[i] && !prev_down
		ctx.mouse_released[i] = !ctx.mouse_down[i] && prev_down
	}

	// Scroll
	ctx.scroll_delta = f32(k2.get_mouse_wheel_delta())

	// Clear text input for this frame
	clear(&ctx.text_input)

	// Update keyboard state (would need proper event handling)
	// For now, basic key detection
	for key in k2.Keyboard_Key {
		ctx.key_held[int(key)] = k2.key_is_held(key)
		ctx.key_pressed[int(key)] = k2.key_went_down(key)
	}

	// Clear draw list
	clear(&ctx.draw_list)
	clear(&ctx.scissor_stack)

	// Reset hover state (will be set by widgets)
	ctx.hot_id = UI_ID_NONE

	// Clear tooltip
	ctx.tooltip_id = UI_ID_NONE
	ctx.tooltip_text = ""
}

ui_end_frame :: proc(ctx: ^UI_Context) {
	// Store last active for next frame
	ctx.last_active_id = ctx.active_id

	// Clear active if mouse released
	if ctx.mouse_released[0] {
		ctx.active_id = UI_ID_NONE
		ctx.is_dragging = false
	}

	// Update widget hover animations
	dt := k2.get_frame_time()
	for id, &state in ctx.widget_state {
		if id == ctx.hot_id {
			state.hover_amount = min(state.hover_amount + dt / ctx.theme.hover_transition, 1.0)
		} else {
			state.hover_amount = max(state.hover_amount - dt / ctx.theme.hover_transition, 0.0)
		}
	}
}

// ============================================================================
// Draw List Rendering
// ============================================================================

ui_render :: proc(ctx: ^UI_Context) {
	for cmd in ctx.draw_list {
		switch c in cmd {
		case Draw_Rect:
			k2.draw_rect(k2.Rect{c.rect.x, c.rect.y, c.rect.w, c.rect.h}, c.color)

		case Draw_Rect_Outline:
			k2.draw_rect_outline(
				k2.Rect{c.rect.x, c.rect.y, c.rect.w, c.rect.h},
				c.thickness,
				c.color,
			)

		case Draw_Circle:
			k2.draw_circle(k2.Vec2{c.center.x, c.center.y}, c.radius, c.color)

		case Draw_Circle_Outline:
			k2.draw_circle_outline(
				k2.Vec2{c.center.x, c.center.y},
				c.radius,
				c.thickness,
				c.color,
			)

		case Draw_Line:
			k2.draw_line(
				k2.Vec2{c.start.x, c.start.y},
				k2.Vec2{c.end.x, c.end.y},
				c.thickness,
				c.color,
			)

		case Draw_Text:
			k2.draw_text(c.text, k2.Vec2{c.pos.x, c.pos.y}, c.font_size, c.color)

		case Draw_Scissor_Push:
			k2.set_scissor_rect(int(c.rect.x), int(c.rect.y), int(c.rect.w), int(c.rect.h))

		case Draw_Scissor_Pop:
			k2.clear_scissor_rect()
		}
	}
}

// ============================================================================
// Draw Helpers - Add commands to draw list
// ============================================================================

draw_rect :: proc(ctx: ^UI_Context, rect: Rect, color: Color, radius: f32 = 0) {
	append(&ctx.draw_list, Draw_Rect{rect, color, radius})
}

draw_rect_outline :: proc(ctx: ^UI_Context, rect: Rect, color: Color, thickness: f32 = 1, radius: f32 = 0) {
	append(&ctx.draw_list, Draw_Rect_Outline{rect, color, thickness, radius})
}

draw_circle :: proc(ctx: ^UI_Context, center: Vec2, radius: f32, color: Color) {
	append(&ctx.draw_list, Draw_Circle{center, radius, color})
}

draw_circle_outline :: proc(ctx: ^UI_Context, center: Vec2, radius: f32, color: Color, thickness: f32 = 1) {
	append(&ctx.draw_list, Draw_Circle_Outline{center, radius, color, thickness})
}

draw_line :: proc(ctx: ^UI_Context, start, end: Vec2, color: Color, thickness: f32 = 1) {
	append(&ctx.draw_list, Draw_Line{start, end, color, thickness})
}

draw_text :: proc(ctx: ^UI_Context, text: string, pos: Vec2, color: Color, font_size: f32 = 0) {
	size := font_size if font_size > 0 else ctx.theme.font_size
	append(&ctx.draw_list, Draw_Text{text, pos, color, size})
}

// ============================================================================
// Scissor (Clipping)
// ============================================================================

push_scissor :: proc(ctx: ^UI_Context, rect: Rect) {
	// Intersect with current scissor if any
	final_rect := rect
	if len(ctx.scissor_stack) > 0 {
		parent := ctx.scissor_stack[len(ctx.scissor_stack) - 1]
		// Calculate intersection
		x1 := max(rect.x, parent.x)
		y1 := max(rect.y, parent.y)
		x2 := min(rect.x + rect.w, parent.x + parent.w)
		y2 := min(rect.y + rect.h, parent.y + parent.h)
		final_rect = Rect{x1, y1, max(0, x2 - x1), max(0, y2 - y1)}
	}

	append(&ctx.scissor_stack, final_rect)
	append(&ctx.draw_list, Draw_Scissor_Push{final_rect})
}

pop_scissor :: proc(ctx: ^UI_Context) {
	if len(ctx.scissor_stack) > 0 {
		pop(&ctx.scissor_stack)
		append(&ctx.draw_list, Draw_Scissor_Pop{})

		// Restore previous scissor if any
		if len(ctx.scissor_stack) > 0 {
			append(&ctx.draw_list, Draw_Scissor_Push{ctx.scissor_stack[len(ctx.scissor_stack) - 1]})
		}
	}
}

// ============================================================================
// Widget State Management
// ============================================================================

get_widget_state :: proc(ctx: ^UI_Context, id: UI_ID) -> ^Widget_State {
	if id not_in ctx.widget_state {
		ctx.widget_state[id] = Widget_State{}
	}
	return &ctx.widget_state[id]
}

// ============================================================================
// Interaction Helpers
// ============================================================================

// Check if a widget can be interacted with
ui_can_interact :: proc(ctx: ^UI_Context) -> bool {
	return ctx.active_id == UI_ID_NONE || ctx.active_id == ctx.hot_id
}

// Standard widget interaction logic
ui_widget_behavior :: proc(ctx: ^UI_Context, id: UI_ID, rect: Rect) -> (hovered: bool, held: bool, pressed: bool, released: bool) {
	hovered = rect_contains(rect, ctx.mouse_pos)

	// Update hot state
	if hovered && ui_can_interact(ctx) {
		ctx.hot_id = id
	}

	// Check if this widget is hot
	is_hot := ctx.hot_id == id
	is_active := ctx.active_id == id

	// Handle press
	if is_hot && ctx.mouse_pressed[0] {
		ctx.active_id = id
		ctx.drag_start_pos = ctx.mouse_pos
		pressed = true
	}

	// Handle hold
	if is_active {
		held = true
		if ctx.mouse_released[0] {
			released = is_hot
		}
	}

	return hovered, held, pressed, released
}

// ============================================================================
// Theme Access
// ============================================================================

set_theme :: proc(ctx: ^UI_Context, theme: ^Theme) {
	ctx.theme = theme
}

set_dark_theme :: proc(ctx: ^UI_Context) {
	ctx.default_theme = theme_dark()
	ctx.theme = &ctx.default_theme
}

set_light_theme :: proc(ctx: ^UI_Context) {
	ctx.default_theme = theme_light()
	ctx.theme = &ctx.default_theme
}
