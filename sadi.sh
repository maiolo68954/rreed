#!/usr/bin/env bash
# Gensyn BlockAssist — unified menu (RU/EN)
# 1) Install/Configure VNC server
# 2) Install Block Assist (inside VNC) [pyenv global 3.10, Chrome only]
# 3) Run Block Assist (inside VNC)
# 4) Show IP and VNC port(s)
# 5) Stop VNC server(s)

set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

# ========= Colors / Styles =========
if command -v tput >/dev/null 2>&1; then
  BOLD="$(tput bold || true)"; RESET="$(tput sgr0 || true)"
else
  BOLD="\033[1m"; RESET="\033[0m"
fi
RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[1;33m"
BLUE="\033[0;34m"; CYAN="\033[0;36m"; MAGENTA="\033[0;35m"; GRAY="\033[0;90m"
LINE="${GRAY}────────────────────────────────────────────────────────────${RESET}"

# ========= Privilege helpers =========
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; else
    echo -e "${RED}[ERR] Root or sudo privileges required.${RESET}"; exit 1
  fi
fi
with_sudo(){ if [ -n "$SUDO" ]; then sudo "$@"; else "$@"; fi; }
pipe_to_bash(){ local url="$1"; shift || true; if [ -n "$SUDO" ]; then curl -fsSL "$url" | sudo bash - "$@"; else curl -fsSL "$url" | bash - "$@"; fi; }

# ========= Safe random password generator =========
gen_pass(){
  set +o pipefail
  tr -dc A-Za-z0-9 </dev/urandom | head -c 8
  set -o pipefail
}

# ========= Logo =========
display_logo(){
  printf "%b" "${CYAN}"
  cat <<'EOF'
 _   _           _  _____      
| \ | |         | ||____ |     
|  \| | ___   __| |    / /_ __ 
| . ` |/ _ \ / _` |    \ \ '__|
| |\  | (_) | (_| |.___/ / |   
\_| \_/\___/ \__,_|\____/|_|
EOF
  printf "%b\n" "${RESET}"
  printf "%b\n" "   ${BOLD}Gensyn BlockAssist${RESET}"
  printf "%b\n" "${BLUE}Telegram:${RESET} https://t.me/NodesN3R"
  printf "%b\n" "${BLUE}Author:${RESET}   https://x.com/andante1994"
  printf "%b\n\n" "${BLUE}Donate:${RESET}   0x0004230c13c3890F34Bb9C9683b91f539E809000"
}

press_enter(){ printf "%b" "${GRAY}Нажмите Enter для продолжения... / Press Enter to continue...${RESET}"; read -r; }

# ========= 1) VNC server installation =========
install_vnc_server(){
  printf "%b\n" "${MAGENTA}${BOLD}▌ Обновление репозиториев и установка VNC (сервер)${RESET}"
  printf "%b\n" "${MAGENTA}▌ Update repositories & install VNC (server)${RESET}"
  printf "%b\n" "${LINE}"

  echo -e "${CYAN}[*] Generating VNC password...${RESET}"
  VNC_PASS="$(gen_pass)"

  echo -e "${CYAN}[*] Updating system packages...${RESET}"
  with_sudo apt-get update -y && with_sudo apt-get upgrade -y

  echo -e "${CYAN}[*] Installing desktop environment & tools...${RESET}"
  with_sudo apt-get install -y xfce4 xfce4-goodies autocutsel xclip curl wget git \
    software-properties-common dbus-x11 libglu1-mesa gnupg libegl1-mesa

  echo -e "${CYAN}[*] Downloading & installing VirtualGL...${RESET}"
  VGL_VER="3.1"
  wget -q "https://github.com/VirtualGL/virtualgl/releases/download/${VGL_VER}/virtualgl_${VGL_VER}_amd64.deb" -O /tmp/virtualgl.deb
  with_sudo dpkg -i /tmp/virtualgl.deb || with_sudo apt-get -y -f install

  echo -e "${CYAN}[*] Downloading & installing TurboVNC...${RESET}"
  TURBO_VER="3.1.1"
  wget -q "https://github.com/TurboVNC/turbovnc/releases/download/${TURBO_VER}/turbovnc_${TURBO_VER}_amd64.deb" -O /tmp/turbovnc.deb
  with_sudo dpkg -i /tmp/turbovnc.deb || with_sudo apt-get -y -f install

  echo -e "${CYAN}[*] Configuring VirtualGL...${RESET}"
  with_sudo /opt/VirtualGL/bin/vglserver_config -config +s +f -t </dev/null

  echo -e "${CYAN}[*] Creating VNC startup script...${RESET}"
  mkdir -p "$HOME/.vnc"
  cat > "$HOME/.vnc/xstartup" <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XKL_XMODMAP_DISABLE=1
export XDG_CURRENT_DESKTOP="XFCE"

# Clipboard sync
autocutsel -fork
autocutsel -selection PRIMARY -fork
xfce4-clipman &

# Keyboard & input tweaks
xset r rate 200 40
setxkbmap us

exec startxfce4
EOF
  chmod +x "$HOME/.vnc/xstartup"
  touch "$HOME/.Xresources"

  echo -e "${CYAN}[*] Setting VNC password...${RESET}"
  echo "$VNC_PASS" | /opt/TurboVNC/bin/vncpasswd -f > "$HOME/.vnc/passwd"
  chmod 600 "$HOME/.vnc/passwd"

  echo -e "${CYAN}[*] Starting VNC server on :1...${RESET}"
  /opt/TurboVNC/bin/vncserver -kill :1 || true
  /opt/TurboVNC/bin/vncserver :1 -geometry 1920x1080 -depth 24

  # GPU check
  if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] GPU detected.${RESET}"
  else
    echo -e "${YELLOW}[WARN] GPU not detected or drivers missing.${RESET}"
  fi

  IP="$(hostname -I | awk '{print $1}')"
  echo -e "${LINE}"
  echo -e "${GREEN}${BOLD}VNC is running!${RESET}"
  echo -e "Connect with: ${BOLD}${IP}:5901${RESET}"
  echo -e "Password:     ${BOLD}${VNC_PASS}${RESET}"
  echo -e "${LINE}"
}
