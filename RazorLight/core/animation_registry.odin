package razorlight_core

// ============================================================================
// Animation Registry
// ============================================================================
// Provides centralized storage for Animation_Sets with stable handles.
// This eliminates the need for pointers in Animation_Component.

Animation_Registry :: struct {
	sets:         [dynamic]Animation_Set_Entry,
	free_indices: [dynamic]u32,  // For handle reuse
}

Animation_Set_Entry :: struct {
	set:      Animation_Set,
	in_use:   bool,
	version:  u32,  // For debugging handle validity
}

// Create a new animation registry
animation_registry_create :: proc() -> ^Animation_Registry {
	reg := new(Animation_Registry)
	reg.sets = make([dynamic]Animation_Set_Entry, 0, 16)
	reg.free_indices = make([dynamic]u32, 0, 8)
	return reg
}

// Destroy the animation registry and all stored animation sets
animation_registry_destroy :: proc(reg: ^Animation_Registry) {
	if reg == nil {
		return
	}
	
	// Clean up all animation sets
	for &entry in reg.sets {
		if entry.in_use {
			animation_set_cleanup(&entry.set)
		}
	}
	
	delete(reg.sets)
	delete(reg.free_indices)
	free(reg)
}

// Register an animation set and get a stable handle to it
animation_registry_register :: proc(reg: ^Animation_Registry, set: Animation_Set) -> Animation_Set_Handle {
	// Reuse a free index if available
	if len(reg.free_indices) > 0 {
		idx := pop(&reg.free_indices)
		reg.sets[idx] = Animation_Set_Entry{
			set     = set,
			in_use  = true,
			version = reg.sets[idx].version + 1,
		}
		return Animation_Set_Handle((u32(idx) << 16) | (reg.sets[idx].version & 0xFFFF))
	}
	
	// Allocate new entry
	idx := len(reg.sets)
	append(&reg.sets, Animation_Set_Entry{
		set     = set,
		in_use  = true,
		version = 1,
	})
	
	// Handle format: upper 16 bits = index, lower 16 bits = version
	return Animation_Set_Handle((u32(idx) << 16) | 1)
}

// Unregister an animation set (frees the handle for reuse)
animation_registry_unregister :: proc(reg: ^Animation_Registry, handle: Animation_Set_Handle) {
	idx := animation_handle_index(handle)
	if idx < 0 || idx >= len(reg.sets) {
		return
	}
	
	entry := &reg.sets[idx]
	if !entry.in_use || entry.version != animation_handle_version(handle) {
		return  // Handle is invalid or stale
	}
	
	// Clean up the animation set
	animation_set_cleanup(&entry.set)
	entry.in_use = false
	append(&reg.free_indices, u32(idx))
}

// Get an animation set by handle (returns nil if invalid)
animation_registry_get :: proc(reg: ^Animation_Registry, handle: Animation_Set_Handle) -> ^Animation_Set {
	idx := animation_handle_index(handle)
	if idx < 0 || idx >= len(reg.sets) {
		return nil
	}
	
	entry := &reg.sets[idx]
	if !entry.in_use || entry.version != animation_handle_version(handle) {
		return nil  // Stale or invalid handle
	}
	
	return &entry.set
}

// Get a specific animation from a set by name
animation_registry_get_anim :: proc(reg: ^Animation_Registry, handle: Animation_Set_Handle, anim_name: string) -> ^Animation {
	set := animation_registry_get(reg, handle)
	if set == nil {
		return nil
	}
	
	anim, ok := &set.animations[anim_name]
	if !ok {
		return nil
	}
	
	return anim
}

// Check if a handle is valid
animation_registry_is_valid :: proc(reg: ^Animation_Registry, handle: Animation_Set_Handle) -> bool {
	return animation_registry_get(reg, handle) != nil
}

// Helper: extract index from handle
@(private)
animation_handle_index :: proc(handle: Animation_Set_Handle) -> int {
	return int(u32(handle) >> 16)
}

// Helper: extract version from handle
@(private)
animation_handle_version :: proc(handle: Animation_Set_Handle) -> u32 {
	return u32(handle) & 0xFFFF
}

// Clean up an Animation_Set's internal data
@(private)
animation_set_cleanup :: proc(set: ^Animation_Set) {
	delete(set.animations)
	// Note: name and texture are not owned by the set
}
