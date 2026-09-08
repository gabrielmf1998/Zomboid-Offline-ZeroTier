# Shared config loading for every zomboid-* script. Sourced, never run.

_load_config() {
    local candidates=(
        "${ZOMBOID_OFFLINE_CONFIG:-}"
        "$HOME/.config/zomboid-offline/config.sh"
        "$(dirname "$(readlink -f "${BASH_SOURCE[1]}")")/../config.sh"
    )
    local c
    for c in "${candidates[@]}"; do
        if [ -n "$c" ] && [ -f "$c" ]; then
            # shellcheck disable=SC1090
            . "$c"
            return 0
        fi
    done
    echo "No config found. Copy config.example.sh to ~/.config/zomboid-offline/config.sh" >&2
    exit 1
}
_load_config

: "${SERVER_NAME:=amigos}"
: "${SERVER_PORT:=16261}"
: "${CLIENT_RAM:=8g}"
: "${SERVER_RAM:=6g}"
: "${BACKUP_KEEP:=20}"
: "${WINE_PREFIX:=$INSTANCE_DIR/../prefix}"
: "${BACKUP_DIR:=$INSTANCE_DIR/../backups}"

SERVER_INI="$INSTANCE_DIR/Server/$SERVER_NAME.ini"
SANDBOX_LUA="$INSTANCE_DIR/Server/${SERVER_NAME}_SandboxVars.lua"
WORLD_DIR="$INSTANCE_DIR/Saves/Multiplayer/$SERVER_NAME"

# pgrep -f would match this script's own command line; match the Java class
# the server actually runs instead.
server_pid() { pgrep -f "jre64-linux/bin/java.*zombie/network/GameServer" | head -1; }

# First ZeroTier address on this machine, for the "tell your friends" line.
zerotier_ip() { ip -4 -brief addr show 2>/dev/null | awk '/^zt/ {split($3,a,"/"); print a[1]; exit}'; }
