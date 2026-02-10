# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Original game (root)
# Linux/macOS
./build.sh              # Debug build
./build.sh release      # Release build
./build.sh size         # Size-optimized build

# Or directly:
odin run .

# Windows
build.bat

# Or directly:
odin run . -extra-linker-flags:"/NODEFAULTLIB:libcmt.lib"

# Demo game (RazorLight showcase)
cd demo && ./build.sh
# Or directly:
cd demo && odin run . -o:none -debug
```

Requires the Odin compiler to be installed and available in PATH.

### Linux Dependencies
```bash
# Ubuntu/Debian
sudo apt install build-essential libx11-dev libgl1-mesa-dev libudev-dev

# Fedora
sudo dnf install gcc libX11-devel mesa-libGL-devel systemd-devel
```

## Project Structure

### RazorLight Engine (`RazorLight/`)
Self-contained 2D game engine library with bundled dependencies:

```
RazorLight/
├── razorlight.odin         # Facade - single import for most features
├── libs/
│   ├── karl2d/             # 2D rendering, windowing, input
│   └── yggsECS/            # Entity-Component System
├── core/                   # Types, World, Time
├── physics/                # Box2D wrapper
├── systems/                # Scheduler + built-in systems
│   └── builtin/            # Physics sync, shape renderer
├── input/                  # Action mapping system
├── debug/                  # Debug draw, logger, profiler
└── editor/ui/              # Immediate-mode UI widgets
```

**Usage pattern:**
```odin
import rl "../RazorLight"              // Engine facade (types, drawing, physics, input)
import ecs "../RazorLight/libs/yggsECS" // ECS queries (polymorphic - can't be re-exported)
```

Note: `ecs.query()`, `ecs.has()`, `ecs.get_table()`, `ecs.add_component()` are polymorphic procs that cannot be aliased across packages. Import yggsECS directly for ECS queries in systems.

### Original Game (`main.odin`)
2D physics defense game using the old `engine/` + `Libraries/` layout (kept for reference).

### Demo (`demo/`)
Bouncing balls demo showcasing RazorLight engine features.

## Architecture

### Dependencies
- **Box2D** (`vendor:box2d`) - Physics simulation
- **karl2d** (`RazorLight/libs/karl2d`) - 2D rendering, windowing, input handling
- **yggsECS** (`RazorLight/libs/yggsECS`) - Entity-Component System

### RazorLight Engine Loop
```
engine_create() -> loop { engine_update() -> engine_render() } -> engine_destroy()
```

Inside `engine_update()`:
1. Pre_Update phase (input processing)
2. Update phase (game logic)
3. Fixed_Update phase (physics step + sync, runs at fixed timestep)
4. Post_Update phase (cleanup)

Inside `engine_render()`:
1. Clear screen
2. Render phase systems (shape_render built-in, then custom)
3. Debug rendering (if enabled)
4. Present

### Coordinate System
Box2D uses Y-up coordinates while screen uses Y-down. The code converts between them:
- Box2D to screen: `screen_y = -box2d_y`
- Screen to Box2D: `box2d_y = -screen_y`

### Physics Configuration
- Fixed timestep: 1/60 second
- Sub-steps: 4 per frame
- Gravity: 900 units down
- Length units per meter: 40

## Key Patterns

- **Entity spawning (composable)**: Create entities with `rl.create_entity()`, then add components individually with `rl.add_component()`. Physics bodies are auto-created when Transform + Collider (+ optional Rigidbody) are all present.
- **Static bodies**: Just add `Transform` + `Collider` (no Rigidbody needed) — an implicit static body is created automatically
- **Dynamic bodies**: Add `Transform` + `Rigidbody{body_type = .Dynamic}` + `Collider{shape = rl.Circle{radius}}` — body created when last component is added
- **Entity removal**: `rl.remove_entity()` (physics bodies auto-cleaned via ECS callbacks)
- **Entity physics wrappers**: `rl.set_velocity()`, `rl.get_velocity()`, `rl.apply_force()`, `rl.apply_impulse()`, `rl.set_position()` — operate on entities, not body IDs
- **Custom systems**: Register with `rl.add_system()` for update or `rl.add_render_system()` for render
- **Shape rendering**: Add `Transform` + `Shape_Component` to entities for automatic rendering by the built-in shape render system
- **ECS queries (flat iterator)**: Use `rl.query2(world, TypeA, TypeB)` + `rl.query2_next` for simple iteration without double loops
- **ECS queries (archetype)**: Use `ecs.query()` with `ecs.has()` predicates for archetype-level iteration (engine internals)
- **Spawn/Build pattern**: `rl.build(rl.with(rl.with(rl.spawn(world), Transform{...}), Collider{...}))` — fluent entity builder with auto physics init
