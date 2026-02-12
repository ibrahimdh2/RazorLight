package razorlight_core

import k2 "../libs/karl2d"

// ============================================================================
// Animation Playback Control
// ============================================================================

// Play a named animation from the component's animation set.
// The registry is needed to look up the animation data via the component's handle.
animation_play :: proc(reg: ^Animation_Registry, comp: ^Animation_Component, name: string) {
	anim := animation_registry_get_anim(reg, comp.set_handle, name)
	if anim == nil {
		return
	}

	comp.animation_name = name
	comp.current_frame = 0
	comp.elapsed = 0
	comp.playing = true
	comp.finished = false
	comp.direction = 1
}

// Start playing an animation on a component (convenience method).
// This sets up the component with the handle and animation name.
animation_start :: proc(reg: ^Animation_Registry, comp: ^Animation_Component, set_handle: Animation_Set_Handle, anim_name: string) {
	anim := animation_registry_get_anim(reg, set_handle, anim_name)
	if anim == nil {
		return
	}

	comp.set_handle = set_handle
	comp.animation_name = anim_name
	comp.current_frame = 0
	comp.elapsed = 0
	comp.playing = true
	comp.finished = false
	comp.direction = 1
}

// Stop the current animation and reset
animation_stop :: proc(comp: ^Animation_Component) {
	comp.playing = false
	comp.current_frame = 0
	comp.elapsed = 0
	comp.finished = false
	comp.direction = 1
}

// Pause the current animation (keeps position)
animation_pause :: proc(comp: ^Animation_Component) {
	comp.playing = false
}

// Resume a paused animation
animation_resume :: proc(reg: ^Animation_Registry, comp: ^Animation_Component) {
	if comp.playing || comp.finished {
		return
	}
	
	anim := animation_registry_get_anim(reg, comp.set_handle, comp.animation_name)
	if anim == nil {
		return
	}
	
	comp.playing = true
}

// Reset animation to the beginning without changing play state
animation_reset :: proc(comp: ^Animation_Component) {
	comp.current_frame = 0
	comp.elapsed = 0
	comp.finished = false
	comp.direction = 1
}

// Set the playback speed multiplier (1.0 = normal)
animation_set_speed :: proc(comp: ^Animation_Component, speed: f32) {
	comp.speed = speed
}

// Jump to a specific frame
animation_set_frame :: proc(reg: ^Animation_Registry, comp: ^Animation_Component, index: int) {
	anim := animation_registry_get_anim(reg, comp.set_handle, comp.animation_name)
	if anim == nil {
		return
	}

	frame_count := len(anim.frames)
	if frame_count == 0 {
		return
	}

	comp.current_frame = clamp(index, 0, frame_count - 1)
	comp.elapsed = 0
}

// Get the current frame's source rectangle for rendering
animation_get_current_frame :: proc(reg: ^Animation_Registry, comp: ^Animation_Component) -> (k2.Rect, bool) {
	anim := animation_registry_get_anim(reg, comp.set_handle, comp.animation_name)
	if anim == nil {
		return {}, false
	}

	frames := anim.frames
	if len(frames) == 0 {
		return {}, false
	}

	frame_idx := clamp(comp.current_frame, 0, len(frames) - 1)
	return frames[frame_idx].src_rect, true
}

// Get the texture for the current animation
animation_get_texture :: proc(reg: ^Animation_Registry, comp: ^Animation_Component) -> (k2.Texture, bool) {
	set := animation_registry_get(reg, comp.set_handle)
	if set == nil {
		return {}, false
	}
	return set.texture, true
}

// Check if a non-looping animation has finished
animation_is_finished :: proc(comp: ^Animation_Component) -> bool {
	return comp.finished
}

// ============================================================================
// Animation Update (Core Tick)
// ============================================================================

// Advance the animation by dt seconds.
// Requires the registry to look up animation data.
animation_update :: proc(reg: ^Animation_Registry, comp: ^Animation_Component, dt: f32) {
	if !comp.playing || comp.finished {
		return
	}

	anim := animation_registry_get_anim(reg, comp.set_handle, comp.animation_name)
	if anim == nil {
		return
	}

	frame_count := len(anim.frames)
	if frame_count == 0 {
		return
	}

	// Calculate frame duration
	frame := &anim.frames[comp.current_frame]
	frame_duration: f32
	if frame.duration_ms > 0 {
		frame_duration = frame.duration_ms / 1000.0  // Convert ms to seconds
	} else if anim.fps > 0 {
		frame_duration = 1.0 / anim.fps
	} else {
		return  // No valid timing
	}

	// Advance time (apply speed multiplier)
	comp.elapsed += dt * abs(comp.speed)

	// Check if we should advance to next frame
	for comp.elapsed >= frame_duration {
		comp.elapsed -= frame_duration

		// Advance frame based on direction
		next_frame := comp.current_frame + int(comp.direction)

		switch anim.loop_mode {
		case .Once:
			if next_frame >= frame_count {
				comp.current_frame = frame_count - 1
				comp.playing = false
				comp.finished = true
				comp.elapsed = 0
				return
			}
			if next_frame < 0 {
				comp.current_frame = 0
				comp.playing = false
				comp.finished = true
				comp.elapsed = 0
				return
			}
			comp.current_frame = next_frame

		case .Loop:
			if next_frame >= frame_count {
				comp.current_frame = 0
			} else if next_frame < 0 {
				comp.current_frame = frame_count - 1
			} else {
				comp.current_frame = next_frame
			}

		case .Ping_Pong:
			if next_frame >= frame_count {
				comp.direction = -1
				comp.current_frame = frame_count - 2 if frame_count > 1 else 0
			} else if next_frame < 0 {
				comp.direction = 1
				comp.current_frame = 1 if frame_count > 1 else 0
			} else {
				comp.current_frame = next_frame
			}
		}

		// Get next frame's duration for continued advancement
		if comp.current_frame >= 0 && comp.current_frame < frame_count {
			next_f := &anim.frames[comp.current_frame]
			if next_f.duration_ms > 0 {
				frame_duration = next_f.duration_ms / 1000.0
			} else if anim.fps > 0 {
				frame_duration = 1.0 / anim.fps
			} else {
				return
			}
		}
	}
}
