# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build and run (Windows)
odin run . -extra-linker-flags:"/NODEFAULTLIB:libcmt.lib"

# Or use the batch file
build.bat
```

Requires the Odin compiler to be installed and available in PATH.

## Architecture

This is a 2D physics defense game built in Odin using three core systems:

### Dependencies
- **Box2D** (`vendor:box2d`) - Physics simulation
- **karl2d** (`Libraries/karl2d`) - 2D rendering, windowing, input handling
- **yggsECS** (`Libraries/yggsECS`) - Entity-Component System

### ECS Components (main.odin)
| Component | Purpose |
|-----------|---------|
| `Position` | Screen coordinates (x, y) |
| `PhysicsBody` | Box2D body for rectangular entities |
| `CirclePhysics` | Box2D body for circular entities |
| `Sprite` | Visual color |
| `Player`, `Enemy`, `Bullet`, `Ground`, `Box` | Entity type markers |

### Game Systems (executed in order each frame)
1. `player_input_system` - Mouse position tracking, shooting input
2. `enemy_spawn_system` - Spawns enemies every 3 seconds
3. `physics_sync_system` - Syncs Box2D positions to ECS Position components
4. `collision_system` - Bullet-enemy collision detection, entity removal
5. `cleanup_system` - Removes off-screen entities
6. `render_system` - Draws all entities

### Coordinate System
Box2D uses Y-up coordinates while screen uses Y-down. The code converts between them:
- Box2D to screen: `screen_y = -box2d_y`
- Screen to Box2D: `box2d_y = -screen_y`

### Physics Configuration
- Fixed timestep: 1/60 second
- Sub-steps: 4 per frame
- Gravity: 900 units down
- Length units per meter: 40

### Game Loop Flow
```
main() -> k2.init() -> start() -> loop { k2.update() -> update(dt) -> render_system() -> k2.present() }
```

## Key Patterns

- **Entity spawning**: Create entity with `ecs.add_entity()`, create Box2D body, then add components
- **Entity removal**: Destroy Box2D body first with `b2.DestroyBody()`, then `ecs.remove_entity()`
- **Input debouncing**: Track previous frame state (`space_was_pressed`, `mouse_was_pressed`) to detect key transitions
- **ECS queries**: Use `ecs.query()` with `ecs.has()` predicates to iterate entities with specific components
