package razorlight_builtin_systems

import ecs "../../libs/yggsECS"
import core "../../core"
import physics "../../physics"

// ============================================================================
// Physics Sync System
// ============================================================================

// Step the physics simulation
// This should be registered as a Fixed_Update system
physics_step_system :: proc(world_ptr: rawptr, dt: f32) {
	world := cast(^core.World)world_ptr
	if world.paused {
		return
	}

	physics.physics_world_step(world.physics, dt)
}

// Sync physics body positions/rotations to Transform components
// This should be registered as a Fixed_Update system, running AFTER physics_step_system
physics_sync_system :: proc(world_ptr: rawptr, dt: f32) {
	world := cast(^core.World)world_ptr
	if world.paused {
		return
	}

	// Only Rigidbody entities move (dynamic/kinematic). Static bodies don't need sync.
	// Exclude Character_Body entities — they use their own sync system.
	for arch in ecs.query(world.ecs, ecs.has(physics.Rigidbody), ecs.has(core.Transform), ecs.not(physics.Character_Body)) {
		bodies := ecs.get_table(world.ecs, arch, physics.Rigidbody)
		transforms := ecs.get_table(world.ecs, arch, core.Transform)

		for i in 0..<len(bodies) {
			if !bodies[i]._initialized { continue }
			transforms[i].position = physics.physics_get_position(bodies[i]._body_id)
			transforms[i].rotation = physics.physics_get_rotation(bodies[i]._body_id)
		}
	}
}

// ============================================================================
// Character Body Sync System
// ============================================================================

// Move Character_Body entities using move_and_slide, then write position back to Transform.
// Runs during Fixed_Update, after physics_sync (priority 15).
character_body_sync_system :: proc(world_ptr: rawptr, dt: f32) {
	world := cast(^core.World)world_ptr
	if world.paused {
		return
	}

	world_id := world.physics.world_id

	for arch in ecs.query(world.ecs, ecs.has(physics.Character_Body), ecs.has(core.Transform)) {
		cbs := ecs.get_table(world.ecs, arch, physics.Character_Body)
		transforms := ecs.get_table(world.ecs, arch, core.Transform)

		for i in 0..<len(cbs) {
			if !cbs[i]._initialized { continue }

			// Run move_and_slide — updates velocity, contact flags, and capsule position
			new_pos := physics.character_body_move_and_slide(&cbs[i], world_id, dt)

			// Write back to Transform
			transforms[i].position = new_pos
		}
	}
}
