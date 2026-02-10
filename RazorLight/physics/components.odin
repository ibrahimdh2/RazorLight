package razorlight_physics

import b2 "vendor:box2d"

// Re-export b2 types for external use
BodyId :: b2.BodyId

// ============================================================================
// Physics Components
// ============================================================================

// Body type enum
Body_Type :: enum {
	Static,      // Does not move (walls, ground)
	Kinematic,   // Moves but not affected by forces (platforms)
	Dynamic,     // Fully simulated (players, enemies, projectiles)
}

// Rigidbody component - owns the Box2D body
Rigidbody :: struct {
	body_type:      Body_Type,
	gravity_scale:  f32,
	fixed_rotation: bool,
	// Internal (set by engine)
	_body_id:       b2.BodyId,
	_initialized:   bool,
}

// Shape types for Collider union
Box :: struct { width, height: f32 }
Circle :: struct { radius: f32 }
Collider_Shape :: union { Box, Circle }

// Unified Collider component - replaces Box_Collider and Circle_Collider
Collider :: struct {
	shape:       Collider_Shape,
	offset:      [2]f32,
	density:     f32,
	friction:    f32,
	restitution: f32,
	is_sensor:   bool,
	// Internal (set by engine)
	_shape_id:    b2.ShapeId,
	_body_id:     b2.BodyId,     // Only used when no Rigidbody exists (implicit static)
	_initialized: bool,
}

// ============================================================================
// Collision Data (for events/queries)
// ============================================================================

Collision_Info :: struct {
	other_body:    b2.BodyId,
	contact_point: [2]f32,
	normal:        [2]f32,
	impulse:       f32,
}

// ============================================================================
// Helper Functions
// ============================================================================

body_type_to_b2 :: proc(bt: Body_Type) -> b2.BodyType {
	switch bt {
	case .Static:    return .staticBody
	case .Kinematic: return .kinematicBody
	case .Dynamic:   return .dynamicBody
	}
	return .dynamicBody
}

b2_to_body_type :: proc(bt: b2.BodyType) -> Body_Type {
	switch bt {
	case .staticBody:    return .Static
	case .kinematicBody: return .Kinematic
	case .dynamicBody:   return .Dynamic
	}
	return .Dynamic
}

// Get the body_id for a collider (from Rigidbody if present, otherwise implicit static)
collider_get_body_id :: proc(col: ^Collider, rb: ^Rigidbody) -> b2.BodyId {
	if rb != nil && rb._initialized {
		return rb._body_id
	}
	return col._body_id
}
