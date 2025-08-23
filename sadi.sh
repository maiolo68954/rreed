#!/usr/bin/env bash
# Gensyn BlockAssist — unified menu (EN)
# 1) Install/Configure VNC on server
# 2) Install Block Assist (inside VNC)  [pyenv global 3.10, Chrome only]
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
    echo -e "${RED}[ERR] Root or sudo required.${RESET}"; exit 1
  fi
fi
with_sudo(){ if [ -n "$SUDO" ]; then sudo "$@"; else "$@"; fi; }
pipe_to_bash(){ local url="$1"; shift || true; if [ -n "$SUDO" ]; then curl -fsSL "$url" | sudo bash - "$@"; else curl -fsSL "$url" | bash - "$@"; fi; }

# ========= Safe random password generator (avoids SIGPIPE with pipefail) =========
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

press_enter(){ printf "%b" "${GRAY}Press Enter to continue...${RESET}"; read -r; }

# ========= 1) VNC on server =========
install_vnc_server(){
  printf "%b\n" "${MAGENTA}${BOLD}▌ Update repositories & install VNC (server)${RESET}"
  printf "%b\n" "${LINE}"

  echo -e "${CYAN}[*] Generating VNC password...${RESET}"
  VNC_PASS="$(gen_pass)"

  echo -e "${CYAN}[*] Updating system...${RESET}"
  with_sudo apt-get update -y && with_sudo apt-get upgrade -y

  echo -e "${CYAN}[*] Installing desktop environment + tools...${RESET}"
  # Base packages that should be available on all Ubuntu versions
  with_sudo apt-get install -y xfce4 xfce4-goodies autocutsel xclip curl wget git \
    software-properties-common dbus-x11 libglu1-mesa gnupg
  
  # Try to install graphics packages with fallbacks
  echo -e "${CYAN}[*] Installing graphics libraries...${RESET}"
  with_sudo apt-get install -y mesa-utils libgl1-mesa-glx || true
  
  # Try libegl packages with fallbacks
  if ! with_sudo apt-get install -y libegl1-mesa 2>/dev/null; then
    echo -e "${YELLOW}[WARN] libegl1-mesa not available, trying alternatives...${RESET}"
    with_sudo apt-get install -y libegl1 || with_sudo apt-get install -y libglvnd0 || true
  fi

  echo -e "${CYAN}[*] Downloading & Installing VirtualGL...${RESET}"
  VGL_VER="3.1"
  wget -q "https://github.com/VirtualGL/virtualgl/releases/download/${VGL_VER}/virtualgl_${VGL_VER}_amd64.deb" -O /tmp/virtualgl.deb || {
    echo -e "${RED}[ERR] Failed to download VirtualGL${RESET}"
    return 1
  }
  with_sudo dpkg -i /tmp/virtualgl.deb || with_sudo apt-get -y -f install

  echo -e "${CYAN}[*] Downloading & Installing TurboVNC...${RESET}"
  TURBO_VER="3.1.1"
  wget -q "https://github.com/TurboVNC/turbovnc/releases/download/${TURBO_VER}/turbovnc_${TURBO_VER}_amd64.deb" -O /tmp/turbovnc.deb || {
    echo -e "${RED}[ERR] Failed to download TurboVNC${RESET}"
    return 1
  }
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

# Input tweaks
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
  /opt/TurboVNC/bin/vncserver -kill :1 2>/dev/null || true
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
  echo -e "Connect: ${BOLD}${IP}:5901${RESET}"
  echo -e "Password: ${BOLD}${VNC_PASS}${RESET}"
  echo -e "${LINE}"
}

# ========= 2) Install Block Assist inside VNC (pyenv global, Chrome only) =========
install_blockassist(){
  printf "%b\n" "${MAGENTA}${BOLD}▌ Install Block Assist (inside VNC)${RESET}"
  printf "%b\n" "${LINE}"

  with_sudo apt-get update -y
  # utilities for XDG and .desktop
  with_sudo apt-get install -y xdg-utils desktop-file-utils

  # --- Browser: always install Google Chrome (VNC-friendly)
  echo -e "${CYAN}[*] Installing Google Chrome...${RESET}"
  wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb || {
    echo -e "${RED}[ERR] Failed to download Chrome${RESET}"
    return 1
  }
  with_sudo apt-get install -y /tmp/chrome.deb || with_sudo apt-get -y -f install

  # VNC-friendly wrapper (+flags for root/VNC operation)
  with_sudo tee /usr/local/bin/google-chrome-vnc >/dev/null <<'SH'
#!/usr/bin/env bash
set -e
BIN="$(command -v google-chrome-stable || command -v google-chrome || echo /usr/bin/google-chrome-stable)"
PROFILE="${HOME}/.chrome-vnc"
ARGS=(--no-sandbox --disable-dev-shm-usage --no-first-run --no-default-browser-check \
      --password-store=basic --user-data-dir="${PROFILE}" --use-gl=desktop)
"$BIN" "${ARGS[@]}" "$@" || "$BIN" "${ARGS[@]}" --use-gl=swiftshader "$@"
SH
  with_sudo chmod +x /usr/local/bin/google-chrome-vnc

  # Desktop shortcut (optional)
  mkdir -p "$HOME/Desktop" "$HOME/.local/share/applications"
  cat > "$HOME/Desktop/google-chrome.desktop" <<'EOF'
[Desktop Entry]
Name=Google Chrome (VNC)
Comment=Chromium-based browser (VNC-safe)
Exec=/usr/local/bin/google-chrome-vnc %U
Terminal=false
Type=Application
Icon=google-chrome
Categories=Network;WebBrowser;
EOF
  chmod +x "$HOME/Desktop/google-chrome.desktop" 2>/dev/null || true

  # Desktop file that uses wrapper, and registration as default
  with_sudo tee /usr/share/applications/google-chrome-vnc.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Google Chrome (VNC-safe)
Comment=Chromium-based browser (uses --no-sandbox etc.)
Exec=/usr/local/bin/google-chrome-vnc %U
Terminal=false
Type=Application
Icon=google-chrome
Categories=Network;WebBrowser;
StartupWMClass=Google-chrome
MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
EOF
  with_sudo update-desktop-database 2>/dev/null || true

  # 1) system-wide: x-www-browser -> wrapper
  with_sudo update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/local/bin/google-chrome-vnc 200
  with_sudo update-alternatives --set x-www-browser /usr/local/bin/google-chrome-vnc 2>/dev/null || true

  # 2) per-user XDG defaults
  DESKTOP_ID="google-chrome-vnc.desktop"
  if command -v xdg-settings >/dev/null 2>&1; then
    xdg-settings set default-web-browser "$DESKTOP_ID" 2>/dev/null || true
  fi
  if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default "$DESKTOP_ID" text/html 2>/dev/null || true
    xdg-mime default "$DESKTOP_ID" x-scheme-handler/http 2>/dev/null || true
    xdg-mime default "$DESKTOP_ID" x-scheme-handler/https 2>/dev/null || true
  fi

  # 3) duplicate in ~/.config/mimeapps.list
  mkdir -p "$HOME/.config"
  MIMERC="$HOME/.config/mimeapps.list"
  [ -f "$MIMERC" ] || touch "$MIMERC"
  if ! grep -q "^\[Default Applications\]" "$MIMERC" 2>/dev/null; then
    printf "[Default Applications]\n" >> "$MIMERC"
  fi
  set_default() {
    local key="$1" val="$2"
    if grep -q "^${key}=" "$MIMERC" 2>/dev/null; then
      sed -i "s|^${key}=.*|${key}=${val}|g" "$MIMERC"
    else
      printf "%s=%s\n" "$key" "$val" >> "$MIMERC"
    fi
  }
  set_default "text/html" "${DESKTOP_ID}"
  set_default "x-scheme-handler/http" "${DESKTOP_ID}"
  set_default "x-scheme-handler/https" "${DESKTOP_ID}"
  echo -e "${GREEN}[OK] Default browser -> google-chrome-vnc.${RESET}"

  echo -e "${CYAN}[*] Cloning blockassist repo...${RESET}"
  cd "$HOME"
  if [ ! -d "$HOME/blockassist" ]; then
    git clone https://github.com/gensyn-ai/blockassist.git || {
      echo -e "${RED}[ERR] Failed to clone blockassist repo${RESET}"
      return 1
    }
  fi
  cd "$HOME/blockassist"
  ./setup.sh 2>/dev/null || true

  echo -e "${CYAN}[*] Installing pyenv...${RESET}"
  if [ ! -d "$HOME/.pyenv" ]; then
    curl -fsSL https://pyenv.run | bash || {
      echo -e "${RED}[ERR] Failed to install pyenv${RESET}"
      return 1
    }
  fi

  # add pyenv to current shell and persist to .bashrc
  export PATH="$HOME/.pyenv/bin:$PATH"
  eval "$("$HOME/.pyenv/bin/pyenv" init -)" 2>/dev/null || true
  eval "$("$HOME/.pyenv/bin/pyenv" virtualenv-init -)" 2>/dev/null || true
  if ! grep -q 'pyenv init' "$HOME/.bashrc" 2>/dev/null; then
    {
      echo 'export PATH="$HOME/.pyenv/bin:$PATH"'
      echo 'eval "$(pyenv init -)"'
      echo 'eval "$(pyenv virtualenv-init -)"'
    } >> "$HOME/.bashrc"
  fi

  echo -e "${CYAN}[*] Python build deps...${RESET}"
  with_sudo apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
    libsqlite3-dev curl git libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
    libffi-dev liblzma-dev zip unzip wget

  echo -e "${CYAN}[*] Installing Python 3.10 via pyenv...${RESET}"
  pyenv install -s 3.10 || {
    echo -e "${RED}[ERR] Failed to install Python 3.10${RESET}"
    return 1
  }
  pyenv global 3.10
  pyenv rehash
  pip install -U pip

  echo -e "${CYAN}[*] Installing Python packages (psutil, readchar)...${RESET}"
  pip install -U psutil readchar

  echo -e "${CYAN}[*] Installing Node.js 20...${RESET}"
  curl -fsSL https://deb.nodesource.com/setup_20.x | with_sudo bash - || {
    echo -e "${RED}[ERR] Failed to setup Node.js${RESET}"
    return 1
  }
  with_sudo apt-get install -y nodejs
  node --version 2>/dev/null || true

  echo -e "${CYAN}[*] Installing Java 8 (OpenJDK)...${RESET}"
  with_sudo apt-get install -y openjdk-8-jdk

  echo -e "${GREEN}=== Install complete ===${RESET}"
  echo -e "${YELLOW}To run:${RESET}"
  echo -e "${GREEN}3) Run Block Assist (inside VNC)${RESET}"
}

# ========= 3) Run Block Assist (inside VNC) =========
run_blockassist(){
  printf "%b\n" "${MAGENTA}${BOLD}▌ Run Block Assist (inside VNC)${RESET}"
  printf "%b\n" "${LINE}"

  if [ ! -d "$HOME/blockassist" ]; then
    echo -e "${YELLOW}~/blockassist not found. Please run step 2 first.${RESET}"
    return 1
  fi

  # load pyenv in this shell and run
  export PATH="$HOME/.pyenv/bin:$PATH"
  if command -v pyenv >/dev/null 2>&1; then
    eval "$(pyenv init -)" 2>/dev/null || true
    eval "$(pyenv virtualenv-init -)" 2>/dev/null || true
  fi

  echo -e "${GREEN}▶ Running: python run.py${RESET}"
  (cd "$HOME/blockassist" && python run.py) || true
}

# ========= 4) Show IP & VNC port(s) =========
show_ip_ports(){
  printf "%b\n" "${MAGENTA}${BOLD}▌ Show IP and VNC port(s)${RESET}"
  printf "%b\n" "${LINE}"

  IP="$(hostname -I | awk '{print $1}')"; [ -z "${IP:-}" ] && IP="127.0.0.1"
  echo -e "IP: ${BOLD}${IP}${RESET}"
  if /opt/TurboVNC/bin/vncserver -list >/tmp/vnclist 2>/dev/null; then
    echo -e "${GRAY}Detected displays:${RESET}"
    grep -oE ":[0-9]+" /tmp/vnclist | sort -u | while read -r disp; do
      num="${disp#:}"; port=$((5900 + num))
      echo -e "  • display ${BOLD}:${num}${RESET} → port ${BOLD}${port}${RESET} (connect: ${IP}:${port})"
    done
  else
    echo -e "${YELLOW}Cannot list displays. Default: :1 → port 5901 (connect: ${IP}:5901)${RESET}"
  fi
}

# ========= 5) Stop VNC server(s) =========
stop_vnc_server(){
  printf "%b\n" "${MAGENTA}${BOLD}▌ Stop VNC server(s)${RESET}"
  printf "%b\n" "${LINE}"

  local VNC_BIN="/opt/TurboVNC/bin/vncserver"
  [ -x "$VNC_BIN" ] || VNC_BIN="$(command -v vncserver 2>/dev/null || echo /opt/TurboVNC/bin/vncserver)"

  # 1) Collect display list from vncserver -list
  local displays=""
  if "$VNC_BIN" -list >/tmp/vnclist 2>/dev/null; then
    displays="$(grep -oE ':[0-9]+' /tmp/vnclist | sort -u | tr '\n' ' ' || true)"
  fi

  # 2) Fallback: from Xvnc processes (without pipefail to avoid failure)
  set +o pipefail
  if [ -z "$displays" ]; then
    displays="$(pgrep -a Xvnc 2>/dev/null | sed -n 's/.* \([:][0-9]\+\)\b.*/\1/p' | sort -u | tr '\n' ' ' || true)"
  fi
  set -o pipefail

  if [ -z "$displays" ]; then
    echo -e "${YELLOW}No active VNC sessions found.${RESET}"
    return 0
  fi

  echo -e "${CYAN}Found sessions:${RESET} ${displays}"
  for d in $displays; do
    echo -e "${CYAN}[*] Stopping ${d}...${RESET}"
    "$VNC_BIN" -kill "$d" >/dev/null 2>&1 || true

    local num="${d#:}"
    pkill -TERM -f "Xvnc.*[: ]${num}\b" 2>/dev/null || true
    sleep 0.5
    pkill -KILL -f "Xvnc.*[: ]${num}\b" 2>/dev/null || true
    fuser -k 590${num}/tcp 2>/dev/null || true
    fuser -k /tmp/.X11-unix/X${num} 2>/dev/null || true
    local host; host="$(hostname -s 2>/dev/null || hostname)"
    rm -f "$HOME/.vnc/${host}:${num}.pid" "/tmp/.X${num}-lock" "/tmp/.X11-unix/X${num}" 2>/dev/null || true
  done

  if "$VNC_BIN" -list 2>/dev/null | grep -qE ':[0-9]+' || pgrep -f 'Xvnc.*:' >/dev/null 2>&1; then
    echo -e "${YELLOW}Some sessions are still active. Check manually:${RESET}"
    "$VNC_BIN" -list 2>/dev/null || true
  else
    echo -e "${GREEN}[OK] All VNC sessions stopped and cleaned.${RESET}"
  fi
}

# ========= Menu =========
show_menu(){
  clear
  display_logo
  printf "%b\n" "${BOLD}${CYAN}Choose an action:${RESET}"
  printf "%b\n" "  ${GREEN}1)${RESET} Update repositories & install VNC (server)"
  printf "%b\n" "  ${GREEN}2)${RESET} Install Block Assist (inside VNC)"
  printf "%b\n" "  ${GREEN}3)${RESET} Run Block Assist (inside VNC)"
  printf "%b\n" "  ${GREEN}4)${RESET} Show IP and VNC port(s)"
  printf "%b\n" "  ${GREEN}5)${RESET} Stop VNC server(s)"
  printf "%b\n" "  ${GREEN}0)${RESET} Exit"
  printf "%b\n" ""
}

main(){
  while true; do
    show_menu
    printf "%b" "${BOLD}Enter number:${RESET} "
    read -r choice
    case "${choice:-}" in
      1) install_vnc_server ; press_enter ;;
      2) install_blockassist ; press_enter ;;
      3) run_blockassist ; press_enter ;;
      4) show_ip_ports ; press_enter ;;
      5) stop_vnc_server ; press_enter ;;
      0) printf "%b\n" "${BLUE}Bye!${RESET}"; exit 0 ;;
      *) printf "%b\n" "${YELLOW}Invalid choice. Try again.${RESET}"; sleep 1 ;;
    esac
  done
}
main "$@"
