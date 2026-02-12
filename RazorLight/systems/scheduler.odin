package razorlight_systems

import "core:slice"
import "core:time"
import "core:fmt"

// Forward declarations for types from other packages
World :: struct {}  // Will be replaced with actual World import

// ============================================================================
// System Phases
// ============================================================================

System_Phase :: enum {
	Pre_Update,      // Before main update (input processing)
	Update,          // Main game logic
	Fixed_Update,    // Physics and fixed-timestep logic
	Post_Update,     // After main update (cleanup, events)
	Render,          // Main rendering
}

// ============================================================================
// System Function Types
// ============================================================================

// Update system - receives world and delta time
System_Update_Proc :: #type proc(world: rawptr, dt: f32)

// Render system - receives world only (no dt)
System_Render_Proc :: #type proc(world: rawptr)

// ============================================================================
// System Entry
// ============================================================================

System_Entry :: struct {
	name:         string,
	phase:        System_Phase,
	update_proc:  System_Update_Proc,
	render_proc:  System_Render_Proc,
	enabled:      bool,
	priority:     i32,               // Lower = runs first within phase

	// Profiling data
	last_time_ms: f64,
	avg_time_ms:  f64,
	max_time_ms:  f64,
	call_count:   u64,
}

// ============================================================================
// System Scheduler
// ============================================================================

System_Scheduler :: struct {
	systems:           [dynamic]System_Entry,
	sorted_indices:    [System_Phase][dynamic]int,  // Indices into systems array (cache-friendly)
	needs_sort:        bool,

	// Profiling
	profiling_enabled: bool,
	frame_start:       time.Time,
	frame_time_ms:     f64,
}

scheduler_create :: proc() -> ^System_Scheduler {
	sched := new(System_Scheduler)
	sched.systems = make([dynamic]System_Entry)
	sched.needs_sort = true
	sched.profiling_enabled = false
	return sched
}

scheduler_destroy :: proc(sched: ^System_Scheduler) {
	if sched == nil {
		return
	}

	delete(sched.systems)
	for &arr in sched.sorted_indices {
		delete(arr)
	}
	free(sched)
}

// ============================================================================
// System Registration
// ============================================================================

// Register an update system
scheduler_add_system :: proc(
	sched: ^System_Scheduler,
	name: string,
	phase: System_Phase,
	proc_fn: System_Update_Proc,
	priority: i32 = 0,
) {
	entry := System_Entry{
		name        = name,
		phase       = phase,
		update_proc = proc_fn,
		enabled     = true,
		priority    = priority,
	}
	append(&sched.systems, entry)
	sched.needs_sort = true
}

// Register a render system
scheduler_add_render_system :: proc(
	sched: ^System_Scheduler,
	name: string,
	proc_fn: System_Render_Proc,
	priority: i32 = 0,
) {
	entry := System_Entry{
		name        = name,
		phase       = .Render,
		render_proc = proc_fn,
		enabled     = true,
		priority    = priority,
	}
	append(&sched.systems, entry)
	sched.needs_sort = true
}

// Enable/disable a system by name
scheduler_set_enabled :: proc(sched: ^System_Scheduler, name: string, enabled: bool) {
	for &entry in sched.systems {
		if entry.name == name {
			entry.enabled = enabled
			return
		}
	}
}

// Check if a system is enabled
scheduler_is_enabled :: proc(sched: ^System_Scheduler, name: string) -> bool {
	for entry in sched.systems {
		if entry.name == name {
			return entry.enabled
		}
	}
	return false
}

// ============================================================================
// System Execution
// ============================================================================

// Run all update systems for a specific phase
scheduler_run_phase :: proc(sched: ^System_Scheduler, world: rawptr, dt: f32, phase: System_Phase) {
	if sched.needs_sort {
		scheduler_sort(sched)
	}

	for idx in sched.sorted_indices[phase] {
		entry := &sched.systems[idx]
		if !entry.enabled || entry.update_proc == nil {
			continue
		}

		if sched.profiling_enabled {
			start := time.now()
			entry.update_proc(world, dt)
			elapsed := time.duration_milliseconds(time.since(start))

			entry.last_time_ms = elapsed
			entry.call_count += 1

			// Exponential moving average
			alpha := 0.1
			entry.avg_time_ms = alpha * elapsed + (1 - alpha) * entry.avg_time_ms

			if elapsed > entry.max_time_ms {
				entry.max_time_ms = elapsed
			}
		} else {
			entry.update_proc(world, dt)
		}
	}
}

// Run all render systems
scheduler_run_render :: proc(sched: ^System_Scheduler, world: rawptr) {
	if sched.needs_sort {
		scheduler_sort(sched)
	}

	for idx in sched.sorted_indices[.Render] {
		entry := &sched.systems[idx]
		if !entry.enabled || entry.render_proc == nil {
			continue
		}

		if sched.profiling_enabled {
			start := time.now()
			entry.render_proc(world)
			elapsed := time.duration_milliseconds(time.since(start))

			entry.last_time_ms = elapsed
			entry.call_count += 1
			alpha := 0.1
			entry.avg_time_ms = alpha * elapsed + (1 - alpha) * entry.avg_time_ms

			if elapsed > entry.max_time_ms {
				entry.max_time_ms = elapsed
			}
		} else {
			entry.render_proc(world)
		}
	}
}

// Convenience: Run all update phases (Pre_Update, Update, Post_Update)
// Fixed_Update should be called separately with fixed timestep
scheduler_run_update :: proc(sched: ^System_Scheduler, world: rawptr, dt: f32) {
	scheduler_run_phase(sched, world, dt, .Pre_Update)
	scheduler_run_phase(sched, world, dt, .Update)
	scheduler_run_phase(sched, world, dt, .Post_Update)
}

// Run fixed update systems (call multiple times per frame if needed)
scheduler_run_fixed_update :: proc(sched: ^System_Scheduler, world: rawptr, fixed_dt: f32) {
	scheduler_run_phase(sched, world, fixed_dt, .Fixed_Update)
}

// ============================================================================
// Sorting
// ============================================================================

@(private)
scheduler_sort :: proc(sched: ^System_Scheduler) {
	// Clear sorted arrays
	for &arr in sched.sorted_indices {
		clear(&arr)
	}

	// Group by phase (store indices instead of pointers)
	for entry, i in sched.systems {
		append(&sched.sorted_indices[entry.phase], i)
	}

	// Sort each phase by priority using insertion sort (simple and works with index-based access)
	for &arr in sched.sorted_indices {
		// Simple insertion sort
		for i := 1; i < len(arr); i += 1 {
			key := arr[i]
			j := i - 1
			for j >= 0 && sched.systems[arr[j]].priority > sched.systems[key].priority {
				arr[j + 1] = arr[j]
				j -= 1
			}
			arr[j + 1] = key
		}
	}

	sched.needs_sort = false
}

// ============================================================================
// Profiling
// ============================================================================

scheduler_enable_profiling :: proc(sched: ^System_Scheduler, enabled: bool) {
	sched.profiling_enabled = enabled
}

scheduler_begin_frame :: proc(sched: ^System_Scheduler) {
	if sched.profiling_enabled {
		sched.frame_start = time.now()
	}
}

scheduler_end_frame :: proc(sched: ^System_Scheduler) {
	if sched.profiling_enabled {
		sched.frame_time_ms = time.duration_milliseconds(time.since(sched.frame_start))
	}
}

// Get profiling data for a system
scheduler_get_system_time :: proc(sched: ^System_Scheduler, name: string) -> (avg_ms: f64, max_ms: f64, ok: bool) {
	for entry in sched.systems {
		if entry.name == name {
			return entry.avg_time_ms, entry.max_time_ms, true
		}
	}
	return 0, 0, false
}

// Get total frame time
scheduler_get_frame_time :: proc(sched: ^System_Scheduler) -> f64 {
	return sched.frame_time_ms
}

// Print profiling report to console
scheduler_print_profile :: proc(sched: ^System_Scheduler) {
	fmt.println("=== System Profiler ===")
	fmt.printf("Frame time: %.2f ms\n", sched.frame_time_ms)
	fmt.println("")
	fmt.println("System                 Phase        Avg(ms)   Max(ms)   Calls")
	fmt.println("--------------------------------------------------------------")

	for entry in sched.systems {
		phase_name: string
		switch entry.phase {
		case .Pre_Update:   phase_name = "PreUpdate"
		case .Update:       phase_name = "Update"
		case .Fixed_Update: phase_name = "FixedUpdate"
		case .Post_Update:  phase_name = "PostUpdate"
		case .Render:       phase_name = "Render"
		}

		fmt.printf("%-22s %-12s %7.3f   %7.3f   %d\n",
			entry.name,
			phase_name,
			entry.avg_time_ms,
			entry.max_time_ms,
			entry.call_count,
		)
	}
}
