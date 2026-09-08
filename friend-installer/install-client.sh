#!/bin/bash
# ============================================================
#  Project Zomboid co-op client installer (Linux + Wine)
#  Run:   bash install-client.sh
# ============================================================
set -u

SERVER_IP="${SERVER_IP:-CHANGE.ME}"   # ask the host for this
SERVER_PORT="${SERVER_PORT:-16261}"

echo "=========================================="
echo " Project Zomboid co-op client installer"
echo "=========================================="
echo

# --- 1. find the game folder -------------------------------
GAME="${1:-}"
if [ -z "$GAME" ]; then
    echo "Looking for the game folder..."
    GAME=$(find "$HOME" /mnt /media -maxdepth 6 -name "ProjectZomboid64.exe" 2>/dev/null | head -1)
    GAME="${GAME%/ProjectZomboid64.exe}"
fi
if [ -z "$GAME" ] || [ ! -f "$GAME/ProjectZomboid64.exe" ]; then
    echo "Could not find the game automatically."
    echo "Run it pointing at the folder holding ProjectZomboid64.exe:"
    echo "   bash $0 /path/to/ProjectZomboid"
    exit 1
fi
echo "OK  game found at: $GAME"

# --- 2. check wine ---------------------------------------
if ! command -v wine >/dev/null 2>&1; then
    echo "ERROR: wine is not installed."
    echo "On Nobara/Fedora:  sudo dnf install wine"
    exit 1
fi
echo "OK  wine: $(wine --version 2>/dev/null)"

BASE="$(dirname "$GAME")"
SAVES="$BASE/Zomboid"
PREFIXO="$BASE/prefix"

# --- 3. wine prefix used only by Zomboid ---------------------
if [ -d "$PREFIXO" ]; then
    echo "OK  wine prefix already exists"
else
    echo ".. creating the wine prefix (takes ~1 min, this is normal)"
    WINEPREFIX="$PREFIXO" WINEDEBUG=-all wineboot -u >/dev/null 2>&1
    echo "OK  prefix created at: $PREFIXO"
fi

# --- 4. save folder -------------------------------------
mkdir -p "$SAVES/mods"
echo "OK  save folder: $SAVES"

# --- 5. mods -----------------------------------------------
ZIP=""
for c in "$(dirname "$0")/mods-for-friends.zip" \
         "$HOME/Downloads/mods-for-friends.zip" \
         "$HOME/Downloads/mods-for-friends.zip"; do
    [ -f "$c" ] && { ZIP="$c"; break; }
done
if [ -n "$ZIP" ]; then
    if command -v unzip >/dev/null 2>&1; then
        unzip -oq "$ZIP" -d "$SAVES/mods"
        echo "OK  $(ls "$SAVES/mods" | wc -l) mods installed"
    else
        echo "!!  unzip missing:  sudo dnf install unzip"
    fi
else
    echo "!!  could not find mods-for-friends.zip"
    echo "    put the zip next to this script and run again,"
    echo "    or unzip it by hand into: $SAVES/mods"
fi

# --- 6. create the launcher -----------------------------
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/zomboid42" <<EOF
#!/bin/bash
# Project Zomboid co-op -- written by the installer
GAME="$GAME"
SAVES="$SAVES"
export WINEPREFIX="$PREFIXO"
export WINEDEBUG=-all
mkdir -p "\$SAVES"
cd "\$GAME" || exit 1
# on Windows -cachedir wants a Windows path; Z: is the Linux root
WSAVES="Z:\${SAVES//\//\\\\}"
echo "starting... (log in \$SAVES/client.log)"
exec wine jre64/bin/java.exe \\
  -Djava.awt.headless=true \\
  --enable-native-access=ALL-UNNAMED \\
  --add-exports=java.base/jdk.internal.misc=ALL-UNNAMED \\
  -Xms4g -Xmx4g \\
  -Dzomboid.steam=0 \\
  -Djava.library.path=./ \\
  -XX:+UseZGC \\
  -XX:-CreateCoredumpOnCrash \\
  -XX:-OmitStackTraceInFastThrow \\
  -cp "./;projectzomboid.jar" \\
  zombie.gameStates.MainScreenState \\
  "-cachedir=\$WSAVES" \\
  -nosteam "\$@" >"\$SAVES/client.log" 2>&1
EOF
chmod +x "$HOME/.local/bin/zomboid42"
echo "OK  launcher created: zomboid42"

# --- 7. desktop entry -------------------------------------
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/zomboid42.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Project Zomboid co-op
Exec=$HOME/.local/bin/zomboid42
Terminal=false
Categories=Game;
EOF
echo "OK  desktop entry created"

# --- 8. PATH -----------------------------------------------
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
       echo "OK  ~/.local/bin added to PATH (open a new terminal)" ;;
esac

echo
echo "=========================================="
echo " DONE!"
echo "=========================================="
echo
echo "  Start the game:  zomboid42"
echo "  (or from the menu: Project Zomboid co-op)"
echo
echo "  In game:  Join Server  ->  direct IP"
echo "     Server:   $SERVER_IP"
echo "     Port:     $SERVER_PORT"
echo "     Password: (leave empty)"
echo
echo "  You must be on the ZeroTier network first!"
echo "     test:   ping $SERVER_IP"
echo
