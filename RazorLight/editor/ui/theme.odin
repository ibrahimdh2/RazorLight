package editor_ui

import k2 "../../libs/karl2d"

// ============================================================================
// Theme - Colors and sizing for the editor UI
// ============================================================================

Color :: k2.Color

Theme :: struct {
	// Background colors
	bg_primary:       Color,    // Main background (panels)
	bg_secondary:     Color,    // Secondary background (headers, toolbars)
	bg_tertiary:      Color,    // Tertiary (input fields, inactive tabs)
	bg_hover:         Color,    // Hover state background
	bg_active:        Color,    // Active/pressed state background

	// Text colors
	text_primary:     Color,    // Main text
	text_secondary:   Color,    // Secondary/muted text
	text_disabled:    Color,    // Disabled text

	// Accent colors
	accent:           Color,    // Primary accent (selection, focus)
	accent_hover:     Color,    // Accent hover state
	accent_active:    Color,    // Accent active/pressed state

	// Border colors
	border:           Color,    // Default border
	border_light:     Color,    // Light border (separators)
	border_focused:   Color,    // Focused element border

	// Status colors
	error:            Color,
	warning:          Color,
	success:          Color,
	info:             Color,

	// Special colors
	selection:        Color,    // Selected items background
	highlight:        Color,    // Hover highlight
	shadow:           Color,    // Drop shadow color

	// Sizing
	font_size:        f32,
	font_size_small:  f32,
	font_size_large:  f32,

	padding:          f32,      // Default padding
	padding_small:    f32,
	padding_large:    f32,

	spacing:          f32,      // Default spacing between elements
	spacing_small:    f32,
	spacing_large:    f32,

	border_radius:    f32,      // Default corner radius
	border_width:     f32,      // Default border width

	scrollbar_width:  f32,
	scrollbar_min_thumb: f32,

	// Widget sizes
	button_height:    f32,
	input_height:     f32,
	header_height:    f32,
	tab_height:       f32,
	icon_size:        f32,

	// Animation
	hover_transition: f32,      // Hover transition time in seconds
}

// ============================================================================
// Dark Theme - Modern dark editor look
// ============================================================================

theme_dark :: proc() -> Theme {
	return Theme{
		// Background colors - Dark grays
		bg_primary       = Color{30, 30, 30, 255},      // #1E1E1E
		bg_secondary     = Color{37, 37, 38, 255},      // #252526
		bg_tertiary      = Color{45, 45, 48, 255},      // #2D2D30
		bg_hover         = Color{60, 60, 60, 255},      // #3C3C3C
		bg_active        = Color{50, 50, 50, 255},      // #323232

		// Text colors
		text_primary     = Color{212, 212, 212, 255},   // #D4D4D4
		text_secondary   = Color{150, 150, 150, 255},   // #969696
		text_disabled    = Color{90, 90, 90, 255},      // #5A5A5A

		// Accent colors - Blue accent
		accent           = Color{0, 122, 204, 255},     // #007ACC
		accent_hover     = Color{28, 151, 234, 255},    // #1C97EA
		accent_active    = Color{0, 100, 180, 255},     // #0064B4

		// Border colors
		border           = Color{60, 60, 60, 255},      // #3C3C3C
		border_light     = Color{50, 50, 50, 255},      // #323232
		border_focused   = Color{0, 122, 204, 255},     // #007ACC

		// Status colors
		error            = Color{244, 67, 54, 255},     // #F44336
		warning          = Color{255, 152, 0, 255},     // #FF9800
		success          = Color{76, 175, 80, 255},     // #4CAF50
		info             = Color{33, 150, 243, 255},    // #2196F3

		// Special colors
		selection        = Color{0, 122, 204, 100},     // Semi-transparent accent
		highlight        = Color{255, 255, 255, 15},    // Subtle highlight
		shadow           = Color{0, 0, 0, 100},         // Semi-transparent black

		// Sizing
		font_size        = 14,
		font_size_small  = 12,
		font_size_large  = 18,

		padding          = 8,
		padding_small    = 4,
		padding_large    = 16,

		spacing          = 8,
		spacing_small    = 4,
		spacing_large    = 16,

		border_radius    = 4,
		border_width     = 1,

		scrollbar_width  = 14,
		scrollbar_min_thumb = 30,

		// Widget sizes
		button_height    = 28,
		input_height     = 24,
		header_height    = 32,
		tab_height       = 28,
		icon_size        = 16,

		// Animation
		hover_transition = 0.1,
	}
}

// ============================================================================
// Light Theme - Clean light editor look
// ============================================================================

theme_light :: proc() -> Theme {
	return Theme{
		// Background colors - Light grays
		bg_primary       = Color{255, 255, 255, 255},   // White
		bg_secondary     = Color{243, 243, 243, 255},   // #F3F3F3
		bg_tertiary      = Color{230, 230, 230, 255},   // #E6E6E6
		bg_hover         = Color{220, 220, 220, 255},   // #DCDCDC
		bg_active        = Color{200, 200, 200, 255},   // #C8C8C8

		// Text colors
		text_primary     = Color{30, 30, 30, 255},      // Dark gray
		text_secondary   = Color{100, 100, 100, 255},   // #646464
		text_disabled    = Color{160, 160, 160, 255},   // #A0A0A0

		// Accent colors - Blue accent
		accent           = Color{0, 120, 212, 255},     // #0078D4
		accent_hover     = Color{16, 137, 225, 255},    // #1089E1
		accent_active    = Color{0, 100, 180, 255},     // #0064B4

		// Border colors
		border           = Color{200, 200, 200, 255},   // #C8C8C8
		border_light     = Color{220, 220, 220, 255},   // #DCDCDC
		border_focused   = Color{0, 120, 212, 255},     // #0078D4

		// Status colors
		error            = Color{232, 17, 35, 255},     // #E81123
		warning          = Color{255, 140, 0, 255},     // #FF8C00
		success          = Color{16, 124, 16, 255},     // #107C10
		info             = Color{0, 120, 212, 255},     // #0078D4

		// Special colors
		selection        = Color{0, 120, 212, 60},      // Semi-transparent accent
		highlight        = Color{0, 0, 0, 10},          // Subtle highlight
		shadow           = Color{0, 0, 0, 40},          // Semi-transparent black

		// Sizing (same as dark)
		font_size        = 14,
		font_size_small  = 12,
		font_size_large  = 18,

		padding          = 8,
		padding_small    = 4,
		padding_large    = 16,

		spacing          = 8,
		spacing_small    = 4,
		spacing_large    = 16,

		border_radius    = 4,
		border_width     = 1,

		scrollbar_width  = 14,
		scrollbar_min_thumb = 30,

		button_height    = 28,
		input_height     = 24,
		header_height    = 32,
		tab_height       = 28,
		icon_size        = 16,

		hover_transition = 0.1,
	}
}

// ============================================================================
// Theme Utilities
// ============================================================================

// Interpolate between two colors
color_lerp :: proc(a, b: Color, t: f32) -> Color {
	t_clamped := clamp(t, 0, 1)
	return Color{
		u8(f32(a.r) + (f32(b.r) - f32(a.r)) * t_clamped),
		u8(f32(a.g) + (f32(b.g) - f32(a.g)) * t_clamped),
		u8(f32(a.b) + (f32(b.b) - f32(a.b)) * t_clamped),
		u8(f32(a.a) + (f32(b.a) - f32(a.a)) * t_clamped),
	}
}

// Create a color with modified alpha
color_alpha :: proc(c: Color, alpha: u8) -> Color {
	return Color{c.r, c.g, c.b, alpha}
}

// Darken a color by a factor (0-1)
color_darken :: proc(c: Color, amount: f32) -> Color {
	factor := 1.0 - clamp(amount, 0, 1)
	return Color{
		u8(f32(c.r) * factor),
		u8(f32(c.g) * factor),
		u8(f32(c.b) * factor),
		c.a,
	}
}

// Lighten a color by a factor (0-1)
color_lighten :: proc(c: Color, amount: f32) -> Color {
	a := clamp(amount, 0, 1)
	return Color{
		u8(f32(c.r) + (255 - f32(c.r)) * a),
		u8(f32(c.g) + (255 - f32(c.g)) * a),
		u8(f32(c.b) + (255 - f32(c.b)) * a),
		c.a,
	}
}
