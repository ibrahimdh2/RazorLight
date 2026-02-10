package rzl_commands

import "core:fmt"
import "core:os"
import "core:strings"
import "core:c/libc"
import "core:time"

// ============================================================================
// Run Command - Build and run the project
// ============================================================================

cmd_run :: proc(args: []string) {
	// Check for --hot flag
	hot_reload := false
	target := "debug"

	for arg in args {
		if arg == "--hot" {
			hot_reload = true
		} else {
			target = arg
		}
	}

	if hot_reload {
		cmd_run_hot()
	} else {
		cmd_run_normal(target)
	}
}

// ============================================================================
// Normal Run Mode
// ============================================================================

@(private)
cmd_run_normal :: proc(target: string) {
	// First build the project
	if !build_project(target) {
		os.exit(1)
	}

	// Then run it
	exe_name := get_executable_name()
	if exe_name == "" {
		fmt.println("Error: Could not determine executable name")
		os.exit(1)
	}

	fmt.printf("Running %s...\n", exe_name)
	fmt.println("")

	// Run the executable using system()
	cmd_cstr := strings.clone_to_cstring(exe_name)
	defer delete(cmd_cstr)

	libc.system(cmd_cstr)
}

// ============================================================================
// Hot-Reload Run Mode
// ============================================================================

@(private)
cmd_run_hot :: proc() {
	fmt.println("Hot-reload mode enabled")
	fmt.println("")

	// Step 1: Build game as shared library
	fmt.println("Building game library...")
	if !build_shared_library("game") {
		fmt.println("Error: Failed to build game library")
		os.exit(1)
	}

	// Step 2: Build host executable
	fmt.println("Building host...")
	if !build_host() {
		fmt.println("Error: Failed to build host")
		os.exit(1)
	}

	// Step 3: Launch host in background
	fmt.println("Launching host with hot-reload...")
	fmt.println("Watching game/ for changes... (Ctrl+C to stop)")
	fmt.println("")

	when ODIN_OS == .Windows {
		host_exe := "host.exe"
	} else {
		host_exe := "./host"
	}

	// Launch the host (it will poll for library changes internally)
	host_cstr := strings.clone_to_cstring(host_exe)
	defer delete(host_cstr)

	// Start host and enter watch loop
	// The host itself uses Hot_Reload_Host to detect changes
	// We also watch and recompile on source changes
	watch_and_run(host_cstr)
}

@(private)
watch_and_run :: proc(host_cmd: cstring) {
	// Simple approach: build and run, then poll for changes
	// In a production tool this would use inotify/FSEvents/ReadDirectoryChanges

	last_mod := get_dir_mod_time("game")

	// Launch host
	libc.system(host_cmd)

	// Note: In a full implementation, the host would run in a separate process
	// and we'd watch game/*.odin files here, recompiling the shared lib on change.
	// For now the host's built-in Hot_Reload_Host handles the file watching.
}

@(private)
build_host :: proc() -> bool {
	cmd: strings.Builder
	strings.builder_init(&cmd)
	defer strings.builder_destroy(&cmd)

	strings.write_string(&cmd, "odin build host -o:none -debug")

	when ODIN_OS == .Windows {
		strings.write_string(&cmd, " -out:host.exe")
		strings.write_string(&cmd, " -extra-linker-flags:/NODEFAULTLIB:libcmt.lib")
	} else {
		strings.write_string(&cmd, " -out:host")
	}

	cmd_str := strings.to_string(cmd)
	fmt.printf("$ %s\n", cmd_str)

	cmd_cstr := strings.clone_to_cstring(cmd_str)
	defer delete(cmd_cstr)

	return libc.system(cmd_cstr) == 0
}

@(private)
get_dir_mod_time :: proc(dir: string) -> time.Time {
	info, err := os.stat(dir)
	if err != os.ERROR_NONE {
		return {}
	}
	return info.modification_time
}

@(private)
get_executable_name :: proc() -> string {
	// Get the current directory name as the executable name
	cwd := os.get_current_directory()

	// Extract directory name from path
	last_sep := -1
	for i := len(cwd) - 1; i >= 0; i -= 1 {
		if cwd[i] == '/' || cwd[i] == '\\' {
			last_sep = i
			break
		}
	}

	dir_name: string
	if last_sep >= 0 && last_sep < len(cwd) - 1 {
		dir_name = cwd[last_sep + 1:]
	} else {
		dir_name = cwd
	}

	when ODIN_OS == .Windows {
		return fmt.tprintf("%s.exe", dir_name)
	} else {
		return dir_name
	}
}
