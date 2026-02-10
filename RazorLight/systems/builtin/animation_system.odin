package razorlight_builtin_systems

import ecs "../../libs/yggsECS"
import core "../../core"

// ============================================================================
// Animation Update System
// ============================================================================

// Updates all Animation_Components each frame.
// Registered in the Update phase, priority 90 (after user game logic).
animation_update_system :: proc(world_ptr: rawptr, dt: f32) {
	world := cast(^core.World)world_ptr

	for arch in ecs.query(world.ecs, ecs.has(core.Animation_Component)) {
		anims := ecs.get_table(world.ecs, arch, core.Animation_Component)

		for i in 0..<len(anims) {
			core.animation_update(&anims[i], dt)
		}
	}
}
