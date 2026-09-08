#!/bin/bash
# Install the host-side tooling: copies the native Linux runtime into the game
# folder and links the scripts into ~/.local/bin.
#
#   bash install.sh
#
# Reads ~/.config/zomboid-offline/config.sh (copy config.example.sh first).

set -eu
HERE="$(dirname "$(readlink -f "$0")")"
CFG="${ZOMBOID_OFFLINE_CONFIG:-$HOME/.config/zomboid-offline/config.sh}"

if [ ! -f "$CFG" ]; then
    echo "No config at $CFG"
    echo "   mkdir -p ~/.config/zomboid-offline"
    echo "   cp $HERE/config.example.sh ~/.config/zomboid-offline/config.sh"
    echo "   \$EDITOR ~/.config/zomboid-offline/config.sh"
    exit 1
fi
# shellcheck disable=SC1090
. "$CFG"

[ -d "$GAME_DIR" ] || { echo "GAME_DIR does not exist: $GAME_DIR"; exit 1; }

# --- native Linux runtime ---------------------------------------------------
# A Windows build ships a Windows JRE and .dll files. The Linux runtime from a
# Steam install of the SAME build runs the very same projectzomboid.jar, so we
# graft it in: natives/ for the .so files, jre64-linux/ for the JVM. The Linux
# JRE goes in its own folder so it does not collide with the bundled jre64.
if [ -d "$GAME_DIR/natives" ] && [ -d "$GAME_DIR/jre64-linux" ]; then
    echo "OK  native runtime already in place"
elif [ -n "${STEAM_RUNTIME_DIR:-}" ] && [ -d "$STEAM_RUNTIME_DIR/natives" ]; then
    echo ".. copying the native Linux runtime (~310 MB)"
    cp -a "$STEAM_RUNTIME_DIR/natives" "$GAME_DIR/natives"
    cp -a "$STEAM_RUNTIME_DIR/jre64"   "$GAME_DIR/jre64-linux"
    echo "OK  native runtime installed"
else
    echo "!!  no native runtime; only Wine mode will work (zomboid-client -win)"
fi

# --- verify the builds actually match ---------------------------------------
if [ -f "$STEAM_RUNTIME_DIR/projectzomboid.jar" ]; then
    A=$(md5sum "$GAME_DIR/projectzomboid.jar" | cut -d' ' -f1)
    B=$(md5sum "$STEAM_RUNTIME_DIR/projectzomboid.jar" | cut -d' ' -f1)
    if [ "$A" = "$B" ]; then
        echo "OK  same build as the Steam install (jar md5 matches)"
    else
        echo "!!  WARNING: the jars differ. Native mode may crash or misbehave."
        echo "    Your offline copy and the Steam install are different builds."
    fi
fi

# --- scripts ----------------------------------------------------------------
mkdir -p "$HOME/.local/bin" "$INSTANCE_DIR"
for s in zomboid-client zomboid-server zomboid-mods zomboid-sandbox zomboid-backup; do
    ln -sf "$HERE/scripts/$s" "$HOME/.local/bin/$s"
done
echo "OK  scripts linked into ~/.local/bin"

case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo "!!  add ~/.local/bin to your PATH" ;;
esac

echo
echo "Next:"
echo "   zomboid-server           # first run creates the world and config"
echo "   zomboid-mods -install    # import Steam Workshop mods"
echo "   zomboid-sandbox          # review the world settings"
