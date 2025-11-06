#!/usr/bin/env bash
set -euo pipefail

# ===== CONFIGURATION =====
BASE_DIR="/mnt/server"
INSTALL_DIR="${BASE_DIR}/nitrox"
DATA_DIR="${INSTALL_DIR}/data"
GAME_DIR="${BASE_DIR}/subnautica"
STEAMCMD_DIR="${BASE_DIR}/steamcmd"
STEAM_APP_ID=264710
GITHUB_REPO="SubnauticaNitrox/Nitrox"

echo "===== Installing Subnautica Nitrox Server ====="

# ====== Detect Alpine & Add Bash/Apt Compat ======
if [ -f /etc/alpine-release ]; then
  echo "Alpine detected — installing bash and dependencies..."
  apk add --no-cache bash curl wget unzip ca-certificates libstdc++ libc6-compat
  ln -sf /bin/bash /usr/bin/bash
fi

# ===== VALIDATE ENVIRONMENT VARIABLES =====
if [[ -z "${STEAM_USER:-}" || -z "${STEAM_PASS:-}" ]]; then
  echo "❌ ERROR: Missing Steam credentials."
  echo "You must define these environment variables in Pterodactyl:"
  echo "  STEAM_USER   = Your Steam username"
  echo "  STEAM_PASS   = Your Steam password"
  echo "Optional:"
  echo "  STEAM_GUARD  = Steam Guard code (if prompted)"
  exit 1
fi

# ===== INSTALL DEPENDENCIES =====
if command -v apt >/dev/null 2>&1; then
  apt update -y
  apt install -y wget curl ca-certificates lib32gcc-s1 lib32stdc++6 unzip jq >/dev/null
fi

mkdir -p "$STEAMCMD_DIR" "$GAME_DIR" "$INSTALL_DIR" "$DATA_DIR"

# ===== INSTALL STEAMCMD =====
cd "$STEAMCMD_DIR"
if [[ ! -f "steamcmd.sh" ]]; then
  echo "Downloading SteamCMD..."
  wget -q https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz -O steamcmd_linux.tar.gz
  tar -xzf steamcmd_linux.tar.gz
  rm steamcmd_linux.tar.gz
fi

# ===== INSTALL SUBNAUTICA =====
echo "Logging into Steam and installing Subnautica..."
"$STEAMCMD_DIR/steamcmd.sh" +@sSteamCmdForcePlatformType windows \
  +force_install_dir "$GAME_DIR" \
  +login "$STEAM_USER" "$STEAM_PASS" "${STEAM_GUARD:-}" \
  +app_update "$STEAM_APP_ID" validate \
  +quit

echo "✅ Subnautica installed successfully at: $GAME_DIR"

# ===== FIND LATEST NITROX RELEASE =====
echo "Fetching latest Nitrox release info..."
LATEST_JSON=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest")
DOWNLOAD_URL=$(echo "$LATEST_JSON" | jq -r '.assets[] | select(.name | endswith("_linux_x64.zip")) | .browser_download_url')

if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
  echo "❌ Could not find Nitrox _linux_x64.zip in latest release."
  exit 1
fi

echo "Found latest Nitrox release:"
echo "  $DOWNLOAD_URL"

# ===== INSTALL NITROX =====
cd "$INSTALL_DIR"
echo "Downloading Nitrox..."
curl -L -o nitrox.zip "$DOWNLOAD_URL"
unzip -qo nitrox.zip
rm nitrox.zip

# Handle nested folder (e.g. linux-x64/)
FIRST_DIR=$(find . -mindepth 1 -maxdepth 1 -type d | head -n 1)
if [ -n "$FIRST_DIR" ]; then
  mv "$FIRST_DIR"/* "$INSTALL_DIR"/
  rm -rf "$FIRST_DIR"
fi

chmod -R +x "$INSTALL_DIR" || true

# ===== CREATE CONFIGS =====
mkdir -p "$BASE_DIR/.config"
echo "/home/container/subnautica" > "$BASE_DIR/path.txt"

if [ ! -f "$BASE_DIR/server.cfg" ]; then
cat > "$BASE_DIR/server.cfg" <<'CFG'
# Default Nitrox server configuration
ServerPort=11000
SaveInterval=120000
MaxConnections=100
InitialSyncTimeout=300000
DisableConsole=False
DisableAutoSave=False
SaveName=MyWorld
ServerPassword=
AdminPassword=PleaseChangeMe
GameMode=SURVIVAL
SerializerMode=JSON
DefaultPlayerPerm=PLAYER
AutoPortForward=False
CFG
fi

# ===== CREATE START SCRIPT =====
cat > "${INSTALL_DIR}/start.sh" <<'EOF'
#!/usr/bin/env bash
set -e

PORT="${SERVER_PORT:-11000}"
GAME_PATH="${SUBNAUTICA_INSTALLATION_PATH:-/home/container/subnautica}"
DATA_PATH="/home/container/nitrox/data"

echo "======================================"
echo " Starting Nitrox Server for Subnautica"
echo "--------------------------------------"
echo " Port:            ${PORT}"
echo " Game Path:       ${GAME_PATH}"
echo " Data Directory:  ${DATA_PATH}"
echo "======================================"
echo

export SUBNAUTICA_INSTALLATION_PATH="${GAME_PATH}"
export HOME="/home/container"
export XDG_CONFIG_HOME="/home/container/.config"
mkdir -p "$XDG_CONFIG_HOME"

cd "$(dirname "$0")"
exec ./NitroxServer-Subnautica --nogui --port "${PORT}" --datapath "${DATA_PATH}"
EOF

chmod +x "${INSTALL_DIR}/start.sh"
chmod +x "${INSTALL_DIR}/NitroxServer-Subnautica" || true

# ===== COMPLETION =====
echo
echo "✅ Nitrox setup complete!"
echo "Run manually with:"
echo "  cd ${INSTALL_DIR} && ./start.sh"
echo
echo "For Pterodactyl startup command:"
echo "  bash /home/container/nitrox/start.sh"
echo
echo "Environment variables:"
echo "  SERVER_PORT=11000"
echo "  STEAM_USER=YourSteamLogin"
echo "  STEAM_PASS=YourSteamPassword"
echo "  (optional) STEAM_GUARD=YourSteamGuardCode"
echo "  SUBNAUTICA_INSTALLATION_PATH=/home/container/subnautica"
