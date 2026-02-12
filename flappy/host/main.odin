package flappy_host

import rl "../../RazorLight"
import "core:fmt"

// ============================================================================
// Hot-Reload Host
// ============================================================================

LIB_PATH :: "game.so"

main :: proc() {
	fmt.println("[Host] Starting...")
	
	// Create engine
	config := rl.Engine_Config{
		window_width     = 400,
		window_height    = 600,
		window_title     = "Flappy Bird",
		fixed_timestep   = 1.0 / 60.0,
		physics_substeps = 4,
		gravity          = {0, 900},
		pixels_per_meter = 40,
		clear_color      = rl.Color{100, 180, 255, 255},
	}

	fmt.println("[Host] Creating engine...")
	engine := rl.engine_create(config)
	defer rl.engine_destroy(engine)
	fmt.println("[Host] Engine created")

	// Create hot-reload host
	fmt.println("[Host] Creating hot-reload host...")
	host := rl.hot_reload_host_create(LIB_PATH, 0.5)
	defer rl.hot_reload_host_destroy(host)
	fmt.println("[Host] Hot-reload host created")

	// Initial load
	fmt.println("[Host] Loading game library...")
	if !rl.hot_reload_load(host) {
		fmt.println("[Host] Failed to load game library!")
		return
	}
	fmt.println("[Host] Game library loaded")

	// Get API and verify game_state was allocated
	fmt.println("[Host] Getting API...")
	api := rl.hot_reload_get_api(host)
	if api.game_init == nil {
		fmt.println("[Host] game_init not found in library!")
		return
	}
	fmt.println("[Host] API obtained, game_init found")
	
	if host.game_state == nil {
		fmt.println("[Host] Game state not allocated!")
		return
	}
	fmt.println("[Host] Game state allocated")

	// Call game_init
	fmt.println("[Host] Calling game_init...")
	api.game_init(host.game_state, engine)
	fmt.println("[Host] game_init completed")

	// Game loop
	fmt.println("[Host] Entering game loop...")
	for rl.engine_is_running(engine) {
		// Update engine
		if !rl.engine_update(engine) {
			break
		}

		// Check for library changes
		if rl.hot_reload_check(host, engine) {
			api = rl.hot_reload_get_api(host)
		}

		// Update game
		if api.game_update != nil {
			api.game_update(host.game_state, engine, rl.engine_get_delta_time(engine))
		}

		// Render game
		if api.game_render != nil {
			api.game_render(host.game_state, engine)
		}

		rl.engine_render(engine)
	}

	// Shutdown
	fmt.println("[Host] Shutting down...")
	api = rl.hot_reload_get_api(host)
	if api.game_shutdown != nil {
		api.game_shutdown(host.game_state, engine)
	}
}
