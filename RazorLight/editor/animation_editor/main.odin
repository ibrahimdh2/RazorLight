package animation_editor

import k2 "../../libs/karl2d"
import ui "../ui"

// ============================================================================
// Animation Editor - Entry Point
// ============================================================================

WINDOW_WIDTH  :: 1400
WINDOW_HEIGHT :: 900
WINDOW_TITLE  :: "RazorLight Animation Editor"

main :: proc() {
	k2.init(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE)
	defer k2.shutdown()

	state := editor_state_create()
	defer editor_state_destroy(state)

	for k2.update() {
		dt := k2.get_frame_time()

		// Handle global keyboard shortcuts
		handle_shortcuts(state)

		// Update preview animation
		preview_update(state, dt)

		// Begin UI frame
		ui.ui_begin_frame(state.ui_ctx)

		// Render
		k2.clear(state.ui_ctx.theme.bg_primary)
		editor_render(state)
		ui.ui_end_frame(state.ui_ctx)
		ui.ui_render(state.ui_ctx)

		k2.present()
	}
}

// ============================================================================
// Global Shortcuts
// ============================================================================

@(private)
handle_shortcuts :: proc(state: ^Editor_State) {
	// Ctrl+S to save
	if k2.key_is_held(.Left_Control) || k2.key_is_held(.Right_Control) {
		if k2.key_went_down(.S) {
			if state.file_path_len > 0 {
				path := string(state.file_path[:state.file_path_len])
				file_save(state, path)
			}
		}
		if k2.key_went_down(.O) {
			// Ctrl+O - load prompt (file path must be typed in UI)
		}
	}

	// Space to toggle preview
	if k2.key_went_down(.Space) {
		state.preview_playing = !state.preview_playing
	}

	// Delete to remove selected frame
	if k2.key_went_down(.Delete) || k2.key_went_down(.Backspace) {
		if state.selected_frame >= 0 {
			editor_remove_frame(state, state.selected_frame)
		}
	}
}
