# Zomboid Offline with ZeroTier -- configuration
#
# Copy to ~/.config/zomboid-offline/config.sh and edit.
#   mkdir -p ~/.config/zomboid-offline
#   cp config.example.sh ~/.config/zomboid-offline/config.sh

# Folder holding ProjectZomboid64.exe / projectzomboid.jar / media/
GAME_DIR="/mnt/games/Project.Zomboid.v42.20.4/ProjectZomboid"

# Where this instance keeps its own saves, mods, options and server config.
# This is what makes the instance separate from your Steam ~/Zomboid.
INSTANCE_DIR="/mnt/games/Project.Zomboid.v42.20.4/Zomboid"

# Server world name. Config lands in $INSTANCE_DIR/Server/$SERVER_NAME.ini
SERVER_NAME="amigos"
SERVER_PORT=16261

# Heap size. The game ships with 3 GB, which is not enough for Build 42.
CLIENT_RAM="8g"
SERVER_RAM="6g"

# Native Linux runtime, copied out of a Steam install of the same build.
# Only needed once, by install.sh. Leave empty if you only use Wine mode.
STEAM_RUNTIME_DIR="$HOME/.steam/steam/steamapps/common/ProjectZomboid/projectzomboid"

# Steam Workshop download folder, used by zomboid-mods to import mods.
WORKSHOP_DIR="$HOME/.steam/steam/steamapps/workshop/content/108600"

# Wine prefix for the Windows fallback mode.
WINE_PREFIX="/mnt/games/Project.Zomboid.v42.20.4/prefix"

# Where backups are written.
BACKUP_DIR="/mnt/games/Project.Zomboid.v42.20.4/backups"
BACKUP_KEEP=20
