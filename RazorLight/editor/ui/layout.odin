package editor_ui

// ============================================================================
// Layout System - Flex-style layout for UI
// ============================================================================

Layout_Direction :: enum {
	Horizontal,
	Vertical,
}

Layout_Align :: enum {
	Start,
	Center,
	End,
	Stretch,
}

Layout_Context :: struct {
	// Bounds for this layout region
	bounds:           Rect,

	// Current position (cursor)
	cursor:           Vec2,

	// Direction of layout
	direction:        Layout_Direction,

	// Alignment
	align_main:       Layout_Align,  // Along main axis
	align_cross:      Layout_Align,  // Perpendicular to main axis

	// Spacing and padding
	spacing:          f32,
	padding:          f32,

	// Size tracking for scrolling
	content_size:     Vec2,
	max_extent:       Vec2,

	// Row/column tracking for flex layout
	row_height:       f32,  // Current row height (horizontal) or width (vertical)
	row_items:        int,  // Items in current row

	// Width override stack
	width_override:   f32,  // 0 = auto
	height_override:  f32,  // 0 = auto

	// Scroll offset
	scroll_offset:    Vec2,

	// Parent layout (for nested layouts)
	parent:           ^Layout_Context,
}

// ============================================================================
// Layout Stack
// ============================================================================

MAX_LAYOUT_DEPTH :: 32

Layout_Stack :: struct {
	layouts:  [MAX_LAYOUT_DEPTH]Layout_Context,
	depth:    int,
}

// Get current layout
@(private)
current_layout :: proc(ctx: ^UI_Context) -> ^Layout_Context {
	if ctx.layout_stack.depth <= 0 {
		return nil
	}
	return &ctx.layout_stack.layouts[ctx.layout_stack.depth - 1]
}

// Add layout stack to UI_Context
// This is added to UI_Context struct - add this field:
// layout_stack: Layout_Stack

// ============================================================================
// Layout Begin/End
// ============================================================================

// Begin a new layout region
layout_begin :: proc(ctx: ^UI_Context, bounds: Rect, direction: Layout_Direction = .Vertical) {
	if ctx.layout_stack.depth >= MAX_LAYOUT_DEPTH {
		return  // Stack overflow protection
	}

	layout := &ctx.layout_stack.layouts[ctx.layout_stack.depth]

	// Get parent if exists
	parent: ^Layout_Context = nil
	if ctx.layout_stack.depth > 0 {
		parent = &ctx.layout_stack.layouts[ctx.layout_stack.depth - 1]
	}

	layout^ = Layout_Context{
		bounds        = bounds,
		cursor        = Vec2{bounds.x + ctx.theme.padding, bounds.y + ctx.theme.padding},
		direction     = direction,
		align_main    = .Start,
		align_cross   = .Stretch,
		spacing       = ctx.theme.spacing,
		padding       = ctx.theme.padding,
		content_size  = Vec2{0, 0},
		max_extent    = Vec2{0, 0},
		row_height    = 0,
		row_items     = 0,
		width_override  = 0,
		height_override = 0,
		scroll_offset = Vec2{0, 0},
		parent        = parent,
	}

	ctx.layout_stack.depth += 1
}

// End the current layout region
layout_end :: proc(ctx: ^UI_Context) {
	if ctx.layout_stack.depth <= 0 {
		return
	}

	layout := current_layout(ctx)

	// Update parent's cursor based on our content size
	if layout.parent != nil {
		parent := layout.parent
		if parent.direction == .Vertical {
			parent.cursor.y += layout.content_size.y + parent.spacing
			parent.max_extent.y = max(parent.max_extent.y, parent.cursor.y)
		} else {
			parent.cursor.x += layout.content_size.x + parent.spacing
			parent.max_extent.x = max(parent.max_extent.x, parent.cursor.x)
		}
	}

	ctx.layout_stack.depth -= 1
}

// ============================================================================
// Layout Properties
// ============================================================================

// Set spacing between items
layout_set_spacing :: proc(ctx: ^UI_Context, spacing: f32) {
	if layout := current_layout(ctx); layout != nil {
		layout.spacing = spacing
	}
}

// Set padding inside layout
layout_set_padding :: proc(ctx: ^UI_Context, padding: f32) {
	if layout := current_layout(ctx); layout != nil {
		layout.padding = padding
		// Adjust cursor for new padding
		layout.cursor = Vec2{
			layout.bounds.x + padding,
			layout.bounds.y + padding,
		}
	}
}

// Set alignment
layout_set_align :: proc(ctx: ^UI_Context, main: Layout_Align, cross: Layout_Align = .Stretch) {
	if layout := current_layout(ctx); layout != nil {
		layout.align_main = main
		layout.align_cross = cross
	}
}

// ============================================================================
// Size Overrides
// ============================================================================

// Push a fixed width for the next widget
layout_push_width :: proc(ctx: ^UI_Context, width: f32) {
	if layout := current_layout(ctx); layout != nil {
		layout.width_override = width
	}
}

// Pop width override (reset to auto)
layout_pop_width :: proc(ctx: ^UI_Context) {
	if layout := current_layout(ctx); layout != nil {
		layout.width_override = 0
	}
}

// Push a fixed height for the next widget
layout_push_height :: proc(ctx: ^UI_Context, height: f32) {
	if layout := current_layout(ctx); layout != nil {
		layout.height_override = height
	}
}

// Pop height override
layout_pop_height :: proc(ctx: ^UI_Context) {
	if layout := current_layout(ctx); layout != nil {
		layout.height_override = 0
	}
}

// ============================================================================
// Row/Column Helpers
// ============================================================================

// Start a new horizontal row within a vertical layout
layout_begin_row :: proc(ctx: ^UI_Context, height: f32 = 0) {
	layout := current_layout(ctx)
	if layout == nil do return

	// Calculate row bounds
	row_bounds := Rect{
		x = layout.cursor.x,
		y = layout.cursor.y,
		w = layout.bounds.w - layout.padding * 2,
		h = height if height > 0 else ctx.theme.button_height,
	}

	layout_begin(ctx, row_bounds, .Horizontal)
}

// End the current row
layout_end_row :: proc(ctx: ^UI_Context) {
	layout_end(ctx)
}

// Start a new vertical column within a horizontal layout
layout_begin_column :: proc(ctx: ^UI_Context, width: f32 = 0) {
	layout := current_layout(ctx)
	if layout == nil do return

	// Calculate column bounds
	col_bounds := Rect{
		x = layout.cursor.x,
		y = layout.cursor.y,
		w = width if width > 0 else 100,
		h = layout.bounds.h - layout.padding * 2,
	}

	layout_begin(ctx, col_bounds, .Vertical)
}

// End the current column
layout_end_column :: proc(ctx: ^UI_Context) {
	layout_end(ctx)
}

// ============================================================================
// Widget Allocation
// ============================================================================

// Allocate space for a widget and return its rect
layout_allocate :: proc(ctx: ^UI_Context, preferred_width, preferred_height: f32) -> Rect {
	layout := current_layout(ctx)
	if layout == nil {
		// No layout - return full screen rect at 0,0
		return Rect{0, 0, preferred_width, preferred_height}
	}

	// Determine actual size
	width := layout.width_override if layout.width_override > 0 else preferred_width
	height := layout.height_override if layout.height_override > 0 else preferred_height

	// Handle stretch alignment for cross axis
	if layout.direction == .Vertical && layout.align_cross == .Stretch {
		width = layout.bounds.w - layout.padding * 2
	} else if layout.direction == .Horizontal && layout.align_cross == .Stretch {
		height = layout.bounds.h - layout.padding * 2
	}

	// Calculate position
	x := layout.cursor.x - layout.scroll_offset.x
	y := layout.cursor.y - layout.scroll_offset.y

	// Handle cross-axis alignment
	if layout.direction == .Vertical {
		switch layout.align_cross {
		case .Start:
			// Already at left
		case .Center:
			x = layout.bounds.x + (layout.bounds.w - width) / 2
		case .End:
			x = layout.bounds.x + layout.bounds.w - layout.padding - width
		case .Stretch:
			// Already handled above
		}
	} else {
		switch layout.align_cross {
		case .Start:
			// Already at top
		case .Center:
			y = layout.bounds.y + (layout.bounds.h - height) / 2
		case .End:
			y = layout.bounds.y + layout.bounds.h - layout.padding - height
		case .Stretch:
			// Already handled above
		}
	}

	result := Rect{x, y, width, height}

	// Advance cursor
	if layout.direction == .Vertical {
		layout.cursor.y += height + layout.spacing
		layout.max_extent.y = max(layout.max_extent.y, layout.cursor.y)
		layout.max_extent.x = max(layout.max_extent.x, x + width)
	} else {
		layout.cursor.x += width + layout.spacing
		layout.max_extent.x = max(layout.max_extent.x, layout.cursor.x)
		layout.max_extent.y = max(layout.max_extent.y, y + height)
	}

	// Update content size
	layout.content_size.x = layout.max_extent.x - layout.bounds.x
	layout.content_size.y = layout.max_extent.y - layout.bounds.y

	// Clear width/height override after use
	layout.width_override = 0
	layout.height_override = 0

	return result
}

// Allocate remaining space in current direction
layout_allocate_remaining :: proc(ctx: ^UI_Context) -> Rect {
	layout := current_layout(ctx)
	if layout == nil {
		return Rect{0, 0, 0, 0}
	}

	if layout.direction == .Vertical {
		remaining_h := layout.bounds.y + layout.bounds.h - layout.padding - layout.cursor.y
		return layout_allocate(ctx, layout.bounds.w - layout.padding * 2, max(0, remaining_h))
	} else {
		remaining_w := layout.bounds.x + layout.bounds.w - layout.padding - layout.cursor.x
		return layout_allocate(ctx, max(0, remaining_w), layout.bounds.h - layout.padding * 2)
	}
}

// ============================================================================
// Spacing and Separators
// ============================================================================

// Add fixed spacing
layout_space :: proc(ctx: ^UI_Context, amount: f32) {
	layout := current_layout(ctx)
	if layout == nil do return

	if layout.direction == .Vertical {
		layout.cursor.y += amount
	} else {
		layout.cursor.x += amount
	}
}

// Add flexible space (pushes remaining items to end)
layout_flex_space :: proc(ctx: ^UI_Context) {
	layout := current_layout(ctx)
	if layout == nil do return

	// Calculate remaining space and add it
	if layout.direction == .Vertical {
		remaining := layout.bounds.y + layout.bounds.h - layout.padding - layout.cursor.y
		if remaining > 0 {
			layout.cursor.y += remaining
		}
	} else {
		remaining := layout.bounds.x + layout.bounds.w - layout.padding - layout.cursor.x
		if remaining > 0 {
			layout.cursor.x += remaining
		}
	}
}

// Draw a separator line
layout_separator :: proc(ctx: ^UI_Context) {
	layout := current_layout(ctx)
	if layout == nil do return

	if layout.direction == .Vertical {
		y := layout.cursor.y + layout.spacing / 2
		draw_line(
			ctx,
			Vec2{layout.bounds.x + layout.padding, y},
			Vec2{layout.bounds.x + layout.bounds.w - layout.padding, y},
			ctx.theme.border_light,
			1,
		)
		layout.cursor.y += layout.spacing
	} else {
		x := layout.cursor.x + layout.spacing / 2
		draw_line(
			ctx,
			Vec2{x, layout.bounds.y + layout.padding},
			Vec2{x, layout.bounds.y + layout.bounds.h - layout.padding},
			ctx.theme.border_light,
			1,
		)
		layout.cursor.x += layout.spacing
	}
}

// ============================================================================
// Scrolling Support
// ============================================================================

// Begin a scrollable region
layout_begin_scroll :: proc(ctx: ^UI_Context, id: UI_ID, bounds: Rect, content_height: f32) -> (visible_rect: Rect, needs_scrollbar: bool) {
	state := get_widget_state(ctx, id)

	// Check if we need a scrollbar
	needs_scrollbar = content_height > bounds.h

	// Clamp scroll
	max_scroll := max(0, content_height - bounds.h)
	state.scroll_y = clamp(state.scroll_y, 0, max_scroll)

	// Handle scroll input if hovered
	if rect_contains(bounds, ctx.mouse_pos) {
		state.scroll_y -= ctx.scroll_delta * 40  // Scroll speed
		state.scroll_y = clamp(state.scroll_y, 0, max_scroll)
	}

	// Begin clipped layout
	push_scissor(ctx, bounds)
	layout_begin(ctx, bounds, .Vertical)

	if layout := current_layout(ctx); layout != nil {
		layout.scroll_offset.y = state.scroll_y
	}

	visible_rect = bounds
	return
}

// End scrollable region and draw scrollbar
layout_end_scroll :: proc(ctx: ^UI_Context, id: UI_ID, bounds: Rect, content_height: f32, needs_scrollbar: bool) {
	state := get_widget_state(ctx, id)

	layout_end(ctx)
	pop_scissor(ctx)

	// Draw scrollbar if needed
	if needs_scrollbar {
		scrollbar_w := ctx.theme.scrollbar_width
		scrollbar_rect := Rect{
			bounds.x + bounds.w - scrollbar_w,
			bounds.y,
			scrollbar_w,
			bounds.h,
		}

		// Scrollbar background
		draw_rect(ctx, scrollbar_rect, ctx.theme.bg_tertiary)

		// Thumb
		visible_ratio := bounds.h / content_height
		thumb_h := max(ctx.theme.scrollbar_min_thumb, bounds.h * visible_ratio)
		scroll_ratio := state.scroll_y / max(1, content_height - bounds.h)
		thumb_y := bounds.y + (bounds.h - thumb_h) * scroll_ratio

		thumb_rect := Rect{
			scrollbar_rect.x + 2,
			thumb_y,
			scrollbar_w - 4,
			thumb_h,
		}

		// Thumb interaction
		thumb_hovered := rect_contains(thumb_rect, ctx.mouse_pos)
		thumb_color := ctx.theme.bg_hover if thumb_hovered else ctx.theme.border

		draw_rect(ctx, thumb_rect, thumb_color, ctx.theme.border_radius)
	}
}

// ============================================================================
// Content Size Query
// ============================================================================

// Get the content size of the current layout
layout_get_content_size :: proc(ctx: ^UI_Context) -> Vec2 {
	if layout := current_layout(ctx); layout != nil {
		return layout.content_size
	}
	return Vec2{0, 0}
}

// Get available size in current layout
layout_get_available_size :: proc(ctx: ^UI_Context) -> Vec2 {
	layout := current_layout(ctx)
	if layout == nil {
		return Vec2{ctx.screen_width, ctx.screen_height}
	}

	return Vec2{
		layout.bounds.w - layout.padding * 2,
		layout.bounds.h - layout.padding * 2,
	}
}
