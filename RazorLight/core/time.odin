package razorlight_core

// ============================================================================
// Time Management
// ============================================================================

Time_State :: struct {
	// Frame timing
	delta_time:       f32,           // Time since last frame (scaled)
	unscaled_delta:   f32,           // Raw frame time (unaffected by time_scale)
	time_scale:       f32,           // Slow-mo/speed-up factor (1.0 = normal)

	// Fixed timestep for physics
	fixed_timestep:   f32,           // Physics update interval
	accumulator:      f32,           // Time accumulated for fixed updates

	// Total elapsed time
	total_time:       f64,           // Time since start (scaled)
	real_time:        f64,           // Time since start (unscaled)

	// Frame counter
	frame_count:      u64,

	// FPS tracking
	fps:              f32,
	fps_update_timer: f32,
	frame_times:      [60]f32,       // Rolling window for FPS calculation
	frame_time_index: int,
}

time_create :: proc(fixed_timestep: f32 = 1.0 / 60.0) -> ^Time_State {
	ts := new(Time_State)
	ts.fixed_timestep = fixed_timestep
	ts.time_scale = 1.0
	ts.fps = 60.0  // Initial estimate
	return ts
}

time_update :: proc(ts: ^Time_State, raw_dt: f32) {
	// Clamp delta time to avoid spiral of death
	clamped_dt := min(raw_dt, 0.25)  // Max 250ms per frame

	ts.unscaled_delta = clamped_dt
	ts.delta_time = clamped_dt * ts.time_scale

	// Accumulate time for fixed update
	ts.accumulator += ts.delta_time

	// Track total time
	ts.total_time += f64(ts.delta_time)
	ts.real_time += f64(clamped_dt)
	ts.frame_count += 1

	// Update FPS tracking (rolling average)
	ts.frame_times[ts.frame_time_index] = clamped_dt
	ts.frame_time_index = (ts.frame_time_index + 1) % len(ts.frame_times)

	// Update FPS display every 0.5 seconds
	ts.fps_update_timer += clamped_dt
	if ts.fps_update_timer >= 0.5 {
		sum: f32 = 0
		for t in ts.frame_times {
			sum += t
		}
		avg := sum / f32(len(ts.frame_times))
		ts.fps = 1.0 / avg if avg > 0 else 0
		ts.fps_update_timer = 0
	}
}

// Check if we should run a fixed update step
time_should_fixed_update :: proc(ts: ^Time_State) -> bool {
	return ts.accumulator >= ts.fixed_timestep
}

// Consume one fixed update step
time_consume_fixed_step :: proc(ts: ^Time_State) {
	ts.accumulator -= ts.fixed_timestep
}

// Get interpolation alpha for rendering (0-1)
// Use this to interpolate between physics states for smooth rendering
time_get_alpha :: proc(ts: ^Time_State) -> f32 {
	return ts.accumulator / ts.fixed_timestep
}

time_destroy :: proc(ts: ^Time_State) {
	free(ts)
}

// Convenience getters
time_get_fps :: proc(ts: ^Time_State) -> f32 {
	return ts.fps
}

time_get_delta :: proc(ts: ^Time_State) -> f32 {
	return ts.delta_time
}

time_get_total :: proc(ts: ^Time_State) -> f64 {
	return ts.total_time
}

time_get_frame_count :: proc(ts: ^Time_State) -> u64 {
	return ts.frame_count
}

// Set time scale (0 = paused, 0.5 = half speed, 2 = double speed)
time_set_scale :: proc(ts: ^Time_State, scale: f32) {
	ts.time_scale = max(scale, 0.0)
}

time_get_scale :: proc(ts: ^Time_State) -> f32 {
	return ts.time_scale
}

// Pause/unpause (convenience wrappers)
time_pause :: proc(ts: ^Time_State) {
	ts.time_scale = 0
}

time_resume :: proc(ts: ^Time_State) {
	ts.time_scale = 1.0
}

time_is_paused :: proc(ts: ^Time_State) -> bool {
	return ts.time_scale == 0
}
