# Doing all of this by hand

Every step the scripts perform, written out so you can do it without them —
and so you know what to look at when something breaks.

Paths below use these placeholders:

- `$GAME` — the folder holding `ProjectZomboid64.exe` and `projectzomboid.jar`
- `$INST` — the folder this instance will use for saves (anything you like)
- `$STEAM` — a Linux install of the same build, e.g.
  `~/.steam/steam/steamapps/common/ProjectZomboid/projectzomboid`

---

## 1. Confirm the two copies are the same build

Native Linux mode works by running your offline copy's `projectzomboid.jar`
with the Linux runtime from a Steam install. That is only safe if the jar is
the same file:

```bash
md5sum "$GAME/projectzomboid.jar" "$STEAM/projectzomboid.jar"
```

Identical checksums mean the two copies are byte-for-byte the same game and the
runtime swap is a no-op. Different checksums mean different builds — stop here
and use Wine mode instead (step 3b).

---

## 2. Graft the native Linux runtime

A Windows build ships a Windows JVM (`jre64/`) and `.dll` files. Linux needs the
`.so` files and a Linux JVM:

```bash
cp -a "$STEAM/natives" "$GAME/natives"
cp -a "$STEAM/jre64"   "$GAME/jre64-linux"
```

`jre64-linux`, not `jre64` — the Windows JVM is already sitting in `jre64/` and
you want to keep it for Wine mode.

You do **not** need `ProjectZomboid64` (the pzexe launcher) or
`ProjectZomboid64.json`. That launcher reads its JSON from the working
directory, and the Windows build already has a `ProjectZomboid64.json` there,
so the two would collide. Call `java` directly instead — which is exactly what
the game's own `.bat` does on Windows.

---

## 3. Launch the game with its own save folder

### 3a. Native Linux (fast path)

```bash
cd "$GAME"
export LD_LIBRARY_PATH="$GAME/natives:$GAME:$GAME/jre64-linux/lib:$LD_LIBRARY_PATH"
export LD_PRELOAD="$LD_PRELOAD:libjsig.so:libPZXInitThreads64.so"
export XMODIFIERS=            # stops input methods from eating keystrokes
export SDL_VIDEODRIVER=x11

jre64-linux/bin/java \
  -Djava.awt.headless=true \
  --enable-native-access=ALL-UNNAMED \
  --add-exports=java.base/jdk.internal.misc=ALL-UNNAMED \
  -Xms8g -Xmx8g \
  -Dzomboid.steam=0 \
  -Djava.library.path=natives/ \
  -XX:+UseZGC \
  -cp .:projectzomboid.jar \
  zombie.gameStates.MainScreenState \
  -cachedir="$INST" \
  -nosteam
```

Two arguments carry the whole idea:

- **`-cachedir=$INST`** — moves saves, options, mods, logs and server config out
  of `~/Zomboid` and into this instance. This is what keeps a Steam install
  untouched.
- **`-nosteam`** — runs the game without the Steam layer. Mandatory if you want
  to join a non-Steam server.

`-Xms8g -Xmx8g` replaces the 3 GB the shipped launcher uses. Build 42 runs out
of that heap and stalls.

### 3b. Windows build under Wine (fallback)

Use this when the builds do not match, or when you need the bundled Steam
emulator for something:

```bash
export WINEPREFIX="$INST/../prefix"   # its own prefix, not your default ~/.wine
wineboot -u

cd "$GAME"
wine jre64/bin/java.exe \
  -Djava.awt.headless=true \
  --enable-native-access=ALL-UNNAMED \
  --add-exports=java.base/jdk.internal.misc=ALL-UNNAMED \
  -Xms8g -Xmx8g \
  -Djava.library.path=./ \
  -XX:+UseZGC \
  -cp "./;projectzomboid.jar" \
  zombie.gameStates.MainScreenState \
  "-cachedir=Z:\\path\\to\\instance"
```

Note the differences: `;` separates the classpath instead of `:`, and
`-cachedir` needs a **Windows** path. `Z:` is mapped to the Linux root, so
`/mnt/games/X` becomes `Z:\mnt\games\X`.

### Carry your settings over

The instance starts with default graphics and keybinds. To reuse what you
already have:

```bash
mkdir -p "$INST"
cp ~/Zomboid/options.ini "$INST/"
cp -r ~/Zomboid/InputBindings "$INST/"
cp -r "$HOME/Zomboid/Sandbox Presets" "$INST/"
```

---

## 4. Run the dedicated server

The server is the same jar with a different main class:

```bash
cd "$GAME"
export LD_LIBRARY_PATH="$GAME/natives:$GAME:$GAME/jre64-linux/lib:$LD_LIBRARY_PATH"
export LD_PRELOAD="$LD_PRELOAD:libjsig.so"

jre64-linux/bin/java \
  -Djava.awt.headless=true \
  --enable-native-access=ALL-UNNAMED \
  --add-exports=java.base/jdk.internal.misc=ALL-UNNAMED \
  -Xms6g -Xmx6g \
  -XX:+UseZGC \
  -Dzomboid.steam=0 \
  -Djava.library.path=./:./natives/ \
  -cp ./:projectzomboid.jar \
  zombie/network/GameServer \
  -cachedir="$INST" \
  -servername amigos \
  -adminusername admin \
  -adminpassword 'something-long' \
  -port 16261 \
  -nosteam
```

Pass `-adminpassword` or the server stops on first run to ask for one on stdin.

The first run creates, under `$INST/Server/`:

| File | What it holds |
|---|---|
| `amigos.ini` | server options — ports, PVP, mod list, save interval |
| `amigos_SandboxVars.lua` | world settings — zombies, loot, time, mod options |
| `amigos_spawnregions.lua` | where players can spawn |
| `amigos_spawnpoints.lua` | exact spawn coordinates, if you set any |

The world itself lands in `$INST/Saves/Multiplayer/amigos`.

Look for these two lines to know it worked:

```
*** SERVER STARTED ****
*** Steam is not enabled
```

### Settings worth changing immediately

```ini
SaveWorldEveryMinutes=10   # ships as 0 — the world is only written on shutdown
BackupsPeriod=30           # the server's own periodic backup, also 0 by default
BackupsCount=10
UPnP=false                 # pointless on a VPN, and it stalls startup
SteamVAC=false             # no Steam here
PublicName=Something       # what players see
MaxPlayers=8
MapRemotePlayerVisibility=4  # 1=hidden 2=friends 3=friends+nearby 4=everyone
```

`SaveWorldEveryMinutes=0` is the dangerous default: on a power cut you lose
everything since the server started.

### Keep it alive past the terminal

Run in the foreground and you get the admin console, but the server dies with
the terminal. For a server that survives, use a systemd user unit:

```ini
# ~/.config/systemd/user/zomboid-server.service
[Unit]
Description=Project Zomboid dedicated server
After=network-online.target

[Service]
Type=simple
ExecStart=%h/.local/bin/zomboid-server
ExecStop=%h/.local/bin/zomboid-server -stop
TimeoutStopSec=120
Restart=on-failure

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now zomboid-server
```

`TimeoutStopSec=120` matters: the shutdown save must not be cut short.

---

## 5. Network and firewall

Get your VPN address:

```bash
ip -4 -brief addr show | grep '^zt'
zerotier-cli listpeers          # are your friends actually connected?
```

Open the ports **only on the VPN zone**:

```bash
sudo firewall-cmd --permanent --zone=ZeroTier --add-port=16261-16262/udp
sudo firewall-cmd --reload
sudo firewall-cmd --get-zone-of-interface=ztXXXXXXXX   # confirm the assignment
```

If the interface is not in that zone, the rule does nothing. Never put game
ports on the public zone.

---

## 6. Mods, by hand

An offline server has no Workshop. Nothing downloads by itself — not for you,
not for the people joining. Everyone needs the same folders on disk.

Copy them out of a Steam Workshop download:

```bash
cp -a ~/.steam/steam/steamapps/workshop/content/108600/<id>/mods/* "$INST/mods/"
```

Then find the mod's real ID — **the folder name is usually not it**:

```bash
cat "$INST/mods/<folder>/42/mod.info"      # Build 42 variant, this ID wins
cat "$INST/mods/<folder>/common/mod.info"
cat "$INST/mods/<folder>/mod.info"         # Build 41 layout
```

Build 42 mods can hold several variants in one folder. Folder `Furry` may
contain both `FurryMod` (B41) and `FurryModB42`. Use the one under `42/`.

Enable them in `$INST/Server/amigos.ini`, semicolons between IDs, dependencies
before dependents:

```ini
Mods=zdk;FurryModB42;SomeModThatNeedsFurry
WorkshopItems=
```

Leave `WorkshopItems=` empty. That field tells a Steam server what to download,
and there is nothing to download here.

Zip the folders and send them to everyone else. They unzip into their own
instance's `Zomboid/mods/`. On Windows that is `C:\Users\<name>\Zomboid\mods\`
— the profile root, **not** Documents.

A mod listed in `Mods=` that the server cannot load will make clients refuse to
connect with "missing mods", so check the server log after any change:

```bash
grep -E "loading |not found" server.log
```

---

## 7. Sandbox settings, by hand

`$INST/Server/amigos_SandboxVars.lua` is a Lua table, read **only when the
server starts**. There is no live reload — `/changeoption` works on the `.ini`,
not on this.

```lua
SandboxVars = {
    Zombies = 4,              -- 1=insane ... 6=none
    ZombieRespawn = 4,
    DayLength = 5,            -- 5 = 2 hours
    MultiHitZombies = false,
    Map = {
        AllowMiniMap = true,
        MapAllKnown = true,   -- whole map revealed
        MapNeedsLight = false,
    },
    ZombieLore = {
        Speed = 2,            -- 1=sprinters 2=fast shamblers 3=shamblers
        Toughness = 4,        -- 1=tough 2=normal 3=fragile 4=random
    },
}
```

Every option has its legal values in a comment right above it. Read the file
before guessing.

**Baked at world creation:** population, distribution and the start date are
written into the world the moment it is generated. Changing them later does
nothing to an existing world.

**Applied on restart:** loot, XP, zombie speed and toughness, day length, the
map options, and every mod-provided option.

### The comfortable way

Do not hand-edit 400 settings. Open the game, go to Solo → Custom Sandbox, set
everything with the game's own descriptions in front of you, save it as a
preset, and convert it. Presets are `~/Zomboid/Sandbox Presets/<Name>.cfg`, a
flat `Key=value` format where nested settings appear as `Section.Key=value`.
The server file nests them as real Lua tables, so the conversion walks the Lua
file and substitutes the value for every key the preset defines.
`zomboid-sandbox -import` does exactly that.

Mod-provided settings only exist in the server file **after** that mod has been
enabled and the server has started once. Import a preset before that and the
mod sections are silently skipped — enable the mods, start once, then import
again.

---

## 8. Backups, by hand

```bash
cd "$INST"
tar --zstd -cf backup-$(date +%F-%H%M).tar.zst \
    Saves/Multiplayer/amigos \
    Server/amigos.ini Server/amigos_SandboxVars.lua \
    Server/amigos_spawnregions.lua Server/amigos_spawnpoints.lua
```

A 150 MB world compresses to roughly 25 MB and takes a couple of seconds.

To restore, stop the server first, and move the current world aside rather than
deleting it:

```bash
mv Saves/Multiplayer/amigos Saves/Multiplayer/amigos.before-restore
tar --zstd -xf backup-....tar.zst -C "$INST"
```

A backup taken while the server runs can catch a file mid-write. Backups taken
with the server stopped are the trustworthy ones — worth recording in the
filename.
