package rzl_commands

import "core:fmt"
import "core:os"
import "core:strings"
import "core:c/libc"

// ============================================================================
// Run Command - Build and run the project
// ============================================================================

cmd_run :: proc(args: []string) {
	target := "debug"
	if len(args) > 0 {
		target = args[0]
	}

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
