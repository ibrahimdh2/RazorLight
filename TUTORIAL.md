# RazorLight Engine Tutorial & Setup Guide

A comprehensive guide for setting up and using the RazorLight 2D game engine built with Odin, Box2D, and Karl2D.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Project Structure](#project-structure)
4. [Architecture Overview](#architecture-overview)
5. [Quick Start](#quick-start)
6. [Core Concepts](#core-concepts)
7. [API Reference](#api-reference)
8. [Examples](#examples)
9. [Platform-Specific Notes](#platform-specific-notes)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

| Platform | Requirements |
|----------|--------------|
| All | [Odin Compiler](https://odin-lang.org/docs/install/) |
| Linux | X11 or Wayland, OpenGL 3.3+, development headers |
| Windows | Visual Studio Build Tools or MinGW |
| macOS | Xcode Command Line Tools |

### Linux Dependencies

```bash
# Ubuntu/Debian
sudo apt install build-essential libx11-dev libgl1-mesa-dev libudev-dev

# Fedora
sudo dnf install gcc libX11-devel mesa-libGL-devel systemd-devel

# Arch Linux
sudo pacman -S base-devel libx11 mesa udev
```

### Windows Dependencies

Ensure the Odin compiler is in your PATH. The engine uses the standard Windows SDK which comes with Visual Studio Build Tools.

### macOS Dependencies

```bash
xcode-select --install
```

---

## Installation

### 1. Clone or Download the Project

```bash
git clone <repository-url> my-game
cd my-game
```

### 2. Verify Odin Installation

```bash
odin version
```

### 3. Build and Run

**Linux/macOS:**
```bash
./build.sh          # Debug build (default)
./build.sh release  # Release build
./build.sh size     # Size-optimized build
```

**Windows:**
```batch
build.bat
```

Or use the Odin compiler directly:

```bash
# Linux/macOS
odin run .

# Windows
odin run . -extra-linker-flags:"/NODEFAULTLIB:libcmt.lib"
```

---

## Project Structure

```
project/
├── main.odin                    # Game entry point
├── build.bat                    # Windows build script
├── build.sh                     # Linux/macOS build script
├── CLAUDE.md                    # Project documentation
├── Libraries/
│   ├── karl2d/                  # 2D graphics/windowing library
│   │   ├── karl2d.odin          # Main API
│   │   ├── platform_windows.odin
│   │   ├── platform_linux.odin
│   │   ├── platform_mac.odin
│   │   └── render_backend_*.odin
│   └── yggsECS/                 # Entity-Component System
└── engine/                      # RazorLight engine (optional)
    ├── razorlight.odin          # Engine facade
    ├── core/
    │   ├── types.odin           # Common types
    │   ├── world.odin           # World container
    │   ├── engine.odin          # Engine lifecycle
    │   └── time.odin            # Time management
    ├── physics/
    │   ├── physics_world.odin   # Box2D wrapper
    │   └── components.odin      # Physics components
    ├── input/
    │   └── input.odin           # Input handling
    ├── systems/
    │   ├── scheduler.odin       # System scheduler
    │   └── builtin/             # Built-in systems
    └── debug/
        ├── logger.odin
        ├── profiler.odin
        └── debug_draw.odin
```

---

## Architecture Overview

The engine consists of three main layers:

```
┌─────────────────────────────────────────────────┐
│                  Your Game                       │
│              (main.odin, etc.)                   │
├─────────────────────────────────────────────────┤
│              RazorLight Engine                   │
│    (ECS, Physics, Input, Systems, Debug)         │
├─────────────────────────────────────────────────┤
│                   Karl2D                         │
│       (Windowing, Rendering, Input)              │
├─────────────────────────────────────────────────┤
│                Platform Layer                    │
│        (Windows/Linux/macOS/Web)                 │
└─────────────────────────────────────────────────┘
```

### Key Components

| Component | Description |
|-----------|-------------|
| **Karl2D** | Low-level 2D rendering, windowing, and input |
| **yggsECS** | Data-oriented Entity-Component System |
| **Box2D** | Physics simulation (via Odin vendor bindings) |
| **RazorLight** | High-level engine combining all systems |

### Coordinate System

- **Screen coordinates**: Y-down (0 at top, positive going down)
- **Physics (Box2D)**: Y-up (0 at bottom, positive going up)

The engine handles conversion automatically:
```odin
screen_to_physics :: proc(screen_pos: [2]f32) -> [2]f32 {
    return {screen_pos.x, -screen_pos.y}
}
```

---

## Quick Start

### Minimal Example (Direct Karl2D)

```odin
package main

import k2 "Libraries/karl2d"

main :: proc() {
    // Initialize window
    k2.init(1280, 720, "My Game")
    defer k2.shutdown()

    // Main loop
    for k2.update() {
        k2.clear(k2.LIGHT_BLUE)

        // Draw a red rectangle
        k2.draw_rect({100, 100, 200, 150}, k2.RED)

        // Draw a blue circle
        k2.draw_circle({640, 360}, 50, k2.BLUE)

        k2.present()

        // Exit on Escape
        if k2.key_is_held(.Escape) {
            break
        }
    }
}
```

### Using RazorLight Engine

```odin
package main

import rl "engine"

main :: proc() {
    // Create engine with default config
    engine := rl.engine_create()
    defer rl.engine_destroy(engine)

    // Get world reference
    world := rl.engine_get_world(engine)

    // Create ground
    ground := rl.world_create_static_box(world, {640, 650}, 1200, 50)
    rl.world_add_component(world, ground, rl.Shape_Component{
        shape_type = .Rectangle,
        color = rl.GREEN,
        size = {1200, 50},
        visible = true,
    })

    // Create player
    player := rl.world_create_physics_circle(world, {640, 300}, 30)
    rl.world_add_component(world, player, rl.Shape_Component{
        shape_type = .Circle,
        color = rl.BLUE,
        size = {30, 30},
        visible = true,
    })

    // Main loop
    for rl.engine_update(engine) {
        rl.engine_render(engine)
    }
}
```

---

## Core Concepts

### Entity-Component System (ECS)

The ECS pattern separates data (components) from behavior (systems):

```odin
import ecs "Libraries/yggsECS"

// Define components (pure data)
Position :: struct { x, y: f32 }
Velocity :: struct { dx, dy: f32 }
Health :: struct { current, max: i32 }

// Create world and entities
ecs_world := ecs.create_world()
defer ecs.delete_world(ecs_world)

// Create entity and add components
player := ecs.add_entity(ecs_world)
ecs.add_component(ecs_world, player, Position{100, 200})
ecs.add_component(ecs_world, player, Velocity{5, 0})
ecs.add_component(ecs_world, player, Health{100, 100})

// Query entities with specific components
for arch in ecs.query(ecs_world, ecs.has(Position), ecs.has(Velocity)) {
    positions := ecs.get_table(ecs_world, arch, Position)
    velocities := ecs.get_table(ecs_world, arch, Velocity)

    for i in 0..<len(positions) {
        positions[i].x += velocities[i].dx
        positions[i].y += velocities[i].dy
    }
}

// Direct component access (O(1) lookup)
if pos := ecs.get(ecs_world, player, Position); pos != nil {
    pos.x = 500
}
```

### Physics Bodies

```odin
import b2 "vendor:box2d"

// Create physics body
body_def := b2.DefaultBodyDef()
body_def.type = .dynamicBody
body_def.position = {640, -360}  // Remember: Y is inverted!
body_id := b2.CreateBody(physics_world, body_def)

// Add shape
shape_def := b2.DefaultShapeDef()
shape_def.density = 1.0
shape_def.material.friction = 0.3

box := b2.MakeBox(25, 25)  // Half-extents
b2.CreatePolygonShape(body_id, shape_def, box)

// Apply forces
b2.Body_ApplyForceToCenter(body_id, {100, 0}, true)
b2.Body_SetLinearVelocity(body_id, {50, -100})
```

### Input Handling

```odin
import k2 "Libraries/karl2d"

// Keyboard
if k2.key_went_down(.Space) {
    // Jump action - triggered once when key is first pressed
}

if k2.key_is_held(.A) {
    // Move left - triggered every frame while held
}

if k2.key_went_up(.W) {
    // Key released
}

// Mouse
mouse_pos := k2.get_mouse_position()
mouse_delta := k2.get_mouse_delta()
wheel := k2.get_mouse_wheel_delta()

if k2.mouse_button_went_down(.Left) {
    // Click
}

// Gamepad
if k2.is_gamepad_active(0) {
    stick_x := k2.get_gamepad_axis(0, .Left_Stick_X)
    stick_y := k2.get_gamepad_axis(0, .Left_Stick_Y)

    if k2.gamepad_button_went_down(0, .Right_Face_Down) {  // A button
        // Action
    }

    k2.set_gamepad_vibration(0, 0.5, 0.5)  // Rumble
}
```

### Action Bindings (RazorLight)

```odin
import input "engine/input"

is := input.input_create()
defer input.input_destroy(is)

// Bind multiple inputs to actions
input.input_bind_keys(is, "jump", .Space, .W, .Up)
input.input_bind_mouse(is, "shoot", .Left)
input.input_bind_gamepad(is, "jump", .Right_Face_Down)

// Check actions
if input.input_is_action_pressed(is, "jump") {
    // Player jumped
}

if input.input_is_action_held(is, "shoot") {
    // Continuous fire
}
```

### Rendering

```odin
import k2 "Libraries/karl2d"

// Basic shapes
k2.draw_rect({x, y, width, height}, k2.RED)
k2.draw_rect_ex({x, y, w, h}, origin, rotation, color)
k2.draw_rect_outline({x, y, w, h}, thickness, color)
k2.draw_circle(center, radius, color, segments)
k2.draw_circle_outline(center, radius, thickness, color)
k2.draw_line(start, end, thickness, color)

// Textures
tex := k2.load_texture_from_file("assets/sprite.png")
defer k2.destroy_texture(tex)

k2.draw_texture(tex, {x, y})
k2.draw_texture_rect(tex, src_rect, {x, y})
k2.draw_texture_ex(tex, src, dst, origin, rotation, tint)

// Text
k2.draw_text("Hello World", {100, 100}, 24, k2.BLACK)
size := k2.measure_text("Hello", 24)

// Custom fonts
font := k2.load_font_from_file("assets/myfont.ttf")
defer k2.destroy_font(font)
k2.draw_text_ex(font, "Custom Font", {100, 200}, 32, k2.WHITE)
```

### Camera

```odin
camera := k2.Camera{
    target = {player_x, player_y},  // What the camera looks at
    offset = {640, 360},            // Center on screen
    zoom = 1.0,                     // Zoom level
    rotation = 0,                   // Rotation in radians
}

k2.set_camera(camera)
// All drawing now uses camera coordinates

// Convert screen to world coordinates
world_pos := k2.screen_to_world(k2.get_mouse_position(), camera)

k2.set_camera(nil)  // Return to screen coordinates
```

---

## API Reference

### Karl2D Core Functions

| Function | Description |
|----------|-------------|
| `init(w, h, title)` | Initialize window |
| `shutdown()` | Clean up resources |
| `update()` | Process events, returns false when closing |
| `present()` | Display rendered frame |
| `clear(color)` | Clear screen |
| `get_frame_time()` | Delta time in seconds |
| `get_time()` | Total time since start |

### Drawing Functions

| Function | Description |
|----------|-------------|
| `draw_rect(rect, color)` | Draw filled rectangle |
| `draw_rect_ex(rect, origin, rot, color)` | Draw rotated rectangle |
| `draw_circle(center, radius, color)` | Draw filled circle |
| `draw_line(start, end, thickness, color)` | Draw line |
| `draw_texture(tex, pos)` | Draw texture |
| `draw_text(text, pos, size, color)` | Draw text |

### Physics Functions (Box2D Wrapper)

| Function | Description |
|----------|-------------|
| `physics_create_dynamic_body(pw, pos)` | Create moving body |
| `physics_create_static_body(pw, pos)` | Create static body |
| `physics_add_box_shape(body, hw, hh)` | Add box collider |
| `physics_add_circle_shape(body, r)` | Add circle collider |
| `physics_get_position(body)` | Get screen position |
| `physics_set_velocity(body, vel)` | Set velocity |

### ECS Functions

| Function | Description |
|----------|-------------|
| `create_world()` | Create ECS world |
| `delete_world(w)` | Destroy ECS world |
| `add_entity(w)` | Create entity |
| `remove_entity(w, e)` | Destroy entity |
| `add_component(w, e, c)` | Add component to entity |
| `get(w, e, T)` | Get component pointer |
| `query(w, ...)` | Query entities by components |

---

## Examples

### Complete Game Loop with Physics

```odin
package main

import b2 "vendor:box2d"
import k2 "Libraries/karl2d"
import ecs "Libraries/yggsECS"
import "core:math"

Position :: struct { x, y: f32 }
PhysicsBody :: struct { body_id: b2.BodyId, size: k2.Vec2 }
Player :: struct {}
Enemy :: struct {}

physics_world: b2.WorldId
ecs_world: ^ecs.World
time_acc: f32

main :: proc() {
    k2.init(1280, 720, "Physics Game")
    defer k2.shutdown()

    // Initialize physics
    b2.SetLengthUnitsPerMeter(40)
    world_def := b2.DefaultWorldDef()
    world_def.gravity = {0, -900}
    physics_world = b2.CreateWorld(world_def)
    defer b2.DestroyWorld(physics_world)

    // Initialize ECS
    ecs_world = ecs.create_world()
    defer ecs.delete_world(ecs_world)

    // Register cleanup callback
    ecs.on_remove(ecs_world, PhysicsBody, proc(ptr: rawptr) {
        body := cast(^PhysicsBody)ptr
        b2.DestroyBody(body.body_id)
    })

    // Create ground
    create_ground()

    // Create player
    create_player()

    // Main loop
    for k2.update() {
        dt := k2.get_frame_time()

        // Physics step (fixed timestep)
        time_acc += dt
        for time_acc >= 1.0/60.0 {
            b2.World_Step(physics_world, 1.0/60.0, 4)
            time_acc -= 1.0/60.0
        }

        // Sync physics to ECS
        sync_physics()

        // Render
        k2.clear(k2.LIGHT_BLUE)
        render_entities()
        k2.present()

        if k2.key_is_held(.Escape) { break }
    }
}

create_ground :: proc() {
    e := ecs.add_entity(ecs_world)

    body_def := b2.DefaultBodyDef()
    body_def.position = {640, -650}
    body_id := b2.CreateBody(physics_world, body_def)

    shape_def := b2.DefaultShapeDef()
    box := b2.MakeBox(600, 25)
    b2.CreatePolygonShape(body_id, shape_def, box)

    ecs.add_component(ecs_world, e, Position{640, 650})
    ecs.add_component(ecs_world, e, PhysicsBody{body_id, {1200, 50}})
}

create_player :: proc() {
    e := ecs.add_entity(ecs_world)

    body_def := b2.DefaultBodyDef()
    body_def.type = .dynamicBody
    body_def.position = {640, -300}
    body_id := b2.CreateBody(physics_world, body_def)

    shape_def := b2.DefaultShapeDef()
    shape_def.density = 1
    circle: b2.Circle
    circle.radius = 30
    b2.CreateCircleShape(body_id, shape_def, circle)

    ecs.add_component(ecs_world, e, Position{640, 300})
    ecs.add_component(ecs_world, e, PhysicsBody{body_id, {60, 60}})
    ecs.add_component(ecs_world, e, Player{})
}

sync_physics :: proc() {
    for arch in ecs.query(ecs_world, ecs.has(Position), ecs.has(PhysicsBody)) {
        positions := ecs.get_table(ecs_world, arch, Position)
        bodies := ecs.get_table(ecs_world, arch, PhysicsBody)

        for i in 0..<len(positions) {
            pos := b2.Body_GetPosition(bodies[i].body_id)
            positions[i] = {pos.x, -pos.y}
        }
    }
}

render_entities :: proc() {
    for arch in ecs.query(ecs_world, ecs.has(Position), ecs.has(PhysicsBody)) {
        positions := ecs.get_table(ecs_world, arch, Position)
        bodies := ecs.get_table(ecs_world, arch, PhysicsBody)

        for i in 0..<len(positions) {
            color := k2.GREEN
            if ecs.has_component(ecs_world, arch.entities[i], Player) {
                color = k2.BLUE
            }

            k2.draw_rect({
                positions[i].x - bodies[i].size.x/2,
                positions[i].y - bodies[i].size.y/2,
                bodies[i].size.x,
                bodies[i].size.y,
            }, color)
        }
    }
}
```

---

## Platform-Specific Notes

### Linux

**Display Server**: The engine auto-detects X11 or Wayland via `XDG_SESSION_TYPE`:
- Wayland: Uses native Wayland protocol with EGL
- X11: Uses Xlib with GLX

**Force X11 on Wayland**:
```bash
XDG_SESSION_TYPE=x11 ./build.sh
```

**Required Libraries**:
- X11: `libX11.so`, `libGL.so`
- Wayland: `libwayland-client.so`, `libwayland-egl.so`, `libEGL.so`

### Windows

**Render Backend**: Defaults to Direct3D 11, OpenGL also available.

**Linker Flag**: The `-extra-linker-flags:"/NODEFAULTLIB:libcmt.lib"` flag is required to avoid C runtime conflicts.

### macOS

**Render Backend**: OpenGL via NSOpenGL

**Frameworks Used**:
- Foundation
- AppKit
- GameController (for gamepad support)

---

## Troubleshooting

### Build Errors

| Error | Solution |
|-------|----------|
| "odin not found" | Add Odin to your PATH |
| Missing X11 headers | Install `libx11-dev` (Ubuntu) |
| Missing GL headers | Install `libgl1-mesa-dev` (Ubuntu) |
| NODEFAULTLIB error | Use `-extra-linker-flags:"/NODEFAULTLIB:libcmt.lib"` on Windows |

### Runtime Errors

| Error | Solution |
|-------|----------|
| "Failed to create window" | Check display server is running |
| Black screen | Verify `k2.present()` is called |
| No input response | Ensure `k2.update()` or `k2.process_events()` is called each frame |
| Physics objects fall through | Check collision shapes are properly sized |

### Performance Issues

1. **Enable profiling**:
   ```odin
   engine.debug.enabled = true
   rl.engine_print_profile(engine)
   ```

2. **Reduce physics substeps** if CPU-bound:
   ```odin
   config.physics_substeps = 2  // Default is 4
   ```

3. **Use batched rendering** - minimize texture switches

4. **Profile with system tools**:
   - Linux: `perf`, `valgrind`
   - Windows: Visual Studio Profiler
   - macOS: Instruments

---

## Best Practices

1. **Use deferred cleanup**:
   ```odin
   k2.init(1280, 720, "Game")
   defer k2.shutdown()  // Always cleanup!
   ```

2. **Fixed timestep for physics**:
   ```odin
   for time_acc >= FIXED_DT {
       b2.World_Step(world, FIXED_DT, substeps)
       time_acc -= FIXED_DT
   }
   ```

3. **Component cleanup callbacks**:
   ```odin
   ecs.on_remove(world, PhysicsBody, cleanup_physics_body)
   ```

4. **Separate update and render**:
   ```odin
   update(dt)
   render()  // No dt needed for rendering
   ```

5. **Use action bindings** instead of raw input for rebindable controls

---

## Resources

- [Odin Language Documentation](https://odin-lang.org/docs/)
- [Box2D Documentation](https://box2d.org/documentation/)
- [Karl2D Examples](Libraries/karl2d/examples/)

---

*RazorLight Engine - Built with Odin*
