package animation_editor

import k2 "../../libs/karl2d"
import "core:encoding/json"
import "core:os"
import "core:fmt"
import "core:strings"

// ============================================================================
// File Operations - Save/Load .razlanim files
// ============================================================================

// JSON structures matching the engine's animation format
@(private)
JSON_Frame :: struct {
	x:           f32    `json:"x"`,
	y:           f32    `json:"y"`,
	w:           f32    `json:"w"`,
	h:           f32    `json:"h"`,
	duration_ms: f32    `json:"duration_ms,omitempty"`,
}

@(private)
JSON_Animation :: struct {
	fps:    f32          `json:"fps"`,
	loop:   string       `json:"loop"`,
	frames: []JSON_Frame `json:"frames"`,
}

@(private)
JSON_Animation_Set :: struct {
	name:         string                      `json:"name"`,
	texture_path: string                      `json:"texture_path,omitempty"`,
	animations:   map[string]JSON_Animation   `json:"animations"`,
}

// ============================================================================
// Save
// ============================================================================

file_save :: proc(state: ^Editor_State, path: string) {
	json_set := JSON_Animation_Set{}
	json_set.name = string(state.set_name[:state.set_name_len])

	if state.texture_path_len > 0 {
		json_set.texture_path = string(state.texture_path[:state.texture_path_len])
	}

	json_set.animations = make(map[string]JSON_Animation)
	defer {
		for key, &anim in json_set.animations {
			delete(anim.frames)
		}
		delete(json_set.animations)
	}

	for &anim in state.animations {
		name := string(anim.name[:anim.name_len])
		if len(name) == 0 {
			continue
		}

		json_anim := JSON_Animation{}
		json_anim.fps = anim.fps
		json_anim.loop = string(loop_modes[anim.loop_mode])

		frames := make([]JSON_Frame, len(anim.frames))
		for &f, i in anim.frames {
			frames[i] = JSON_Frame{
				x = f.src_rect.x,
				y = f.src_rect.y,
				w = f.src_rect.w,
				h = f.src_rect.h,
				duration_ms = f.duration_ms,
			}
		}
		json_anim.frames = frames

		json_set.animations[name] = json_anim
	}

	data, err := json.marshal(json_set, json.Marshal_Options{
		pretty = true,
	})
	if err != nil {
		fmt.eprintln("Failed to marshal animation data")
		return
	}
	defer delete(data)

	ok := os.write_entire_file(path, data)
	if ok {
		fmt.printf("Saved animation set to: %s\n", path)
	} else {
		fmt.eprintf("Failed to save to: %s\n", path)
	}
}

// ============================================================================
// Load
// ============================================================================

file_load :: proc(state: ^Editor_State, path: string) {
	data, ok := os.read_entire_file(path)
	if !ok {
		fmt.eprintf("Failed to read file: %s\n", path)
		return
	}
	defer delete(data)

	json_set: JSON_Animation_Set
	err := json.unmarshal(data, &json_set)
	if err != nil {
		fmt.eprintf("Failed to parse animation file: %s\n", path)
		return
	}
	defer {
		for key, &anim in json_set.animations {
			delete(anim.frames)
		}
		delete(json_set.animations)
	}

	// Clear existing animations
	for &anim in state.animations {
		delete(anim.frames)
	}
	clear(&state.animations)

	// Set name
	if len(json_set.name) > 0 {
		name_bytes := transmute([]u8)json_set.name
		copy_len := min(len(name_bytes), len(state.set_name))
		for i in 0..<copy_len {
			state.set_name[i] = name_bytes[i]
		}
		state.set_name_len = copy_len
	}

	// Set texture path
	if len(json_set.texture_path) > 0 {
		path_bytes := transmute([]u8)json_set.texture_path
		copy_len := min(len(path_bytes), len(state.texture_path))
		for i in 0..<copy_len {
			state.texture_path[i] = path_bytes[i]
		}
		state.texture_path_len = copy_len

		// Try to load the texture
		state.texture = k2.load_texture_from_file(json_set.texture_path)
		state.texture_loaded = state.texture.width > 0 && state.texture.height > 0
	}

	// Load animations
	for anim_name, &json_anim in json_set.animations {
		editor_anim := Editor_Animation{}
		editor_anim.fps = json_anim.fps
		editor_anim.frames = make([dynamic]Editor_Frame)

		// Set loop mode
		for li in 0..<len(loop_modes) {
			if loop_modes[li] == json_anim.loop {
				editor_anim.loop_mode = li
				break
			}
		}

		// Copy name
		name_bytes := transmute([]u8)anim_name
		copy_len := min(len(name_bytes), len(editor_anim.name))
		for i in 0..<copy_len {
			editor_anim.name[i] = name_bytes[i]
		}
		editor_anim.name_len = copy_len

		// Copy frames
		for &jf in json_anim.frames {
			frame := Editor_Frame{
				src_rect = k2.Rect{jf.x, jf.y, jf.w, jf.h},
				duration_ms = jf.duration_ms,
			}
			append(&editor_anim.frames, frame)
		}

		append(&state.animations, editor_anim)
	}

	state.selected_anim = 0 if len(state.animations) > 0 else -1
	state.selected_frame = -1
	state.preview_frame = 0
	state.preview_elapsed = 0

	fmt.printf("Loaded animation set from: %s\n", path)
}
