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

echo "===== Installing Subnautica via SteamCMD ====="

# ===== VALIDATE ENVIRONMENT VARIABLES =====
if [[ -z "${STEAM_USER:-}" || -z "${STEAM_PASS:-}" ]]; then
  echo "❌ ERROR: Missing Steam credentials."
  echo "You must define the following environment variables in Pterodactyl:"
  echo "  STEAM_USER   = Your Steam username"
  echo "  STEAM_PASS   = Your Steam password"
  echo "Optional:"
  echo "  STEAM_GUARD  = Steam Guard code (if prompted)"
  exit 1
fi

# ===== INSTALL DEPENDENCIES =====
if [ -f /etc/alpine-release ]; then
  apk add --no-cache bash wget curl ca-certificates libstdc++ libgcc unzip
else
  apt update -y
  apt install -y wget curl ca-certificates lib32gcc-s1 lib32stdc++6 unzip
fi

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

# ===== GET LATEST NITROX RELEASE =====
echo "Fetching latest Nitrox release..."
LATEST_RELEASE_JSON=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest")
NITROX_URL=$(echo "$LATEST_RELEASE_JSON" | grep -oP '"browser_download_url":\s*"\K[^"]*linux_x64\.zip"' | head -n1)

if [[ -z "$NITROX_URL" ]]; then
  echo "❌ Could not find a Linux x64 build for Nitrox. Check the GitHub release page."
  exit 1
fi

echo "Downloading Nitrox from:"
echo "  $NITROX_URL"

cd "$INSTALL_DIR"
curl -L -o nitrox.zip "$NITROX_URL"
unzip -o nitrox.zip >/dev/null
rm nitrox.zip

chmod -R +x "$INSTALL_DIR" || true

# ===== CREATE CONFIG AND PATH FILES =====
export HOME="$BASE_DIR"
mkdir -p "$HOME/.config"
echo "$GAME_DIR" > "$HOME/path.txt"

# ===== COMPLETION =====
echo
echo "✅ Nitrox setup complete!"
echo
echo "For Pterodactyl startup, use the following command:"
echo
echo "export HOME=/home/container && \\"
echo "export XDG_CONFIG_HOME=/home/container/.config && \\"
echo "mkdir -p \$XDG_CONFIG_HOME && \\"
echo "export SUBNAUTICA_INSTALLATION_PATH=/home/container/subnautica && \\"
echo "cd /home/container/nitrox && \\"
echo "exec ./NitroxServer-Subnautica --nogui --port \${SERVER_PORT:-11000} --datapath ./data"
echo
echo "Environment variables needed:"
echo "  STEAM_USER=YourSteamLogin"
echo "  STEAM_PASS=YourSteamPassword"
echo "  (optional) STEAM_GUARD=YourSteamGuardCode"