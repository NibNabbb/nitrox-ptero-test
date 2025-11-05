#!/usr/bin/env bash
set -euo pipefail

# ===== CONFIG =====
INSTALL_DIR="${HOME}/nitrox"
DATA_DIR="${INSTALL_DIR}/data"
GAME_DIR="${HOME}/subnautica"
STEAMCMD_DIR="${HOME}/steamcmd"
NITROX_URL="https://github.com/SubnauticaNitrox/Nitrox/releases/latest/download/Nitrox_1.8.0.1_linux_x64.zip"
STEAM_APP_ID=264710

echo "===== Installing Subnautica via SteamCMD ====="

# ===== VALIDATE ENVIRONMENT VARIABLES =====
if [[ -z "${STEAM_USER:-}" || -z "${STEAM_PASS:-}" ]]; then
  echo "❌ ERROR: Missing Steam credentials."
  echo "You must define the following environment variables in Pterodactyl:"
  echo "  STEAM_USER   = Your Steam username"
  echo "  STEAM_PASS   = Your Steam password"
  echo "Optional:"
  echo "  STEAM_GUARD  = Steam Guard code (if prompted)"
  echo
  exit 1
fi

# ===== INSTALL DEPENDENCIES =====
apt update -y
apt install -y wget curl ca-certificates lib32gcc-s1 lib32stdc++6 unzip >/dev/null

# ===== PREPARE DIRECTORIES =====
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

# ===== INSTALL NITROX =====
echo "Installing Nitrox server..."
cd "$INSTALL_DIR"
curl -L -o nitrox.zip "$NITROX_URL"
unzip -o nitrox.zip >/dev/null
rm nitrox.zip

# ===== CREATE START SCRIPT =====
cat > "${INSTALL_DIR}/start.sh" <<'EOF'
#!/usr/bin/env bash
set -e

PORT="${SERVER_PORT:-11000}"
GAME_PATH="${SUBNAUTICA_INSTALLATION_PATH:-${HOME}/subnautica}"
DATA_PATH="${HOME}/nitrox/data"

clear
echo "======================================"
echo " Starting Nitrox Server for Subnautica"
echo "--------------------------------------"
echo " Port:            ${PORT}"
echo " Game Path:       ${GAME_PATH}"
echo " Data Directory:  ${DATA_PATH}"
echo "======================================"
echo

export SUBNAUTICA_INSTALLATION_PATH="${GAME_PATH}"
cd "$(dirname "$0")"

./NitroxServer-Subnautica --nogui --port "${PORT}" --datapath "${DATA_PATH}"
EOF

chmod +x "${INSTALL_DIR}/start.sh"
chmod +x "${INSTALL_DIR}/NitroxServer-Subnautica" || true

# ===== COMPLETION =====
echo
echo "✅ Nitrox setup complete!"
echo "Run manually with:"
echo "  cd ${INSTALL_DIR} && ./start.sh"
echo
echo "For Pterodactyl:"
echo "  Startup command: ./nitrox/start.sh"
echo
echo "Environment variables:"
echo "  SERVER_PORT=11000"
echo "  STEAM_USER=YourSteamLogin"
echo "  STEAM_PASS=YourSteamPassword"
echo "  (optional) STEAM_GUARD=YourSteamGuardCode"
echo "  SUBNAUTICA_INSTALLATION_PATH=/home/container/subnautica"