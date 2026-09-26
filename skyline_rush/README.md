# SKYLINE RUSH v8: endless runner with 9 tracks, 5 runners, 3 rideable vehicles (Godot 4.3+, PC)

Open Godot 4.3 or newer → Import → choose `project.godot` → press F5.

## What's new in v8
- **Soundtrack:** 10 original songs, one per track plus the menu, all built on the **same melody** in different styles:
  - menu: lo-fi
  - Sky Roads: synthwave
  - Lantern Festival: Chinese festive
  - Skate Park: pop-punk
  - Rain Alley: drum & bass
  - Neo Market: city-pop
  - Harbor: tropical house
  - Sakura: Japanese lo-fi
  - Carnival: chiptune
  - Turbo Highway: outrun

  Songs **crossfade smoothly** (2.2 s, equal-power) when you enter a new map. They are rendered by `tools/music/compose.py`.
- **New SFX pack:** 31 synthesised sounds for coins, jumps, landings, crashes, shields, vehicles, tricks, grinds and more (`tools/music/sfx.py`).
- **Lobbies:** every runner waits in their own detailed place, with lights, glossy floors and a reflection probe:
  - HOOPS: a street court at sunset.
  - ROCKY: a boxing gym.
  - PIXEL: a bedroom with toys, books, a desk, fairy lights and a night window.
  - ACE: a golf course.
  - CHILL: a neon rooftop.
- **HOOPS dribble:** now uses the Mixamo *Dribble* clip. The ball is held on the push-down, bounces off the floor and meets the hand again.
- **The fox is retired.** The roster is HOOPS, ROCKY, PIXEL, ACE and CHILL.
- **Buses:** parked and oncoming buses, with coins on the roofs of parked ones. There are also **bus ramps** you can run up and along.
- **Detailed obstacles:**
  - cars with windows, mirrors, grilles, plates and hubcaps
  - crates with planks
  - amps with feet and reflectors
  - lasers with emitters and cables
  - drones with arms, eye and LED
- **Coins:** fewer of them, smaller, and a new rimmed design with an embossed star.
- **Cinematic death camera:** it sweeps around to the side and never looks back at the vanished road.
- **Run animation:** slower, and synced to the running speed.
- **Wall run:** a Prince-of-Persia style wall run. The runner is tilted onto the wall with a fast stride and throws dust.
- **Moto / hover power-slide:** press **S** while riding to lay the bike down and skid under obstacles. The moto throws sparks.
- **Fullscreen by default** (F11 toggles it).
- **Chaos Games splash screen** at boot. Press any key or click to skip.

## What's new in v7
- **Detailed buildings:** every town building is now fully built:
  - stone plinth, corner pilasters, floor bands, and a cornice with a parapet
  - a shop floor with glass, mullions, a door and wall lamps, a striped awning with a valance, and an LED sign board
  - framed windows with sills, lintels, crossbars, shutters and flower boxes
  - balconies with railings and plants, windows on the end wall you see as you run in, and drain pipes
  - rooftops with water tanks, AC units, antennas, stair huts or roof gardens
- **Performance:** static scenery is merged into **one mesh per building or prop** (`world.gd` → `flush_batches`), which cuts draw calls by roughly 10–20×. There are also at most 10 real point lights, lighter rain, and no screen-space reflections.
- **Look:** a soft cartoon-realistic light ramp on the world shaders (`shaders/toon_light.gdshaderinc`) and ACES tonemapping. The **fog is depth-based**, so it's clear up close and only fades the far distance (from 110 m).
- **Camera:** a closer over-the-shoulder chase. It still rises with sky-highways and roofs.
- **No slow motion:** hit-stops, close-call slow-mo and the death slow-mo are gone. The Slow-Mo power-up is replaced by **Spring Shoes** (much higher jumps).
- **Crashes:** the runner bounces off the obstacle instead of clipping into it.
- **Menu:** a new showroom stage (a podium with a neon ring, an LED wall, spotlights and a skyline) replaces the live track, so nothing overlaps. There's a top navigation bar and a **YOUR UPGRADES** card showing every upgradable part.
- **Lobby animations:**
  - HOOPS now has a real dribble, with the ball synced to his hand.
  - ROCKY's bag hangs at fist height and swings when he punches it.
  - ACE's ball flies off the tee on every drive.
  - PIXEL's bean bag is fitted under her, so her legs no longer clip into it.
- **Run animation synced** to the ground speed, using each runner's real stride.
- **Animations:**
  - Skateboard: push-kicks, carving into lane changes, a crouch and grab in the air, and landing crouches.
  - Grapple: a swing pose with one arm on the rope.
  - Moto and hover: pitch nose-up in the air, with the rider tilting along.
- **Arcade skating:** every jump on the board is a named trick (Kickflip, Heelflip, 360 Shuv-It, Tre Flip, Varial, Impossible) with a **combo multiplier**. The board turns sideways for boardslides on rails.
- **Timed rides:** entering a vehicle map hands you your ride for **RIDE TIME** seconds (a new upgrade, 20 → 52 s), or until it's wrecked. **Ride tokens** on the track refill it or put you back on.
- **Warps:** you get a clear 140 m run-in after a warp. The warp tunnel is now narrow enough to stay inside its own lane.

## What's new in v6
### Controls: abilities on Q, E and double-tap SPACE
| Key | Ability | What it does |
|---|---|---|
| **Q** (or Shift) | **Dash** / **Air Dash** | On the ground: burst forward and smash crates/barrels/drones. In the air: dash forward, or sideways with A/D. |
| **E** | **Hook** | Uses whatever is in reach: grapples a green anchor, launches a quarter-pipe trick (Skate Park), or starts a wall run. The slot's label shows which. |
| **SPACE ×2** (quick double-tap) | **Sky Jump** | A rocket jump high enough to reach the sky-highways and floating power-ups. A slower second press is still a normal double jump. |
| S (in air) | Ground Slam | Unchanged. |

Time Shift, Phase and Magnet are no longer keys. They are now **power-ups on the track**:
**Magnet** (pulls coins), **Shield** (smash through anything), **Slow-Mo** and **2X** (double score and coins).
Active power-ups show as timers at the top right of the HUD.

### Vehicles and the garage
Your garage vehicle is **equipped automatically in its map**, and the rider sits or stands on it with a proper pose:
| Vehicle | Model | Map | Perks |
|---|---|---|---|
| Skateboard | `models/skateboard.glb`, trimmed into **10 boards** | SKATE PARK | grind rails, kickflips, quarter-pipe 360s, +10 % speed |
| Hover scooter | `models/scooter.glb` (purple) | HOVER HARBOR | floats over gaps, +18 % speed |
| Moto scooter | `models/scooter_1.glb` (orange) | **TURBO HIGHWAY** (new map) | +28 % speed |

Each scooter comes in **8 paint jobs** (Factory, Crimson, Ocean, Toxic, Sunset, Bubblegum, Gold Rush, Stealth), made by recolouring the model's own texture (`shaders/vehicle.gdshader`).
A crash while riding wrecks the vehicle instead of you (Vehicle Armor upgrade: up to 3 hits). The vehicle is rebuilt 5 s later.
Open the garage from the menu (**G**) to buy and equip boards and paints. The runner sits on the vehicle in the lobby preview.

### Upgrades and coins
Coins you collect are **banked into a wallet** that is saved between runs.
Spend them in **UPGRADES (U)** on: Magnet, Shield, Slow-Mo and 2X durations, Dash cooldown, Sky Jump cooldown, and Vehicle Armor (5 levels each).
Revives also cost wallet coins.

### Skate Park quarter-pipes
Curved quarter-pipes run along one edge of the road. Swerve into one from the outer lane (A or D), or press E: you ride up the curve, spin a **360 in the air** and land in the middle lane, clearing anything there.

### Maps and readability
- **Neon Market:** coffee shops (terrace, umbrella, giant steaming cup, chalkboard), barber shops (spinning barber pole, chair, mirror, scissors sign), food carts, LED blade signboards (NOODLES, ARCADE, SUSHI and more), window flower boxes, and rooftop water tanks and antennas.
- **Every town:** street lamps, benches, bins, hydrants, planters, vending machines and bus stops along the sidewalks.
- **Skate Park:** fun boxes with ledges and rails, stair sets with handrails, bleachers with a crowd, graffiti walls with tags, skaters, and a food truck.
- **TURBO HIGHWAY** (track 9): a sunset motorway with guard rails, green gantry signs, overpasses, billboards, gas stations, diners, palm trees and a city skyline. Traffic, trucks and oil barrels are the obstacles.
- **Trees:** `models/trees.glb` is trimmed into **10 trees** (oak, sakura, pine, palm, golden, birch, spruce, red maple, bamboo, bonsai), and each town gets the kinds that suit it.
- **Obstacles you can't confuse with scenery:** everything that can end a run has a glowing red-orange outline and a red danger line on the road in front of it. Jumpables have yellow/black hazard stripes, and slide gates have a red laser curtain with down-chevrons.
- **Holes are easy to see:** each one is a dark pit with walls and glowing red lips, with yellow/red chevrons across the road before it, warning beacons, and an on-screen **"GAP! JUMP · 35 m"** marker.
- **Camera:** the camera now follows the height of what you're standing on (sky-highways, car roofs) and pulls back, so you can see the road ahead from up high. Ordinary jumps are damped so the view doesn't bob. It also frames the quarter-pipe tricks.
- **More coins:** extra coin lines through empty lanes, arcs over barriers, gold on car roofs, and lines in the open stretches between rows. The safe coin trail is still there.

### Professional HUD
- **In game:** a score card, a zone progress bar with the next town and your speed, a coin counter, power-up timers, a vehicle card with armour pips, and three ability slots (Q / E / SPACE×2) with cooldown sweeps and context labels.
- **Menus:** a redesigned main menu, garage, upgrade shop, controls sheet, pause screen and game-over screen.

### Character textures
The five textures are installed in `characters/textures/`. The mapping was checked by rendering every model with every texture:
HOOPS = yellow, ROCKY = blue, PIXEL = pink, ACE = green, CHILL = purple.

### Dev tools
- `tools/smoke_test.gd` plays every track with an autopilot and saves screenshots to `tools/shots/`:
  `godot --rendering-method gl_compatibility -s res://tools/smoke_test.gd` (add `-- quick` for a fast headless logic run)
- `tools/render_ride.gd` renders every runner on every vehicle, to check the riding poses.
- The riding poses are in `POSES` in `characters/character_rig.gd`. The vehicle seat and handlebar points are in `scripts/vehicles.gd`.

---

There are no asset files: the art is built from shapes and code, and the music and sounds are generated when the game starts.

## Older notes (v5 and earlier)
> Kept for reference. Where they differ from the v6 notes above (keys, cores, board pickups), the v6 notes are current.

### Moves and abilities (v5)
| Key | Ability | What it does |
|---|---|---|
| Shift (ground) | **Dash** | A quick burst forward that smashes weak obstacles (crates, amps, drones). Jump during a dash for a higher, faster **dash-jump**. |
| Shift (in air) | **Air Dash** | A forward burst, or a sideways barrel roll if you hold A/D. You get one per jump, and it recharges when you land, wall-run or grapple. |
| Q, or push into a wall | **Wall Run** | Run along the neon glass walls for up to 3 s, skipping every lane obstacle. Space kicks you off the wall; A/D drops you off. |
| E | **Grapple** | Hook the green anchors (an on-screen marker shows when one is in range) to swing over wide gaps or reel up onto the glass sky-highways. Space lets go with a boost. |
| R | **Time Shift** | Slows the world (including patrolling drones) for 3 s while you keep full speed. |
| F | **Phase** | Become intangible for 1 s. Time it to ghost through one obstacle, even a car or speaker stack. |
| C | **Magnet Pull** | Yanks power cores and gold to you, even ones high up or in other lanes. |
| S (in air) | **Ground Slam** | Slam down, destroy weak obstacles around you, and bounce back up. |

**Power cores**, which you usually reach with Magnet Pull, grapples or double jumps:
- cyan **Shield**: blocks one crash
- pink **Surge**: lets you use one ability that is still on cooldown
- gold: +20 gold and double score for 8 s

You can hold up to 3 cores, and they orbit the fox.

**Flow meter:** tricks fill it. That includes close calls, smashes, wall runs, grapples, phasing through obstacles and dash-jumps. At 35% you get +1 to your score multiplier, and at 70% you get +2.

## The map
- **Sky roads:** a neon road that curves and dips into the distance, with gaps you jump over or grapple across.
- **Wall-run sections:** glass walls with gold you can only reach by running on the wall.
- **Sky-highways:** glass roads high above the main road, full of gold and reached by grappling.
- **Obstacles:** drones that sweep across the lanes, breakable crates, cars you can run on top of, speaker stacks, laser gates, boost pads and portals.
- **Zones:** the sky changes every 900 m. Pink Dawn → Neon Dusk → Midnight Aurora (stars, stronger neon glow) → Crystal Skies.
- **Scenery:** giant spinning vinyl records, floating islands, searchlight beams, speaker towers and a giant speaker arch, all pulsing to the music.

## Camera and game feel
- **Spring kicks:** jumps, landings, dashes, slams and hits nudge the camera, and it springs back with a slight bounce.
- **Hit-stop:** the game freezes for a split second when you smash something, and slows briefly on close calls.
- **Context framing:** the camera tilts during a wall run, pulls back to show a grapple, looks down during a slam, and moves in closer during Time Shift.
- **Field of view** widens with speed, flow and dashes, and the camera leans into the road's curves.
- **Screen effects:** a radial speed blur, colour fringing at the edges of the screen, a colour tint for Time Shift and Phase, and speed lines.

## Other controls
A/D change lane, W/Space jump (hold for higher, press again in the air for a double jump), S/Ctrl slide, Esc pause, M music, F11 fullscreen. Gamepads are supported. Keys 1–6 also trigger the abilities.

## Files
- `scripts/main.gd`: abilities, flow meter, scoring, zones
- `scripts/world.gd`: map generation
- `scripts/player.gd`: movement
- `scripts/camera_rig.gd`: camera
- `scripts/hud.gd`: UI
- `scripts/audio.gd`: generated music and sound
- `scripts/fx.gd`: particles

You can tune the cooldowns and durations in the `ABILITIES` list at the top of `main.gd`.

## Tracks (v3)
Choose a starting track on the menu with A/D or the arrow buttons. After that, the town changes every 750 m and the new town arrives from the horizon.

| # | Track | Look |
|---|---|---|
| 1 | Sky Roads | the original neon sky-road over a sea of clouds |
| 2 | Lantern Festival | pastel shophouses, strings of red lanterns overhead, market stalls, people, confetti, a skyline with a needle tower |
| 3 | Skate Park | sunny plaza, graffiti half-pipes, trees, pennant flags, roller-coaster arches |
| 4 | Neon Rain Alley | night, rain, wet reflective street (reflections need the Forward+ renderer), neon signs, glowing lanterns, a pagoda on misty peaks |
| 5 | Neon Market | stacked cartoon buildings, neon panels, AC units, power lines, a glowing pink bike lane |
| 6 | Hover Harbor | golden-hour sky city with floating platforms, cranes, beacon pillars and hover pods |
| 7 | Sakura Heights | cherry trees, torii gates, stone lanterns, timber houses, falling petals, snowy mountains |
| 8 | Candy Carnival | striped tents, giant lollipops, balloons, light-bulb strings, Ferris wheels |

Night towns place real point lights at their signs, lanterns and lamps. A soft light also follows the fox in dark zones.

**Warp tunnels** sit over one side lane only, so entering is your choice. An on-screen marker shows where each one goes ("WARP TO …"). Switch into that lane to warp to that town (+300 points), or stay in the other lanes to keep running.

All the town models live in `scripts/themes.gd`.

## v4 changes
- **Fair paths:** every row has a guaranteed clear lane. It is either empty or needs just a jump or a slide, and it never moves more than one lane from the previous row's clear lane. A **gold coin trail** leads you into it: arcs mean jump, low coins mean slide, and coins on a rail mean grind. Drones never patrol into the clear lane. A bot that only follows the coins ran through all 8 towns without dying.
- **More forgiving:**
  - smaller hitboxes
  - short grace periods after wall runs, grapples and warps
  - clipping the side of an obstacle makes you stumble instead of crashing
  - no ground obstacles under the sky highways
- **Revive:** when you crash with enough gold, press **R** (or click the button) to continue. It costs 100 gold, and the cost doubles each time.
- **Skate Park:**
  - grab the floating **skateboard** (30 s). You ride faster, and your first crash only breaks the board
  - jump onto **metal rails** to **grind**, with sparks and bonus points
  - hit **launch ramps** for big air (a kickflip bonus on the board)
  - the side walls turn into graffiti skate walls for wall rides
- **Pop-up traps** (Lantern Festival, Neon Rain, Neon Market, Hover Harbor, Sakura, Carnival): barriers and spike strips rise out of the road, and crates drop from the sky. Flashing red chevrons, or a red circle for drops, show exactly where each trap will appear. Traps are never placed in the coin lane.

## v5: characters and shared animations
On the menu, press **Q / E** (or click the arrows) to pick a runner. Mixamo characters wait in a **lobby** doing their hobby. Your pick is saved.

| Runner | Model file | Lobby hobby and props |
|---|---|---|
| HOOPS | Medium_Run.fbx | dribbling, with a bouncing ball. Uses the lean clip until **Dribble.fbx** is added |
| ROCKY | Punching_Bag.fbx | punching bag on a frame |
| PIXEL | Gaming.fbx | bean bag, TV and console |
| ACE | Golf_Drive.fbx | golf drive / bad shot (alternating), club in hand, ball on a tee |
| CHILL | Leaning_On_A_Wall.fbx | leaning on a brick wall, glowing headphones |

**How the retargeting works:** all the FBX files use the same Mixamo skeleton (65 bones). `tools/bake_animations.gd` pulls every clip into one shared library, `characters/animations.res`. It removes the forward drift so runs stay in place and sets which clips loop. Each character then loads that library and scales the hip height to its own skeleton, so **every runner plays every animation**.

**In-game clips:**

| When | Clip |
|---|---|
| Running (speeds up with the game) | Medium Run |
| Lane changes | Running Arc / Running Arc 1 |
| Jump | Running Jump |
| Double jump | Jump 1 |
| Slide | Running Slide |
| Dash | Soccer Tackle, played fast (a slide-tackle through crates) |
| Air dash, slam, riding the skateboard | Dash pose |
| Stumble | first part of Sweep Fall |
| Crash | Fall Flat |

### Adding more
- **New clips** (Dribble.fbx, Run_Forward.fbx and so on): put the FBX in `characters/source/` and run
  `godot --headless -s res://tools/bake_animations.gd`
  Dribble becomes HOOPS's hobby automatically. Run_Forward is baked as `run_fast`, but the game doesn't use it yet. To add a new clip name, edit `NAMES` in the bake script.
- **Textures:** `characters/textures/<runner>.jpg` (hoops, rocky, pixel, ace, chill). They are applied automatically.
- **New characters:** add an entry to `CHARACTERS` in `characters/character_rig.gd` with its FBX, hobby clip(s), texture name and prop.
