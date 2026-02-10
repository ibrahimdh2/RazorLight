package razorlight_core

import k2 "../libs/karl2d"
import "core:encoding/json"
import "core:os"
import "core:fmt"
import "core:strings"

// ============================================================================
// Animation File Format (.razlanim)
// ============================================================================
// Supports two modes:
//   1. Sprite sheet: single texture with frame rectangles
//   2. Image sequence: individual images per frame

// ============================================================================
// JSON Structures (for serialization)
// ============================================================================

@(private)
JSON_Frame :: struct {
	// Sprite sheet mode
	x: f32 `json:"x,omitempty"`,
	y: f32 `json:"y,omitempty"`,
	w: f32 `json:"w,omitempty"`,
	h: f32 `json:"h,omitempty"`,
	// Image sequence mode
	path: string `json:"path,omitempty"`,
	// Common
	duration_ms: f32 `json:"duration_ms,omitempty"`,
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
	anim_type:    string                      `json:"type,omitempty"`,
	animations:   map[string]JSON_Animation   `json:"animations"`,
}

// ============================================================================
// Load / Save
// ============================================================================

// Load an animation set from a .razlanim JSON file (no texture loading)
animation_set_load :: proc(path: string) -> (^Animation_Set, bool) {
	data, ok := os.read_entire_file(path)
	if !ok {
		fmt.eprintf("animation_set_load: failed to read file '%s'\n", path)
		return nil, false
	}
	defer delete(data)

	json_set: JSON_Animation_Set
	err := json.unmarshal(data, &json_set)
	if err != nil {
		fmt.eprintf("animation_set_load: failed to parse JSON in '%s'\n", path)
		return nil, false
	}
	defer {
		for key, &anim in json_set.animations {
			delete(anim.frames)
		}
		delete(json_set.animations)
	}

	set := new(Animation_Set)
	set.name = strings.clone(json_set.name)
	set.animations = make(map[string]Animation)

	for anim_name, &json_anim in json_set.animations {
		anim := Animation{}
		anim.name = strings.clone(anim_name)
		anim.fps = json_anim.fps
		anim.loop_mode = parse_loop_mode(json_anim.loop)

		// Build frames
		frames := make([]Animation_Frame, len(json_anim.frames))
		for &jf, i in json_anim.frames {
			frames[i] = Animation_Frame{
				src_rect = k2.Rect{jf.x, jf.y, jf.w, jf.h},
				duration_ms = jf.duration_ms,
			}
		}
		anim.frames = frames

		set.animations[strings.clone(anim_name)] = anim
	}

	return set, true
}

// Load an animation set and also load the texture from the texture_path field
animation_set_load_with_texture :: proc(path: string) -> (^Animation_Set, bool) {
	// Read the file to get texture_path first
	data, ok := os.read_entire_file(path)
	if !ok {
		fmt.eprintf("animation_set_load_with_texture: failed to read file '%s'\n", path)
		return nil, false
	}

	// Parse just to get texture_path
	json_set: JSON_Animation_Set
	err := json.unmarshal(data, &json_set)
	delete(data)
	if err != nil {
		fmt.eprintf("animation_set_load_with_texture: failed to parse JSON in '%s'\n", path)
		return nil, false
	}
	texture_path := json_set.texture_path
	is_image_seq := json_set.anim_type == "image_sequence"

	// Clean up the json_set
	for key, &anim in json_set.animations {
		delete(anim.frames)
	}
	delete(json_set.animations)

	// Re-load with the standard path
	set, load_ok := animation_set_load(path)
	if !load_ok {
		return nil, false
	}

	// Load shared texture if sprite sheet mode
	if !is_image_seq && texture_path != "" {
		// Resolve texture path relative to the animation file's directory
		dir := directory_of_path(path)
		full_texture_path := fmt.tprintf("%s/%s", dir, texture_path) if dir != "" else texture_path
		set.texture = k2.load_texture_from_file(full_texture_path)

		// Apply texture to all animations
		for name, &anim in set.animations {
			anim.texture = set.texture
		}
	}

	return set, true
}

// Save an animation set to a .razlanim JSON file
animation_set_save :: proc(set: ^Animation_Set, path: string) -> bool {
	if set == nil {
		return false
	}

	json_set := JSON_Animation_Set{}
	json_set.name = set.name
	json_set.animations = make(map[string]JSON_Animation)
	defer {
		for key, &anim in json_set.animations {
			delete(anim.frames)
		}
		delete(json_set.animations)
	}

	for anim_name, &anim in set.animations {
		json_anim := JSON_Animation{}
		json_anim.fps = anim.fps
		json_anim.loop = loop_mode_to_string(anim.loop_mode)

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
		json_set.animations[anim_name] = json_anim
	}

	data, err := json.marshal(json_set, json.Marshal_Options{
		pretty = true,
	})
	if err != nil {
		fmt.eprintf("animation_set_save: failed to marshal JSON\n")
		return false
	}
	defer delete(data)

	ok := os.write_entire_file(path, data)
	if !ok {
		fmt.eprintf("animation_set_save: failed to write file '%s'\n", path)
		return false
	}

	return true
}

// Free all memory associated with an animation set
animation_set_destroy :: proc(set: ^Animation_Set) {
	if set == nil {
		return
	}

	for key, &anim in set.animations {
		delete(anim.frames)
		delete(anim.name)
		delete(key)
	}
	delete(set.animations)
	delete(set.name)
	free(set)
}

// ============================================================================
// Helpers
// ============================================================================

@(private)
parse_loop_mode :: proc(s: string) -> Animation_Loop_Mode {
	switch s {
	case "once":      return .Once
	case "loop":      return .Loop
	case "ping_pong": return .Ping_Pong
	case:             return .Loop
	}
}

@(private)
loop_mode_to_string :: proc(mode: Animation_Loop_Mode) -> string {
	switch mode {
	case .Once:      return "once"
	case .Loop:      return "loop"
	case .Ping_Pong: return "ping_pong"
	case:            return "loop"
	}
}

@(private)
directory_of_path :: proc(path: string) -> string {
	last_sep := -1
	for i := len(path) - 1; i >= 0; i -= 1 {
		if path[i] == '/' || path[i] == '\\' {
			last_sep = i
			break
		}
	}
	if last_sep >= 0 {
		return path[:last_sep]
	}
	return ""
}
