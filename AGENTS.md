# RazorLight Game Engine - Agent Documentation

This file provides essential information for AI coding agents working with the RazorLight game engine project.

---

## Project Overview

RazorLight is a 2D game engine written in the [Odin programming language](https://odin-lang.org/). It combines a custom Entity-Component-System (ECS) with Box2D physics and the Karl2D rendering library to provide a complete game development framework.

### Key Components

| Component | Description | Location |
|-----------|-------------|----------|
| **RazorLight Engine** | Full game engine with ECS, physics, systems, and hot-reload | `RazorLight/` |
| **Karl2D** | 2D rendering, windowing, and input library | `RazorLight/libs/karl2d/` or `Libraries/karl2d/` |
| **yggsECS** | Entity-Component-System implementation | `RazorLight/libs/yggsECS/` or `Libraries/yggsECS/` |
| **Box2D** | Physics simulation (via Odin vendor bindings) | `vendor:box2d` |
| **RZL CLI** | Command-line tool for project management | `rzl/` |
| **Animation Editor** | Built-in editor for sprite animations | `RazorLight/editor/animation_editor/` |

---

## Build and Run Commands

### Prerequisites

- **Odin compiler** must be installed and available in PATH
- **Linux dependencies**: `build-essential libx11-dev libgl1-mesa-dev libudev-dev`
- **Windows**: Visual Studio Build Tools or MinGW
- **macOS**: Xcode Command Line Tools

### Original Game (root/main.odin)

```bash
# Linux/macOS
./build.sh              # Debug build (default)
./build.sh release      # Release build
./build.sh size         # Size-optimized build

# Or directly:
odin run .

# Windows
build.bat

# Or directly:
odin run . -extra-linker-flags:"/NODEFAULTLIB:libcmt.lib"
```

### RazorLight Engine Projects

```bash
# Using RZL CLI
rzl new my_game         # Create new project
rzl run                 # Build and run
rzl run --hot           # Run with hot-reload
rzl build release       # Build without running
rzl editor              # Launch animation editor

# Manual build (for projects using RazorLight)
odin run . -o:none -debug
```

### RZL CLI Tool

```bash
# Build the CLI tool
cd rzl && odin build . -out:rzl_cli

# Use it
./rzl_cli new my_project
./rzl_cli run
./rzl_cli build release
```

---

## Project Structure

```
RazorLight/
├── main.odin                    # Original physics defense game (legacy)
├── build.sh / build.bat         # Build scripts
├── RazorLight/                  # Main engine (self-contained)
│   ├── razorlight.odin         # Engine facade - single import for most features
│   ├── libs/
│   │   ├── karl2d/             # 2D rendering, windowing, input
│   │   └── yggsECS/            # ECS implementation
│   ├── core/                   # Types, World, Time, Animation, Hot-reload
│   ├── physics/                # Box2D wrapper, components, character body
│   ├── systems/                # Scheduler + built-in systems
│   │   └── builtin/            # Physics sync, shape render, sprite render, animation
│   ├── input/                  # Action mapping system
│   ├── debug/                  # Debug draw, logger, profiler
│   └── editor/
│       ├── ui/                 # Immediate-mode UI widgets
│       └── animation_editor/   # Sprite animation editor
├── rzl/                         # RZL CLI tool
│   ├── main.odin               # CLI entry point
│   └── commands/               # new, build, run, editor commands
├── Libraries/                   # Legacy location (kept for reference)
│   ├── karl2d/
│   └── yggsECS/
├── engine/                      # Old engine layout (kept for reference)
└── examples/                    # Example games
    ├── Basic Physics/
    ├── Avoiding Game/
    └── demo_platformer/
```

---

## Import Patterns

### Standard RazorLight Usage

```odin
import rl "../RazorLight"              # Engine facade (types, drawing, physics, input)
import ecs "../RazorLight/libs/yggsECS" # ECS queries (polymorphic - can't be re-exported)
import "vendor:box2d"                   # Direct Box2D access if needed
```

### Legacy Direct Usage

```odin
import k2 "./Libraries/karl2d"
import ecs "./Libraries/yggsECS"
import "vendor:box2d"
```

**Important**: `ecs.query()`, `ecs.has()`, `ecs.get_table()`, and `ecs.add_component()` are polymorphic procs that cannot be aliased across packages. Import yggsECS directly for ECS queries in systems.

---

## Architecture

### Engine Lifecycle

```
engine_create() -> loop { engine_update() -> engine_render() } -> engine_destroy()
```

### Update Phase (engine_update)

1. **Pre_Update** - Input processing
2. **Update** - Game logic
3. **Fixed_Update** - Physics step + sync (runs at fixed timestep)
4. **Post_Update** - Cleanup

### Render Phase (engine_render)

1. Clear screen
2. Render phase systems (shape_render built-in, then custom)
3. Debug rendering (if enabled)
4. Present

### Coordinate System

- **Screen**: Y-down (0 at top, positive going down)
- **Box2D Physics**: Y-up (0 at bottom, positive going up)

Conversion:
- Box2D to screen: `screen_y = -box2d_y`
- Screen to Box2D: `box2d_y = -screen_y`

### Physics Configuration

- Fixed timestep: `1/60` second
- Sub-steps: `4` per frame
- Gravity: `900` units down (positive Y)
- Length units per meter: `40`

---

## Key Programming Patterns

### Entity Creation (Compositional)

```odin
// Method 1: Individual component addition
entity := rl.create_entity(world)
rl.add_component(world, entity, rl.Transform{position = {100, 200}})
rl.add_component(world, entity, rl.Collider{shape = rl.Circle{radius = 30}})
rl.add_component(world, entity, rl.Rigidbody{body_type = .Dynamic})
rl.add_component(world, entity, rl.Shape_Component{shape_type = .Circle, color = rl.BLUE})

// Physics body auto-created when Transform + Collider (+ optional Rigidbody) are all present

// Method 2: Spawn/build pattern (fluent API)
entity := rl.build(rl.with(rl.with(rl.spawn(world), 
    rl.Transform{position = {100, 200}}), 
    rl.Collider{shape = rl.Circle{radius = 30}}))
```

### Static vs Dynamic Bodies

```odin
// Static body (no Rigidbody needed)
ground := rl.create_entity(world)
rl.add_component(world, ground, rl.Transform{position = {640, 650}})
rl.add_component(world, ground, rl.Collider{shape = rl.Box{width = 1200, height = 50}})
// Implicit static body created automatically

// Dynamic body
player := rl.create_entity(world)
rl.add_component(world, player, rl.Transform{position = {640, 300}})
rl.add_component(world, player, rl.Rigidbody{body_type = .Dynamic})
rl.add_component(world, player, rl.Collider{shape = rl.Circle{radius = 30}})
// Body created when last required component is added
```

### Entity Removal

```odin
rl.remove_entity(world, entity)  // Physics bodies auto-cleaned via ECS callbacks
```

### Physics Wrappers (Entity-based)

```odin
rl.set_velocity(world, entity, {100, 0})
rl.apply_force(world, entity, {0, -500})
rl.apply_impulse(world, entity, {500, 0})
rl.set_position(world, entity, {320, 240})
vel := rl.get_velocity(world, entity)
```

### Custom Systems

```odin
// Update system
rl.add_system(engine.scheduler, "my_system", .Update, proc(world: ^rl.World, dt: f32) {
    // Game logic here
}, priority = 50)

// Render system
rl.add_render_system(engine.scheduler, "my_render", proc(world: ^rl.World) {
    // Rendering here
}, priority = 10)
```

### ECS Queries

```odin
// Flat iterator (simple, recommended for most cases)
for it := rl.query2(world, Position, Velocity); rl.query2_next(&it); {
    entity, pos, vel := it.entity, it.a, it.b
    // Process entity
}

// Archetype-level (for engine internals)
for arch in ecs.query(world.ecs, ecs.has(Position), ecs.has(Velocity)) {
    positions := ecs.get_table(world.ecs, arch, Position)
    velocities := ecs.get_table(world.ecs, arch, Velocity)
    for i in 0..<len(positions) {
        positions[i].x += velocities[i].x * dt
    }
}
```

---

## Code Style Guidelines

### Naming Conventions

- **Packages**: `snake_case` (e.g., `razorlight_core`, `rzl_commands`)
- **Types**: `PascalCase` (e.g., `Engine_Config`, `Transform`)
- **Procedures**: `snake_case` (e.g., `engine_create`, `add_component`)
- **Constants**: `SCREAMING_SNAKE_CASE` or `PascalCase` (e.g., `DEFAULT_CONFIG`)
- **Enum values**: `PascalCase` or `snake_case` depending on context
- **Files**: `snake_case.odin`

### File Organization

```odin
package razorlight_core  // Package name with module prefix

// Imports grouped: core/vendor first, then project
import "core:fmt"
import "core:math"
import "vendor:box2d"
import k2 "../libs/karl2d"

// ============================================================================
// Section Headers
// ============================================================================

// Public types first
My_Type :: struct {
    field: Type,
}

// Then public procedures
public_proc :: proc() {}

// Private procedures marked with @(private)
@(private)
internal_helper :: proc() {}
```

### Comments

- Use `//` for single-line comments
- Use block comments with `//` for section separators
- Document public APIs with purpose comments

---

## Testing

The project does not have a formal test suite. Testing is done through:

1. **Example projects** in `examples/` directory
2. **Manual testing** via `rzl run`
3. **Karl2D examples** in `RazorLight/libs/karl2d/examples/`

When making changes:

1. Build and run the original game: `./build.sh`
2. Test with example projects
3. Verify the animation editor still works: `rzl editor`

---

## Hot Reload

RazorLight supports hot-reload for faster iteration. Project structure for hot-reload:

```
my_game/
├── host/
│   └── main.odin          # Host executable (owns window, state memory)
├── game/
│   ├── main.odin          # Game library (exported functions)
│   └── game_state.odin    # ALL game state (no package globals!)
├── assets/
└── project.json
```

**Critical rule for hot-reload**: ALL game state must be in the `Game_State` struct. Package globals are reset on reload.

---

## Common Issues

### Build Errors

| Error | Solution |
|-------|----------|
| "odin not found" | Add Odin to PATH |
| Missing X11 headers | `sudo apt install libx11-dev` |
| Missing GL headers | `sudo apt install libgl1-mesa-dev` |
| NODEFAULTLIB error | Use `-extra-linker-flags:"/NODEFAULTLIB:libcmt.lib"` on Windows |

### Runtime Errors

| Error | Solution |
|-------|----------|
| "Failed to create window" | Check display server is running |
| Black screen | Verify `k2.present()` is called |
| No input response | Ensure `k2.update()` is called each frame |
| Physics objects fall through | Check collision shapes are properly sized |
| Entity not found after reload | Don't use package globals for hot-reload |

---

## Dependencies

### External (System)
- Linux: X11 or Wayland, OpenGL 3.3+, libudev
- Windows: Direct3D 11 or OpenGL, Windows SDK
- macOS: Cocoa, NSOpenGL

### Bundled/Vendor
- Box2D (Odin vendor package)

### Project Libraries
- Karl2D (in `RazorLight/libs/karl2d/`)
- yggsECS (in `RazorLight/libs/yggsECS/`)

---

## Editor Features

### Animation Editor

```bash
rzl editor
# or directly:
cd RazorLight/editor/animation_editor && odin run . -o:none -debug
```

Features:
- Sprite sheet viewing
- Animation frame editing
- Timeline editing
- Real-time preview
- Save/load animation files (`.anim` format)

---

## File Formats

### Animation Files (`.anim`)

Binary format containing:
- Animation metadata (frame count, duration, loop mode)
- Frame data (source rectangle, duration)
- Optional: embedded texture reference

---

## Security Considerations

- The `rzl_cli` and `razl_editor` binaries in the root are compiled artifacts
- Hot-reload loads shared libraries - only use with trusted code
- No sandboxing is implemented for plugins/scripts

---

## Additional Resources

- [Odin Language Documentation](https://odin-lang.org/docs/)
- [Box2D Documentation](https://box2d.org/documentation/)
- `TUTORIAL.md` - Comprehensive setup and usage guide
- `CLAUDE.md` - Quick reference for Claude Code
- `design_doc.txt` - Engine design philosophy and planned features

---

*RazorLight Engine - Built with Odin*
