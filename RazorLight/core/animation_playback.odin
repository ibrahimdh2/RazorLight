package razorlight_core

import k2 "../libs/karl2d"

// ============================================================================
// Animation Playback Control
// ============================================================================

// Play a named animation from the component's animation set
animation_play :: proc(comp: ^Animation_Component, name: string) {
	if comp.animation_set == nil {
		return
	}

	anim, ok := &comp.animation_set.animations[name]
	if !ok {
		return
	}

	animation_play_anim(comp, anim)
}

// Play a specific Animation directly
animation_play_anim :: proc(comp: ^Animation_Component, anim: ^Animation) {
	comp.current_animation = anim
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
animation_resume :: proc(comp: ^Animation_Component) {
	if comp.current_animation != nil && !comp.finished {
		comp.playing = true
	}
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
animation_set_frame :: proc(comp: ^Animation_Component, index: int) {
	if comp.current_animation == nil {
		return
	}

	frame_count := len(comp.current_animation.frames)
	if frame_count == 0 {
		return
	}

	comp.current_frame = clamp(index, 0, frame_count - 1)
	comp.elapsed = 0
}

// Get the current frame's source rectangle for rendering
animation_get_current_frame :: proc(comp: ^Animation_Component) -> (k2.Rect, bool) {
	if comp.current_animation == nil {
		return {}, false
	}

	frames := comp.current_animation.frames
	if len(frames) == 0 {
		return {}, false
	}

	frame_idx := clamp(comp.current_frame, 0, len(frames) - 1)
	return frames[frame_idx].src_rect, true
}

// Check if a non-looping animation has finished
animation_is_finished :: proc(comp: ^Animation_Component) -> bool {
	return comp.finished
}

// ============================================================================
// Animation Update (Core Tick)
// ============================================================================

// Advance the animation by dt seconds
animation_update :: proc(comp: ^Animation_Component, dt: f32) {
	if !comp.playing || comp.current_animation == nil || comp.finished {
		return
	}

	anim := comp.current_animation
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
