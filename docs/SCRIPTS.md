# The scripts

All five read the same config file, looked up in this order:

1. `$ZOMBOID_OFFLINE_CONFIG`
2. `~/.config/zomboid-offline/config.sh`
3. `config.sh` next to the repo

Start from `config.example.sh`.

---

## `zomboid-client` — launch the game

```
zomboid-client            native Linux, non-Steam (default)
zomboid-client -win       Windows build under Wine, Steam emulator active
zomboid-client -saves     open the instance's save folder
zomboid-client -console   mirror the game output to the terminal
```

Anything else is passed to the game, so `zomboid-client -debug` works.

Native mode runs the Linux JVM from `jre64-linux/` with `natives/` on the
library path, and passes `-cachedir` and `-nosteam`. Wine mode runs the bundled
Windows JVM in its own prefix, and converts the save path to a `Z:\` Windows
path. Both write to the same instance folder, so you can switch freely.

Heap comes from `CLIENT_RAM`, replacing the 3 GB the shipped launcher uses.

---

## `zomboid-server` — the dedicated server

```
zomboid-server            start (admin console stays in this terminal)
zomboid-server -stop      stop, saving the world first
zomboid-server -status    up/down, plus the address to give your friends
zomboid-server -config    open the config folder
zomboid-server -password  print the generated admin password
zomboid-server -service   install a systemd user unit
```

Runs `zombie/network/GameServer` natively with `-nosteam`. On first start it
generates a 16-character admin password, stores it `chmod 600`, and prints it
once.

`-stop` sends SIGTERM, which triggers the game's own shutdown-and-save, then
waits up to 30 seconds for the process to actually exit.

`-status` reports the ZeroTier address rather than making you look it up.

Detecting whether the server runs uses `pgrep -f` against the **Java class
name**, not the script name — matching on the script name would match the
running script's own command line and always report "up".

---

## `zomboid-mods` — Workshop mods without Workshop

```
zomboid-mods                 what is installed, and what the server enables
zomboid-mods -install        copy every Workshop mod into the instance
zomboid-mods -install <id>   copy one Workshop item
zomboid-mods -enable a,b,c   set the server's mod list
zomboid-mods -package        zip the enabled mods for your friends
```

Build 42 mods can nest: `mod.info` may sit at the folder root, under `common/`
or under `42/` (some use `42.0/`), and one folder can hold several variants
with different IDs. The script always prefers the `42/` variant, because that
is the one Build 42 loads.

`-package` resolves each enabled ID back to its folder by reading `mod.info`,
because the folder name frequently is not the mod ID — folder `Furry` holds
`FurryModB42`, folder `PsychoKiller42` holds `PK42Psychopath`. Matching on the
folder name silently drops mods from the zip, and your friends then fail to
connect.

`-enable` prints a reminder that disabling a mod also wipes its sandbox
section.

---

## `zomboid-sandbox` — world settings

```
zomboid-sandbox                 the settings that matter most, with meanings
zomboid-sandbox -find <text>    search all ~440 settings by name
zomboid-sandbox -set K=v [...]  change settings
zomboid-sandbox -import [Name]  import a preset saved in the game
zomboid-sandbox -edit           open the file in $EDITOR
```

`-import` converts a `Sandbox Presets/*.cfg` (flat `Key=value`, nested keys as
`Section.Key`) into the server's nested Lua table, walking the Lua file and
substituting values in place so comments and structure survive. It reports how
many settings it applied and which the server does not have — those belong to
mods that are not enabled.

`-set` accepts dotted paths for nested settings, e.g.
`zomboid-sandbox -set ZombieLore.Toughness=1 Map.MapAllKnown=true`.

Both back up the file once as `*.before-preset` before the first change.

---

## `zomboid-backup` — snapshots

```
zomboid-backup             back up now
zomboid-backup -list       list backups with size and date
zomboid-backup -restore    restore the newest
zomboid-backup -restore <file>
zomboid-backup -auto       systemd timer, every 15 minutes
zomboid-backup -auto-off
```

Archives the world plus the four server config files with `tar --zstd`. Keeps
`BACKUP_KEEP` (default 20) and deletes older ones.

The filename records whether the server was running, because a backup taken
mid-session can catch a file being written. Backups taken with the server
stopped are the reliable ones.

`-restore` refuses to run while the server is up, and moves the existing world
aside with a timestamp instead of deleting it, so restoring the wrong file is
also undoable.

---

## `friend-installer/install-client.sh`

One script to hand to a friend on Linux, along with the mod zip. It finds their
game folder, checks for wine, creates a dedicated prefix, unpacks the mods,
writes a launcher with `-nosteam` already set, adds a desktop entry, and prints
the connection details.

```bash
bash install-client.sh                       # finds the game itself
bash install-client.sh /path/to/ProjectZomboid   # or tell it where
SERVER_IP=10.0.0.5 bash install-client.sh    # bake in your address
```
