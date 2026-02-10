package razorlight_physics

import b2 "vendor:box2d"
import "core:math"

// ============================================================================
// Character Body Component — Godot-style kinematic character controller
// ============================================================================
// Uses Box2D's Mover API (capsule-based) for move_and_slide behavior.
// Does NOT create a regular Box2D body — operates independently via geometry queries.

MAX_COLLISION_PLANES :: 8
MAX_SLIDE_ITERATIONS :: 4

// Floor detection threshold: surface normal Y component (physics Y-up)
// Normals pointing upward (Y > threshold) are floors
FLOOR_NORMAL_THRESHOLD :: f32(0.7)   // ~45 degrees
CEILING_NORMAL_THRESHOLD :: f32(-0.7) // ~135 degrees

Character_Body :: struct {
	// Config (user-set)
	width:           f32,       // Capsule width (diameter)
	height:          f32,       // Capsule total height
	max_slope_angle: f32,       // Max walkable slope (radians, default ~45°)

	// Runtime state (read by game code)
	velocity:        [2]f32,    // Screen-space velocity (Y-down)
	is_on_floor:     bool,
	is_on_wall:      bool,
	is_on_ceiling:   bool,
	floor_normal:    [2]f32,    // Screen-space
	wall_normal:     [2]f32,    // Screen-space

	// Internal
	_capsule:        b2.Capsule, // Physics-space capsule geometry
	_initialized:    bool,
}

// ============================================================================
// Initialization
// ============================================================================

// Build the Box2D capsule geometry from width/height at a screen-space position.
// Called automatically when Character_Body + Transform are both present.
character_body_init :: proc(cb: ^Character_Body, screen_pos: [2]f32) {
	if cb._initialized { return }

	phys_pos := screen_to_physics(screen_pos)
	radius := cb.width / 2

	// Capsule is defined by two semicircle centers vertically offset
	// Total height = distance between centers + 2*radius
	// So center distance = height - 2*radius
	half_extent := max((cb.height - cb.width) / 2, 0)

	cb._capsule = b2.Capsule{
		center1 = {phys_pos.x, phys_pos.y - half_extent}, // Bottom semicircle center
		center2 = {phys_pos.x, phys_pos.y + half_extent}, // Top semicircle center
		radius  = radius,
	}

	if cb.max_slope_angle == 0 {
		cb.max_slope_angle = math.PI / 4 // Default 45°
	}

	cb._initialized = true
}

// ============================================================================
// Move and Slide — core movement algorithm
// ============================================================================

// Performs kinematic character movement with collision response.
// Updates cb.velocity, position flags (is_on_floor, etc.), and moves the capsule.
// Returns the new screen-space position.
character_body_move_and_slide :: proc(
	cb: ^Character_Body,
	world_id: b2.WorldId,
	dt: f32,
) -> [2]f32 {
	if !cb._initialized { return {} }

	// Convert velocity to physics space (flip Y)
	phys_vel := b2.Vec2{cb.velocity.x, -cb.velocity.y}

	// Track remaining time for compounding across slide iterations
	remaining_t := dt

	// Desired translation this frame
	delta := b2.Vec2{phys_vel.x * remaining_t, phys_vel.y * remaining_t}

	filter := b2.DefaultQueryFilter()

	// Reset contact flags
	cb.is_on_floor = false
	cb.is_on_wall = false
	cb.is_on_ceiling = false
	cb.floor_normal = {}
	cb.wall_normal = {}

	// Slide loop
	for iter := 0; iter < MAX_SLIDE_ITERATIONS; iter += 1 {
		// Skip if remaining delta is negligible
		len_sq := delta.x * delta.x + delta.y * delta.y
		if len_sq < 1e-6 { break }

		// Cast mover to find earliest collision
		fraction := b2.World_CastMover(world_id, cb._capsule, delta, filter)

		// Move capsule by fraction of delta
		move := b2.Vec2{delta.x * fraction, delta.y * fraction}
		cb._capsule.center1.x += move.x
		cb._capsule.center1.y += move.y
		cb._capsule.center2.x += move.x
		cb._capsule.center2.y += move.y

		// If no collision, we're done
		if fraction >= 1.0 { break }

		// Gather collision planes at new position
		plane_ctx := Plane_Context{
			count = 0,
		}
		b2.World_CollideMover(world_id, cb._capsule, filter, collect_planes, &plane_ctx)

		if plane_ctx.count == 0 { break }

		planes := plane_ctx.planes[:plane_ctx.count]

		// Classify surfaces from plane normals
		for i in 0..<plane_ctx.count {
			normal := planes[i].plane.normal
			// Physics Y-up: positive Y = floor, negative Y = ceiling
			if normal.y >= FLOOR_NORMAL_THRESHOLD {
				cb.is_on_floor = true
				cb.floor_normal = {normal.x, -normal.y} // Convert to screen
			} else if normal.y <= CEILING_NORMAL_THRESHOLD {
				cb.is_on_ceiling = true
			} else {
				cb.is_on_wall = true
				cb.wall_normal = {normal.x, -normal.y} // Convert to screen
			}

			// pushLimit = FLT_MAX (rigid wall) and clipVelocity = true already set in callback
		}

		// Resolve remaining delta against collision planes
		remaining := b2.Vec2{delta.x * (1.0 - fraction), delta.y * (1.0 - fraction)}
		result := b2.SolvePlanes(remaining, planes)

		// Apply solved translation (penetration resolution)
		cb._capsule.center1.x += result.translation.x
		cb._capsule.center1.y += result.translation.y
		cb._capsule.center2.x += result.translation.x
		cb._capsule.center2.y += result.translation.y

		// Clip velocity against planes for next iteration
		phys_vel = b2.ClipVector(phys_vel, planes)

		// Compound remaining time and recompute delta for next slide iteration
		remaining_t *= (1.0 - fraction)
		delta = b2.Vec2{phys_vel.x * remaining_t, phys_vel.y * remaining_t}
	}

	// Always check for surface contacts at final position.
	// This ensures is_on_floor/wall/ceiling are correct even when
	// velocity is zero or parallel to surfaces (no cast collision).
	{
		ground_ctx := Plane_Context{count = 0}
		b2.World_CollideMover(world_id, cb._capsule, filter, collect_planes, &ground_ctx)

		for i in 0..<ground_ctx.count {
			normal := ground_ctx.planes[i].plane.normal
			if normal.y >= FLOOR_NORMAL_THRESHOLD {
				cb.is_on_floor = true
				cb.floor_normal = {normal.x, -normal.y}
			} else if normal.y <= CEILING_NORMAL_THRESHOLD {
				cb.is_on_ceiling = true
			} else {
				cb.is_on_wall = true
				cb.wall_normal = {normal.x, -normal.y}
			}
		}
	}

	// Write clipped velocity back (convert to screen space)
	cb.velocity = {phys_vel.x, -phys_vel.y}

	// Return new screen position from capsule center
	center := b2.Vec2{
		(cb._capsule.center1.x + cb._capsule.center2.x) / 2,
		(cb._capsule.center1.y + cb._capsule.center2.y) / 2,
	}
	return physics_to_screen({center.x, center.y})
}

// ============================================================================
// Collision Plane Collection (callback)
// ============================================================================

@(private)
Plane_Context :: struct {
	planes: [MAX_COLLISION_PLANES]b2.CollisionPlane,
	count:  int,
}

@(private)
collect_planes :: proc "c" (shape_id: b2.ShapeId, plane_result: ^b2.PlaneResult, ctx: rawptr) -> bool {
	pc := cast(^Plane_Context)ctx
	if !plane_result.hit { return true } // Skip non-hits
	if pc.count >= MAX_COLLISION_PLANES { return false } // Full

	pc.planes[pc.count] = b2.CollisionPlane{
		plane        = plane_result.plane,
		pushLimit    = math.F32_MAX,
		push         = 0,
		clipVelocity = true,
	}
	pc.count += 1
	return true // Continue collecting
}

// ============================================================================
// Capsule Position Update (for sync system)
// ============================================================================

// Update capsule position to match a new screen-space position.
// Used when the Transform is moved externally.
character_body_set_position :: proc(cb: ^Character_Body, screen_pos: [2]f32) {
	if !cb._initialized { return }

	phys_pos := screen_to_physics(screen_pos)
	half_extent := max((cb.height - cb.width) / 2, 0)

	cb._capsule.center1 = {phys_pos.x, phys_pos.y - half_extent}
	cb._capsule.center2 = {phys_pos.x, phys_pos.y + half_extent}
}
