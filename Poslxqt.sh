#!/bin/bash
set -e

USUARIO="paulo"
HOME_USUARIO="/home/$USUARIO"

echo "=============================="
echo "Pós-inst Debian 13 Lxqt-core"
echo "=============================="

# ----------------------------------
# VERIFICAÇÕES BÁSICAS
# -----------------------------------

if [ "$EUID" -ne 0 ]; then
  echo "Execute como root."
  exit 1
fi

if ! id "$USUARIO" >/dev/null 2>&1; then
  echo "Usuário $USUARIO não existe."
  exit 1
fi

# ---------------------------------
# UPDATE & BASE
# ---------------------------------

echo "Atualizando sistema"
apt update && apt upgrade -y

# ----------------------------------
# BASE GRÁFICA LXQT
# ----------------------------------

echo "Instalando Xorg + LXQt mínimo"

apt install -y xserver-xorg-core \
xinit lxqt-core lxqt-panel \
lxqt-session lxqt-config openbox \
dbus-x11 gvfs gvfs-backends \
gvfs-fuse x11-xserver-utils || true

apt-get install lightdm \ --no-install-recomends -y

# -----------------------------------
# INTERNET, WI-FI E FIRMWARE
#------------------------------------

echo "Instalando rede e firmwares"

apt install -y network-manager \ network-manager-gnome wpasupplicant \
firmware-linux \
firmware-misc-nonfree || true

systemctl enable-now NetworkManager

# -----------------------------------
# PROGRAMAS ESSENCIAIS
#------------------------------------

echo "Instalando programas essenciais"

apt install -y mupdf htop abiword \ audacious xarchiver rclone \
falkon claws-mail claws-mail-plugins \ pavucontrol gkrellm fonts-ubuntu || true
  
echo"Criar diretório conf gkrellm ,baixar themas copliland e descompactar na pasta ~/.gkrellm2/themes/"

mkdir -p ~/.gkrellm2/themes/
wget -c --progress=bar  http://www.muhri.net/gkrellm/CoplandOS.gkrellm.tar.gz
tar -xvf CoplandOS.tar.gz -C ~/.gkrellm2/themes/

# --------------------------------
# REMOÇÃO DE PROGRAMAS INÚTEIS
# -------------------------------


# -------------------------------
# TERMINAIS E AUTOCOMPLETE
# -------------------------------

echo "Instalando terminais e bash completion"

apt install -y lxterminal qterminal bash-completion fonts-ubuntu || true

# -------------------------------
# QTERMINAL - CONFIGURAÇÃO
# -------------------------------

echo "Configurando lxterminal"

mkdir -p "$HOME_USUARIO/.config/qterminal.org"

cat > "$HOME_USUARIO/.config/qterminal.org/qterminal.ini" <<'EOF'

[General]
Font=Ubuntu Mono,14,-1,5,50,0,0,0,0,0
ColorScheme=Linux
ScrollbarPosition=Hidden
HistoryLimited=true
HistorySize=5000
EOF

chown -R "$USUARIO:$USUARIO" "$HOME_USUARIO/.config"

update-alternatives --set x-terminal-emulator /usr/bin/qterminal

# -----------------------------------
# XTERM (FALLBACK)
# -----------------------------------

echo "Configurando xterm"

cat > "$HOME_USUARIO/.Xresources" <<'EOF'
XTerm*faceName: Ubuntu mono 
XTerm*faceSize: 14
XTerm*foreground: green
XTerm*background: black
XTerm*cursorColor: green
XTerm*geometry: 100x30
XTerm*scrollBar: false
XTerm*saveLines: 5000
XTerm*termName: xterm-256color
EOF

chown "$USUARIO:$USUARIO" "$HOME_USUARIO/.Xresources"

cat > /etc/X11/Xsession.d/90xresources <<'EOF'
#!/bin/sh
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"
EOF

chmod +x /etc/X11/Xsession.d/90xresources

# ------------------------------------
# BASH COMPLETION GLOBAL
# ------------------------------------

if ! grep -q bash_completion /etc/bash.bashrc; then
cat >> /etc/bash.bashrc <<'EOF'

if [ -f /usr/share/bash-completion/bash_completion ]; then
  . /usr/share/bash-completion/bash_completion
fi
EOF
fi

# ----------------------------------
# LOGIN AUTOMÁTICO
# ---------------------------------

echo "==> Configurando login automático"

mkdir -p /etc/lightdm/lightdm.conf.d

cat > /etc/lightdm/lightdm.conf.d/20-autologin.conf <<EOF
[Seat:*]
autologin-user=$USUARIO
autologin-user-timeout=0
user-session=lxqt
EOF

# --------------------------------
# GRUPOS DO USUÁRIO
# --------------------------------

usermod -aG audio,video,netdev,plugdev "$USUARIO"

# --------------------------------
# SWAP EM ARQUIVO
# --------------------------------

echo "Configurando swapfile"

if ! swapon --show | grep -q "/swapfile"; then
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
fi

if ! grep -q "/swapfile" /etc/fstab; then
  echo "/swapfile none swap sw 0 0" >> /etc/fstab
fi

# -----------------------------------
# OTIMIZAÇÕES
# -----------------------------------

echo "Aplicando otimizações"

echo "vm.swappiness=10" > /etc/sysctl.d/99-swappiness.conf
sysctl -p /etc/sysctl.d/99-swappiness.conf

mkdir -p /etc/systemd/journald.conf.d

cat > /etc/systemd/journald.conf.d/limit.conf <<EOF
[Journal]
SystemMaxUse=50M
RuntimeMaxUse=50M
EOF

systemctl restart systemd-journald

# ----------------------------------
# DISPLAY MANAGER
# ----------------------------------

systemctl enable lightdm

# ---------------------------------
# LIMPEZA FINAL
# --------------------------------

echo "Limpeza final"

apt autoremove -y
apt clean

echo "============================"
echo " Sistema pronto."
echo " Reiniciando..."
echo "============================"

reboot
