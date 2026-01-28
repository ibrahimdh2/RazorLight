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

// Rigidbody component - represents a physics body
Rigidbody :: struct {
	body_id:       b2.BodyId,
	body_type:     Body_Type,

	// Cached properties (avoid Box2D calls for common reads)
	mass:          f32,
	gravity_scale: f32,
	fixed_rotation: bool,
}

DEFAULT_RIGIDBODY :: Rigidbody {
	body_type     = .Dynamic,
	mass          = 1.0,
	gravity_scale = 1.0,
	fixed_rotation = false,
}

// Box collider component
Box_Collider :: struct {
	body_id:  b2.BodyId,
	width:    f32,
	height:   f32,
	offset:   [2]f32,     // Offset from entity center

	// Physics material
	density:     f32,
	friction:    f32,
	restitution: f32,      // Bounciness
	is_sensor:   bool,     // Triggers events but no collision response
}

DEFAULT_BOX_COLLIDER :: Box_Collider {
	width       = 32,
	height      = 32,
	offset      = {0, 0},
	density     = 1.0,
	friction    = 0.3,
	restitution = 0.0,
	is_sensor   = false,
}

// Circle collider component
Circle_Collider :: struct {
	body_id:  b2.BodyId,
	radius:   f32,
	offset:   [2]f32,     // Offset from entity center

	// Physics material
	density:     f32,
	friction:    f32,
	restitution: f32,
	is_sensor:   bool,
}

DEFAULT_CIRCLE_COLLIDER :: Circle_Collider {
	radius      = 16,
	offset      = {0, 0},
	density     = 1.0,
	friction    = 0.3,
	restitution = 0.0,
	is_sensor   = false,
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
