package odin_test
import b2 "vendor:box2d"
import k2 "./Libraries/karl2d"
import ecs "./Libraries/yggsECS"
import "core:math"
import "core:math/rand"
import "core:fmt"

// ECS World
ecs_world: ^ecs.World

// Box2D World
physics_world: b2.WorldId
time_acc: f32

// Components
Position :: struct {
    x: f32,
    y: f32,
}

PhysicsBody :: struct {
    body_id: b2.BodyId,
    width: f32,
    height: f32,
}

CirclePhysics :: struct {
    body_id: b2.BodyId,
    radius: f32,
}

Sprite :: struct {
    color: k2.Color,
}

Player :: struct {}
Enemy :: struct {
    spawn_time: f32,
}
Box :: struct {}
Ground :: struct {}
Bullet :: struct {}

// Game state
player_entity: ecs.EntityID
score: int = 0
game_time: f32 = 0
enemies_destroyed: int = 0

// Input tracking
space_was_pressed: bool = false
mouse_was_pressed: bool = false

GROUND :: k2.Rect {
    0, 600,
    1280, 120,
}

start :: proc() {
    ecs_world = ecs.create_world()

    // Register cleanup callbacks for physics bodies (auto-cleanup on entity removal)
    ecs.on_remove(ecs_world, PhysicsBody, proc(ptr: rawptr) {
        body := cast(^PhysicsBody)ptr
        b2.DestroyBody(body.body_id)
    })
    ecs.on_remove(ecs_world, CirclePhysics, proc(ptr: rawptr) {
        body := cast(^CirclePhysics)ptr
        b2.DestroyBody(body.body_id)
    })

    // Initialize Box2D
    b2.SetLengthUnitsPerMeter(40)
    world_def := b2.DefaultWorldDef()
    world_def.gravity = b2.Vec2{0, -900}
    physics_world = b2.CreateWorld(world_def)
    
    // Create ground
    ground_body_def := b2.DefaultBodyDef()
    ground_body_def.position = b2.Vec2{GROUND.x, -GROUND.y - GROUND.h}
    ground_body_id := b2.CreateBody(physics_world, ground_body_def)
    ground_box := b2.MakeBox(GROUND.w, GROUND.h)
    ground_shape_def := b2.DefaultShapeDef()
    _ = b2.CreatePolygonShape(ground_body_id, ground_shape_def, ground_box)
    
    // Create ground entity in ECS
    ground_entity := ecs.add_entity(ecs_world)
    ecs.add_component(ecs_world, ground_entity, Position{GROUND.x, GROUND.y})
    ecs.add_component(ecs_world, ground_entity, Ground{})
    
    // Create player (circle that follows mouse)
    player_entity = ecs.add_entity(ecs_world)
    
    body_def := b2.DefaultBodyDef()
    body_def.type = .dynamicBody
    body_def.position = b2.Vec2{640, -360}
    player_body := b2.CreateBody(physics_world, body_def)
    
    shape_def := b2.DefaultShapeDef()
    shape_def.density = 1000
    shape_def.material.friction = 0.3
    circle: b2.Circle
    circle.radius = 30
    _ = b2.CreateCircleShape(player_body, shape_def, circle)
    
    ecs.add_component(ecs_world, player_entity, Position{640, 360})
    ecs.add_component(ecs_world, player_entity, CirclePhysics{player_body, 30})
    ecs.add_component(ecs_world, player_entity, Sprite{k2.BLUE})
    ecs.add_component(ecs_world, player_entity, Player{})
    
    // Create some initial enemies (boxes)
    for i in 0..<5 {
        spawn_enemy(f32(200 + i * 100), -200)
    }
    
    fmt.println("=== PHYSICS DEFENSE GAME ===")
    fmt.println("Move mouse to control your circle")
    fmt.println("Click or SPACE to shoot bullets")
    fmt.println("Destroy the falling boxes!")
    fmt.println("===========================")
}

spawn_enemy :: proc(x, y: f32) {
    entity := ecs.add_entity(ecs_world)
    
    body_def := b2.DefaultBodyDef()
    body_def.type = .dynamicBody
    body_def.position = b2.Vec2{x, y}
    body_id := b2.CreateBody(physics_world, body_def)
    
    shape_def := b2.DefaultShapeDef()
    shape_def.density = 1
    shape_def.material.friction = 0.3
    box := b2.MakeBox(25, 25)
    _ = b2.CreatePolygonShape(body_id, shape_def, box)
    
    ecs.add_component(ecs_world, entity, Position{x, -y})
    ecs.add_component(ecs_world, entity, PhysicsBody{body_id, 50, 50})
    ecs.add_component(ecs_world, entity, Sprite{k2.RED})
    ecs.add_component(ecs_world, entity, Enemy{game_time})
}

spawn_bullet :: proc(x, y: f32, target_x, target_y: f32) {
    entity := ecs.add_entity(ecs_world)
    
    // Calculate direction to target
    dx := target_x - x
    dy := target_y - y
    length := math.sqrt(dx*dx + dy*dy)
    if length > 0 {
        dx /= length
        dy /= length
    }
    
    body_def := b2.DefaultBodyDef()
    body_def.type = .dynamicBody
    body_def.position = b2.Vec2{x, -y}
    body_def.gravityScale = 0 // Bullets ignore gravity
    body_id := b2.CreateBody(physics_world, body_def)
    
    shape_def := b2.DefaultShapeDef()
    shape_def.density = 0.1
    shape_def.material.friction = 0.0
    shape_def.material.restitution = 1.0
    circle: b2.Circle
    circle.radius = 8
    _ = b2.CreateCircleShape(body_id, shape_def, circle)
    
    // Apply initial velocity
    BULLET_SPEED :: 800.0
    b2.Body_SetLinearVelocity(body_id, b2.Vec2{dx * BULLET_SPEED, -dy * BULLET_SPEED})
    
    ecs.add_component(ecs_world, entity, Position{x, y})
    ecs.add_component(ecs_world, entity, CirclePhysics{body_id, 8})
    ecs.add_component(ecs_world, entity, Sprite{k2.YELLOW})
    ecs.add_component(ecs_world, entity, Bullet{})
}

// Systems
player_input_system :: proc(dt: f32) {
    // Get player physics body directly using new get API (O(1) lookup)
    if physics := ecs.get(ecs_world, player_entity, CirclePhysics); physics != nil {
        // Move player to mouse position
        mouse_pos := k2.get_mouse_position()
        b2.Body_SetTransform(physics.body_id, {mouse_pos.x, -mouse_pos.y}, {})

        // Shooting
        space_is_pressed := k2.key_is_held(k2.Keyboard_Key.Space)
        mouse_is_pressed := k2.mouse_button_is_held(k2.Mouse_Button.Left)

        if (space_is_pressed && !space_was_pressed) || (mouse_is_pressed && !mouse_was_pressed) {
            // Shoot in direction of mouse movement
            spawn_bullet(mouse_pos.x, mouse_pos.y, mouse_pos.x, mouse_pos.y - 100)
        }

        space_was_pressed = space_is_pressed
        mouse_was_pressed = mouse_is_pressed
    }
}

enemy_spawn_system :: proc(dt: f32) {
    // Spawn new enemies periodically
    if int(game_time) % 3 == 0 && int((game_time - dt)) % 3 != 0 {
        spawn_x := rand.float32_range(100, 1180)
        spawn_enemy(spawn_x, -100)
    }
}

physics_sync_system :: proc() {
    // Sync Box2D positions to ECS for boxes
    for arch in ecs.query(ecs_world, ecs.has(Position), ecs.has(PhysicsBody)) {
        positions := ecs.get_table(ecs_world, arch, Position)
        physics_bodies := ecs.get_table(ecs_world, arch, PhysicsBody)
        
        for i in 0..<len(positions) {
            b2_pos := b2.Body_GetPosition(physics_bodies[i].body_id)
            positions[i].x = b2_pos.x
            positions[i].y = -b2_pos.y
        }
    }
    
    // Sync circle physics
    for arch in ecs.query(ecs_world, ecs.has(Position), ecs.has(CirclePhysics)) {
        positions := ecs.get_table(ecs_world, arch, Position)
        physics_bodies := ecs.get_table(ecs_world, arch, CirclePhysics)
        
        for i in 0..<len(positions) {
            b2_pos := b2.Body_GetPosition(physics_bodies[i].body_id)
            positions[i].x = b2_pos.x
            positions[i].y = -b2_pos.y
        }
    }
}

collision_system :: proc() {
    entities_to_remove: [dynamic]ecs.EntityID
    defer delete(entities_to_remove)
    
    // Check bullet-enemy collisions
    for bullet_arch in ecs.query(ecs_world, ecs.has(Bullet), ecs.has(Position)) {
        bullet_positions := ecs.get_table(ecs_world, bullet_arch, Position)
        bullet_entities := bullet_arch.entities[:]
        
        for bullet_pos, bullet_idx in bullet_positions {
            for enemy_arch in ecs.query(ecs_world, ecs.has(Enemy), ecs.has(Position)) {
                enemy_positions := ecs.get_table(ecs_world, enemy_arch, Position)
                enemy_entities := enemy_arch.entities[:]
                
                for enemy_pos, enemy_idx in enemy_positions {
                    dx := bullet_pos.x - enemy_pos.x
                    dy := bullet_pos.y - enemy_pos.y
                    distance := math.sqrt(dx*dx + dy*dy)
                    
                    if distance < 35 { // Collision radius
                        append(&entities_to_remove, enemy_entities[enemy_idx])
                        append(&entities_to_remove, bullet_entities[bullet_idx])
                        enemies_destroyed += 1
                        score += 100
                    }
                }
            }
        }
    }
    
    // Remove collided entities (physics bodies auto-cleanup via on_remove callbacks)
    for entity in entities_to_remove {
        if ecs.entity_exists(ecs_world, entity) {
            ecs.remove_entity(ecs_world, entity)
        }
    }
}

cleanup_system :: proc() {
    entities_to_remove: [dynamic]ecs.EntityID
    defer delete(entities_to_remove)
    
    // Remove bullets that are off screen
    for arch in ecs.query(ecs_world, ecs.has(Bullet), ecs.has(Position)) {
        positions := ecs.get_table(ecs_world, arch, Position)
        entities := arch.entities[:]
        
        for pos, i in positions {
            if pos.y < -100 || pos.y > 800 || pos.x < -100 || pos.x > 1380 {
                append(&entities_to_remove, entities[i])
            }
        }
    }
    
    // Remove enemies that fell off screen (game over condition could be added here)
    for arch in ecs.query(ecs_world, ecs.has(Enemy), ecs.has(Position)) {
        positions := ecs.get_table(ecs_world, arch, Position)
        entities := arch.entities[:]
        
        for pos, i in positions {
            if pos.y > 750 {
                append(&entities_to_remove, entities[i])
                score -= 50 // Penalty for missing
            }
        }
    }
    
    // Remove entities (physics bodies auto-cleanup via on_remove callbacks)
    for entity in entities_to_remove {
        if ecs.entity_exists(ecs_world, entity) {
            ecs.remove_entity(ecs_world, entity)
        }
    }
}

render_system :: proc() {
    // Draw ground
    k2.draw_rect(GROUND, k2.GREEN)
    
    // Draw boxes (enemies)
    for arch in ecs.query(ecs_world, ecs.has(Enemy), ecs.has(Position), ecs.has(PhysicsBody), ecs.has(Sprite)) {
        positions := ecs.get_table(ecs_world, arch, Position)
        physics_bodies := ecs.get_table(ecs_world, arch, PhysicsBody)
        sprites := ecs.get_table(ecs_world, arch, Sprite)
        
        for i in 0..<len(positions) {
            r := b2.Body_GetRotation(physics_bodies[i].body_id)
            rot := math.atan2(r.s, r.c)
            k2.draw_rect_ex(
                {positions[i].x, positions[i].y, physics_bodies[i].width, physics_bodies[i].height},
                {physics_bodies[i].width / 2, physics_bodies[i].height / 2},
                rot,
                sprites[i].color,
            )
        }
    }
    
    // Draw circles (player and bullets)
    for arch in ecs.query(ecs_world, ecs.has(Position), ecs.has(CirclePhysics), ecs.has(Sprite)) {
        positions := ecs.get_table(ecs_world, arch, Position)
        physics := ecs.get_table(ecs_world, arch, CirclePhysics)
        sprites := ecs.get_table(ecs_world, arch, Sprite)
        
        for i in 0..<len(positions) {
            k2.draw_circle(
                {positions[i].x, positions[i].y},
                physics[i].radius,
                sprites[i].color,
            )
        }
    }
    
    // Draw UI text in console
    fmt.printf("\rScore: %d | Destroyed: %d | Time: %.1f   ", score, enemies_destroyed, game_time)
}

update :: proc(dt: f32) {
    game_time += dt
    
    player_input_system(dt)
    enemy_spawn_system(dt)
    
    // Step Box2D physics with fixed timestep
    SUB_STEPS :: 4
    TIME_STEP :: 1.0 / 60.0
    time_acc += dt
    
    for time_acc >= TIME_STEP {
        b2.World_Step(physics_world, TIME_STEP, SUB_STEPS)
        time_acc -= TIME_STEP
    }
    
    physics_sync_system()
    collision_system()
    cleanup_system()
}

main :: proc() {
    k2.init(1280, 720, "Physics Defense - Box2D + ECS + Karl2D")
    defer k2.shutdown()
    defer ecs.delete_world(ecs_world)
    defer b2.DestroyWorld(physics_world)
    
    start()
    
    for k2.update() {
        dt := k2.get_frame_time()
        k2.process_events()
        
        k2.clear(k2.LIGHT_BLUE)
        
        update(dt)
        render_system()
        
        k2.present()
        
        if k2.key_is_held(k2.Keyboard_Key.Escape) {
            break
        }
    }
    
    fmt.println("\n\n=== GAME OVER ===")
    fmt.println("Final Score:", score)
    fmt.println("Enemies Destroyed:", enemies_destroyed)
    fmt.println("Time Survived:", game_time, "seconds")
}
