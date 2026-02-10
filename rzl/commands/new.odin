package rzl_commands

import "core:fmt"
import "core:os"
import "core:strings"

// ============================================================================
// New Command - Create a new RazorLight project
// ============================================================================

cmd_new :: proc(args: []string) {
	if len(args) == 0 {
		fmt.println("Error: Project name required")
		fmt.println("Usage: rzl new <project_name>")
		os.exit(1)
	}

	project_name := args[0]

	// Validate project name
	if !is_valid_project_name(project_name) {
		fmt.printf("Error: Invalid project name '%s'\n", project_name)
		fmt.println("Project name must start with a letter and contain only letters, numbers, and underscores.")
		os.exit(1)
	}

	// Check if directory already exists
	if os.exists(project_name) {
		fmt.printf("Error: Directory '%s' already exists\n", project_name)
		os.exit(1)
	}

	fmt.printf("Creating new RazorLight project: %s\n", project_name)

	// Create project structure
	create_directory(project_name)
	create_directory(fmt.tprintf("%s/host", project_name))
	create_directory(fmt.tprintf("%s/game", project_name))
	create_directory(fmt.tprintf("%s/assets", project_name))
	create_directory(fmt.tprintf("%s/assets/sprites", project_name))
	create_directory(fmt.tprintf("%s/assets/sounds", project_name))
	create_directory(fmt.tprintf("%s/assets/animations", project_name))

	// Create project files
	create_project_json(project_name)
	create_host_main(project_name)
	create_game_main(project_name)
	create_game_state(project_name)
	create_build_script(project_name)
	create_gitignore(project_name)

	fmt.println("")
	fmt.println("Project created successfully!")
	fmt.println("")
	fmt.println("Next steps:")
	fmt.printf("  cd %s\n", project_name)
	fmt.println("  rzl run             # Normal mode")
	fmt.println("  rzl run --hot       # Hot-reload mode")
}

@(private)
is_valid_project_name :: proc(name: string) -> bool {
	if len(name) == 0 {
		return false
	}

	// First character must be a letter
	first := name[0]
	if !((first >= 'a' && first <= 'z') || (first >= 'A' && first <= 'Z')) {
		return false
	}

	// Rest can be letters, numbers, or underscores
	for c in name {
		valid := (c >= 'a' && c <= 'z') ||
		         (c >= 'A' && c <= 'Z') ||
		         (c >= '0' && c <= '9') ||
		         c == '_'
		if !valid {
			return false
		}
	}

	return true
}

@(private)
create_directory :: proc(path: string) {
	err := os.make_directory(path)
	if err != os.ERROR_NONE {
		// Ignore if already exists
		if !os.exists(path) {
			fmt.printf("Error creating directory '%s': %v\n", path, err)
			os.exit(1)
		}
	}
}

@(private)
create_project_json :: proc(project_name: string) {
	content := fmt.tprintf(`{{
	"name": "%s",
	"version": "0.1.0",
	"engine_version": "0.1.0",
	"hot_reload": true,
	"engine_path": "../../RazorLight",
	"build": {{
		"debug": {{
			"optimization": "none",
			"debug_symbols": true
		}},
		"release": {{
			"optimization": "speed",
			"debug_symbols": false
		}}
	}}
}}
`, project_name)

	write_file(fmt.tprintf("%s/project.json", project_name), content)
}

@(private)
create_host_main :: proc(project_name: string) {
	content := fmt.tprintf(`package %s_host

import rl "../../RazorLight"
import "core:fmt"

// ============================================================================
// Hot-Reload Host
// ============================================================================
// This executable owns the window, engine, and game state memory.
// The game logic runs from a shared library that can be reloaded at runtime.

LIB_PATH :: "game.so"  // Or "game.dll" on Windows, "game.dylib" on macOS

main :: proc() {{
	// Create engine
	config := rl.Engine_Config{{
		window_width     = 1280,
		window_height    = 720,
		window_title     = "%s",
		fixed_timestep   = 1.0 / 60.0,
		physics_substeps = 4,
		gravity          = {{0, 900}},
		pixels_per_meter = 40,
		clear_color      = rl.LIGHT_BLUE,
	}}

	engine := rl.engine_create(config)
	defer rl.engine_destroy(engine)

	// Create hot-reload host
	host := rl.hot_reload_host_create(LIB_PATH, 0.5)
	defer rl.hot_reload_host_destroy(host)

	// Initial load
	if !rl.hot_reload_load(host) {{
		fmt.println("Failed to load game library!")
		return
	}}

	// Call game_init
	api := rl.hot_reload_get_api(host)
	if api.game_init != nil {{
		api.game_init(host.game_state, engine)
	}}

	// Game loop
	for rl.engine_update(engine) {{
		// Check for library changes
		rl.hot_reload_check(host, engine)

		// Get current API (may have changed after reload)
		api = rl.hot_reload_get_api(host)

		// Update game
		if api.game_update != nil {{
			api.game_update(host.game_state, engine, rl.engine_get_delta_time(engine))
		}}

		// Render
		if api.game_render != nil {{
			api.game_render(host.game_state, engine)
		}}

		rl.engine_render(engine)
	}}

	// Shutdown
	api = rl.hot_reload_get_api(host)
	if api.game_shutdown != nil {{
		api.game_shutdown(host.game_state, engine)
	}}
}}
`, project_name, project_name)

	write_file(fmt.tprintf("%s/host/main.odin", project_name), content)
}

@(private)
create_game_main :: proc(project_name: string) {
	content := fmt.tprintf(`package %s_game

import rl "../../RazorLight"
import "core:fmt"

// ============================================================================
// Game Library - Exported Functions
// ============================================================================
// These functions are loaded by the host via hot-reload.
// ALL game state must live in Game_State (no package globals).

@(export)
game_state_size :: proc "c" () -> int {{
	return size_of(Game_State)
}}

@(export)
game_init :: proc "c" (state_ptr: rawptr, engine_ptr: rawptr) {{
	context = {{}}
	state := cast(^Game_State)state_ptr
	engine := cast(^rl.Engine)engine_ptr

	world := rl.engine_get_world(engine)

	// Create a player
	state.player = rl.world_create_physics_circle(world, {{640, 360}}, 30, 1.0, 0.3)
	rl.world_add_component(world, state.player, rl.Shape_Component{{
		shape_type = .Circle,
		color = rl.BLUE,
		size = {{30, 30}},
		visible = true,
	}})

	// Create ground
	ground := rl.world_create_static_box(world, {{640, 660}}, 1280, 120)
	rl.world_add_component(world, ground, rl.Shape_Component{{
		shape_type = .Rectangle,
		color = rl.GREEN,
		size = {{1280, 120}},
		visible = true,
	}})

	state.score = 0
	fmt.println("Game initialized!")
}}

@(export)
game_update :: proc "c" (state_ptr: rawptr, engine_ptr: rawptr, dt: f32) {{
	context = {{}}
	state := cast(^Game_State)state_ptr
	engine := cast(^rl.Engine)engine_ptr

	// Game logic goes here
	// Modify state.score, move entities, etc.

	// Quit with Escape
	if rl.key_went_down(.Escape) {{
		rl.engine_quit(engine)
	}}
}}

@(export)
game_render :: proc "c" (state_ptr: rawptr, engine_ptr: rawptr) {{
	context = {{}}
	state := cast(^Game_State)state_ptr
	engine := cast(^rl.Engine)engine_ptr

	// Custom rendering
	text := fmt.tprintf("Score: %%d", state.score)
	rl.draw_text(text, {{10, 10}}, 20, rl.BLACK)
}}

@(export)
game_shutdown :: proc "c" (state_ptr: rawptr, engine_ptr: rawptr) {{
	context = {{}}
	fmt.println("Game shutting down")
}}

@(export)
game_on_reload :: proc "c" (state_ptr: rawptr, engine_ptr: rawptr) {{
	context = {{}}
	fmt.println("Game library reloaded!")
}}
`, project_name)

	write_file(fmt.tprintf("%s/game/main.odin", project_name), content)
}

@(private)
create_game_state :: proc(project_name: string) {
	content := fmt.tprintf(`package %s_game

import ecs "../../RazorLight/libs/yggsECS"

// ============================================================================
// Game State
// ============================================================================
// ALL game state must be in this struct.
// Package globals are reset on hot-reload, so never use them for state.

Game_State :: struct {{
	player: ecs.EntityID,
	score:  int,
}}
`, project_name)

	write_file(fmt.tprintf("%s/game/game_state.odin", project_name), content)
}

@(private)
create_build_script :: proc(project_name: string) {
	content := `#!/bin/bash
# Build script for hot-reload project

set -e

TARGET=${1:-debug}

case "$TARGET" in
    debug)
        OPT="-o:none -debug"
        ;;
    release)
        OPT="-o:speed"
        ;;
    *)
        echo "Usage: ./build.sh [debug|release]"
        exit 1
        ;;
esac

echo "Building game library..."
odin build game -build-mode:shared -out:game.so $OPT
echo "Game library built."

echo "Building host..."
odin build host -out:host $OPT
echo "Host built."

echo "Done! Run with: ./host"
`
	write_file(fmt.tprintf("%s/build.sh", project_name), content)
}

@(private)
create_gitignore :: proc(project_name: string) {
	content := `# Build outputs
*.exe
*.pdb
*.obj

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db
`
	write_file(fmt.tprintf("%s/.gitignore", project_name), content)
}

@(private)
write_file :: proc(path: string, content: string) {
	ok := os.write_entire_file(path, transmute([]u8)content)
	if !ok {
		fmt.printf("Error writing file '%s'\n", path)
		os.exit(1)
	}
}
