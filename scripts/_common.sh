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

# One instance can host several servers. They share the game folder and the
# mods folder; each has its own world, .ini (so its own mod list), sandbox and
# port. Pick one with -s <name>, or $ZOMBOID_SERVER.
_select_server() {
    _rest=()
    while [ $# -gt 0 ]; do
        case "$1" in
            -s|--server) SERVER_NAME="$2"; shift 2 ;;
            *) _rest+=("$1"); shift ;;
        esac
    done
}
[ -n "${ZOMBOID_SERVER:-}" ] && SERVER_NAME="$ZOMBOID_SERVER"
_select_server "$@"
set -- "${_rest[@]+"${_rest[@]}"}"

# Per-server port and RAM live next to its config.
SERVER_CONF="$INSTANCE_DIR/Server/$SERVER_NAME.instance"
# shellcheck disable=SC1090
[ -f "$SERVER_CONF" ] && . "$SERVER_CONF"
: "${CLIENT_RAM:=8g}"
: "${SERVER_RAM:=6g}"
: "${BACKUP_KEEP:=20}"
: "${WINE_PREFIX:=$INSTANCE_DIR/../prefix}"
: "${BACKUP_DIR:=$INSTANCE_DIR/../backups}"

SERVER_INI="$INSTANCE_DIR/Server/$SERVER_NAME.ini"
SANDBOX_LUA="$INSTANCE_DIR/Server/${SERVER_NAME}_SandboxVars.lua"
WORLD_DIR="$INSTANCE_DIR/Saves/Multiplayer/$SERVER_NAME"

# pgrep -f would match this script's own command line; match the Java class
# AND the server name, or two running servers look like one.
server_pid_of() { pgrep -f "zombie/network/GameServer.*-servername $1( |\$)" | head -1; }
server_pid() { server_pid_of "$SERVER_NAME"; }

# Every server that has a config in this instance.
server_list() {
    ls -1 "$INSTANCE_DIR/Server/"*.ini 2>/dev/null | while read -r f; do
        basename "$f" .ini
    done
}

server_port_of() {
    local c="$INSTANCE_DIR/Server/$1.instance"
    if [ -f "$c" ]; then (. "$c"; echo "${SERVER_PORT:-16261}"); else echo 16261; fi
}

# First ZeroTier address on this machine, for the "tell your friends" line.
zerotier_ip() { ip -4 -brief addr show 2>/dev/null | awk '/^zt/ {split($3,a,"/"); print a[1]; exit}'; }
