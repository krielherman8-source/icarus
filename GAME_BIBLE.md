# ICARUS — Game Bible

Status of this document: written from the code on `main` at `3ad8e07` (the squash of PR #1). **This build has not been playtested in Studio.** Distances, flight times, and “a first run feels like…” notes below are design targets from `src/shared/Config.luau`, not measured sessions. Every item is tagged **[BUILT]** or **PROPOSAL — needs Granite's approval**.

Units: the flight code treats 1 stud as 1 displayed meter. Altitudes are studs above sea level (`SeaLevel = 4`).

---

## 1. Concept and pitch

**Logline.** **[BUILT]** You are thrown from a cliff slingshot toward the sun. Glide as far as you can. Every meter toward the sun pays coins when you land or your wings melt. Coins buy a harder throw, more lift, a longer glide, and wax that survives higher air. Then you throw again.

**Myth hook.** **[BUILT]** The Icarus story is the failure state, not a cutscene. Fly too high and the wings heat, darken, drip, and fall off. You drop. The run still pays, so melting is a lesson, not a wipe of the save. A plaque on the cliff reads “Fly for the sun. Don't melt.” The shop is named the Wingwright. There is no spoken story, quest, or character dialogue.

**Target audience.** **PROPOSAL — needs Granite's approval.** All ages, with a lean toward players who like short Roblox runs and incremental upgrades (roughly 9–16, plus anyone who enjoys one-more-try loops). The built game has no text or systems that assume an older audience. Copy is short and non-violent: you fall, you do not die as the fail state.

**Platform.** **[BUILT]** Roblox, PC and mobile. Keyboard, mouse, gamepad, and touch are all wired. The place is a Rojo project (`default.project.json`) that builds with `rojo build -o ICARUS.rbxlx`. The cliff, ocean, buoys, and sun are created when the server starts, so Edit mode looks empty until you press Play.

**Playtest gap.** **[BUILT]** as a fact about the project: nobody has flown this in Studio yet. Rojo can compile the place. It cannot tell us whether the glide is fun, the melt reads, or the first shop trip feels generous.

---

## 2. Core loop

**[BUILT]** One run, then the shop, then another run.

1. Spawn on the cliff. Feather wings are already welded on.
2. Climb into the slingshot (proximity prompt). Hold to pull the pouch back. Release to launch. A tap under 18% charge does not fire.
3. Glide toward +X, the sun. Pitch trades height for speed. Yaw turns you, but only forward progress is paid.
4. Heat rises once you cross the altitude band. Drop back down and it cools. Stay up and the wings melt, flight shuts off, and you fall (terminal speed 90).
5. Touch the sea or an island. The server ends the run, pays coins, updates best distance, and shows a summary. “Return to the cliff” teleports you home and regrows wings if they melted.
6. Spend coins at the Wingwright. The next launch uses the new levels. Purchases do not change a flight already in the air.

A run is capped at **90 seconds** (`Config.Run.MaxSeconds`). Leaving the server mid-flight still pays the distance the server had already seen.

**Session shape.** **PROPOSAL — needs Granite's approval.** Design intent, not a measured session: one careful first glide of a few hundred meters should buy several cheap levels, not finish a tree. A satisfying sitting is many short throws (well under 90 seconds each), not one long flight. Confirm or retune after the first Studio playtest.

---

## 3. Mechanics and systems

### 3.1 Slingshot launch and charge — **[BUILT]**

One slingshot, one occupant. The server owns the pull and the impulse. The client only reports whether the button is still held, and repeats that about every 0.25s. If those reports stop for **0.75s**, the pull resets instead of launching you by accident.

| Input | Desktop | Gamepad | Touch |
| --- | --- | --- | --- |
| Climb in | E on the prompt | X | Tap the prompt |
| Pull | Hold Space or left mouse | Hold RT | Hold “HOLD TO LAUNCH” |
| Launch | Release | Release RT | Release |
| Leave without launching | X | B | Leave |

Charge fills from 0 to 1 in **1.15 seconds** (`ChargeSeconds`). The pouch pulls back up to **9 studs**. Minimum charge to fire is **0.18**.

Full-charge speed is `100 + 6.2 × LaunchPower level` studs/s (`BaseSpeed`, `SpeedPerLevel`). A partial charge scales that by `0.42 + 0.58 × charge`, so even a full bar’s *minimum* accepted pull is 42% of full speed, and a half charge is 71% (`MinSpeedFraction`). Launch angle is **26° + 8° × charge**. A full pull leaves the cliff at **34°** and full speed. At level 0 that is **100** studs/s. At level 10 it is **162**. At level 30 it is **286**.

Walking still uses normal Roblox gravity. The glide uses its own gravity, **58** studs/s² (`Config.Flight.Gravity`), so a throw can actually climb. After a melt, the fall uses real workspace gravity with vertical speed capped at **90**.

### 3.2 Wings — **[BUILT]**

Three feather panels per side, welded to the torso (R15 or R6). They are visual. The numbers below are the glide model.

**Lift** (0–30) does not add a motor. It changes the path:

- Stall speed starts at **33** and drops by **0.6** per level, floored at **16**.
- While the nose is down, vertical speed is divided by `1 + 0.055 × level`. Level 10 sinks at about **0.65×**. Level 30 sinks at about **0.38×**.
- While the nose is up, vertical speed is multiplied by `1 + 0.035 × level`. Level 10 climbs at **1.35×**. Level 30 climbs at **2.05×**.

**Glide Efficiency** (0–30) multiplies drag by **0.93** per level, starting from **0.0022**, and never goes below **0.00035**.

| Level (both Lift and Glide) | Drag | Stall speed | Descent scale | Climb scale |
| --- | ---: | ---: | ---: | ---: |
| 0 | 0.00220 | 33 | 1.00 | 1.00 |
| 5 | 0.00153 | 30 | 0.78 | 1.18 |
| 10 | 0.00106 | 27 | 0.65 | 1.35 |
| 20 | 0.00052 | 21 | 0.48 | 1.70 |
| 30 | 0.00035 (the floor) | 16 | 0.38 | 2.05 |

Pitch is the flight path. Positive is nose up, clamped to **+38° / −78°**. Keyboard pitch is **68°/s**, yaw **78°/s**. Below stall speed the nose is forced down at **50°/s** and an extra **0.5×** flight-gravity penalty is applied. Speed is capped at **520**.

Controls while flying:

| Action | Desktop | Gamepad | Touch |
| --- | --- | --- | --- |
| Pitch | W / S, arrows, or mouse | Right stick | Drag the right side of the screen |
| Turn | A / D or mouse | Right stick | Drag |

Mouse pitch scale is **0.0024** rad per pixel, yaw **0.0016**. Touch is **0.0044** and **0.0034**. Pointer input is clamped to **48°** per frame so a wild swipe cannot flip you.

**Heat Resistance** is the third wing stat. It does not change lift or drag. See the next section.

### 3.3 Heat and melting — **[BUILT]**

Heat is a 0–max bar. At level 0, max is **100** and heat starts at **68** above the sea. The band is **110** studs tall, so the full melt rate is at altitude **178** before any Heat Resistance.

Inside the band, heat per second is:

`34 × riseScale × (0.28 + 0.72 × alpha)`

`alpha` is 0 at the bottom of the band and 1 at the top. `riseScale` is `1 / (1 + 0.045 × HeatResistance level)`.

Below the band, heat falls at `40 × (0.6 + 0.4 × depth)` per second, where `depth` reaches 1 when you are **40** studs under the start line. A full bar in cool air clears in a few seconds (40/s at the fast end, 24/s at the slow end).

| Heat Resistance | Band starts | Max heat | Rise scale | Heat/s at band floor | Heat/s at band top |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 68 | 100 | 1.00 | 9.5 | 34 |
| 5 | 108 | 130 | 0.82 | 7.8 | 28 |
| 10 | 148 | 160 | 0.69 | 6.6 | 23 |
| 20 | 228 | 220 | 0.53 | 5.0 | 18 |
| 30 | 308 | 280 | 0.43 | 4.1 | 14 |

Per level: **+8** start altitude, **+6** max heat, and the rise divisor above (`AltitudePerLevel`, `MaxHeatPerLevel`, `RiseReduction`).

At max heat the client paints the feathers from cream through ember to ash, bursts drip particles, and tells the server. The server breaks the welds, drops the panels, and sets them to ash. Flight lift turns off. You fall. Coins are still paid for the distance you had reached. Wings regrow when you return to the cliff or respawn.

Fall damage is suppressed during a run: the pilot is not the thing that breaks. The HUD shows “THE WAX IS WARMING”, then “WINGS MELTING”. The summary title for a melt is “THE WAX GAVE WAY”.

### 3.4 Coins per meter, with server validation — **[BUILT]**

**1 coin per meter** (`CoinsPerMeter = 1`), rounded down, paid once at the end of the run. Not per frame.

The server reads the character’s replicated position. Distance is forward progress only: `max(0, position.X − slingshotX)`. Sideways flight does not pay. Circling does not pay.

A single-frame jump farther than **640 studs/s × dt + 40** is clamped (`MaxStepSpeed`, `Slack`). The client’s HUD distance is for feel. The summary uses the server number.

Two gates:

- A hop that stops before **14m** with almost no speed is a failed launch. The server zeroes the distance and pays nothing.
- Otherwise, anything under **8m** also pays nothing (`MinDistance`), and the summary says the slingshot barely let go.

Best distance is the integer meters of your best paid run.

### 3.5 Upgrade shop — **[BUILT]**

The Wingwright is a stall on the cliff. Prompt: “Browse upgrades”. The same prompt again, the X button, or a tap on the dimmed background closes it. The board in the world shows level and price. The screen card shows the blurb and the before/after number.

Four upgrades, each level **0–30**. Price of the next level is:

`floor(BaseCost × CostGrowth ^ currentLevel + 0.5)`

The server rejects unknown ids, a buy before data is loaded, max level, and a short wallet. Spending and the level-up happen on the server, then a save is queued.

### 3.6 Saving and leaderstats — **[BUILT]**

DataStore name: **`ICARUS_PlayerData_v1`**. Key: **`p_<UserId>`**. Saved fields: `coins`, `bestDistance`, and the four upgrade levels. Values are forced to finite non-negative integers and clamped to each upgrade’s max.

Writes use `UpdateAsync`, up to **4** retries, on purchase, on run end, every **90 seconds**, on leave, and on `BindToClose`. A failed save stays queued. If the player earned coins before the load returned, the server keeps the higher coins, best distance, and levels, then saves that merge.

If Studio API access is off, or the store errors as disabled, progress stays in memory for that session. The output warns once. The HUD says “Studio session — progress stays on this server only.” Rejoining starts at zero. That is the built fallback, not a bug.

Leaderstats, on the player list:

- **Coins**
- **Best Distance**

There is no global ordered leaderboard.

---

## 4. World and theme

**[BUILT]** One course, generated in code from parts. No uploaded meshes, no terrain voxels, no streaming (`StreamingEnabled` is off).

- Launch cliff of slate and grass, wooden deck, spawn pad, braziers, gold chevrons pointing +X.
- Slingshot: pouch, two posts, two black bands. The posts are far enough apart that the feathers clear them, and they do not collide.
- Wingwright counter, red awning, price board.
- Ocean of glass-blue tiles from X **−500** to **12000**, about **3200** studs wide. Sea surface at Y **4**.
- Sand-capped rock islands scattered downrange (about 240m to 8800m).
- Distance buoys every **100m** out to **10000m**, labeled “100 m”, “200 m”, and so on. They do not collide.
- A neon sun about **4200m** downrange and **620** studs up, with a “THE SUN” billboard. It is a view target, not a finish line. The ocean and buoys continue past it.
- Lighting is late-afternoon (clock **16.35**), with a light atmosphere, a little bloom, and a warm grade. All of that is created at runtime.

Theme on screen: cream, gold, ink, wood, slate, sea. UI font is Gotham. The fantasy is wax, feathers, and a cliff, drawn with simple parts.

**Named world zones** (storm shelf, wax fields, a city under the sun, anything past the 10km buoys) are **PROPOSAL — needs Granite's approval**. Nothing in the code switches rules by region. Heat is altitude, not geography.

**Time of day, weather, and a day/night cycle** are **PROPOSAL — needs Granite's approval**. The server sets one afternoon and leaves it.

---

## 5. Progression and economy

**[BUILT]** Four tracks, 30 levels each. No rebirth, no prestige multiplier, no daily bonus, no offline earnings.

### Cost of the next level

Price to leave that level (level 0 means the first purchase). Computed from the formula above.

| From level | Launch Power (25 × 1.45^n) | Lift (30 × 1.47^n) | Glide Efficiency (40 × 1.48^n) | Heat Resistance (35 × 1.46^n) |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 25 | 30 | 40 | 35 |
| 1 | 36 | 44 | 59 | 51 |
| 2 | 53 | 65 | 88 | 75 |
| 3 | 76 | 95 | 130 | 109 |
| 4 | 111 | 140 | 192 | 159 |
| 5 | 160 | 206 | 284 | 232 |
| 9 | 708 | 962 | 1,363 | 1,055 |
| 14 | 4,540 | 6,600 | 9,677 | 6,999 |
| 19 | 29,103 | 45,305 | 68,712 | 46,427 |
| 24 | 186,540 | 310,983 | 487,912 | 307,990 |
| 29 (last, into 30) | 1,195,672 | 2,134,637 | 3,464,573 | 2,043,153 |

### Coins to reach a level from zero (one track only)

| Reach level | Launch Power | Lift | Glide | Heat |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 25 | 30 | 40 | 35 |
| 3 | 114 | 139 | 187 | 161 |
| 5 | 301 | 374 | 509 | 429 |
| 8 | 1,030 | 1,328 | 1,835 | 1,495 |
| 10 | 2,227 | 2,944 | 4,119 | 3,273 |
| 15 | 14,574 | 20,579 | 29,754 | 22,138 |
| 20 | 93,720 | 141,635 | 211,780 | 147,280 |
| 30 | 3,852,665 | 6,676,352 | 10,682,353 | 6,484,714 |

Because payout is 1 coin per meter, the “Reach level” column is also the total meters you must cash in to finish that track and nothing else.

### How a session is meant to feel

**[BUILT]** as targets in the config and the README. **Not playtested.**

- First upgrades cost **25–40** coins, so the first real flight (the README’s “a few hundred meters”) buys several levels if the player spreads them, or pushes one track to about level 5 (**300–500** coins).
- Levels in the high teens already cost tens of thousands per step. Level 30 is millions of meters on a single track. That is an aspirational cap, not a weekend goal. A Studio playtest may show it is too steep or too flat; both knobs are `BaseCost` and `CostGrowth`.
- Chasing the sun is supposed to get riskier as Launch Power and Lift go up: you can reach the heat band easily, and a melt can pay less than a shallow glide until Heat Resistance catches up. That interaction is designed. It has not been flown.
- Max run length **90s** keeps a single throw from becoming a screensaver. There is no energy timer and no “come back tomorrow” gate.

**Rebirths, prestige, and a second currency** are **PROPOSAL — needs Granite's approval**. Do not add them until the first curve has been flown and Granite wants a reason to reset.

---

## 6. Art and audio direction

### What is on screen now — **[BUILT]**

A blockout with a palette, not a finished art pass.

- World: slate cliff, grass cap, wood deck and slingshot, gold chevrons and buoy rings, cream posts, ink signs, glass-blue ocean, sand islands, neon sun.
- Wings: cream feathers, gold shoulder bone. Heat lerps cream → ember → ash. Drips use the built-in sparkle particle. Melted panels drop and are deleted after 8 seconds.
- UI: dark ink panels, gold strokes, cream type, a vertical heat thermometer, a charge bar, a run-summary card. Gotham / Gotham Bold.
- Camera while flying sits behind the nose, field of view 76, then returns to the default Roblox camera.
- Audio: **none.** No sounds are played. No music.

### Direction to aim at — **PROPOSAL — needs Granite's approval**

Keep it bright, readable, and mythic without gore. Wax and feathers, not fire and injury. The melt should read as craft failing (drips, curl, ash) rather than the character burning.

- A small set of wing meshes (3–4 tiers) that replace the wedge parts as Lift and Glide climb. Same silhouette from a distance so the heat color still reads.
- A slingshot that creaks and a launch whoosh. A soft heat hiss that tracks the bar. One sting when the wings let go. No jump-scare stinger.
- One looping piece of music on the cliff (lyre, wood, low drums) and a thinner version in the air, or silence in the air if Granite prefers the wind. Music off by default if it fights Roblox’s player volume.
- The sun stays a landmark. Do not put a face on it.
- Particles and meshes must stay cheap on mobile. The current part-ocean is already many tiles; a later art pass should not multiply that.

No audio ids and no mesh ids exist in the repo. Nothing here should be commissioned until Granite picks the tone.

---

## 7. Monetisation

**[BUILT]** There is none. No game passes, no developer products, no premium payout hook, no random items. Progress is coins from flying.

**PROPOSAL — needs Granite's approval.** If the game ever charges Robux, keep it fair, skippable, and within Roblox commerce rules.

Recommended, and the only monetisation this bible asks for:

- **Cosmetics only.** Wing dyes, a trail, slingshot band colors, a cliff title. They must not change speed, lift, drag, heat, or coins.
- **One game pass** that bundles a cosmetic set and nothing else. Price is Granite’s call after a playtest. Show the contents before purchase. No limited-time pressure.
- **No loot boxes, no random paid items, no wheels, no trading.** That avoids gambling rules and is the right call for a kid-friendly game.
- **No paid stat boosts, no paid heat immunity, no coin packs.** Selling meters fights the loop this game is. If Granite later wants a convenience product (an extra cosmetic slot, a second wing skin loadout), it still must not grant coins or levels.
- Robux only, through Roblox. No off-platform payment, no external links asking for money.
- The free loop — launch, fly, melt, upgrade — stays the whole game. A player who never spends Robux can reach every upgrade level the code allows.

Anything beyond cosmetics needs a new pass from Granite before it is designed, let alone scripted.

---

## 8. Roadmap

The only milestone with code behind it is the first one, and even that is unflown.

### Milestone 0 — Playable loop — **[BUILT]**, not playtested

Slingshot, glide, heat, melt, coins, four upgrades, save, leaderstats, cliff-to-sun course, HUD, shop, summary. `rojo build` succeeds. Studio playtest has not happened.

### Milestone 1 — Playtest and tuning — **PROPOSAL — needs Granite's approval**

Fly it in Studio on desktop and on the touch emulator. Write down real numbers: first-run distance, time aloft, whether the heat bar appears when you climb, whether a melt pays less than a safe glide, whether the first shop trip buys more than one upgrade. Then change only `Config.luau` until Granite is happy. Do not add systems in this pass.

Pass criteria to propose: a new player finishes three runs and one purchase without being told the controls beyond the on-screen hint, and can say why they melted or why they didn’t.

### Milestone 2 — Polish — **PROPOSAL — needs Granite's approval**

Sounds from section 6, a cleaner wing model, camera shake on launch only if it still feels fair, summary lines that match the tone Granite wants, and a pass on the cliff so the slingshot and the shop read without a wiki. Fix whatever the playtest broke. Still no rebirths and no Robux.

### Milestone 3 — Launch — **PROPOSAL — needs Granite's approval**

Publish the place, turn on DataStore API access for the live game, watch the first real saves, and keep the cosmetic-only rule unless Granite has signed a different monetisation note. Add a short in-experience control card if the playtest showed the hint is not enough. No limited-time event at launch.

### Milestone 4 — Post-launch — **PROPOSAL — needs Granite's approval**

Only after people are actually flying:

- More course, if 10km is something players reach. New scenery, not a new ruleset, unless Granite wants regions.
- A real global leaderboard for best distance (the player list already shows your own best).
- Cosmetic shop, still with no stat effect.
- Rebirths only if the level-30 cost curve has been lived in and Granite wants a reset. Not before.

Not proposed: PvP, combat, paying to skip heat, random crates.

---

## Where the numbers live

All of the figures in this bible that are marked **[BUILT]** come from `src/shared/Config.luau`, `src/shared/UpgradeMath.luau`, and `src/shared/FlightModel.luau`, with the world and the save path in `src/server/`. Change the config, then change this document. Do not tune the game from the bible alone.
