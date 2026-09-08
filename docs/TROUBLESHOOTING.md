# Troubleshooting

Every failure here was hit for real while building this, with the exact
symptom and what actually fixed it.

---

## "The server failed to respond" when a friend joins

The connect screen also shows *"This Steam client can only connect to Steam
servers."*

**Cause.** Their client is running in Steam mode while the server runs
`-nosteam`. In Steam mode the game routes the connection through Steam's
networking instead of sending UDP to the address you typed, so it never
reaches the server. The network is fine; the two halves just do not speak.

**Fix.** The client must launch with `-nosteam` too.

- Linux/Wine: add `-nosteam` to the game arguments.
- Windows shortcut: append ` -nosteam` to the Target, after the closing quote.
- Windows batch file: `start "" "ProjectZomboid64.exe" -nosteam`
- Heroic Games Launcher: game settings → **Advanced** → **Game Arguments**.
  It saves automatically. The same value lands in
  `~/.config/heroic/GamesConfig/<AppName>.json` as `"launcherArgs"`.

**Check the network separately** before chasing this:

```bash
zerotier-cli listpeers     # is their address listed, with a sane latency?
ping <their VPN address>
```

---

## Client crashes with "Sorry, an unexpected error occurred"

`console.txt` ends with:

```
WorldDictionaryException: [SpriteConfigs] Missing dictionary script on client: Base.SomeItem
WorldDictionary: Cannot load world due to WorldDictionary error.
```

**Cause.** A mod that adds items was removed from a world that had already used
it. Project Zomboid records every item script a world has ever seen in its
world dictionary. Remove the mod and that record points at nothing, so the
client refuses to load the world at all.

**Fix.** Put the mod back in `Mods=` and restart. Find which mod owned the
missing script with:

```bash
grep -rl "Base.SomeItem" "$INST/mods"
```

**This is not recoverable any other way.** On a world already in use, a mod
that adds items is part of the save's structure. If you want it gone, you need
a new world.

**What to do instead:** leave the mod enabled and neutralise it through the
sandbox. Set its damage multipliers to `1.0`, turn its features off. The items
keep existing so the dictionary stays happy, and the mod stops affecting play.

Check before removing anything:

```bash
find "$INST/mods/<mod>" -path '*media/scripts*' -type f
```

Any hits mean that mod adds items, and removing it will break the world.

---

## Sandbox tuning silently reverted

You set a mod's options, later toggled that mod off and back on, and your
values are the author's defaults again.

**Cause.** Starting the server without a mod **deletes that mod's section**
from `SandboxVars.lua`. Re-enabling it recreates the section from the mod's own
defaults. Your edits are not merged back.

**Fix.** After any change to `Mods=`, re-check the sandbox. Treat mod list and
sandbox as one operation, never two.

---

## A mod will not load: "required mod X not found"

Several distinct causes, all with the same message:

| Cause | How to spot it | Fix |
|---|---|---|
| Author capped the version | `versionMax=42.13` in `mod.info` while you run 42.20 | none — the mod is genuinely too old |
| Build 41 layout | only a root `mod.info`, no `42/` or `common/` folder | none — it is a B41 mod |
| Dependency uses the B41 ID | `require=FurryMod` when the loaded mod is `FurryModB42` | edit `42/mod.info` to require the B42 ID |
| Wrong ID in `Mods=` | folder name used instead of the real ID | read `42/mod.info` for the actual `id=` |

Inspect all variants a folder holds:

```bash
find "$INST/mods/<folder>" -maxdepth 2 -name mod.info \
  -exec sh -c 'echo "--- $1"; grep -iE "^(id|name|require|versionMax)=" "$1"' _ {} \;
```

---

## Log noise that is not a problem

These appear on every Build 42 server, with or without mods. Count them across
two runs before worrying — identical counts mean they are structural:

- `Property Name not found: ladderW / ladderS / ladderE / ladderN / WindowShape`
  — leftover Build 41 tile aliases, emitted before any mod loads
- `duplicate texture d_streetcracks_1_*` — base-game tiles declared twice
- `No packet handler for type: ...` — a long list printed on every connection
- `NoSuchFileException: .../mods/<mod>/common/media/AnimSets` — the animator
  probing for optional folders a mod does not ship
- `Sanitizing container name 'Large Bucket'` — base-game script warning

---

## The server exits with code 143

`143` is `128 + 15`: it received SIGTERM. Nothing crashed. Check the tail of the
log for a clean shutdown:

```
Saving finish
The id_manager_data.bin file is saved
Shutdown handling finished
```

If those lines are there, the world was saved properly.

The usual reason is that the server was started from a terminal or a background
job that then ended. Install the systemd unit (`zomboid-server -service`) for a
server that outlives the shell that started it.

---

## Damage numbers look absurd

A floating "2000" over a zombie is almost certainly a HUD mod's display scale,
not real damage. Project Zomboid's internal damage values are small floats
around `0.5`–`3.0`; mods multiply them to make a readable number, and the
multiplier is often a **per-player slider**, which is why two people see wildly
different numbers for the same hit.

Real damage comes from elsewhere. Check the sandbox for multipliers a mod added:

```bash
zomboid-sandbox -find damage
```

One-hit kills with a decent one-handed weapon are vanilla behaviour, especially
with `ZombieLore.Toughness = 4` (random), which makes a share of zombies
fragile. `Toughness = 1` makes them all tough.

---

## Ports are open but nobody can connect

```bash
firewall-cmd --get-zone-of-interface=ztXXXXXXXX   # must be the VPN zone
firewall-cmd --zone=ZeroTier --list-ports         # must list 16261/udp
ss -lunp | grep 16261                             # server must be listening
```

A rule on the wrong zone does nothing. Also confirm the server is up at all —
it is easy to edit config for an hour and forget it was never restarted.

---

## Changes did not take effect

Almost always a missing restart. What is read when:

| Where | When it is read |
|---|---|
| `<server>.ini` | server start |
| `<server>_SandboxVars.lua` | server start |
| `Mods=` | server start |
| population / distribution / start date | **world creation only** |
| client `options.ini` | game start |

There is no live reload for sandbox settings. `/changeoption` only touches
`.ini` options.
