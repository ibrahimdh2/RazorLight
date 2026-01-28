package razorlight_physics

import b2 "vendor:box2d"
import "core:math"

// ============================================================================
// Physics World
// ============================================================================

Physics_World :: struct {
	world_id:         b2.WorldId,
	pixels_per_meter: f32,
	gravity:          [2]f32,
	substeps:         i32,

	// Debug settings
	debug_draw:       bool,
	draw_colliders:   bool,
	draw_velocities:  bool,
	draw_contacts:    bool,
}

physics_world_create :: proc(gravity: [2]f32, pixels_per_meter: f32 = 40, substeps: i32 = 4) -> ^Physics_World {
	pw := new(Physics_World)

	b2.SetLengthUnitsPerMeter(pixels_per_meter)

	world_def := b2.DefaultWorldDef()
	// Note: Box2D uses Y-up, so we negate Y for screen coordinates
	world_def.gravity = b2.Vec2{gravity.x, -gravity.y}
	pw.world_id = b2.CreateWorld(world_def)

	pw.pixels_per_meter = pixels_per_meter
	pw.gravity = gravity
	pw.substeps = substeps

	pw.debug_draw = false
	pw.draw_colliders = true
	pw.draw_velocities = true

	return pw
}

physics_world_destroy :: proc(pw: ^Physics_World) {
	if pw != nil {
		b2.DestroyWorld(pw.world_id)
		free(pw)
	}
}

// Step the physics simulation
physics_world_step :: proc(pw: ^Physics_World, dt: f32) {
	b2.World_Step(pw.world_id, dt, pw.substeps)
}

// ============================================================================
// Body Creation
// ============================================================================

// Create a dynamic body at screen position
physics_create_dynamic_body :: proc(pw: ^Physics_World, screen_pos: [2]f32, gravity_scale: f32 = 1.0) -> b2.BodyId {
	body_def := b2.DefaultBodyDef()
	body_def.type = .dynamicBody
	body_def.position = screen_to_physics(screen_pos)
	body_def.gravityScale = gravity_scale
	return b2.CreateBody(pw.world_id, body_def)
}

// Create a static body at screen position
physics_create_static_body :: proc(pw: ^Physics_World, screen_pos: [2]f32) -> b2.BodyId {
	body_def := b2.DefaultBodyDef()
	body_def.type = .staticBody
	body_def.position = screen_to_physics(screen_pos)
	return b2.CreateBody(pw.world_id, body_def)
}

// Create a kinematic body at screen position
physics_create_kinematic_body :: proc(pw: ^Physics_World, screen_pos: [2]f32) -> b2.BodyId {
	body_def := b2.DefaultBodyDef()
	body_def.type = .kinematicBody
	body_def.position = screen_to_physics(screen_pos)
	return b2.CreateBody(pw.world_id, body_def)
}

// ============================================================================
// Shape Creation
// ============================================================================

// Add a box shape to a body
physics_add_box_shape :: proc(
	body_id: b2.BodyId,
	half_width, half_height: f32,
	density: f32 = 1.0,
	friction: f32 = 0.3,
	restitution: f32 = 0.0,
	is_sensor: bool = false,
) -> b2.ShapeId {
	shape_def := b2.DefaultShapeDef()
	shape_def.density = density
	shape_def.material.friction = friction
	shape_def.material.restitution = restitution
	shape_def.isSensor = is_sensor

	box := b2.MakeBox(half_width, half_height)
	return b2.CreatePolygonShape(body_id, shape_def, box)
}

// Add a circle shape to a body
physics_add_circle_shape :: proc(
	body_id: b2.BodyId,
	radius: f32,
	density: f32 = 1.0,
	friction: f32 = 0.3,
	restitution: f32 = 0.0,
	is_sensor: bool = false,
) -> b2.ShapeId {
	shape_def := b2.DefaultShapeDef()
	shape_def.density = density
	shape_def.material.friction = friction
	shape_def.material.restitution = restitution
	shape_def.isSensor = is_sensor

	circle: b2.Circle
	circle.radius = radius
	return b2.CreateCircleShape(body_id, shape_def, circle)
}

// ============================================================================
// Body Accessors
// ============================================================================

// Get body position in screen coordinates
physics_get_position :: proc(body_id: b2.BodyId) -> [2]f32 {
	pos := b2.Body_GetPosition(body_id)
	return physics_to_screen({pos.x, pos.y})
}

// Get body rotation in radians
physics_get_rotation :: proc(body_id: b2.BodyId) -> f32 {
	r := b2.Body_GetRotation(body_id)
	return math.atan2(r.s, r.c)
}

// Get body linear velocity in screen coordinates
physics_get_velocity :: proc(body_id: b2.BodyId) -> [2]f32 {
	vel := b2.Body_GetLinearVelocity(body_id)
	return {vel.x, -vel.y}  // Flip Y for screen coords
}

// Get body angular velocity
physics_get_angular_velocity :: proc(body_id: b2.BodyId) -> f32 {
	return b2.Body_GetAngularVelocity(body_id)
}

// ============================================================================
// Body Mutators
// ============================================================================

// Set body transform (position in screen coords, rotation in radians)
physics_set_transform :: proc(body_id: b2.BodyId, screen_pos: [2]f32, rotation: f32 = 0) {
	phys_pos := screen_to_physics(screen_pos)
	rot := b2.Rot{math.sin(rotation), math.cos(rotation)}
	b2.Body_SetTransform(body_id, b2.Vec2{phys_pos.x, phys_pos.y}, rot)
}

// Set body position (screen coords)
physics_set_position :: proc(body_id: b2.BodyId, screen_pos: [2]f32) {
	phys_pos := screen_to_physics(screen_pos)
	rot := b2.Body_GetRotation(body_id)
	b2.Body_SetTransform(body_id, b2.Vec2{phys_pos.x, phys_pos.y}, rot)
}

// Set linear velocity (screen coords)
physics_set_velocity :: proc(body_id: b2.BodyId, velocity: [2]f32) {
	b2.Body_SetLinearVelocity(body_id, b2.Vec2{velocity.x, -velocity.y})
}

// Set angular velocity
physics_set_angular_velocity :: proc(body_id: b2.BodyId, omega: f32) {
	b2.Body_SetAngularVelocity(body_id, omega)
}

// Apply force at center of mass
physics_apply_force :: proc(body_id: b2.BodyId, force: [2]f32) {
	b2.Body_ApplyForceToCenter(body_id, b2.Vec2{force.x, -force.y}, true)
}

// Apply impulse at center of mass
physics_apply_impulse :: proc(body_id: b2.BodyId, impulse: [2]f32) {
	b2.Body_ApplyLinearImpulseToCenter(body_id, b2.Vec2{impulse.x, -impulse.y}, true)
}

// Set gravity scale
physics_set_gravity_scale :: proc(body_id: b2.BodyId, scale: f32) {
	b2.Body_SetGravityScale(body_id, scale)
}

// Set fixed rotation
physics_set_fixed_rotation :: proc(body_id: b2.BodyId, fixed: bool) {
	b2.Body_SetFixedRotation(body_id, fixed)
}

// Destroy a body
physics_destroy_body :: proc(body_id: b2.BodyId) {
	b2.DestroyBody(body_id)
}

// ============================================================================
// Coordinate Conversion (Screen <-> Physics)
// ============================================================================

// Screen coordinates: Y-down (0 at top, positive going down)
// Physics coordinates: Y-up (0 at bottom, positive going up)

screen_to_physics :: proc(screen_pos: [2]f32) -> [2]f32 {
	return {screen_pos.x, -screen_pos.y}
}

physics_to_screen :: proc(phys_pos: [2]f32) -> [2]f32 {
	return {phys_pos.x, -phys_pos.y}
}

// ============================================================================
// Raycasting
// ============================================================================

Raycast_Hit :: struct {
	hit:      bool,
	point:    [2]f32,
	normal:   [2]f32,
	fraction: f32,
	body_id:  b2.BodyId,
}

// Cast a ray from start to end (screen coordinates)
physics_raycast :: proc(pw: ^Physics_World, start, end: [2]f32) -> Raycast_Hit {
	origin := b2.Vec2{start.x, -start.y}
	translation := b2.Vec2{end.x - start.x, -(end.y - start.y)}

	filter := b2.DefaultQueryFilter()
	result := b2.World_CastRayClosest(pw.world_id, origin, translation, filter)

	if result.hit {
		return Raycast_Hit{
			hit      = true,
			point    = physics_to_screen({result.point.x, result.point.y}),
			normal   = {result.normal.x, -result.normal.y},
			fraction = result.fraction,
			body_id  = b2.Shape_GetBody(result.shapeId),
		}
	}

	return Raycast_Hit{hit = false}
}
