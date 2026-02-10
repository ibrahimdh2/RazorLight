package razorlight_builtin_systems

import k2 "../../libs/karl2d"
import ecs "../../libs/yggsECS"
import core "../../core"

// ============================================================================
// Sprite Render System
// ============================================================================

// Renders all entities with Transform + Sprite_Component.
// If the entity also has an Animation_Component, uses the current animation
// frame's source rect. Otherwise draws the full texture (or src_rect if set).
// Registered in the Render phase, priority 5 (after shape_render at 0).
sprite_render_system :: proc(world_ptr: rawptr) {
	world := cast(^core.World)world_ptr

	// Render animated sprites (entities with Transform + Sprite_Component + Animation_Component)
	for arch in ecs.query(world.ecs, ecs.has(core.Transform), ecs.has(core.Sprite_Component), ecs.has(core.Animation_Component)) {
		transforms := ecs.get_table(world.ecs, arch, core.Transform)
		sprites := ecs.get_table(world.ecs, arch, core.Sprite_Component)
		anims := ecs.get_table(world.ecs, arch, core.Animation_Component)

		for i in 0..<len(transforms) {
			sprite := &sprites[i]
			if !sprite.visible {
				continue
			}

			t := &transforms[i]
			anim := &anims[i]

			// Determine which texture to use
			tex: k2.Texture
			if anim.current_animation != nil && anim.current_animation.texture.width > 0 {
				tex = anim.current_animation.texture
			} else {
				tex = sprite.texture
			}

			if tex.width == 0 || tex.height == 0 {
				continue
			}

			// Get source rect from animation
			src_rect: k2.Rect
			if frame_rect, ok := core.animation_get_current_frame(anim); ok {
				src_rect = frame_rect
			} else {
				src_rect = k2.Rect{0, 0, f32(tex.width), f32(tex.height)}
			}

			render_sprite(t, sprite, tex, src_rect)
		}
	}

	// Render static sprites (entities with Transform + Sprite_Component but NO Animation_Component)
	for arch in ecs.query(world.ecs, ecs.has(core.Transform), ecs.has(core.Sprite_Component), ecs.not(core.Animation_Component)) {
		transforms := ecs.get_table(world.ecs, arch, core.Transform)
		sprites := ecs.get_table(world.ecs, arch, core.Sprite_Component)

		for i in 0..<len(transforms) {
			sprite := &sprites[i]
			if !sprite.visible {
				continue
			}

			t := &transforms[i]
			tex := sprite.texture

			if tex.width == 0 || tex.height == 0 {
				continue
			}

			// Use src_rect if set, otherwise full texture
			src_rect: k2.Rect
			if sprite.src_rect.w > 0 && sprite.src_rect.h > 0 {
				src_rect = sprite.src_rect
			} else {
				src_rect = k2.Rect{0, 0, f32(tex.width), f32(tex.height)}
			}

			render_sprite(t, sprite, tex, src_rect)
		}
	}
}

// ============================================================================
// Shared Rendering Logic
// ============================================================================

@(private)
render_sprite :: proc(t: ^core.Transform, sprite: ^core.Sprite_Component, tex: k2.Texture, src_rect: k2.Rect) {
	// Calculate destination rect (centered on transform position)
	dst_w := src_rect.w * t.scale.x
	dst_h := src_rect.h * t.scale.y

	dst := k2.Rect{
		t.position.x - dst_w * sprite.origin.x,
		t.position.y - dst_h * sprite.origin.y,
		dst_w,
		dst_h,
	}

	// Apply flips via negative source dimensions
	flipped_src := src_rect
	if sprite.flip_x {
		flipped_src.w = -flipped_src.w
	}
	if sprite.flip_y {
		flipped_src.h = -flipped_src.h
	}

	origin := k2.Vec2{dst_w * sprite.origin.x, dst_h * sprite.origin.y}

	k2.draw_texture_ex(tex, flipped_src, dst, origin, t.rotation, sprite.color)
}
