package razorlight_core

import "core:dynlib"
import "core:os"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:time"

// ============================================================================
// Hot-Reload Host
// ============================================================================
// Manages loading, unloading, and reloading of game shared libraries.
// The host owns the game state memory so it persists across reloads.

Hot_Reload_Host :: struct {
	lib:            dynlib.Library,
	lib_path:       string,
	copy_path:      string,       // Copy to avoid OS file locking
	api:            Game_API,
	game_state:     rawptr,       // Heap-allocated, persists across reloads
	state_size:     int,
	last_modified:  time.Time,
	check_interval: f32,          // Seconds between file checks
	check_timer:    f32,
	lib_version:    int,
	loaded:         bool,
}

// Create a new hot-reload host for the given shared library path
hot_reload_host_create :: proc(lib_path: string, check_interval: f32 = 0.5) -> ^Hot_Reload_Host {
	host := new(Hot_Reload_Host)
	host.lib_path = strings.clone(lib_path)
	host.check_interval = check_interval
	host.check_timer = 0
	host.lib_version = 0
	host.loaded = false
	return host
}

// Destroy the hot-reload host and free all resources
hot_reload_host_destroy :: proc(host: ^Hot_Reload_Host) {
	if host == nil {
		return
	}

	if host.loaded {
		unload_library(host)
	}

	if host.game_state != nil {
		free(host.game_state)
	}

	delete(host.lib_path)
	if host.copy_path != "" {
		// Try to clean up the copy
		os.remove(host.copy_path)
		delete(host.copy_path)
	}

	free(host)
}

// Perform initial load of the game library
hot_reload_load :: proc(host: ^Hot_Reload_Host) -> bool {
	if host == nil {
		return false
	}

	if !load_library(host) {
		return false
	}

	// Get game state size and allocate persistent memory
	if host.api.game_state_size != nil {
		host.state_size = host.api.game_state_size()
		if host.state_size > 0 {
			host.game_state, _ = mem.alloc(host.state_size)
			mem.zero(host.game_state, host.state_size)
		}
	}

	// Record the initial modification time
	host.last_modified = get_file_mod_time(host.lib_path)
	host.loaded = true

	return true
}

// Check if the library has been modified and reload if so.
// Call this once per frame. Returns true if a reload occurred.
hot_reload_check :: proc(host: ^Hot_Reload_Host, engine: rawptr) -> bool {
	if host == nil || !host.loaded {
		return false
	}

	host.check_timer += 1.0 / 60.0  // Approximate; caller can adjust
	if host.check_timer < host.check_interval {
		return false
	}
	host.check_timer = 0

	current_mod := get_file_mod_time(host.lib_path)
	if current_mod == host.last_modified {
		return false
	}

	// File has changed — reload
	return hot_reload_reload(host, engine)
}

// Force a reload of the game library
hot_reload_reload :: proc(host: ^Hot_Reload_Host, engine: rawptr) -> bool {
	if host == nil {
		return false
	}

	fmt.println("[Hot-Reload] Reloading game library...")

	// Call shutdown on old library
	if host.loaded && host.api.game_shutdown != nil {
		host.api.game_shutdown(host.game_state, engine)
	}

	// Unload old library
	unload_library(host)

	// Load new library
	if !load_library(host) {
		fmt.eprintln("[Hot-Reload] Failed to reload library!")
		return false
	}

	host.last_modified = get_file_mod_time(host.lib_path)
	host.loaded = true

	// Call on_reload callback
	if host.api.game_on_reload != nil {
		host.api.game_on_reload(host.game_state, engine)
	}

	fmt.println("[Hot-Reload] Reload successful!")
	return true
}

// Get the current game API
hot_reload_get_api :: proc(host: ^Hot_Reload_Host) -> Game_API {
	if host == nil {
		return {}
	}
	return host.api
}

// ============================================================================
// Internal Helpers
// ============================================================================

@(private)
load_library :: proc(host: ^Hot_Reload_Host) -> bool {
	// Copy the library to a versioned path to avoid OS file locking
	host.lib_version += 1

	// Clean up old copy
	if host.copy_path != "" {
		os.remove(host.copy_path)
		delete(host.copy_path)
	}

	host.copy_path = strings.clone(fmt.tprintf("%s.%d", host.lib_path, host.lib_version))

	// Copy the file
	if !copy_file(host.lib_path, host.copy_path) {
		fmt.eprintln("[Hot-Reload] Failed to copy library file")
		return false
	}

	// Load the copy
	lib, ok := dynlib.load_library(host.copy_path)
	if !ok {
		fmt.eprintf("[Hot-Reload] Failed to load library: %s\n", host.copy_path)
		return false
	}
	host.lib = lib

	// Resolve symbols
	host.api.game_init = cast(Game_Init_Proc)dynlib.symbol_address(lib, "game_init")
	host.api.game_update = cast(Game_Update_Proc)dynlib.symbol_address(lib, "game_update")
	host.api.game_render = cast(Game_Render_Proc)dynlib.symbol_address(lib, "game_render")
	host.api.game_shutdown = cast(Game_Shutdown_Proc)dynlib.symbol_address(lib, "game_shutdown")
	host.api.game_on_reload = cast(Game_On_Reload_Proc)dynlib.symbol_address(lib, "game_on_reload")
	host.api.game_state_size = cast(Game_State_Size_Proc)dynlib.symbol_address(lib, "game_state_size")

	// game_init and game_update are required
	if host.api.game_init == nil || host.api.game_update == nil {
		fmt.eprintln("[Hot-Reload] Library missing required exports: game_init, game_update")
		dynlib.unload_library(lib)
		return false
	}

	return true
}

@(private)
unload_library :: proc(host: ^Hot_Reload_Host) {
	if host.lib != nil {
		dynlib.unload_library(host.lib)
		host.lib = nil
	}
	host.api = {}
}

@(private)
copy_file :: proc(src, dst: string) -> bool {
	data, ok := os.read_entire_file(src)
	if !ok {
		return false
	}
	defer delete(data)

	return os.write_entire_file(dst, data)
}

@(private)
get_file_mod_time :: proc(path: string) -> time.Time {
	info, err := os.stat(path)
	if err != os.ERROR_NONE {
		return {}
	}
	return info.modification_time
}
