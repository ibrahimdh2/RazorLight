package razorlight_input

import k2 "../../Libraries/karl2d"

// ============================================================================
// Type Aliases (Re-export from karl2d)
// ============================================================================

Keyboard_Key :: k2.Keyboard_Key
Mouse_Button :: k2.Mouse_Button
Gamepad_Button :: k2.Gamepad_Button
Gamepad_Axis :: k2.Gamepad_Axis
Gamepad_Index :: k2.Gamepad_Index

// ============================================================================
// Input State
// ============================================================================

Input_State :: struct {
	// Current frame mouse state
	mouse_position:   [2]f32,
	mouse_delta:      [2]f32,
	mouse_wheel:      f32,

	// Action mappings
	action_bindings:  map[string]Action_Binding,
}

Action_Binding :: struct {
	keys:            [dynamic]Keyboard_Key,
	mouse_buttons:   [dynamic]Mouse_Button,
	gamepad_buttons: [dynamic]Gamepad_Button,
}

// ============================================================================
// Lifecycle
// ============================================================================

input_create :: proc() -> ^Input_State {
	is := new(Input_State)
	is.action_bindings = make(map[string]Action_Binding)
	return is
}

input_destroy :: proc(is: ^Input_State) {
	if is == nil {
		return
	}

	for _, binding in is.action_bindings {
		delete(binding.keys)
		delete(binding.mouse_buttons)
		delete(binding.gamepad_buttons)
	}
	delete(is.action_bindings)
	free(is)
}

// Update input state (call once per frame before processing input)
input_update :: proc(is: ^Input_State) {
	pos := k2.get_mouse_position()
	is.mouse_position = {pos.x, pos.y}

	delta := k2.get_mouse_delta()
	is.mouse_delta = {delta.x, delta.y}

	is.mouse_wheel = k2.get_mouse_wheel_delta()
}

// ============================================================================
// Action Binding
// ============================================================================

// Bind keys to an action
input_bind_keys :: proc(is: ^Input_State, action: string, keys: ..Keyboard_Key) {
	binding := &is.action_bindings[action]
	if binding.keys == nil {
		binding.keys = make([dynamic]Keyboard_Key)
	}
	for key in keys {
		append(&binding.keys, key)
	}
}

// Bind mouse buttons to an action
input_bind_mouse :: proc(is: ^Input_State, action: string, buttons: ..Mouse_Button) {
	binding := &is.action_bindings[action]
	if binding.mouse_buttons == nil {
		binding.mouse_buttons = make([dynamic]Mouse_Button)
	}
	for btn in buttons {
		append(&binding.mouse_buttons, btn)
	}
}

// Bind gamepad buttons to an action
input_bind_gamepad :: proc(is: ^Input_State, action: string, buttons: ..Gamepad_Button) {
	binding := &is.action_bindings[action]
	if binding.gamepad_buttons == nil {
		binding.gamepad_buttons = make([dynamic]Gamepad_Button)
	}
	for btn in buttons {
		append(&binding.gamepad_buttons, btn)
	}
}

// Clear all bindings for an action
input_clear_bindings :: proc(is: ^Input_State, action: string) {
	if binding, ok := &is.action_bindings[action]; ok {
		clear(&binding.keys)
		clear(&binding.mouse_buttons)
		clear(&binding.gamepad_buttons)
	}
}

// ============================================================================
// Action Queries
// ============================================================================

// Check if an action is currently held
input_is_action_held :: proc(is: ^Input_State, action: string) -> bool {
	binding, ok := is.action_bindings[action]
	if !ok {
		return false
	}

	for key in binding.keys {
		if k2.key_is_held(key) {
			return true
		}
	}

	for btn in binding.mouse_buttons {
		if k2.mouse_button_is_held(btn) {
			return true
		}
	}

	for btn in binding.gamepad_buttons {
		if k2.gamepad_button_is_held(0, btn) {
			return true
		}
	}

	return false
}

// Check if an action was just pressed this frame
input_is_action_pressed :: proc(is: ^Input_State, action: string) -> bool {
	binding, ok := is.action_bindings[action]
	if !ok {
		return false
	}

	for key in binding.keys {
		if k2.key_went_down(key) {
			return true
		}
	}

	for btn in binding.mouse_buttons {
		if k2.mouse_button_went_down(btn) {
			return true
		}
	}

	for btn in binding.gamepad_buttons {
		if k2.gamepad_button_went_down(0, btn) {
			return true
		}
	}

	return false
}

// Check if an action was just released this frame
input_is_action_released :: proc(is: ^Input_State, action: string) -> bool {
	binding, ok := is.action_bindings[action]
	if !ok {
		return false
	}

	for key in binding.keys {
		if k2.key_went_up(key) {
			return true
		}
	}

	for btn in binding.mouse_buttons {
		if k2.mouse_button_went_up(btn) {
			return true
		}
	}

	for btn in binding.gamepad_buttons {
		if k2.gamepad_button_went_up(0, btn) {
			return true
		}
	}

	return false
}

// ============================================================================
// Direct Key/Mouse Queries (passthrough to karl2d)
// ============================================================================

input_key_held :: proc(key: Keyboard_Key) -> bool {
	return k2.key_is_held(key)
}

input_key_pressed :: proc(key: Keyboard_Key) -> bool {
	return k2.key_went_down(key)
}

input_key_released :: proc(key: Keyboard_Key) -> bool {
	return k2.key_went_up(key)
}

input_mouse_held :: proc(button: Mouse_Button) -> bool {
	return k2.mouse_button_is_held(button)
}

input_mouse_pressed :: proc(button: Mouse_Button) -> bool {
	return k2.mouse_button_went_down(button)
}

input_mouse_released :: proc(button: Mouse_Button) -> bool {
	return k2.mouse_button_went_up(button)
}

// ============================================================================
// Mouse Queries
// ============================================================================

input_get_mouse_position :: proc(is: ^Input_State) -> [2]f32 {
	return is.mouse_position
}

input_get_mouse_delta :: proc(is: ^Input_State) -> [2]f32 {
	return is.mouse_delta
}

input_get_mouse_wheel :: proc(is: ^Input_State) -> f32 {
	return is.mouse_wheel
}

// ============================================================================
// Gamepad Queries
// ============================================================================

input_gamepad_active :: proc(gamepad: Gamepad_Index = 0) -> bool {
	return k2.is_gamepad_active(gamepad)
}

input_gamepad_button_held :: proc(button: Gamepad_Button, gamepad: Gamepad_Index = 0) -> bool {
	return k2.gamepad_button_is_held(gamepad, button)
}

input_gamepad_button_pressed :: proc(button: Gamepad_Button, gamepad: Gamepad_Index = 0) -> bool {
	return k2.gamepad_button_went_down(gamepad, button)
}

input_gamepad_button_released :: proc(button: Gamepad_Button, gamepad: Gamepad_Index = 0) -> bool {
	return k2.gamepad_button_went_up(gamepad, button)
}

input_gamepad_axis :: proc(axis: Gamepad_Axis, gamepad: Gamepad_Index = 0) -> f32 {
	return k2.get_gamepad_axis(gamepad, axis)
}

input_gamepad_set_vibration :: proc(left, right: f32, gamepad: Gamepad_Index = 0) {
	k2.set_gamepad_vibration(gamepad, left, right)
}

// ============================================================================
// Axis Helpers
// ============================================================================

// Get movement vector from WASD/Arrow keys
input_get_movement_vector :: proc() -> [2]f32 {
	x: f32 = 0
	y: f32 = 0

	if k2.key_is_held(.A) || k2.key_is_held(.Left) {
		x -= 1
	}
	if k2.key_is_held(.D) || k2.key_is_held(.Right) {
		x += 1
	}
	if k2.key_is_held(.W) || k2.key_is_held(.Up) {
		y -= 1
	}
	if k2.key_is_held(.S) || k2.key_is_held(.Down) {
		y += 1
	}

	return {x, y}
}

// Get gamepad left stick as a vector
input_get_gamepad_left_stick :: proc(gamepad: Gamepad_Index = 0) -> [2]f32 {
	return {
		k2.get_gamepad_axis(gamepad, .Left_Stick_X),
		k2.get_gamepad_axis(gamepad, .Left_Stick_Y),
	}
}

// Get gamepad right stick as a vector
input_get_gamepad_right_stick :: proc(gamepad: Gamepad_Index = 0) -> [2]f32 {
	return {
		k2.get_gamepad_axis(gamepad, .Right_Stick_X),
		k2.get_gamepad_axis(gamepad, .Right_Stick_Y),
	}
}
