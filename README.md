RazorLight ⚡
RazorLight is a fast, modern 2D game engine written in Odin,

built around a hot-reloadable ECS architecture with performance and

iteration speed as first-class goals.
It combines Odin's low-level power with a data-oriented design, while

aiming to support Lua scripting for rapid gameplay iteration and

tooling.

✨ Features
·	🧠 ECS-First Architecture
o	Built on yggsECS
o	Data-oriented, cache-friendly design
o	Systems over inheritance
·	🔥 Hot Reload
o	Reload systems and gameplay logic at runtime
o	Fast iteration without restarting the engine
·	🎮 2D Rendering
o	Powered by Karl2D
o	Clean, minimal rendering pipeline
o	Designed for pixel-perfect and modern 2D games
·	🧱 Physics
o	Uses Box2D
o	Stable, battle-tested 2D physics
·	🐍 Lua Scripting (Planned)
o	Optional high-level gameplay scripting
o	Safe sandboxed runtime
o	Designed to coexist with Odin systems
·	⚙️ Odin-Native
o	No C++ or heavy abstractions
o	Predictable performance
o	Explicit memory management

🧩 Tech Stack
Component   Library

Language    Odin

ECS         yggsECS

Rendering   Karl2D

Physics     Box2D

Scripting   Lua (planned)

🎯 Goals
RazorLight is designed with these principles in mind:
·	Fast iteration over editor bloat
·	Explicit over magical
·	Runtime reloadability
·	Engine as a framework, not a black box
·	Simple core, extensible systems
Best suited for: - Indie 2D games - Simulation-heavy games - Strategy,

roguelikes, and sandbox games - Developers who prefer code-first

workflows

🚧 Project Status
⚠️ Early Development / Experimental
RazorLight is actively evolving. APIs may change, and some features

(like Lua integration and tooling) are still under development.
Not production-ready yet --- but moving fast.

📂 Project Structure (WIP)
RazorLight/
├── core/          # Engine core
├── ecs/           # ECS integration (yggsECS)
├── render/        # Karl2D rendering layer
├── physics/       # Box2D bindings & systems
├── scripting/     # Lua integration (planned)
├── assets/        # Asset loading & management
└── examples/      # Sample games & demos


🛠 Building
Requirements
·	Odin compiler (latest)
·	OS: Linux / Windows (macOS TBD)
odin build .

More detailed build instructions will be added as the engine stabilizes.

🧠 Inspiration
·	Data-oriented design
·	Handmade-style development
·	Bevy (architecture, not implementation)
·	Love2D & Defold (simplicity)
·	Custom in-house engines

📜 License
MIT License

Free to use, modify, and ship games with.

🤝 Contributing
Contributions, ideas, and experiments are welcome.
If you enjoy: - ECS architecture - Odin - Engine internals - Runtime

systems
You'll probably feel at home here.

🚀 Name Origin
RazorLight represents sharp, minimal design --- cutting away

unnecessary abstractions while staying lightweight and fast.
