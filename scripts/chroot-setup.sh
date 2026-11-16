#!/bin/bash
# Runs INSIDE the chroot (started by 02-build-rootfs.sh). Installs and configures PearyOS.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C LANG=C
APT="apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"
trap 'echo "!!! chroot-setup failed at line $LINENO" >&2' ERR

# Never start services while building the image
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod 755 /usr/sbin/policy-rc.d

cat > /etc/apt/sources.list <<'APTEOF'
deb http://archive.ubuntu.com/ubuntu noble main restricted universe
deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe
deb http://security.ubuntu.com/ubuntu noble-security main restricted universe
APTEOF
rm -f /etc/apt/sources.list.d/ubuntu.sources
$APT update

# ---- 1. system base -------------------------------------------------------
$APT install --no-install-recommends \
  systemd-sysv systemd-resolved udev dbus dbus-user-session dbus-x11 libpam-systemd sudo \
  locales tzdata less nano curl wget iproute2 iputils-ping net-tools bind9-dnsutils ethtool \
  pciutils usbutils lshw mokutil unzip zip p7zip-full ntfs-3g exfatprogs dosfstools e2fsprogs \
  openssh-client htop kmod bash-completion polkitd pkexec xdg-utils systemd-zram-generator \
  initramfs-tools

# Build the initramfs once at the end, not after every package
sed -i 's/^update_initramfs=.*/update_initramfs=no/' /etc/initramfs-tools/update-initramfs.conf

# ---- 2. kernel (newest HWE), firmware, microcode, live-boot support --------
if apt-cache show linux-image-generic-hwe-24.04 >/dev/null 2>&1; then
  KPKG=linux-image-generic-hwe-24.04
else
  KPKG=linux-generic-hwe-24.04
fi
$APT install --no-install-recommends "$KPKG" linux-firmware intel-microcode amd64-microcode casper
KVER=$(ls /lib/modules | sort -V | tail -1)
echo "KERNEL VERSION: $KVER"
# Extra drivers: older kernels ship them in a separate package; newer ones bundle them in linux-modules
if apt-cache show "linux-modules-extra-$KVER" >/dev/null 2>&1; then
  $APT install --no-install-recommends "linux-modules-extra-$KVER"
else
  echo "No separate modules-extra package for $KVER (drivers are bundled in linux-modules)"
fi

# ---- 3. desktop -----------------------------------------------------------
$APT install --no-install-recommends \
  lightdm lightdm-gtk-greeter xfce4-session xfce4-panel xfdesktop4 xfwm4 xfce4-settings \
  xfce4-terminal xfce4-appfinder xfce4-notifyd xfce4-power-manager xfce4-power-manager-plugins \
  xfce4-pulseaudio-plugin xfce4-whiskermenu-plugin xfce4-screenshooter xfce4-taskmanager \
  xfce4-clipman-plugin thunar thunar-archive-plugin thunar-volman mousepad ristretto file-roller \
  gvfs gvfs-backends udisks2 upower policykit-1-gnome gparted epiphany-browser libxfce4ui-utils \
  xdg-user-dirs-gtk libgtk-3-bin

# ---- 4. look & feel -------------------------------------------------------
$APT install --no-install-recommends \
  arc-theme papirus-icon-theme fonts-inter fonts-noto-core fonts-noto-color-emoji fonts-firacode \
  adwaita-icon-theme gnome-themes-extra librsvg2-common gsettings-desktop-schemas \
  dconf-gsettings-backend at-spi2-core

# ---- 4b. glass: compositor (blur, shadows, rounded corners) + the dock that acts as the taskbar ----
$APT install --no-install-recommends picom plank

# ---- 5. network, bluetooth, audio -----------------------------------------
$APT install --no-install-recommends \
  network-manager network-manager-gnome wpasupplicant iw wireless-regdb dnsmasq-base \
  bluez blueman pipewire pipewire-pulse wireplumber pipewire-alsa libspa-0.2-bluetooth \
  pavucontrol alsa-utils

# ---- 6. graphics + VM guest integration -----------------------------------
$APT install --no-install-recommends \
  xserver-xorg-core xserver-xorg-input-libinput xserver-xorg-video-fbdev xserver-xorg-video-vesa \
  libgl1-mesa-dri libglx-mesa0 mesa-vulkan-drivers x11-xserver-utils xauth mesa-utils \
  spice-vdagent open-vm-tools-desktop qemu-guest-agent

# ---- 7. PearyOS configuration (applied after packages so our files win) -----
tar -C /root/overlay -cf - . | tar -C / -xf - --no-overwrite-dir
chmod 0755 /usr/local/bin/pearyos-diag /usr/local/bin/pearyos-glass /usr/local/bin/pearyos-dock \
  /usr/local/bin/pearyos-wallpaper /usr/local/sbin/pearyos-selftest

# PearyGlass is Arc-Dark plus glass; it needs Arc-Dark's compiled resources next to it
install -m 0644 /usr/share/themes/Arc-Dark/gtk-3.0/gtk.gresource /usr/share/themes/PearyGlass/gtk-3.0/gtk.gresource
ln -sfn ../Arc-Dark/gtk-2.0 /usr/share/themes/PearyGlass/gtk-2.0
glib-compile-schemas /usr/share/glib-2.0/schemas
gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
# We start the compositor and the dock ourselves (pearyos-glass / pearyos-dock autostart entries)
rm -f /etc/xdg/autostart/picom.desktop /etc/xdg/autostart/plank.desktop
test -x /usr/bin/picom && test -x /usr/bin/plank

rm -f /etc/os-release
cat > /etc/os-release <<'OSEOF'
PRETTY_NAME="PearyOS 1.0"
NAME="PearyOS"
VERSION_ID="1.0"
VERSION="1.0 (built on Ubuntu 24.04 noble)"
VERSION_CODENAME=noble
ID=pearyos
ID_LIKE="ubuntu debian"
UBUNTU_CODENAME=noble
OSEOF
cat > /etc/lsb-release <<'LSBEOF'
DISTRIB_ID=PearyOS
DISTRIB_RELEASE=1.0
DISTRIB_CODENAME=noble
DISTRIB_DESCRIPTION="PearyOS 1.0"
LSBEOF
printf 'PearyOS 1.0 \\n \\l\n\n' > /etc/issue
echo "pearyos" > /etc/hostname
printf '127.0.0.1 localhost\n127.0.1.1 pearyos\n::1 localhost ip6-localhost ip6-loopback\n' > /etc/hosts

sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8
ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
echo "Etc/UTC" > /etc/timezone

# Authentication agent for the XFCE session (polkit dialogs)
AGENT=$(dpkg -L policykit-1-gnome | grep -E 'polkit-gnome-authentication-agent-1$' | head -1)
echo "POLKIT AGENT: $AGENT"
cat > /etc/xdg/autostart/pearyos-polkit-agent.desktop <<AGEOF
[Desktop Entry]
Type=Application
Name=PolicyKit Authentication Agent
Exec=$AGENT
OnlyShowIn=XFCE;
NoDisplay=true
AGEOF

# Services
systemctl enable NetworkManager.service lightdm.service bluetooth.service \
  systemd-resolved.service pearyos-selftest.service
systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service || true
systemctl set-default graphical.target
systemctl disable NetworkManager-wait-online.service apt-daily.timer apt-daily-upgrade.timer || true

# ---- diagnostics for review (how casper/lightdm autologin is wired) ---------
echo "==== casper autologin wiring ===="
grep -rn -i -E 'lightdm|nopasswdlogin|autologin|USERGROUPS' /usr/share/initramfs-tools/scripts/casper-bottom/ /usr/share/initramfs-tools/scripts/casper 2>/dev/null | head -40 || true
echo "==== lightdm autologin PAM ===="
cat /etc/pam.d/lightdm-autologin || true
getent group nopasswdlogin || echo "(no nopasswdlogin group yet)"

# ---- 8. initramfs -----------------------------------------------------------
sed -i 's/^update_initramfs=.*/update_initramfs=yes/' /etc/initramfs-tools/update-initramfs.conf
update-initramfs -c -k "$KVER" || update-initramfs -u -k "$KVER"
ls -lh /boot

# ---- 9. cleanup -------------------------------------------------------------
rm -f /usr/sbin/policy-rc.d
$APT clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin /tmp/* /var/tmp/*
rm -f /etc/resolv.conf
ln -s ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
: > /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id
rm -rf /root/overlay /root/chroot-setup.sh /root/.bash_history
find /var/log -type f -exec truncate -s 0 {} +
echo "CHROOT SETUP COMPLETE"
