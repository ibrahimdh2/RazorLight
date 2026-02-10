package razorlight_debug

import "core:fmt"
import "core:time"
import "base:runtime"

// ============================================================================
// Log Levels
// ============================================================================

Log_Level :: enum {
	Trace,      // Detailed debugging info
	Debug,      // Debug messages
	Info,       // General information
	Warning,    // Warnings
	Error,      // Errors
	Fatal,      // Fatal errors (will panic)
}

// ============================================================================
// Logger Configuration
// ============================================================================

Logger_Config :: struct {
	min_level:       Log_Level,
	show_timestamp:  bool,
	show_location:   bool,
	colored_output:  bool,
}

DEFAULT_LOGGER_CONFIG :: Logger_Config {
	min_level      = .Debug,
	show_timestamp = true,
	show_location  = false,
	colored_output = true,
}

// Global logger state
@(private="file")
g_config: Logger_Config = DEFAULT_LOGGER_CONFIG

// ============================================================================
// Configuration
// ============================================================================

log_set_level :: proc(level: Log_Level) {
	g_config.min_level = level
}

log_set_show_timestamp :: proc(show: bool) {
	g_config.show_timestamp = show
}

log_set_show_location :: proc(show: bool) {
	g_config.show_location = show
}

log_set_colored :: proc(colored: bool) {
	g_config.colored_output = colored
}

// ============================================================================
// Logging Functions
// ============================================================================

log_trace :: proc(args: ..any, loc := #caller_location) {
	log_impl(.Trace, args, loc)
}

log_debug :: proc(args: ..any, loc := #caller_location) {
	log_impl(.Debug, args, loc)
}

log_info :: proc(args: ..any, loc := #caller_location) {
	log_impl(.Info, args, loc)
}

log_warn :: proc(args: ..any, loc := #caller_location) {
	log_impl(.Warning, args, loc)
}

log_error :: proc(args: ..any, loc := #caller_location) {
	log_impl(.Error, args, loc)
}

log_fatal :: proc(args: ..any, loc := #caller_location) {
	log_impl(.Fatal, args, loc)
}

// ============================================================================
// Implementation
// ============================================================================

@(private)
log_impl :: proc(level: Log_Level, args: []any, loc: runtime.Source_Code_Location) {
	if level < g_config.min_level {
		return
	}

	// Level prefix and color
	level_str: string
	color_code: string
	reset_code := "\x1b[0m"

	switch level {
	case .Trace:
		level_str = "[TRACE]"
		color_code = "\x1b[90m"  // Dark gray
	case .Debug:
		level_str = "[DEBUG]"
		color_code = "\x1b[36m"  // Cyan
	case .Info:
		level_str = "[INFO] "
		color_code = "\x1b[32m"  // Green
	case .Warning:
		level_str = "[WARN] "
		color_code = "\x1b[33m"  // Yellow
	case .Error:
		level_str = "[ERROR]"
		color_code = "\x1b[31m"  // Red
	case .Fatal:
		level_str = "[FATAL]"
		color_code = "\x1b[35m"  // Magenta
	}

	// Print timestamp
	if g_config.show_timestamp {
		t := time.now()
		hour, min, sec := time.clock_from_time(t)
		fmt.printf("%02d:%02d:%02d ", hour, min, sec)
	}

	// Print level (with color if enabled)
	if g_config.colored_output {
		fmt.printf("%s%s%s ", color_code, level_str, reset_code)
	} else {
		fmt.printf("%s ", level_str)
	}

	// Print location
	if g_config.show_location {
		// Extract just the filename from the path
		filename := loc.file_path
		for i := len(filename) - 1; i >= 0; i -= 1 {
			if filename[i] == '/' || filename[i] == '\\' {
				filename = filename[i+1:]
				break
			}
		}
		fmt.printf("(%s:%d) ", filename, loc.line)
	}

	// Print message
	for idx := 0; idx < len(args); idx += 1 {
		if idx > 0 {
			fmt.print(" ")
		}
		fmt.print(args[idx])
	}
	fmt.println()

	// Fatal should panic
	if level == .Fatal {
		panic("Fatal error - see log above")
	}
}

// ============================================================================
// Formatted Logging
// ============================================================================

log_tracef :: proc(format: string, args: ..any, loc := #caller_location) {
	if .Trace >= g_config.min_level {
		log_impl(.Trace, {fmt.tprintf(format, ..args)}, loc)
	}
}

log_debugf :: proc(format: string, args: ..any, loc := #caller_location) {
	if .Debug >= g_config.min_level {
		log_impl(.Debug, {fmt.tprintf(format, ..args)}, loc)
	}
}

log_infof :: proc(format: string, args: ..any, loc := #caller_location) {
	if .Info >= g_config.min_level {
		log_impl(.Info, {fmt.tprintf(format, ..args)}, loc)
	}
}

log_warnf :: proc(format: string, args: ..any, loc := #caller_location) {
	if .Warning >= g_config.min_level {
		log_impl(.Warning, {fmt.tprintf(format, ..args)}, loc)
	}
}

log_errorf :: proc(format: string, args: ..any, loc := #caller_location) {
	if .Error >= g_config.min_level {
		log_impl(.Error, {fmt.tprintf(format, ..args)}, loc)
	}
}

log_fatalf :: proc(format: string, args: ..any, loc := #caller_location) {
	log_impl(.Fatal, {fmt.tprintf(format, ..args)}, loc)
}
