#!/data/data/com.termux/files/usr/bin/bash
if [ -z "$BASH_VERSION" ]; then exec bash "$0" "$@"; fi
# Wikilow Proot Installer
# Repository: https://github.com/Santuybe/
echo ""
echo " +----------------------------------------------------------+"
echo " |  W I K I L O W   P R O O T   I N S T A L L E R           |"
echo " |  Repository: https://github.com/Santuybe/                |"
echo " +----------------------------------------------------------+"
echo ""
ARCH=$(dpkg --print-architecture)
NOW=$(date +%T)
echo "[$NOW] [INFO] Scanning architecture: $ARCH"
PD_INSTALLED="false"
if command -v proot-distro >/dev/null 2>&1; then
    PD_INSTALLED="true"
    echo "[$NOW] [INFO] Official proot-distro detected."
fi
echo "[$NOW] [INFO] Fetching distribution data..."
LATEST_TAG=$(curl -s https://api.github.com/repos/termux/proot-distro/releases/latest | grep '"tag_name":' | sed 's/.*"tag_name": "//' | sed 's/".*//')
if [ -z "$LATEST_TAG" ]; then LATEST_TAG="v4.34.2"; fi
echo "[$NOW] [INFO] Latest Version: $LATEST_TAG"
case "$ARCH" in
    aarch64) PD_ARCH="aarch64" ;;
    arm) PD_ARCH="arm" ;;
    x86_64|amd64) PD_ARCH="x86_64" ;;
    i686|x86) PD_ARCH="i686" ;;
    *) echo "Error: Unsupported architecture"; exit 1 ;;
esac

echo ""
echo "Select Action:"
echo " 1. Install Distribution"
echo " 2. Uninstall Distribution"
printf "Choice [1-2]: "
read -r action_choice

if [ "$action_choice" = "2" ]; then
    echo ""
    echo "Distros detected (External):"
    manual_list=$(ls -d *-fs 2>/dev/null | sed 's/-fs//')
    if [ -n "$manual_list" ]; then
        echo "$manual_list"
    else
        echo "(None)"
    fi

    if [ "$PD_INSTALLED" = "true" ]; then
        echo ""
        echo "Distros detected (Official):"
        proot-distro list | grep "installed" | sed 's/^[ *]*//;s/ .*//' || echo "(None)"
    fi

    echo ""
    printf "Enter distro name to uninstall: "
    read -r REMOVE_DISTRO

    if [ -n "$REMOVE_DISTRO" ]; then
        # Remove manual
        if [ -d "${REMOVE_DISTRO}-fs" ]; then
            printf "Remove external ${REMOVE_DISTRO}? [y/N]: "
            read -r conf_rem
            if [ "$conf_rem" = "y" ] || [ "$conf_rem" = "Y" ]; then
                rm -rf "${REMOVE_DISTRO}-fs" "${REMOVE_DISTRO}.sh"
                echo "[$NOW] [INFO] External ${REMOVE_DISTRO} removed."
            fi
        fi
        # Remove official
        if [ "$PD_INSTALLED" = "true" ]; then
            if proot-distro list | sed 's/^[ *]*//' | grep -q "^$REMOVE_DISTRO "; then
                printf "Remove official ${REMOVE_DISTRO}? [y/N]: "
                read -r conf_rem_pd
                if [ "$conf_rem_pd" = "y" ] || [ "$conf_rem_pd" = "Y" ]; then
                    proot-distro remove "$REMOVE_DISTRO"
                    rm -f "${REMOVE_DISTRO}.sh"
                    echo "[$NOW] [INFO] Official ${REMOVE_DISTRO} removed."
                fi
            fi
        fi
    fi
    exit 0
fi

echo ""
echo "Available Distributions:"
echo " 1. alpine"
echo " 2. archlinux"
echo " 3. debian"
echo " 4. fedora"
echo " 5. kali"
echo " 6. ubuntu"
echo " 7. void"
echo ""
printf "Select distro [1-7]: "
read -r choice
case "$choice" in
    1) SELECTED="alpine" ;;
    2) SELECTED="archlinux" ;;
    3) SELECTED="debian" ;;
    4) SELECTED="fedora" ;;
    5) SELECTED="kali" ;;
    6) SELECTED="ubuntu" ;;
    7) SELECTED="void" ;;
    *) echo "Invalid selection"; exit 1 ;;
esac
echo "[$NOW] [INFO] Selected: $SELECTED"
FS_DIR="${SELECTED}-fs"
TAR="${SELECTED}.tar.xz"
if [ -d "$FS_DIR" ]; then
    printf "[$NOW] [WARNING] %s exists. Reinstall? [y/N]: " "$FS_DIR"
    read -r confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then rm -rf "$FS_DIR"; fi
fi
if [ ! -d "$FS_DIR" ]; then
    for pkg in wget proot tar xz-utils; do
        if ! command -v "$pkg" >/dev/null 2>&1; then echo "Error: $pkg not installed"; exit 1; fi
    done
    URL="https://github.com/termux/proot-distro/releases/download/${LATEST_TAG}/${SELECTED}-${PD_ARCH}-pd-${LATEST_TAG}.tar.xz"
    echo "[$NOW] [INFO] Downloading $SELECTED..."
    if wget "$URL" -O "$TAR"; then
        mkdir -p "$FS_DIR"
        echo "[$NOW] [INFO] Extracting..."
        proot --link2symlink tar -xJf "$TAR" -C "$FS_DIR" --exclude='dev' || :
        echo "nameserver 8.8.8.8" > "$FS_DIR/etc/resolv.conf"
        printf "#!/bin/sh\nexec \"\$@\"\n" > "$FS_DIR/usr/bin/sudo"
        chmod +x "$FS_DIR/usr/bin/sudo"
        rm -f "$TAR"
    else
        echo "Download failed"; exit 1
    fi
fi
echo ""
printf "Create non-root user? [y/N]: "
read -r create_user
if [ "$create_user" = "y" ] || [ "$create_user" = "Y" ]; then
    printf "Enter username: "
    read -r UNAME
    if [ -n "$UNAME" ]; then
        echo "[$NOW] [INFO] Configuring user $UNAME..."
        cat > "$FS_DIR/tmp/u.sh" << 'EOM'
U=$1
if command -v useradd >/dev/null; then useradd -m -s /bin/bash "$U"; else adduser -D -s /bin/bash "$U"; fi
if [ -d /etc/sudoers.d ]; then echo "$U ALL=(ALL:ALL) ALL" > "/etc/sudoers.d/$U"; fi
EOM
        proot --link2symlink -0 -r "$FS_DIR" /bin/sh /tmp/u.sh "$UNAME"
        rm -f "$FS_DIR/tmp/u.sh"
        L_USER="$UNAME"; L_HOME="/home/$UNAME"
    fi
fi
if [ -z "${L_USER:-}" ]; then L_USER="root"; L_HOME="/root"; fi
if [ "$PD_INSTALLED" = "true" ]; then
    PD_EXISTS=false
    if proot-distro list | sed 's/^[ *]*//' | grep -q "^$SELECTED "; then
        PD_EXISTS=true
    fi

    if [ "$PD_EXISTS" = "true" ]; then
        echo ""
        echo "Official $SELECTED is already installed."
        echo " 1. Continue to create/update launcher"
        echo " 2. Reinstall official $SELECTED"
        printf "Choice [1-2]: "
        read -r pd_exist_choice
        if [ "$pd_exist_choice" = "2" ]; then
            proot-distro remove "$SELECTED"
            proot-distro install "$SELECTED"
        fi
        FS_DIR="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/$SELECTED"
    else
        printf "\nUse official proot-distro rootfs for $SELECTED? [y/N]: "
        read -r pd_use
        if [ "$pd_use" = "y" ] || [ "$pd_use" = "Y" ]; then
            proot-distro install "$SELECTED"
            FS_DIR="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/$SELECTED"
        fi
    fi
fi
cat > "${SELECTED}.sh" << EOF
#!/bin/bash
unset LD_PRELOAD
command="proot --link2symlink -0 -r $FS_DIR -b /dev -b /proc -b /sys -b /data/data/com.termux -b /sdcard -b /storage -b /mnt -w $L_HOME /usr/bin/env -i HOME=$L_HOME PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games TERM=\$TERM USER=$L_USER LANG=C.UTF-8 /bin/bash --login"
if [ -z "\$1" ]; then exec \$command; else \$command -c "\$@"; fi
EOF
chmod +x "${SELECTED}.sh"
if command -v termux-fix-shebang > /dev/null 2>&1; then termux-fix-shebang "${SELECTED}.sh"; fi
echo "[$NOW] [INFO] Done. Run ./${SELECTED}.sh"
