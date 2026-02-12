package razorlight_core

import ecs "../libs/yggsECS"
import physics "../physics"

// ============================================================================
// World Container
// ============================================================================

// World contains all game state: ECS entities/components and physics simulation
World :: struct {
	ecs:               ^ecs.World,
	physics:           ^physics.Physics_World,
	animation_registry: ^Animation_Registry,  // Centralized animation storage

	// Coordinate system settings
	y_flip:            bool,           // Box2D Y-up vs Screen Y-down
	pixels_per_meter:  f32,

	// State
	paused:            bool,
}

world_create :: proc(config: Engine_Config) -> ^World {
	world := new(World)

	// Create ECS world
	world.ecs = ecs.create_world()

	// Create physics world
	world.physics = physics.physics_world_create(
		config.gravity,
		config.pixels_per_meter,
		config.physics_substeps,
	)

	world.y_flip = true
	world.pixels_per_meter = config.pixels_per_meter
	world.paused = false
	
	// Create animation registry
	world.animation_registry = animation_registry_create()

	// Register built-in component cleanup callbacks
	world_register_physics_cleanup(world)

	return world
}

world_destroy :: proc(world: ^World) {
	if world == nil {
		return
	}

	physics.physics_world_destroy(world.physics)
	animation_registry_destroy(world.animation_registry)
	ecs.delete_world(world.ecs)
	free(world)
}

// ============================================================================
// Physics Cleanup Callbacks
// ============================================================================

// Register on_remove callbacks for physics components
// This ensures Box2D bodies are destroyed when ECS components are removed
world_register_physics_cleanup :: proc(world: ^World) {
	// Cleanup Rigidbody: destroy body if initialized
	ecs.on_remove(world.ecs, physics.Rigidbody, proc(ptr: rawptr) {
		rb := cast(^physics.Rigidbody)ptr
		if rb._initialized {
			physics.physics_destroy_body(rb._body_id)
		}
	})

	// Cleanup Collider: only destroy body if it owns an implicit static body
	ecs.on_remove(world.ecs, physics.Collider, proc(ptr: rawptr) {
		col := cast(^physics.Collider)ptr
		if col._initialized && col._body_id != {} {
			physics.physics_destroy_body(col._body_id)
		}
	})

	// Character_Body doesn't own a Box2D body (uses Mover API directly),
	// so cleanup is a no-op. Register for consistency.
	ecs.on_remove(world.ecs, physics.Character_Body, proc(ptr: rawptr) {
		// No Box2D body to destroy — capsule geometry is value-type
	})
}

// ============================================================================
// Coordinate Conversion
// ============================================================================

// Convert screen position to physics world position
world_screen_to_physics :: proc(world: ^World, screen_pos: Vec2) -> Vec2 {
	return physics.screen_to_physics(screen_pos)
}

// Convert physics world position to screen position
world_physics_to_screen :: proc(world: ^World, phys_pos: Vec2) -> Vec2 {
	return physics.physics_to_screen(phys_pos)
}

// ============================================================================
// Entity Helpers
// ============================================================================

// Create a new entity
create_entity :: proc(world: ^World) -> ecs.EntityID {
	return ecs.add_entity(world.ecs)
}

// Remove an entity (physics bodies auto-cleaned via callbacks)
remove_entity :: proc(world: ^World, entity: ecs.EntityID) {
	ecs.remove_entity(world.ecs, entity)
}

// Check if entity exists
world_entity_exists :: proc(world: ^World, entity: ecs.EntityID) -> bool {
	return ecs.entity_exists(world.ecs, entity)
}

// ============================================================================
// Auto Physics Initialization
// ============================================================================

// Called when Rigidbody or Collider is added. Checks if all required components
// are present and creates the Box2D body + shape if so.
//
// - Rigidbody + Collider + Transform → creates body of specified type, shape attached
// - Collider + Transform (no Rigidbody) → creates implicit static body
// - Missing any required component → no-op (will init when last piece is added)
try_init_physics :: proc(world: ^World, entity: ecs.EntityID) {
	// Need at least Collider + Transform
	if !ecs.has_component(world.ecs, entity, physics.Collider) { return }
	if !ecs.has_component(world.ecs, entity, Transform) { return }

	col := ecs.get(world.ecs, entity, physics.Collider)
	if col._initialized { return }

	transform := ecs.get(world.ecs, entity, Transform)
	has_rb := ecs.has_component(world.ecs, entity, physics.Rigidbody)

	body_id: physics.BodyId

	if has_rb {
		rb := ecs.get(world.ecs, entity, physics.Rigidbody)
		if rb._initialized { return } // Already done

		// Create body based on Rigidbody type
		switch rb.body_type {
		case .Dynamic:
			body_id = physics.physics_create_dynamic_body(world.physics, transform.position, rb.gravity_scale)
		case .Kinematic:
			body_id = physics.physics_create_kinematic_body(world.physics, transform.position)
		case .Static:
			body_id = physics.physics_create_static_body(world.physics, transform.position)
		}

		if rb.fixed_rotation {
			physics.physics_set_fixed_rotation(body_id, true)
		}

		rb._body_id = body_id
		rb._initialized = true
	} else {
		// No Rigidbody → implicit static body (Bevy convention)
		body_id = physics.physics_create_static_body(world.physics, transform.position)
		col._body_id = body_id  // Collider owns implicit static body
	}

	// Attach shape to body
	switch shape in col.shape {
	case physics.Box:
		col._shape_id = physics.physics_add_box_shape(
			body_id, shape.width / 2, shape.height / 2,
			col.density, col.friction, col.restitution, col.is_sensor,
		)
	case physics.Circle:
		col._shape_id = physics.physics_add_circle_shape(
			body_id, shape.radius,
			col.density, col.friction, col.restitution, col.is_sensor,
		)
	}

	col._initialized = true
}

// ============================================================================
// Auto Character Body Initialization
// ============================================================================

// Called when Character_Body is added. Builds capsule geometry if Transform is also present.
try_init_character_body :: proc(world: ^World, entity: ecs.EntityID) {
	if !ecs.has_component(world.ecs, entity, physics.Character_Body) { return }
	if !ecs.has_component(world.ecs, entity, Transform) { return }

	cb := ecs.get(world.ecs, entity, physics.Character_Body)
	if cb._initialized { return }

	transform := ecs.get(world.ecs, entity, Transform)
	physics.character_body_init(cb, transform.position)
}

// ============================================================================
// Entity-Based Physics Wrappers
// ============================================================================

// Set velocity on an entity's physics body
set_velocity :: proc(world: ^World, entity: ecs.EntityID, velocity: Vec2) {
	body_id, ok := _get_entity_body_id(world, entity)
	if !ok { return }
	physics.physics_set_velocity(body_id, velocity)
}

// Get velocity of an entity's physics body
get_velocity :: proc(world: ^World, entity: ecs.EntityID) -> Vec2 {
	body_id, ok := _get_entity_body_id(world, entity)
	if !ok { return {} }
	return physics.physics_get_velocity(body_id)
}

// Apply force to an entity's physics body
apply_force :: proc(world: ^World, entity: ecs.EntityID, force: Vec2) {
	body_id, ok := _get_entity_body_id(world, entity)
	if !ok { return }
	physics.physics_apply_force(body_id, force)
}

// Apply impulse to an entity's physics body
apply_impulse :: proc(world: ^World, entity: ecs.EntityID, impulse: Vec2) {
	body_id, ok := _get_entity_body_id(world, entity)
	if !ok { return }
	physics.physics_apply_impulse(body_id, impulse)
}

// Set position of an entity's physics body
set_position :: proc(world: ^World, entity: ecs.EntityID, position: Vec2) {
	body_id, ok := _get_entity_body_id(world, entity)
	if !ok { return }
	physics.physics_set_position(body_id, position)
}

// Get position of an entity's physics body
get_position :: proc(world: ^World, entity: ecs.EntityID) -> Vec2 {
	body_id, ok := _get_entity_body_id(world, entity)
	if !ok { return {} }
	return physics.physics_get_position(body_id)
}

// Internal: get body_id from entity (Rigidbody takes priority, then Collider's implicit body)
@(private)
_get_entity_body_id :: proc(world: ^World, entity: ecs.EntityID) -> (physics.BodyId, bool) {
	if ecs.has_component(world.ecs, entity, physics.Rigidbody) {
		rb := ecs.get(world.ecs, entity, physics.Rigidbody)
		if rb._initialized {
			return rb._body_id, true
		}
	}
	if ecs.has_component(world.ecs, entity, physics.Collider) {
		col := ecs.get(world.ecs, entity, physics.Collider)
		if col._initialized && col._body_id != {} {
			return col._body_id, true
		}
	}
	return {}, false
}

// ============================================================================
// Pause/Resume
// ============================================================================

world_pause :: proc(world: ^World) {
	world.paused = true
}

world_resume :: proc(world: ^World) {
	world.paused = false
}

world_is_paused :: proc(world: ^World) -> bool {
	return world.paused
}

world_toggle_pause :: proc(world: ^World) {
	world.paused = !world.paused
}
