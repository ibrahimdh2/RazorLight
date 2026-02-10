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

// ============================================================================
// Shared Library Build (for hot-reload)
// ============================================================================

build_shared_library :: proc(source_dir: string) -> bool {
	fmt.printf("Building shared library from %s...\n", source_dir)

	start_time := time.now()

	cmd: strings.Builder
	strings.builder_init(&cmd)
	defer strings.builder_destroy(&cmd)

	strings.write_string(&cmd, "odin build ")
	strings.write_string(&cmd, source_dir)
	strings.write_string(&cmd, " -build-mode:shared -o:none -debug")

	when ODIN_OS == .Windows {
		strings.write_string(&cmd, " -out:game.dll")
		strings.write_string(&cmd, " -extra-linker-flags:/NODEFAULTLIB:libcmt.lib")
	} else when ODIN_OS == .Darwin {
		strings.write_string(&cmd, " -out:game.dylib")
	} else {
		strings.write_string(&cmd, " -out:game.so")
	}

	cmd_str := strings.to_string(cmd)
	fmt.printf("$ %s\n", cmd_str)

	cmd_cstr := strings.clone_to_cstring(cmd_str)
	defer delete(cmd_cstr)

	exit_code := libc.system(cmd_cstr)
	if exit_code != 0 {
		fmt.println("Shared library build failed")
		return false
	}

	elapsed := time.duration_seconds(time.since(start_time))
	fmt.printf("Shared library built in %.2f seconds\n", elapsed)

	return true
}
