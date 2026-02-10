package razorlight_core

// ============================================================================
// Hot-Reload Interface Types
// ============================================================================
// These define the contract between the host application and game library.
// The game library must export these functions with @(export) and proc "c".

// Function signatures the game library must export
Game_Init_Proc       :: #type proc "c" (state: rawptr, engine: rawptr)
Game_Update_Proc     :: #type proc "c" (state: rawptr, engine: rawptr, dt: f32)
Game_Render_Proc     :: #type proc "c" (state: rawptr, engine: rawptr)
Game_Shutdown_Proc   :: #type proc "c" (state: rawptr, engine: rawptr)
Game_On_Reload_Proc  :: #type proc "c" (state: rawptr, engine: rawptr)
Game_State_Size_Proc :: #type proc "c" () -> int

// Collected game API function pointers
Game_API :: struct {
	game_init:       Game_Init_Proc,
	game_update:     Game_Update_Proc,
	game_render:     Game_Render_Proc,
	game_shutdown:   Game_Shutdown_Proc,
	game_on_reload:  Game_On_Reload_Proc,
	game_state_size: Game_State_Size_Proc,
}
