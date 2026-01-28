package razorlight_debug

import k2 "../../Libraries/karl2d"
import ecs "../../Libraries/yggsECS"
import core "../core"
import physics "../physics"
import "core:math"

// ============================================================================
// Debug Draw Context
// ============================================================================

Debug_Context :: struct {
	enabled:           bool,

	// What to draw
	draw_colliders:    bool,
	draw_velocities:   bool,
	draw_transforms:   bool,
	draw_grid:         bool,

	// Colors
	box_collider_color:    k2.Color,
	circle_collider_color: k2.Color,
	velocity_color:        k2.Color,
	transform_color:       k2.Color,
	grid_color:            k2.Color,

	// Grid settings
	grid_size:         f32,
}

debug_context_create :: proc() -> ^Debug_Context {
	dc := new(Debug_Context)

	dc.enabled = false

	dc.draw_colliders = true
	dc.draw_velocities = true
	dc.draw_transforms = false
	dc.draw_grid = false

	// Semi-transparent colors for debug drawing
	dc.box_collider_color = k2.Color{0, 255, 0, 128}      // Green
	dc.circle_collider_color = k2.Color{0, 200, 255, 128} // Cyan
	dc.velocity_color = k2.Color{255, 255, 0, 255}        // Yellow
	dc.transform_color = k2.Color{255, 0, 255, 200}       // Magenta
	dc.grid_color = k2.Color{100, 100, 100, 50}           // Gray

	dc.grid_size = 32

	return dc
}

debug_context_destroy :: proc(dc: ^Debug_Context) {
	if dc != nil {
		free(dc)
	}
}

// ============================================================================
// Debug Rendering
// ============================================================================

debug_render :: proc(dc: ^Debug_Context, world: ^core.World) {
	if !dc.enabled {
		return
	}

	if dc.draw_grid {
		debug_draw_grid(dc)
	}

	if dc.draw_colliders {
		debug_draw_colliders(dc, world)
	}

	if dc.draw_velocities {
		debug_draw_velocities(dc, world)
	}

	if dc.draw_transforms {
		debug_draw_transforms(dc, world)
	}
}

// ============================================================================
// Grid Drawing
// ============================================================================

@(private)
debug_draw_grid :: proc(dc: ^Debug_Context) {
	screen_w := f32(k2.get_screen_width())
	screen_h := f32(k2.get_screen_height())
	size := dc.grid_size

	// Vertical lines
	x: f32 = 0
	for x < screen_w {
		k2.draw_line(k2.Vec2{x, 0}, k2.Vec2{x, screen_h}, 1, dc.grid_color)
		x += size
	}

	// Horizontal lines
	y: f32 = 0
	for y < screen_h {
		k2.draw_line(k2.Vec2{0, y}, k2.Vec2{screen_w, y}, 1, dc.grid_color)
		y += size
	}
}

// ============================================================================
// Collider Drawing
// ============================================================================

@(private)
debug_draw_colliders :: proc(dc: ^Debug_Context, world: ^core.World) {
	// Draw box colliders
	for arch in ecs.query(world.ecs, ecs.has(physics.Box_Collider)) {
		colliders := ecs.get_table(world.ecs, arch, physics.Box_Collider)

		for i in 0..<len(colliders) {
			col := &colliders[i]

			// Get position and rotation from physics body
			pos := physics.physics_get_position(col.body_id)
			rot := physics.physics_get_rotation(col.body_id)

			// Draw rotated rectangle outline
			draw_rotated_rect_outline(
				pos,
				col.width, col.height,
				rot,
				dc.box_collider_color,
			)
		}
	}

	// Draw circle colliders
	for arch in ecs.query(world.ecs, ecs.has(physics.Circle_Collider)) {
		colliders := ecs.get_table(world.ecs, arch, physics.Circle_Collider)

		for i in 0..<len(colliders) {
			col := &colliders[i]

			pos := physics.physics_get_position(col.body_id)
			rot := physics.physics_get_rotation(col.body_id)

			// Draw circle outline
			k2.draw_circle_outline(
				k2.Vec2{pos.x, pos.y},
				col.radius,
				2,
				dc.circle_collider_color,
			)

			// Draw rotation indicator line
			end_x := pos.x + math.cos(rot) * col.radius
			end_y := pos.y + math.sin(rot) * col.radius
			k2.draw_line(
				k2.Vec2{pos.x, pos.y},
				k2.Vec2{end_x, end_y},
				2,
				dc.circle_collider_color,
			)
		}
	}
}

// ============================================================================
// Velocity Drawing
// ============================================================================

@(private)
debug_draw_velocities :: proc(dc: ^Debug_Context, world: ^core.World) {
	// Draw velocities for box colliders
	for arch in ecs.query(world.ecs, ecs.has(physics.Box_Collider)) {
		colliders := ecs.get_table(world.ecs, arch, physics.Box_Collider)

		for i in 0..<len(colliders) {
			col := &colliders[i]
			draw_velocity_arrow(col.body_id, dc.velocity_color)
		}
	}

	// Draw velocities for circle colliders
	for arch in ecs.query(world.ecs, ecs.has(physics.Circle_Collider)) {
		colliders := ecs.get_table(world.ecs, arch, physics.Circle_Collider)

		for i in 0..<len(colliders) {
			col := &colliders[i]
			draw_velocity_arrow(col.body_id, dc.velocity_color)
		}
	}
}

@(private)
draw_velocity_arrow :: proc(body_id: physics.BodyId, color: k2.Color) {
	pos := physics.physics_get_position(body_id)
	vel := physics.physics_get_velocity(body_id)

	// Scale velocity for visualization
	scale: f32 = 0.1
	end_pos := core.Vec2{
		pos.x + vel.x * scale,
		pos.y + vel.y * scale,
	}

	// Only draw if there's meaningful velocity
	speed := math.sqrt(vel.x * vel.x + vel.y * vel.y)
	if speed < 1 {
		return
	}

	// Draw velocity line
	k2.draw_line(
		k2.Vec2{pos.x, pos.y},
		k2.Vec2{end_pos.x, end_pos.y},
		2,
		color,
	)

	// Draw arrowhead
	arrow_size: f32 = 8
	dir := core.Vec2{vel.x, vel.y}
	dir = core.vec2_normalize(dir)

	perp := core.Vec2{-dir.y, dir.x}

	p1 := core.Vec2{
		end_pos.x - dir.x * arrow_size + perp.x * arrow_size * 0.5,
		end_pos.y - dir.y * arrow_size + perp.y * arrow_size * 0.5,
	}
	p2 := core.Vec2{
		end_pos.x - dir.x * arrow_size - perp.x * arrow_size * 0.5,
		end_pos.y - dir.y * arrow_size - perp.y * arrow_size * 0.5,
	}

	k2.draw_line(k2.Vec2{end_pos.x, end_pos.y}, k2.Vec2{p1.x, p1.y}, 2, color)
	k2.draw_line(k2.Vec2{end_pos.x, end_pos.y}, k2.Vec2{p2.x, p2.y}, 2, color)
}

// ============================================================================
// Transform Drawing
// ============================================================================

@(private)
debug_draw_transforms :: proc(dc: ^Debug_Context, world: ^core.World) {
	for arch in ecs.query(world.ecs, ecs.has(core.Transform)) {
		transforms := ecs.get_table(world.ecs, arch, core.Transform)

		for i in 0..<len(transforms) {
			t := &transforms[i]

			// Draw position marker (cross)
			size: f32 = 10
			k2.draw_line(
				k2.Vec2{t.position.x - size, t.position.y},
				k2.Vec2{t.position.x + size, t.position.y},
				2,
				dc.transform_color,
			)
			k2.draw_line(
				k2.Vec2{t.position.x, t.position.y - size},
				k2.Vec2{t.position.x, t.position.y + size},
				2,
				dc.transform_color,
			)

			// Draw rotation indicator
			end_x := t.position.x + math.cos(t.rotation) * size * 2
			end_y := t.position.y + math.sin(t.rotation) * size * 2
			k2.draw_line(
				k2.Vec2{t.position.x, t.position.y},
				k2.Vec2{end_x, end_y},
				2,
				k2.RED,
			)
		}
	}
}

// ============================================================================
// Helper Functions
// ============================================================================

@(private)
draw_rotated_rect_outline :: proc(center: core.Vec2, width, height, rotation: f32, color: k2.Color) {
	hw := width / 2
	hh := height / 2

	cos_r := math.cos(rotation)
	sin_r := math.sin(rotation)

	// Calculate rotated corners
	corners: [4]k2.Vec2
	offsets := [4][2]f32{{-hw, -hh}, {hw, -hh}, {hw, hh}, {-hw, hh}}

	for i in 0..<4 {
		ox := offsets[i][0]
		oy := offsets[i][1]

		rx := center.x + ox * cos_r - oy * sin_r
		ry := center.y + ox * sin_r + oy * cos_r

		corners[i] = k2.Vec2{rx, ry}
	}

	// Draw lines between corners
	k2.draw_line(corners[0], corners[1], 2, color)
	k2.draw_line(corners[1], corners[2], 2, color)
	k2.draw_line(corners[2], corners[3], 2, color)
	k2.draw_line(corners[3], corners[0], 2, color)
}

// ============================================================================
// Toggle Functions
// ============================================================================

debug_toggle :: proc(dc: ^Debug_Context) {
	dc.enabled = !dc.enabled
}

debug_toggle_colliders :: proc(dc: ^Debug_Context) {
	dc.draw_colliders = !dc.draw_colliders
}

debug_toggle_velocities :: proc(dc: ^Debug_Context) {
	dc.draw_velocities = !dc.draw_velocities
}

debug_toggle_transforms :: proc(dc: ^Debug_Context) {
	dc.draw_transforms = !dc.draw_transforms
}

debug_toggle_grid :: proc(dc: ^Debug_Context) {
	dc.draw_grid = !dc.draw_grid
}
