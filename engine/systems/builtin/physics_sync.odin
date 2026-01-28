package razorlight_builtin_systems

import ecs "../../../Libraries/yggsECS"
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

	// Sync Box_Collider -> Transform
	for arch in ecs.query(world.ecs, ecs.has(physics.Box_Collider), ecs.has(core.Transform)) {
		colliders := ecs.get_table(world.ecs, arch, physics.Box_Collider)
		transforms := ecs.get_table(world.ecs, arch, core.Transform)

		for i in 0..<len(colliders) {
			pos := physics.physics_get_position(colliders[i].body_id)
			rot := physics.physics_get_rotation(colliders[i].body_id)

			transforms[i].position = pos
			transforms[i].rotation = rot
		}
	}

	// Sync Circle_Collider -> Transform
	for arch in ecs.query(world.ecs, ecs.has(physics.Circle_Collider), ecs.has(core.Transform)) {
		colliders := ecs.get_table(world.ecs, arch, physics.Circle_Collider)
		transforms := ecs.get_table(world.ecs, arch, core.Transform)

		for i in 0..<len(colliders) {
			pos := physics.physics_get_position(colliders[i].body_id)
			rot := physics.physics_get_rotation(colliders[i].body_id)

			transforms[i].position = pos
			transforms[i].rotation = rot
		}
	}

	// Sync Rigidbody -> Transform (if entity has Rigidbody but no collider components)
	for arch in ecs.query(world.ecs, ecs.has(physics.Rigidbody), ecs.has(core.Transform)) {
		bodies := ecs.get_table(world.ecs, arch, physics.Rigidbody)
		transforms := ecs.get_table(world.ecs, arch, core.Transform)

		for i in 0..<len(bodies) {
			pos := physics.physics_get_position(bodies[i].body_id)
			rot := physics.physics_get_rotation(bodies[i].body_id)

			transforms[i].position = pos
			transforms[i].rotation = rot
		}
	}
}
