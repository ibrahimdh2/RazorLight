package rzl_commands

import "core:fmt"
import "core:os"
import "core:strings"
import "core:c/libc"
import "core:time"

// ============================================================================
// Editor Command - Build and launch the animation editor
// ============================================================================

cmd_editor :: proc(args: []string) {
	fmt.println("Building Animation Editor...")

	start_time := time.now()

	// Determine the engine path
	editor_src := find_editor_path()
	if editor_src == "" {
		fmt.println("Error: Could not find the animation editor source.")
		fmt.println("Expected at: RazorLight/editor/animation_editor/")
		os.exit(1)
	}

	// Build command
	cmd: strings.Builder
	strings.builder_init(&cmd)
	defer strings.builder_destroy(&cmd)

	strings.write_string(&cmd, "odin build ")
	strings.write_string(&cmd, editor_src)
	strings.write_string(&cmd, " -o:none -debug")

	// Output name
	when ODIN_OS == .Windows {
		strings.write_string(&cmd, " -out:razl_editor.exe")
		strings.write_string(&cmd, " -extra-linker-flags:/NODEFAULTLIB:libcmt.lib")
	} else {
		strings.write_string(&cmd, " -out:razl_editor")
	}

	cmd_str := strings.to_string(cmd)
	fmt.printf("$ %s\n", cmd_str)

	cmd_cstr := strings.clone_to_cstring(cmd_str)
	defer delete(cmd_cstr)

	exit_code := libc.system(cmd_cstr)
	if exit_code != 0 {
		fmt.println("Failed to build animation editor")
		os.exit(1)
	}

	elapsed := time.duration_seconds(time.since(start_time))
	fmt.printf("Editor built in %.2f seconds\n", elapsed)

	// Launch the editor
	fmt.println("Launching Animation Editor...")

	when ODIN_OS == .Windows {
		run_cstr := strings.clone_to_cstring("razl_editor.exe")
	} else {
		run_cstr := strings.clone_to_cstring("./razl_editor")
	}
	defer delete(run_cstr)

	libc.system(run_cstr)
}

// ============================================================================
// Path Resolution
// ============================================================================

@(private)
find_editor_path :: proc() -> string {
	// Try common locations relative to the project
	paths := [?]string{
		"RazorLight/editor/animation_editor",
		"../RazorLight/editor/animation_editor",
		"../../RazorLight/editor/animation_editor",
	}

	for path in paths {
		if os.exists(path) {
			return path
		}
	}

	// Try reading engine_path from project.json
	if data, ok := os.read_entire_file("project.json"); ok {
		defer delete(data)
		// Simple string search for engine_path value
		content := string(data)
		if idx := strings.index(content, "\"engine_path\""); idx >= 0 {
			// Find the value after the colon
			rest := content[idx:]
			if colon := strings.index(rest, ":"); colon >= 0 {
				value_str := rest[colon + 1:]
				if q1 := strings.index(value_str, "\""); q1 >= 0 {
					value_str = value_str[q1 + 1:]
					if q2 := strings.index(value_str, "\""); q2 >= 0 {
						engine_path := value_str[:q2]
						editor_path := fmt.tprintf("%s/editor/animation_editor", engine_path)
						if os.exists(editor_path) {
							return editor_path
						}
					}
				}
			}
		}
	}

	return ""
}
