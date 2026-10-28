# Playing Byte Rush

## Controls

| Action | Keyboard / mouse | PlayStation | Xbox | Nintendo |
| --- | --- | --- | --- | --- |
| Menu navigation | Arrows / Tab / mouse | Left stick / D-pad | Left stick / D-pad | Left stick / D-pad |
| Select | Enter / Space / click | Cross | A | A |
| Back / resume from pause | Escape | Circle | B | B |
| Accelerate | W / Up | R2 | RT | ZR |
| Brake, then reverse | S / Down | L2 | LT | ZL |
| Steer | A, D / Left, Right | Left stick | Left stick | Left stick |
| Drift | Hold Space in a turn | Hold Cross | Hold A | Hold B |
| Capacitor boost | Left Shift | R1 | RB | R |
| Use held item | E | Square | X | Y |
| Recover | R | Triangle | Y | X |
| Pause / resume | Escape | Options | Menu | + |

Controller Options / Menu / + also starts a quick Grand Prix from the main menu and races again from Results. Confirm activates the focused menu choice. Nintendo uses A to confirm and B to go back in menus; during driving B is drift. The HUD, menu footer and Settings driving guide show the active device's labels. Meaningful keyboard/mouse or controller input switches prompts automatically. Controllers can be connected after launch or reconnected; losing the active pad pauses an unfinished race. Generic pads use positional face-button names. Recognition uses device names and vendor IDs; controllers emulating another brand may be identified as that exposed brand.

Controller axes and triggers are analogue. Settings include resolution, steering sensitivity, master volume, fullscreen and 4× antialiasing. Choose from 1280 × 720 through **3840 × 2160 (4K UHD)**. The 3D scene renders within the chosen pixel budget; fullscreen fits the monitor aspect ratio without stretching, and the interface stays sharp at the native desktop scale. Windowed mode fits the available desktop. No render preset above 4K is offered. The keyboard also has smoothed steering.

## Driving and racing

Hold drift while steering, then release it to spend the drift charge. Amber sparks unlock Mini Turbo after 0.45 seconds, cyan unlock Super Turbo after 1.3 seconds, and violet unlock Ultra Turbo after 2.4 seconds. A short hop begins a drift; reduced lateral grip allows a controlled slide. Boost changes acceleration, top speed, camera field of view and the exhaust trail.

The separate capacitor charges while drifting, drafting within 3–14 metres behind a rival, and taking a jump. At least 30% energy is needed for a capacitor discharge. Each discharge spends 30% for 1.5 seconds of boost. Releasing a drift does not spend capacitor energy.

Collect rotating cyan cubes for one inventory item. Turbo Cell gives a 2.2-second boost. EMP Burst slows rivals within 24 metres for 2.5 seconds. Hardlight Shield absorbs one EMP or electrical-hazard hit. Collected cubes respawn after five seconds. AI racers collect and use the same items.

The Keyboard Kingdom is a closed, elevated circuit through the Mechanical Keyboard, Motherboard Motorway and Cooling Chamber. It has solid luminous barriers, two jump ramps, three boost pads, electrical hazards, an inside service-bridge shortcut, animated fans and a cooling tunnel with a gentle crosswind. The shortcut rejoins the main road and remains subject to checkpoint rules.

All racers must pass 12 ordered checkpoints per lap, facing forward. Reversing across the finish, jumping ahead or repeatedly crossing the same gate cannot earn a lap. Recovery returns to the last grounded racing position without crediting checkpoints. Finished vehicles become non-blocking so the rest of the field can finish.


## Save files

On macOS, local records and settings live at:

`~/Library/Application Support/Godot/app_userdata/Byte Rush/`

`settings.cfg` stores preferences. `records.cfg` stores Time Trial personal bests. The integration test uses `validation_` filenames to avoid changing real preferences or records.
