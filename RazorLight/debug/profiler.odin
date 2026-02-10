package razorlight_debug

import "core:fmt"
import "core:time"

// ============================================================================
// Profiler
// ============================================================================

Profiler :: struct {
	enabled:         bool,
	frame_start:     time.Time,
	sections:        map[string]^Profile_Section,
	frame_times:     [120]f64,       // 2 seconds of history at 60fps
	frame_index:     int,
	current_frame_ms: f64,
}

Profile_Section :: struct {
	name:        string,
	start_time:  time.Time,
	total_ms:    f64,             // Total time this frame
	avg_ms:      f64,             // Rolling average
	max_ms:      f64,             // Peak time
	call_count:  int,             // Calls this frame
	total_calls: u64,             // Total calls ever
}

// Global profiler instance
@(private="file")
g_profiler: Profiler

// ============================================================================
// Lifecycle
// ============================================================================

profiler_init :: proc() {
	g_profiler.sections = make(map[string]^Profile_Section)
	g_profiler.enabled = true
}

profiler_shutdown :: proc() {
	for _, section in g_profiler.sections {
		free(section)
	}
	delete(g_profiler.sections)
}

profiler_enable :: proc(enabled: bool) {
	g_profiler.enabled = enabled
}

profiler_is_enabled :: proc() -> bool {
	return g_profiler.enabled
}

// ============================================================================
// Frame Management
// ============================================================================

profiler_begin_frame :: proc() {
	if !g_profiler.enabled {
		return
	}

	g_profiler.frame_start = time.now()

	// Reset per-frame data for all sections
	for _, section in g_profiler.sections {
		section.total_ms = 0
		section.call_count = 0
	}
}

profiler_end_frame :: proc() {
	if !g_profiler.enabled {
		return
	}

	// Record frame time
	g_profiler.current_frame_ms = time.duration_milliseconds(time.since(g_profiler.frame_start))
	g_profiler.frame_times[g_profiler.frame_index] = g_profiler.current_frame_ms
	g_profiler.frame_index = (g_profiler.frame_index + 1) % len(g_profiler.frame_times)
}

// ============================================================================
// Section Profiling
// ============================================================================

profiler_begin :: proc(name: string) {
	if !g_profiler.enabled {
		return
	}

	section := g_profiler.sections[name]
	if section == nil {
		section = new(Profile_Section)
		section.name = name
		g_profiler.sections[name] = section
	}

	section.start_time = time.now()
}

profiler_end :: proc(name: string) {
	if !g_profiler.enabled {
		return
	}

	section := g_profiler.sections[name]
	if section == nil {
		return
	}

	elapsed := time.duration_milliseconds(time.since(section.start_time))
	section.total_ms += elapsed
	section.call_count += 1
	section.total_calls += 1

	// Update rolling average (exponential moving average)
	alpha := 0.1
	section.avg_ms = alpha * elapsed + (1 - alpha) * section.avg_ms

	// Update max
	if elapsed > section.max_ms {
		section.max_ms = elapsed
	}
}

// Scoped profiling - use with defer
// Usage: defer profiler_scope("my_section")
profiler_scope :: proc(name: string) -> string {
	profiler_begin(name)
	return name
}

@(deferred_out=profiler_end)
PROFILE :: proc(name: string) -> string {
	profiler_begin(name)
	return name
}

// ============================================================================
// Queries
// ============================================================================

profiler_get_fps :: proc() -> f32 {
	if !g_profiler.enabled {
		return 0
	}

	sum: f64 = 0
	count := 0
	for t in g_profiler.frame_times {
		if t > 0 {
			sum += t
			count += 1
		}
	}

	if count == 0 {
		return 0
	}

	avg_ms := sum / f64(count)
	return f32(1000.0 / avg_ms) if avg_ms > 0 else 0
}

profiler_get_frame_time :: proc() -> f64 {
	return g_profiler.current_frame_ms
}

profiler_get_section :: proc(name: string) -> (avg_ms: f64, max_ms: f64, calls: u64, ok: bool) {
	section := g_profiler.sections[name]
	if section == nil {
		return 0, 0, 0, false
	}
	return section.avg_ms, section.max_ms, section.total_calls, true
}

// ============================================================================
// Reporting
// ============================================================================

profiler_print_report :: proc() {
	if !g_profiler.enabled {
		fmt.println("Profiler is disabled")
		return
	}

	fmt.println("")
	fmt.println("╔══════════════════════════════════════════════════════════════╗")
	fmt.println("║                    PROFILER REPORT                           ║")
	fmt.println("╠══════════════════════════════════════════════════════════════╣")
	fmt.printf("║  FPS: %.1f  |  Frame Time: %.2f ms                           ║\n",
		profiler_get_fps(), g_profiler.current_frame_ms)
	fmt.println("╠══════════════════════════════════════════════════════════════╣")
	fmt.println("║  Section              │  Avg(ms)  │  Max(ms)  │  Calls      ║")
	fmt.println("╟───────────────────────┼───────────┼───────────┼─────────────╢")

	for name, section in g_profiler.sections {
		fmt.printf("║  %-20s │  %7.3f  │  %7.3f  │  %9d  ║\n",
			name,
			section.avg_ms,
			section.max_ms,
			section.total_calls,
		)
	}

	fmt.println("╚══════════════════════════════════════════════════════════════╝")
	fmt.println("")
}

// Reset all statistics
profiler_reset :: proc() {
	for _, section in g_profiler.sections {
		section.avg_ms = 0
		section.max_ms = 0
		section.total_calls = 0
	}

	for &t in g_profiler.frame_times {
		t = 0
	}
	g_profiler.frame_index = 0
}
