#!/bin/bash
set -e
echo " LINE 03." 
#========= VARIÁVEIS ===============
# ==================================
USUARIO=paulo
HOME_USUARIO=/home/$USUARIO
SWAPFILE=/swapfile
LOG=/home/lxqt-install.log
echo " LINE 10." 
#========= ROOT + LOG ==============
# =================================
check_root() {
  [ "$EUID" -ne 0 ] && { echo "Execute como root."; exit 1; }
}
setup_log() {
  exec > >(tee -a "$LOG") 2>&1
}
echo " LINE 19. "
#======== SOURCES LIST =============
# =================================
setup_sources() {
  cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true
  cat > /etc/apt/sources.list <<'EOF'
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF
  apt-get update
}
echo  " LINE 30." 
#======= SISTEMA GRÁFICO ==========
# =================================
install_gui() {
# >>>>>componente gráfico básico<<<<<<<<
  apt-get install -y \
  xserver-xorg-core \
  dbus-x11 \
  gvfs \
  gvfs-backends \
  gvfs-fuse \
  firmware-linux \
  firmware-misc-nonfree \
# >>>>>Ambiente gráfico LXQT<<<<<<<<<<<<
  lxqt-core \
  lxqt-session \
  lxqt-panel \
  lxqt-config \
  openbox  || true
}
echo " LINE  50 "
#========== LIGHTDM ==============
# =================================
setup_lightdm() {
  apt-get install -y --no-install-recommends lightdm
  apt-get install -y lightdm-gtk-greeter || true

  mkdir -p /etc/lightdm/lightdm.conf.d
  cat > /etc/lightdm/lightdm.conf.d/20-autologin.conf <<EOF
[Seat:*]
autologin-user=$USUARIO
autologin-user-timeout=0
user-session=lxqt
EOF
}
echo " LINE 65 "
#========= PROGRAMAS =============
# =================================
install_apps() {
  apt-get install -y \
  mupdf \
  falkon \
  qbittorrent \
  xarchiver \
  mplayer \
  rclone \
  git \
  wget \
  gdebi \
  fonts-ubuntu || true
}
echo " LINE 81. "
#======= REDE (CABEADA) ============
# =================================
setup_network() {
  apt-get install -y \
  systemd-networkd \
  ufw \
  systemd-resolved || true

systemctl disable --now NetworkManager.service 2>/dev/null || true

systemctl enable --now systemd-networkd
systemctl enable --now systemd-resolved

ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

mkdir -p /etc/systemd/network
cat > /etc/systemd/network/20-wired.network <<EOF
[Match]
Type=ether
[Network]
DHCP=yes
EOF
}
echo " LINE 104. "
#======= SERVIÇOS INÚTEIS ==========
# ==================================
disable_services() {
  systemctl disable --now cups.service cups-browsed.service 2>/dev/null || true
  systemctl disable --now bluetooth.service 2>/dev/null || true
  systemctl disable --now avahi-daemon.service avahi-daemon.socket 2>/dev/null || true

  systemctl mask cups.service cups-browsed.service 2>/dev/null || true
  systemctl mask avahi-daemon.service avahi-daemon.socket 2>/dev/null || true
}
echo " LINE 115." 
#======= SWAP + TWEAKS ==============
# ===================================
setup_swap() {
  swapon --show | grep -q "$SWAPFILE" || {
    fallocate -l 2G "$SWAPFILE"
    chmod 600 "$SWAPFILE"
    mkswap "$SWAPFILE"
    swapon "$SWAPFILE"
    echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
}
  echo "vm.swappiness=10" > /etc/sysctl.d/99-swappiness.conf
}
echo " LINE 128 " 
#======== LXTERMINAL================
# ==================================
setup_lxterminal() {
apt-get install -y lxterminal || true

mkdir -p "$HOME_USUARIO/.config/lxterminal"

cat > "$HOME_USUARIO/.config/lxterminal/lxterminal.conf" <<'EOF'
[general]
fontname=Ubuntu Mono 14
bgcolor=#002b36
fgcolor=#ffffff
scrollback=5000
scrollbar=false
EOF
}
echo " LINE 145 " 
#======== GKRELLM ==============
# =================================
setup_gkrellm() {
  apt-get install -y gkrellm

  THEME_DIR="$HOME_USUARIO/.gkrellm2/themes"
  AUTOSTART="$HOME_USUARIO/.config/autostart"
  TMP=$(mktemp -d)

  sudo -u "$USUARIO" mkdir -p "$THEME_DIR" "$AUTOSTART"

  cd "$TMP"
  wget -q http://muhri.net/gkrellm/CoplandOS.gkrellm.tar.gz
  tar -xzf CoplandOS.gkrellm.tar.gz
  cp -r CoplandOS "$THEME_DIR/"

  cat > "$AUTOSTART/gkrellm.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Exec=gkrellm -g +1100+20
X-LXQt-Autostart=true
Name=GKrellM
EOF

  chown -R "$USUARIO:$USUARIO" "$HOME_USUARIO/.gkrellm2" "$AUTOSTART"
  rm -rf "$TMP"
}
echo " LINE 173 "
#======== CLAWS MAIL ============
# ================================
setup_claws() {
  apt-get install -y claws-mail claws-mail-plugins || true

  CLAWS="$HOME_USUARIO/.claws-mail"
  ACC="$CLAWS/accountrc"

  sudo -u "$USUARIO" mkdir -p "$CLAWS"

  [ -f "$ACC" ] && return

  sudo -u "$USUARIO" tee "$ACC" >/dev/null <<'EOF'
[Common]
default_account=0

[Account:0]
account_name=Gmail
#=== Configuração IMAP =========
protocol=IMAP4
is_default=1
name=Paulo Santos 
email=pl840489307@gmail.com
server=imap.gmail.com
user=pxxxxxxxxx07@gmail.com
password=xxxxxxxxxxxxx
ssl=1
imap_port=993

#=== Configuração SMTP =========
smtp_server=smtp.gmail.com
smtp_user=plxxxxxxxx07@gmail.com
smtp_password=xxxxxxxxxxc
smtp_port=587
smtp_tls=1
EOF

  chown -R "$USUARIO:$USUARIO" "$CLAWS"
}
echo " LINE 213 "
#========= EXECUÇÃO ==============
# =================================
check_root
setup_log
setup_sources
install_gui
setup_lightdm
install_apps
setup_network
disable_services
setup_swap
setup_lxterminal
setup_gkrellm
setup_claws

echo "<<<INSTALAÇÃO CONCLUIDA>>>>>>"
echo "LINE 230 <<<FIM>>>>>>>>>>>>>>>>>"