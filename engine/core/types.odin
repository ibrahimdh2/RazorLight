package razorlight_core

import k2 "../../Libraries/karl2d"
import "core:math"

// ============================================================================
// Common Type Aliases
// ============================================================================

Vec2 :: [2]f32
Vec3 :: [3]f32
Color :: k2.Color

// Re-export karl2d colors for convenience
WHITE       :: k2.WHITE
BLACK       :: k2.BLACK
RED         :: k2.RED
GREEN       :: k2.GREEN
BLUE        :: k2.BLUE
YELLOW      :: k2.YELLOW
ORANGE      :: k2.ORANGE
PURPLE      :: k2.PURPLE
MAGENTA     :: k2.MAGENTA
LIGHT_BLUE  :: k2.LIGHT_BLUE
LIGHT_GREEN :: k2.LIGHT_GREEN
LIGHT_GRAY  :: k2.RL_LIGHTGRAY
DARK_GRAY   :: k2.DARK_GRAY
PINK        :: k2.RL_PINK
CYAN        :: Color{0, 255, 255, 255}

// ============================================================================
// Transform Component
// ============================================================================

Transform :: struct {
	position: Vec2,
	rotation: f32,      // Radians
	scale:    Vec2,
}

DEFAULT_TRANSFORM :: Transform {
	position = {0, 0},
	rotation = 0,
	scale    = {1, 1},
}

// ============================================================================
// Sprite Component
// ============================================================================

Sprite_Component :: struct {
	texture:  k2.Texture,
	color:    Color,         // Tint color
	flip_x:   bool,
	flip_y:   bool,
	origin:   Vec2,          // Normalized origin (0-1), 0.5 = center
	layer:    i32,           // Render order (higher = on top)
	visible:  bool,
}

DEFAULT_SPRITE :: Sprite_Component {
	color   = WHITE,
	origin  = {0.5, 0.5},
	layer   = 0,
	visible = true,
}

// Simple colored shape (no texture)
Shape_Component :: struct {
	shape_type: Shape_Type,
	color:      Color,
	size:       Vec2,       // For rect: width/height, for circle: radius in x
	layer:      i32,
	visible:    bool,
}

Shape_Type :: enum {
	Rectangle,
	Circle,
}

DEFAULT_SHAPE :: Shape_Component {
	shape_type = .Rectangle,
	color      = WHITE,
	size       = {32, 32},
	layer      = 0,
	visible    = true,
}

// ============================================================================
// Engine Configuration
// ============================================================================

Engine_Config :: struct {
	window_width:      i32,
	window_height:     i32,
	window_title:      string,
	fixed_timestep:    f32,       // Default: 1.0/60.0
	physics_substeps:  i32,       // Default: 4
	gravity:           Vec2,      // Default: {0, 900} (Y-down screen coords)
	pixels_per_meter:  f32,       // Default: 40
	clear_color:       Color,     // Default: LIGHT_BLUE
}

DEFAULT_ENGINE_CONFIG :: Engine_Config {
	window_width     = 1280,
	window_height    = 720,
	window_title     = "RazorLight Game",
	fixed_timestep   = 1.0 / 60.0,
	physics_substeps = 4,
	gravity          = {0, 900},   // Positive Y = down in screen coords
	pixels_per_meter = 40,
	clear_color      = LIGHT_BLUE,
}

// ============================================================================
// Resource Handles
// ============================================================================

Texture_Handle :: distinct u32
INVALID_TEXTURE :: Texture_Handle(0)

// ============================================================================
// Tag Components (Zero-size markers)
// ============================================================================

// These are meant to be extended by games
// Example game-specific tags would go in game code

// ============================================================================
// Utility Functions
// ============================================================================

// Create a color with alpha
color_alpha :: proc(c: Color, alpha: u8) -> Color {
	return Color{c.r, c.g, c.b, alpha}
}

// Lerp between two vectors
vec2_lerp :: proc(a, b: Vec2, t: f32) -> Vec2 {
	return Vec2{
		a.x + (b.x - a.x) * t,
		a.y + (b.y - a.y) * t,
	}
}

// Vector length
vec2_length :: proc(v: Vec2) -> f32 {
	return math.sqrt(v.x * v.x + v.y * v.y)
}

// Normalize vector
vec2_normalize :: proc(v: Vec2) -> Vec2 {
	len := vec2_length(v)
	if len > 0 {
		return Vec2{v.x / len, v.y / len}
	}
	return Vec2{0, 0}
}

// Distance between two points
vec2_distance :: proc(a, b: Vec2) -> f32 {
	dx := b.x - a.x
	dy := b.y - a.y
	return math.sqrt(dx * dx + dy * dy)
}
