package razorlight_core

import ecs "../../Libraries/yggsECS"
import physics "../physics"

// ============================================================================
// World Container
// ============================================================================

// World contains all game state: ECS entities/components and physics simulation
World :: struct {
	ecs:              ^ecs.World,
	physics:          ^physics.Physics_World,

	// Coordinate system settings
	y_flip:           bool,           // Box2D Y-up vs Screen Y-down
	pixels_per_meter: f32,

	// State
	paused:           bool,
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

	// Register built-in component cleanup callbacks
	world_register_physics_cleanup(world)

	return world
}

world_destroy :: proc(world: ^World) {
	if world == nil {
		return
	}

	physics.physics_world_destroy(world.physics)
	ecs.delete_world(world.ecs)
	free(world)
}

// ============================================================================
// Physics Cleanup Callbacks
// ============================================================================

// Register on_remove callbacks for physics components
// This ensures Box2D bodies are destroyed when ECS components are removed
world_register_physics_cleanup :: proc(world: ^World) {
	// Cleanup Rigidbody components
	ecs.on_remove(world.ecs, physics.Rigidbody, proc(ptr: rawptr) {
		rb := cast(^physics.Rigidbody)ptr
		physics.physics_destroy_body(rb.body_id)
	})

	// Cleanup Box_Collider components
	ecs.on_remove(world.ecs, physics.Box_Collider, proc(ptr: rawptr) {
		col := cast(^physics.Box_Collider)ptr
		physics.physics_destroy_body(col.body_id)
	})

	// Cleanup Circle_Collider components
	ecs.on_remove(world.ecs, physics.Circle_Collider, proc(ptr: rawptr) {
		col := cast(^physics.Circle_Collider)ptr
		physics.physics_destroy_body(col.body_id)
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
world_create_entity :: proc(world: ^World) -> ecs.EntityID {
	return ecs.add_entity(world.ecs)
}

// Remove an entity (physics bodies auto-cleaned via callbacks)
world_remove_entity :: proc(world: ^World, entity: ecs.EntityID) {
	ecs.remove_entity(world.ecs, entity)
}

// Check if entity exists
world_entity_exists :: proc(world: ^World, entity: ecs.EntityID) -> bool {
	return ecs.entity_exists(world.ecs, entity)
}

// ============================================================================
// Component Helpers
// ============================================================================

// Add a component to an entity
world_add_component :: proc(world: ^World, entity: ecs.EntityID, component: $T) {
	ecs.add_component(world.ecs, entity, component)
}

// Get a component from an entity
world_get_component :: proc(world: ^World, entity: ecs.EntityID, $T: typeid) -> ^T {
	return ecs.get(world.ecs, entity, T)
}

// Check if entity has a component
world_has_component :: proc(world: ^World, entity: ecs.EntityID, $T: typeid) -> bool {
	return ecs.has_component(world.ecs, entity, T)
}

// Remove a component from an entity
world_remove_component :: proc(world: ^World, entity: ecs.EntityID, $T: typeid) {
	ecs.remove_component(world.ecs, entity, T)
}

// ============================================================================
// Physics Body Creation Helpers
// ============================================================================

// Create a dynamic physics entity with a box collider
world_create_physics_box :: proc(
	world: ^World,
	position: Vec2,
	width, height: f32,
	density: f32 = 1.0,
	friction: f32 = 0.3,
) -> ecs.EntityID {
	entity := ecs.add_entity(world.ecs)

	// Add Transform
	ecs.add_component(world.ecs, entity, Transform{
		position = position,
		scale = {1, 1},
	})

	// Create physics body
	body_id := physics.physics_create_dynamic_body(world.physics, position)
	physics.physics_add_box_shape(body_id, width/2, height/2, density, friction)

	// Add physics component
	ecs.add_component(world.ecs, entity, physics.Box_Collider{
		body_id = body_id,
		width = width,
		height = height,
		density = density,
		friction = friction,
	})

	return entity
}

// Create a dynamic physics entity with a circle collider
world_create_physics_circle :: proc(
	world: ^World,
	position: Vec2,
	radius: f32,
	density: f32 = 1.0,
	friction: f32 = 0.3,
) -> ecs.EntityID {
	entity := ecs.add_entity(world.ecs)

	// Add Transform
	ecs.add_component(world.ecs, entity, Transform{
		position = position,
		scale = {1, 1},
	})

	// Create physics body
	body_id := physics.physics_create_dynamic_body(world.physics, position)
	physics.physics_add_circle_shape(body_id, radius, density, friction)

	// Add physics component
	ecs.add_component(world.ecs, entity, physics.Circle_Collider{
		body_id = body_id,
		radius = radius,
		density = density,
		friction = friction,
	})

	return entity
}

// Create a static physics entity (walls, ground, etc.)
world_create_static_box :: proc(
	world: ^World,
	position: Vec2,
	width, height: f32,
) -> ecs.EntityID {
	entity := ecs.add_entity(world.ecs)

	// Add Transform
	ecs.add_component(world.ecs, entity, Transform{
		position = position,
		scale = {1, 1},
	})

	// Create static physics body
	body_id := physics.physics_create_static_body(world.physics, position)
	physics.physics_add_box_shape(body_id, width/2, height/2)

	// Add physics component
	ecs.add_component(world.ecs, entity, physics.Box_Collider{
		body_id = body_id,
		width = width,
		height = height,
	})

	return entity
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
