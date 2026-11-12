# ICARUS

An incremental flight game for Roblox. Climb into a slingshot, pull it back, and throw yourself at the sun. Glide as far as you can. Every meter toward the sun pays coins when you land or your wings melt. Coins buy a harder throw, more lift, a cleaner glide, and wax that survives higher air.

The map is built when the server starts. Distance on the buoys matches the HUD: both measure studs forward from the slingshot, and the game calls those studs meters.

## Play it in Studio

You need [Rojo](https://rojo.rbx.dev/) 7 and the [Rojo Studio plugin](https://www.roblox.com/library/13916111004/Rojo).

From this folder, with Rojo on your PATH:

```bash
rojo serve
```

In Studio, connect the plugin to `localhost:34872`. Press **Play**.

To build a place file instead of a live sync:

```bash
rojo build -o ICARUS.rbxlx
```

Open `ICARUS.rbxlx` in Studio and press Play. The cliff, ocean, buoys, and sun are created by the server at runtime, so they do not show up in Edit mode.

### Toolchain

[Rokit](https://github.com/rojo-rbx/rokit) will install the versions pinned in `rokit.toml`:

```bash
rokit install
```

That gives you Rojo, StyLua, and Selene. Format and lint with:

```bash
stylua src
selene src
```

There is no Wally package. The game is plain Luau.

### Saving coins

Coins, best distance, and upgrade levels are stored with `DataStoreService` (`ICARUS_PlayerData_v1`). Saves retry, and a failed save stays queued for the next attempt.

In Studio, turn on **Game Settings → Security → Enable Studio Access to API Services** if you want progress to persist. With API access off, the server keeps the session in memory, warns once in the output, and the HUD says the session will not be saved. Leaving and rejoining in that mode starts you over. That is expected.

## Controls

| Action | Desktop | Gamepad | Touch |
| --- | --- | --- | --- |
| Climb into the slingshot | E (prompt) | X | Tap the prompt |
| Pull back | Hold Space or left mouse | Hold RT | Hold the launch button |
| Launch | Release | Release RT | Release |
| Leave the slingshot | X | B | Leave |
| Pitch | W / S, arrow keys, or mouse | Right stick | Drag the right side of the screen |
| Turn | A / D or mouse | Right stick | Drag |
| Upgrades | E at the wingwright | X | Tap the prompt |
| Close the shop | X on the card, or E again | — | Tap the dimmed background |
| Return after a flight | Click the button, or Enter | A | Tap the button |

A short tap does not launch. Hold until the bar moves, then release. A full pull aims higher as well as faster, which is the quickest way to find the heat.

## The loop

1. Walk onto the slingshot pouch and climb in. Your wings are already on.
2. Hold to draw the bands. Release to throw yourself downrange.
3. Point the nose to trade height and speed. Diving keeps you fast. A shallow nose goes farther. Pulling up climbs, and the heat bar wakes up once you cross the altitude in `Config.Heat`.
4. Dip back down and the wax cools. Stay up and the feathers darken, drip, and then come off. Flight cuts out and you drop. Terminal speed is capped so the fall does not kill you; the run still pays.
5. Touch the sea or an island and the server ends the run. Coins and best distance update, and a summary offers a ride back to the cliff.
6. Buy upgrades at the wingwright. Early levels are cheap. The price of each next level is `floor(BaseCost * CostGrowth ^ level)`.

The server stores the wallet and the upgrade levels. It also records how far your character actually moved and ignores a single-frame teleport beyond `Config.AntiCheat.MaxStepSpeed`. The client runs the glide so it feels immediate. Launch speed, drag, lift, and heat limits are sent by the server at the moment you let go, so a purchase applies to the next throw.

## Tuning

All of the numbers live in [`src/shared/Config.luau`](src/shared/Config.luau). [`UpgradeMath`](src/shared/UpgradeMath.luau) and [`FlightModel`](src/shared/FlightModel.luau) turn those numbers into prices, launch velocity, and the glide step. Flight gravity is separate from `Workspace.Gravity`, so walking on the cliff still feels like Roblox while a throw can actually climb.

A first careful glide, nose a little down, is meant to clear a few hundred meters: enough for several cheap upgrades, not a finished tree. Chasing the sun with a stock slingshot should warm the bar. Once launch power and lift are high, holding the climb melts the wings and usually pays less than a shallow glide, unless heat resistance has caught up.

## Project layout

```
default.project.json    Rojo tree
src/shared              Config, upgrade curves, glide step
src/server              Data, world, slingshot, run payout, wings, shop
src/client              Flight, heat visuals, HUD, shop, summary
```

`src/server/init.server.luau` and `src/client/init.client.luau` are the two entry scripts.

## What to try in Studio

Rojo can build the place, but it cannot fly the character. Worth a pass on a real client:

- Draw, release, glide, land, and see the coin payout match the distance.
- Climb until the wings melt, confirm you drop and still get paid, then buy heat resistance and survive a higher line.
- Buy one level of each upgrade and feel the next throw.
- Stop Play and start again with API access on, and confirm the coins are still there. With API access off, confirm the session banner and that a reconnect resets them.
- On a phone or the Studio device emulator: prompt, hold-to-launch, and drag-to-steer.
