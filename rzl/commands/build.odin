package rzl_commands

import "core:fmt"
import "core:os"
import "core:strings"
import "core:c/libc"
import "core:time"

// ============================================================================
// Build Command - Build the project
// ============================================================================

cmd_build :: proc(args: []string) {
	target := "debug"
	if len(args) > 0 {
		target = args[0]
	}

	if !build_project(target) {
		os.exit(1)
	}
}

build_project :: proc(target: string) -> bool {
	fmt.printf("Building project (%s)...\n", target)

	start_time := time.now()

	// Determine build options based on target
	optimization: string
	debug_flag: string

	switch target {
	case "debug":
		optimization = "-o:none"
		debug_flag = "-debug"
	case "release":
		optimization = "-o:speed"
		debug_flag = ""
	case "size":
		optimization = "-o:size"
		debug_flag = ""
	case:
		fmt.printf("Unknown build target: %s\n", target)
		fmt.println("Valid targets: debug, release, size")
		return false
	}

	// Build command string
	cmd: strings.Builder
	strings.builder_init(&cmd)
	defer strings.builder_destroy(&cmd)

	strings.write_string(&cmd, "odin build src")

	if optimization != "" {
		strings.write_string(&cmd, " ")
		strings.write_string(&cmd, optimization)
	}
	if debug_flag != "" {
		strings.write_string(&cmd, " ")
		strings.write_string(&cmd, debug_flag)
	}

	// Windows-specific linker flags
	when ODIN_OS == .Windows {
		strings.write_string(&cmd, " -extra-linker-flags:/NODEFAULTLIB:libcmt.lib")
	}

	cmd_str := strings.to_string(cmd)
	fmt.printf("$ %s\n", cmd_str)

	// Execute build using system()
	cmd_cstr := strings.clone_to_cstring(cmd_str)
	defer delete(cmd_cstr)

	exit_code := libc.system(cmd_cstr)

	if exit_code != 0 {
		fmt.println("Build failed")
		return false
	}

	elapsed := time.duration_seconds(time.since(start_time))
	fmt.printf("Build completed in %.2f seconds\n", elapsed)

	return true
}
