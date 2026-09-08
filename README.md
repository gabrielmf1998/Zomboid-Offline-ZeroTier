# Zomboid Offline with ZeroTier

Run a **separate, self-contained Project Zomboid instance** with its own saves,
mods and dedicated server, and play it with friends over a ZeroTier network —
without a Steam connection and without touching the saves of a Steam install of
the same game.

Built and tested against **Build 42.20.4** on Fedora/Nobara with KDE Wayland.

## Why this exists

Project Zomboid keeps everything — saves, options, mods, server config — in one
folder, `~/Zomboid` by default. Point a second copy of the game at the same
folder and the two fight over it.

The game accepts a `-cachedir=` argument that moves that whole folder somewhere
else. Everything here is built on that one flag: a second instance that shares
nothing with the first.

The rest solves the problems that show up once you do that offline:

- the game's own launcher gives the JVM 3 GB, which Build 42 outgrows
- a non-Steam server can only be joined by a client that is also non-Steam
- with no Steam, Workshop mods never download by themselves, for anyone
- sandbox settings live in a Lua file the server only reads at startup
- pulling a mod out of a world that already used it makes the world unloadable

## What you get

| Command | What it does |
|---|---|
| `zomboid-client` | Launch the instance — native Linux, or Wine with `-win` |
| `zomboid-server` | Dedicated server, start/stop/status, optional systemd unit |
| `zomboid-mods` | Import Workshop mods, pick which the server enables, zip them for friends |
| `zomboid-sandbox` | Read, search and change world settings; import presets saved in-game |
| `zomboid-backup` | Snapshot world + config, rotate, restore, run on a timer |

Plus `friend-installer/install-client.sh`, a single script your friends run on
their own Linux box: it finds their game, builds a private Wine prefix,
unpacks the mod zip and writes a launcher that already has `-nosteam` in it.

## Quick start

```bash
git clone <this repo> && cd Zomboid-Offline-ZeroTier

mkdir -p ~/.config/zomboid-offline
cp config.example.sh ~/.config/zomboid-offline/config.sh
$EDITOR ~/.config/zomboid-offline/config.sh    # paths, RAM, server name

bash install.sh          # grafts the native runtime, links the scripts

zomboid-server           # first run creates the world and the config files
# Ctrl+C, then:
zomboid-mods -install    # copy Workshop mods into the instance
zomboid-mods -enable modA,modB
zomboid-sandbox -import New     # optional: a preset you saved in the game
zomboid-backup -auto     # 15-minute automatic backups
zomboid-server           # start it for real
```

Open UDP for the game **only on the ZeroTier zone**, never on the public one:

```bash
sudo firewall-cmd --permanent --zone=ZeroTier --add-port=16261-16262/udp
sudo firewall-cmd --reload
```

Friends connect to your ZeroTier address on port 16261, with no password.

## Documentation

- **[docs/MANUAL-SETUP.md](docs/MANUAL-SETUP.md)** — every step by hand, no
  scripts, with the reasoning behind each one
- **[docs/SCRIPTS.md](docs/SCRIPTS.md)** — what each script does and the
  commands it accepts
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** — the failures we
  actually hit, what the error looks like, and what fixes it

## Requirements

- A Project Zomboid installation you own
- `zstd`, `zip`, `unzip`, `wine` (only for the Windows fallback mode)
- ZeroTier, or any other VPN that gives everyone an address they can ping
- For native Linux mode: a Linux install of the **same build**, to source the
  runtime from. `install.sh` compares the jar checksums and warns if they differ.

## Scope

These scripts do not patch, crack or redistribute the game. They configure an
instance of a game you already have, point it at its own save folder, and run
its stock dedicated server in the offline mode the game itself ships with.

## License

MIT — see [LICENSE](LICENSE).
