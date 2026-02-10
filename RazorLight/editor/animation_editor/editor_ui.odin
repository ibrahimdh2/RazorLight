package animation_editor

import k2 "../../libs/karl2d"
import ui "../ui"
import "core:fmt"

// ============================================================================
// Editor Layout and Panel Rendering
// ============================================================================

LEFT_PANEL_WIDTH  :: 250
TIMELINE_HEIGHT   :: 200
TOOLBAR_HEIGHT    :: 30

editor_render :: proc(state: ^Editor_State) {
	screen_w := f32(k2.get_screen_width())
	screen_h := f32(k2.get_screen_height())

	center_x := f32(LEFT_PANEL_WIDTH)
	center_w := screen_w - f32(LEFT_PANEL_WIDTH)
	center_h := screen_h - f32(TIMELINE_HEIGHT)

	// Left panel: animations list + properties
	editor_render_left_panel(state, ui.Rect{0, 0, f32(LEFT_PANEL_WIDTH), screen_h - f32(TIMELINE_HEIGHT)})

	// Center panel: sprite sheet view
	sheet_view_render(state, k2.Rect{center_x, 0, center_w, center_h})

	// Bottom panel: timeline
	editor_render_timeline(state, k2.Rect{0, screen_h - f32(TIMELINE_HEIGHT), screen_w, f32(TIMELINE_HEIGHT)})
}

// ============================================================================
// Left Panel - Animation List + Properties
// ============================================================================

editor_render_left_panel :: proc(state: ^Editor_State, bounds: ui.Rect) {
	ctx := state.ui_ctx

	// Background
	ui.draw_rect(ctx, bounds, ctx.theme.bg_secondary)

	// Layout within the panel
	ui.layout_begin(ctx, ui.rect_shrink(bounds, 8))
	defer ui.layout_end(ctx)

	// Title
	ui.ui_header(ctx, "Animations")

	// Load texture section
	ui.ui_label(ctx, "Sprite Sheet:")

	ui.layout_begin_row(ctx, 24)
	ui.layout_push_width(ctx, bounds.w - 80)
	ui.ui_text_input(ctx, "##tex_path", state.texture_path[:], &state.texture_path_len)
	ui.layout_pop_width(ctx)

	ui.layout_push_width(ctx, 50)
	if ui.ui_button(ctx, "Load") {
		if state.texture_path_len > 0 {
			path := string(state.texture_path[:state.texture_path_len])
			state.texture = k2.load_texture_from_file(path)
			state.texture_loaded = state.texture.width > 0 && state.texture.height > 0
		}
	}
	ui.layout_pop_width(ctx)
	ui.layout_end_row(ctx)

	ui.ui_separator(ctx)

	// Add animation button
	if ui.ui_button(ctx, "+ New Animation") {
		editor_add_animation(state)
	}

	ui.ui_spacing(ctx, 4)

	// Animation list
	for i in 0..<len(state.animations) {
		anim := &state.animations[i]
		name := string(anim.name[:anim.name_len])
		label := fmt.tprintf("%s (%d frames)", name, len(anim.frames))

		is_selected := i == state.selected_anim

		// Selectable item
		item_rect := ui.layout_allocate(ctx, bounds.w - 24, 24)
		bg_color := ctx.theme.accent if is_selected else ctx.theme.bg_primary
		ui.draw_rect(ctx, item_rect, bg_color)

		text_color := ui.Color{255, 255, 255, 255} if is_selected else ctx.theme.text_primary
		ui.draw_text(ctx, label, ui.Vec2{item_rect.x + 4, item_rect.y + 4}, text_color, 14)

		// Click to select
		id := ui.ui_id_with_parent("anim_item", ui.UI_ID(i))
		_, _, pressed, _ := ui.ui_widget_behavior(ctx, id, item_rect)
		if pressed {
			state.selected_anim = i
			state.selected_frame = -1
			state.preview_frame = 0
			state.preview_elapsed = 0
		}
	}

	ui.ui_separator(ctx)

	// Properties panel for selected animation
	if state.selected_anim >= 0 && state.selected_anim < len(state.animations) {
		anim := &state.animations[state.selected_anim]

		ui.ui_header(ctx, "Properties")

		ui.ui_label(ctx, "Name:")
		ui.ui_text_input(ctx, "##anim_name", anim.name[:], &anim.name_len)

		ui.ui_label(ctx, "FPS:")
		ui.ui_slider(ctx, "##fps", &anim.fps, 1, 60)

		ui.ui_label(ctx, "Loop Mode:")
		ui.ui_dropdown(ctx, "##loop", loop_modes[:], &anim.loop_mode)

		ui.ui_spacing(ctx, 4)

		// Delete animation button
		if ui.ui_button(ctx, "Delete Animation") {
			editor_remove_animation(state, state.selected_anim)
		}
	}

	ui.ui_separator(ctx)

	// Grid settings
	ui.ui_header(ctx, "Grid")
	ui.ui_checkbox(ctx, "Enable Grid", &state.grid_enabled)
	if state.grid_enabled {
		ui.ui_slider_int(ctx, "Cell W", &state.grid_cell_w, 8, 256)
		ui.ui_slider_int(ctx, "Cell H", &state.grid_cell_h, 8, 256)

		if ui.ui_button(ctx, "Auto-Slice") {
			auto_slice(state)
		}
	}

	ui.ui_separator(ctx)

	// File operations
	ui.ui_header(ctx, "File")
	ui.ui_label(ctx, "Set Name:")
	ui.ui_text_input(ctx, "##set_name", state.set_name[:], &state.set_name_len)

	ui.ui_label(ctx, "File Path:")
	ui.ui_text_input(ctx, "##file_path", state.file_path[:], &state.file_path_len)

	ui.layout_begin_row(ctx, 24)
	ui.layout_push_width(ctx, 60)
	if ui.ui_button(ctx, "Save") {
		if state.file_path_len > 0 {
			path := string(state.file_path[:state.file_path_len])
			file_save(state, path)
		}
	}
	ui.layout_pop_width(ctx)

	ui.layout_push_width(ctx, 60)
	if ui.ui_button(ctx, "Load") {
		if state.file_path_len > 0 {
			path := string(state.file_path[:state.file_path_len])
			file_load(state, path)
		}
	}
	ui.layout_pop_width(ctx)
	ui.layout_end_row(ctx)
}

// ============================================================================
// Auto-Slice Helper
// ============================================================================

@(private)
auto_slice :: proc(state: ^Editor_State) {
	if !state.texture_loaded || state.grid_cell_w <= 0 || state.grid_cell_h <= 0 {
		return
	}

	if state.selected_anim < 0 || state.selected_anim >= len(state.animations) {
		return
	}

	cw := f32(state.grid_cell_w)
	ch := f32(state.grid_cell_h)
	tw := f32(state.texture.width)
	th := f32(state.texture.height)

	cols := int(tw / cw)
	rows := int(th / ch)

	for row in 0..<rows {
		for col in 0..<cols {
			rect := k2.Rect{
				f32(col) * cw,
				f32(row) * ch,
				cw,
				ch,
			}
			editor_add_frame(state, rect)
		}
	}
}
