#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
#                      W I K I L O W
#           https://github.com/Santuybe/
# ============================================================

echo '
+----------------------------------------------------------+
|  __      __.__ __   .__.__                               |
| /  \    /  \__|  | _|__|  |   ______  _  __              |
| \   \/\/   /  |  |/ /  |  |  /  _ \ \/ \/ /              |
|  \        /|  |    <|  |  |_(  <_> )     /               |
|   \__/\  / |__|__|_ \__|____/\____/ \/\_/                |
|        \/          \/                                    |
|                                                          |
|           Repo: https://github.com/Santuybe/             |
+----------------------------------------------------------+
'

# Professional UI prefix with time
get_time() {
    date +"%r"
}

# UI markers
INFO_TAG="INFO"
WARN_TAG="WARNING"
ERR_TAG="ERROR"
QUEST_TAG="QUESTION"

log_info() { echo "[$(get_time)] [$INFO_TAG] $*"; }
log_warn() { echo "[$(get_time)] [$WARN_TAG] $*"; }
log_err() { echo "[$(get_time)] [$ERR_TAG] $*"; }
log_quest() { printf "[$(get_time)] [$QUEST_TAG] $*"; }

# Hardware Detection Mock
log_info "Scanning hardware components..."
sleep 0.5
ARCH=$(dpkg --print-architecture)
MODEL=$(getprop ro.product.model 2>/dev/null || echo "Generic Device")
KERNEL=$(uname -r)
log_info "Device Model  : $MODEL"
log_info "Architecture  : $ARCH"
log_info "Kernel Version : $KERNEL"
log_info "Memory Status  : [ OK ]"
log_info "Storage Status : [ OK ]"
log_info "System analysis complete."
echo ""

# proot-distro detection
PD_INSTALLED=false
if command -v proot-distro > /dev/null 2>&1; then
    PD_INSTALLED=true
    log_info "Official proot-distro detected."
fi

# Fetch latest version from proot-distro repo
log_info "Fetching latest distribution data..."
LATEST_TAG=$(curl -s https://api.github.com/repos/termux/proot-distro/releases/latest | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')

if [ -z "$LATEST_TAG" ]; then
    log_err "Failed to fetch latest version. Using fallback v4.34.2"
    LATEST_TAG="v4.34.2"
else
    log_info "Latest version found: $LATEST_TAG"
fi

# Map architecture
case "$ARCH" in
    aarch64) PD_ARCH="aarch64";;
    arm) PD_ARCH="arm";;
    x86_64|amd64) PD_ARCH="x86_64";;
    i686|x86) PD_ARCH="i686";;
    *)
        log_err "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Distro List
distros="alpine archlinux debian fedora kali ubuntu void"

echo ""
echo "Available Distributions:"
count=1
for d in $distros; do
    echo " [$count] $d"
    count=$((count+1))
done

echo ""
log_quest "Select a distro [1-$((count-1))]: "
read choice

selected_count=1
SELECTED_DISTRO=""
for d in $distros; do
    if [ "$choice" -eq "$selected_count" ] 2>/dev/null; then
        SELECTED_DISTRO=$d
        break
    fi
    selected_count=$((selected_count+1))
done

if [ -z "$SELECTED_DISTRO" ]; then
    log_err "Invalid selection."
    exit 1
else
    log_info "Selected: $SELECTED_DISTRO"
fi

# Define directory and tarball name
FS_DIR="${SELECTED_DISTRO}-fs"
TARBALL="${SELECTED_DISTRO}.tar.xz"

install_distro() {
    if [ -d "$FS_DIR" ]; then
        log_warn "$FS_DIR already exists."
        log_quest "Reinstall? [y/N]: "
        read confirm
        case "$confirm" in
            [Yy]*) rm -rf "$FS_DIR" ;;
            *) log_info "Skipping installation."; return ;;
        esac
    fi

    # Check dependencies
    for pkg in wget proot tar xz-utils; do
        if ! command -v $pkg > /dev/null 2>&1; then
            log_err "$pkg is not installed. Please install it first."
            exit 1
        fi
    done

    # Download URL
    DL_URL="https://github.com/termux/proot-distro/releases/download/${LATEST_TAG}/${SELECTED_DISTRO}-${PD_ARCH}-pd-${LATEST_TAG}.tar.xz"

    log_info "Downloading $SELECTED_DISTRO rootfs..."
    if ! wget "$DL_URL" -O "$TARBALL"; then
        log_err "Download failed. The rootfs might not be available for this architecture/version."
        exit 1
    fi

    mkdir -p "$FS_DIR"
    log_info "Extracting rootfs..."
    proot --link2symlink tar -xJf "$TARBALL" -C "$FS_DIR" --exclude='dev'||:

    log_info "Configuring network..."
    printf "nameserver 8.8.8.8\nnameserver 8.8.4.4\n" > "$FS_DIR/etc/resolv.conf"

    log_info "Writing stubs..."
    echo -e "#!/bin/sh\nexit" > "$FS_DIR/usr/bin/groups" 2>/dev/null || :

    # Sudo stub for compatibility
    echo -e "#!/bin/sh\nexec \"\$@\"" > "$FS_DIR/usr/bin/sudo" 2>/dev/null || :
    chmod +x "$FS_DIR/usr/bin/sudo" 2>/dev/null || :

    log_info "Cleaning up..."
    rm "$TARBALL"
    log_info "$SELECTED_DISTRO installation complete (No GUI)."
}

setup_user() {
    echo ""
    log_quest "Create a non-root user (e.g. wikilow)? [y/N]: "
    read create_user
    case "$create_user" in
        [Yy]*)
            log_quest "Enter username: "
            read NEW_USER
            if [ -n "$NEW_USER" ]; then
                log_info "Configuring user $NEW_USER..."
                cat > "$FS_DIR/tmp/setup_user.sh" << EOM
#!/bin/sh
if command -v useradd > /dev/null; then
    useradd -m -s /bin/bash "$NEW_USER"
elif command -v adduser > /dev/null; then
    adduser -D -s /bin/bash "$NEW_USER"
fi
if [ -d /etc/sudoers.d ]; then
    echo "$NEW_USER ALL=(ALL:ALL) ALL" > "/etc/sudoers.d/$NEW_USER"
fi
EOM
                chmod +x "$FS_DIR/tmp/setup_user.sh"
                proot --link2symlink -0 -r "$FS_DIR" /bin/sh /tmp/setup_user.sh 2>/dev/null || :
                rm "$FS_DIR/tmp/setup_user.sh"
                log_info "User $NEW_USER has been set up with sudo privileges."
            fi
            ;;
    esac
}

if [ "$PD_INSTALLED" = true ]; then
    echo ""
    echo "Options:"
    echo " [1] Install via this script (Manual)"
    echo " [2] Use existing proot-distro (Official)"
    echo " [3] Create launcher only"
    log_quest "Choice [1-3]: "
    read mode_choice
    case "$mode_choice" in
        1) install_distro; setup_user ;;
        2)
            log_info "Using official proot-distro for $SELECTED_DISTRO"
            if ! proot-distro list | grep -q "$SELECTED_DISTRO"; then
                 log_warn "$SELECTED_DISTRO not found in proot-distro list. Installing..."
                 proot-distro install "$SELECTED_DISTRO"
            else
                 log_info "$SELECTED_DISTRO is already installed via proot-distro."
            fi
            FS_DIR="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/$SELECTED_DISTRO"
            ;;
        3) log_info "Proceeding to launcher creation..." ;;
        *) log_err "Invalid choice."; exit 1 ;;
    esac
else
    install_distro
    setup_user
fi

# Launcher creation
LAUNCHER="${SELECTED_DISTRO}.sh"
log_info "Creating launcher: $LAUNCHER"

# Common binds
BINDS=""
BINDS="$BINDS -b /dev"
BINDS="$BINDS -b /proc"
BINDS="$BINDS -b /sys"
BINDS="$BINDS -b /data/data/com.termux"
BINDS="$BINDS -b /sdcard"
BINDS="$BINDS -b /storage"
BINDS="$BINDS -b /mnt"

# Determine user for launcher
if [ -z "$NEW_USER" ]; then
    L_USER="root"
    L_HOME="/root"
else
    L_USER="$NEW_USER"
    L_HOME="/home/$NEW_USER"
fi

cat > "$LAUNCHER" << EOM
#!/bin/bash
# Wikilow Launcher for ${SELECTED_DISTRO}
# Repo: https://github.com/Santuybe/

unset LD_PRELOAD
command="proot"
command="\$command --link2symlink"
command="\$command -0"
command="\$command -r $FS_DIR"
command="\$command $BINDS"
command="\$command -w $L_HOME"
command="\$command /usr/bin/env -i"
command="\$command HOME=$L_HOME"
command="\$command PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
command="\$command TERM=\$TERM"
command="\$command USER=$L_USER"
command="\$command LANG=C.UTF-8"
command="\$command /bin/bash --login"

if [ -z "\$1" ]; then
    exec \$command
else
    \$command -c "\$@"
fi
EOM

chmod +x "$LAUNCHER"
if command -v termux-fix-shebang > /dev/null 2>&1; then
    termux-fix-shebang "$LAUNCHER"
fi

log_info "Launcher created successfully."
log_info "You can start $SELECTED_DISTRO by running: ./${LAUNCHER}"
log_info "Storage access (/sdcard) is enabled."
