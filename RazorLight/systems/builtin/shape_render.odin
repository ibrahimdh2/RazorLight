package razorlight_builtin_systems

import k2 "../../libs/karl2d"
import ecs "../../libs/yggsECS"
import core "../../core"

// ============================================================================
// Shape Render System
// ============================================================================

// Renders all entities that have Transform + Shape_Component.
// Handles Rectangle (with rotation) and Circle shapes.
shape_render_system :: proc(world_ptr: rawptr) {
	world := cast(^core.World)world_ptr

	for arch in ecs.query(world.ecs, ecs.has(core.Transform), ecs.has(core.Shape_Component)) {
		transforms := ecs.get_table(world.ecs, arch, core.Transform)
		shapes := ecs.get_table(world.ecs, arch, core.Shape_Component)

		for i in 0..<len(transforms) {
			shape := &shapes[i]
			if !shape.visible {
				continue
			}

			t := &transforms[i]

			switch shape.shape_type {
			case .Rectangle:
				w := shape.size.x
				h := shape.size.y
				rect := k2.Rect{
					t.position.x - w / 2,
					t.position.y - h / 2,
					w,
					h,
				}
				if t.rotation != 0 {
					origin := k2.Vec2{w / 2, h / 2}
					k2.draw_rect_ex(rect, origin, t.rotation, shape.color)
				} else {
					k2.draw_rect(rect, shape.color)
				}

			case .Circle:
				k2.draw_circle(
					k2.Vec2{t.position.x, t.position.y},
					shape.size.x,  // radius stored in size.x
					shape.color,
				)
			}
		}
	}
}
