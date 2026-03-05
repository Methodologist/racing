🏎️ Roblox Hover-Kart Racing Framework

<img width="1582" height="632" alt="image" src="https://github.com/user-attachments/assets/d3ed4d3c-21cd-4108-b50b-c4aa3b94351c" />

A robust, physics-driven hovercraft racing engine built for Roblox. This project features a custom raycast-based suspension system, full multiplayer race management, dynamic AI opponents, and a persistent e-commerce/garage system.

✨ Key Features
🛸 Custom Physics & Handling
Raycast Suspension (MagLev): Replaces standard Roblox wheeled vehicles with a custom 5-point raycast hover system. Features adjustable spring stiffness, damping, and asymmetric low-pass filtering for buttery-smooth terrain traversal.

Direct Angular Velocity Steering: Bypasses mass/inertia constraints for snappy, highly responsive steering that feels identical across different vehicle models.

Auto-Righting Gyroscope: Calculates local-axis tilt errors against smoothed ground normals to prevent side-pull on ramps and keep karts perfectly level.

Tiered Drift Mechanics: A Mario Kart-style drifting system that grants Mini, Super, and Ultra boosts based on drift duration and tier.

🎮 Cross-Platform & Mobile Optimized
StreamingEnabled Safe: Implements memory persistence for racer models while allowing the environment to dynamically load/unload, preventing memory crashes on low-end mobile devices.

Mobile-Specific Input Curves: Features custom thumbstick deadzones, exponential steering curves, and gentler input smoothing specifically triggered when touch devices are detected.

Dynamic UI: Includes an interactive minimap, dynamic camera FOV scaling based on speed, 3D world-space player tags, and mobile-friendly touch buttons.

🏁 Full Race Management Loop
Multiplayer State Machine: Handles lobby waiting, countdowns, active racing, and post-race cleanup.

AI Bot Backfilling: Automatically spawns and navigates AI karts to ensure a full racing grid if there are not enough human players.

Anti-Cheat Lap Tracking: A robust checkpoint service that calculates race progress using monotonic sequence tracking to prevent sequence breaking or lap skipping.

Out-of-Bounds Rescue: Detects if players fall into the void or get trapped under terrain and safely respawns them at their last valid checkpoint with zeroed momentum.

🍄 Item & Combat System
Position-Based RNG: Mystery boxes roll items based on the player's current race placement (e.g., 1st place gets defensive items, 8th place gets speed boosts).

Client-Side Projectile Prediction: Items like Green and Red shells are immediately simulated locally for visual responsiveness while the server handles the actual hit validation.

🏪 Persistent Garage Data
Utilizes DataStoreService to manage a virtual economy. Players earn coins from racing and track pickups to purchase and equip modular kart bodies and wheel attachments.

🏗️ Architecture & Core Scripts
KartController.client.lua: The core local heartbeat loop. Handles input, suspension physics, drifting, engine audio pitch-shifting, slipstream detection, and camera manipulation.

RaceManager.lua: The server-side authority. Manages the race state, tracks competitor progress, calculates live leaderboards, and handles race completion/rewards.

CheckpointService.lua: Object-oriented module that validates racer pathing and triggers visual/audio positive reinforcement feedback loops.

KartConfig.lua: A centralized, easily tweakable configuration module containing over 50 variables for fine-tuning game feel (downforce, grip, fov, audio ranges, boost power).

GarageUI.client.lua: Front-end shop interface that reads from replicated data to render 3D ViewportFrames of purchasable models.

🛠️ Setup & Installation
Clone the Repository: Download the source files.

Roblox Studio Integration: Use Rojo or manually sync the .lua files into their respective Roblox Studio directories:

ServerScriptService/Server -> Server-side scripts (RaceManager).

ReplicatedStorage/Shared -> Shared modules (KartConfig, CheckpointService, Remotes).

StarterPlayer/StarterPlayerScripts -> Client scripts (KartController, PortalVisuals).

Map Setup: Ensure your race track has a folder of parts named Checkpoint1, Checkpoint2, etc., and starting grid parts named Spawn1, Spawn2.

Publish: Enable Studio Access to API Services so the GarageStore DataStore can save player inventory and currency.

👨‍💻 Tech Stack
Language: Luau (Roblox Lua)

Paradigms: Client-Server Model, Object-Oriented Programming (OOP), Event-Driven Architecture

Math/Physics: Raycasting, Vector Cross/Dot Products, Linear Interpolation (Lerp), Spring-Damper Systems
