#!/data/data/com.termux/files/usr/bin/bash
if [ -z "$BASH_VERSION" ]; then exec bash "$0" "$@"; fi

# Wikilow Proot Installer
# Repository: https://github.com/Santuybe/

# UI and Utility functions
get_time() { date +%T; }
log_info() { echo "[$(get_time)] [INFO] $*"; }
log_warn() { echo "[$(get_time)] [WARNING] $*"; }
log_err() { echo "[$(get_time)] [ERROR] $*"; }
log_quest() { printf "[$(get_time)] [QUESTION] $*"; }

# Banner Definition
show_banner() {
    cat << 'EOF'

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

EOF
}

# Guest setup function (Unified for all methods)
setup_guest_env() {
    log_info "Configuring guest environment for $SELECTED..."

    # 1. Inject Banner
    mkdir -p "$FS_DIR/etc"
    cat > "$FS_DIR/etc/wikilow-banner" << 'EOF'

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

EOF
    if ! grep -q "wikilow-banner" "$FS_DIR/etc/profile" 2>/dev/null; then
        echo "cat /etc/wikilow-banner" >> "$FS_DIR/etc/profile"
    fi

    # 2. Hardware Mock
    MOCK_DIR="$FS_DIR/etc/wikilow-mock"
    mkdir -p "$MOCK_DIR"
    cat > "$MOCK_DIR/cpuinfo" << 'EOF'
processor	: 0
BogoMIPS	: 100.00
Features	: fp asimd evtstrm aes pmull sha1 sha2 crc32 atomics fphp asimdhp cpuid asimdrdm jscvt fcma lrcpc dcpop sha3 sm3 sm4 asimdfhm dit uscat ilrcpc flagm sb paca pacg dcpodp sv2
CPU implementer	: 0x41
CPU architecture: 8
CPU variant	: 0x0
CPU part	: 0xd03
CPU revision	: 4
EOF
    cat > "$MOCK_DIR/meminfo" << 'EOF'
MemTotal:        8192000 kB
MemFree:         4096000 kB
MemAvailable:    5120000 kB
Buffers:          200000 kB
Cached:          1000000 kB
EOF

    # 3. Sudo stub (Only if not exists)
    # Create storage mount points
    mkdir -p "$FS_DIR/sdcard" "$FS_DIR/storage" "$FS_DIR/mnt" "$FS_DIR/host-rootfs"
    # Also create /storage/emulated/0 if possible
    mkdir -p "$FS_DIR/storage/emulated/0" 2>/dev/null || :

    if [ ! -f "$FS_DIR/usr/bin/sudo" ]; then
        mkdir -p "$FS_DIR/usr/bin"
        printf "#!/bin/sh\nexec \"\$@\"\n" > "$FS_DIR/usr/bin/sudo"
        chmod +x "$FS_DIR/usr/bin/sudo"
    fi

    # 4. Root Storage Symlinks
    mkdir -p "$FS_DIR/root"
    ln -s /sdcard "$FS_DIR/root/storage" 2>/dev/null || :
    ln -s /sdcard "$FS_DIR/root/sdcard" 2>/dev/null || :

    # 5. Non-root User
    echo ""
    log_quest "Create a non-root user (e.g. wikilow)? [y/N]: "
    read -r create_user
    if [[ "$create_user" =~ ^[Yy]$ ]]; then
        log_quest "Enter username: "
        read -r UNAME
        if [ -n "$UNAME" ]; then
            log_info "Setting up user $UNAME..."
            # Detect internal shell
            INT_SHELL_GUEST="/bin/sh"
            [ -x "$FS_DIR/bin/bash" ] && INT_SHELL_GUEST="/bin/bash"

            cat > "$FS_DIR/tmp/u.sh" << EOM
U=\$1
S=$INT_SHELL_GUEST
if command -v useradd >/dev/null; then
    useradd -m -s "\$S" "\$U" 2>/dev/null || :
else
    adduser -D -s "\$S" "\$U" 2>/dev/null || :
fi
mkdir -p /home/"\$U" 2>/dev/null
# Create a symlink to internal storage for easy access
ln -s /sdcard /home/"\$U"/storage 2>/dev/null || :
ln -s /sdcard /home/"\$U"/sdcard 2>/dev/null || :
chown -R "\$U":"\$U" /home/"\$U" 2>/dev/null || :
mkdir -p /etc/sudoers.d
echo "\$U ALL=(ALL:ALL) ALL" > "/etc/sudoers.d/\$U" 2>/dev/null || :
EOM
            proot --link2symlink -0 -r "$FS_DIR" /bin/sh /tmp/u.sh "$UNAME"
            rm -f "$FS_DIR/tmp/u.sh"
            LAUNCH_USER="$UNAME"
        fi
    fi
}

# START SCRIPT
show_banner

# Storage Setup Check
if [ ! -d "$HOME/storage" ]; then
    log_warn "Termux storage access not detected."
    log_quest "Run termux-setup-storage? [y/N]: "
    read -r tss
    if [[ "$tss" =~ ^[Yy]$ ]]; then
        termux-setup-storage
        echo "Please grant storage permission and press enter to continue..."
        read -r
    fi
fi

# Dependency Check
log_info "Checking dependencies..."
for pkg in wget proot tar xz-utils curl; do
    p_check=$pkg; [ "$pkg" = "xz-utils" ] && p_check="xz"
    if ! command -v "$p_check" >/dev/null 2>&1; then
        log_warn "$pkg is missing. Install? [y/N]: "
        read -r ic; if [[ "$ic" =~ ^[Yy]$ ]]; then pkg install "$pkg" -y; else exit 1; fi
    fi
done

ARCH=$(dpkg --print-architecture)
log_info "Architecture: $ARCH"

PD_INSTALLED=false; command -v proot-distro >/dev/null && PD_INSTALLED=true

echo ""
echo "Select Action:"
echo " 1. Install Distribution"
echo " 2. Uninstall Distribution"
log_quest "Choice [1-2]: "; read -r action_choice

if [ "$action_choice" = "2" ]; then
    echo ""
    echo "Installed (External):"
    manual_list=$(ls -d *-fs 2>/dev/null | sed 's/-fs//')
    [ -z "$manual_list" ] && echo " (None)" || echo "$manual_list"

    if $PD_INSTALLED; then
        echo "Installed (Official):"
        proot-distro list | grep "Status: installed" -B1 | grep "Alias:" | sed 's/.*Alias: //' || echo " (None)"
    fi

    echo ""
    log_quest "Enter distro name to uninstall: "; read -r REMOVE_DISTRO
    if [ -n "$REMOVE_DISTRO" ]; then
        if [ -d "${REMOVE_DISTRO}-fs" ]; then
            log_quest "Remove external $REMOVE_DISTRO? [y/N]: "; read -r conf_rem
            if [[ "$conf_rem" =~ ^[Yy]$ ]]; then rm -rf "${REMOVE_DISTRO}-fs" "${REMOVE_DISTRO}.sh"; log_info "External $REMOVE_DISTRO removed."; fi
        fi
        if $PD_INSTALLED; then
            if proot-distro list | grep -q "Alias: $REMOVE_DISTRO"; then
                log_quest "Remove official $REMOVE_DISTRO? [y/N]: "; read -r conf_rem_pd
                if [[ "$conf_rem_pd" =~ ^[Yy]$ ]]; then proot-distro remove "$REMOVE_DISTRO"; rm -f "${REMOVE_DISTRO}.sh"; log_info "Official $REMOVE_DISTRO removed."; fi
            fi
        fi
    fi
    exit 0
fi

# INSTALL FLOW
echo ""
echo "Available Distributions:"
echo " 1. alpine  2. archlinux  3. debian  4. fedora  5. kali  6. ubuntu  7. void"
log_quest "Select distro [1-7]: "; read -r choice
case "$choice" in
    1) SELECTED="alpine";; 2) SELECTED="archlinux";; 3) SELECTED="debian";;
    4) SELECTED="fedora";; 5) SELECTED="kali";; 6) SELECTED="ubuntu";; 7) SELECTED="void";;
    *) log_err "Invalid selection"; exit 1;;
esac

METHOD="manual"
if $PD_INSTALLED; then
    IS_PD_INSTALLED=false
    proot-distro list | grep "Status: installed" -B1 | grep -q "Alias: $SELECTED" && IS_PD_INSTALLED=true

    if $IS_PD_INSTALLED; then
        echo ""
        log_warn "Official $SELECTED is already installed."
        echo " 1. Use existing installation  2. Reinstall official  3. Install manual (External)"
        log_quest "Choice [1-3]: "; read -r mc
        case "$mc" in
            1) METHOD="official";;
            2) proot-distro remove "$SELECTED"; proot-distro install "$SELECTED"; METHOD="official";;
            3) METHOD="manual";;
        esac
    else
        echo ""
        echo "Choose method for $SELECTED:"
        echo " 1. Official proot-distro (Recommended)  2. Manual installation"
        log_quest "Choice [1-2]: "; read -r mc
        [ "$mc" = "1" ] && METHOD="official" || METHOD="manual"
    fi
fi

if [ "$METHOD" = "official" ]; then
    proot-distro list | grep "Status: installed" -B1 | grep -q "Alias: $SELECTED" || proot-distro install "$SELECTED"
    FS_DIR="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/$SELECTED"
else
    FS_DIR="$HOME/${SELECTED}-fs"
    if [ -d "$FS_DIR" ]; then
        log_warn "$FS_DIR exists. Reinstall? [y/N]: "; read -r c
        if [[ "$c" =~ ^[Yy]$ ]]; then rm -rf "$FS_DIR"; else exit 0; fi
    fi

    # Download
    case "$ARCH" in aarch64) PARCH="aarch64";; arm) PARCH="arm";; x86_64|amd64) PARCH="x86_64";; i686|x86) PARCH="i686";; *) exit 1;; esac
    log_info "Fetching download URL for $SELECTED ($ARCH)..."
    URL=$(curl -s https://api.github.com/repos/termux/proot-distro/releases | grep -o 'https://github.com/termux/proot-distro/releases/download/[^"]*' | grep "${SELECTED}" | grep "${PARCH}" | head -n 1)

    if [ -z "$URL" ]; then
        log_err "Could not find a download URL for $SELECTED on $ARCH."
        exit 1
    fi

    log_info "Downloading rootfs..."
    wget "$URL" -O "${SELECTED}.tar.xz" || exit 1
    mkdir -p "$FS_DIR"
    log_info "Extracting..."
    proot --link2symlink tar -xJf "${SELECTED}.tar.xz" -C "$FS_DIR" --exclude='dev' || :

    # Hoisting logic: detect and fix nested rootfs structure
    if [ "$(ls -1 "$FS_DIR" | wc -l)" -eq 1 ]; then
        nested_path=$(find "$FS_DIR" -maxdepth 1 -type d | grep -v "^$FS_DIR$" | head -n 1)
        if [ -n "$nested_path" ]; then
            log_info "Correcting nested rootfs structure..."
            mv "$nested_path"/* "$FS_DIR/" 2>/dev/null || :
            mv "$nested_path"/.* "$FS_DIR/" 2>/dev/null || :
            rmdir "$nested_path" 2>/dev/null || :
        fi
    fi

    printf "nameserver 8.8.8.8\n" > "$FS_DIR/etc/resolv.conf"
    rm -f "${SELECTED}.tar.xz"
fi

# Setup guest environment
setup_guest_env

# Launcher creation
L_USER="${LAUNCH_USER:-root}"
L_HOME="/root"; [ "$L_USER" != "root" ] && L_HOME="/home/$L_USER"

# Detect shell for launcher
INT_SHELL="/bin/sh"
[ -x "$FS_DIR/bin/bash" ] && INT_SHELL="/bin/bash"

cat > "${SELECTED}.sh" << EOF
#!/data/data/com.termux/files/usr/bin/bash
cd "\$(dirname "\$0")"
unset LD_PRELOAD
# Binds
MOCK=""
[ -d "$FS_DIR/etc/wikilow-mock" ] && MOCK="-b $FS_DIR/etc/wikilow-mock/cpuinfo:/proc/cpuinfo -b $FS_DIR/etc/wikilow-mock/meminfo:/proc/meminfo"

STORAGE="-b /sdcard -b /storage -b /mnt -b /:/host-rootfs"

# Ensure home exists for user
[ "$L_USER" != "root" ] && [ ! -d "$FS_DIR$L_HOME" ] && mkdir -p "$FS_DIR$L_HOME"

# Check for env and shell existence
LAUNCH_CMD="/usr/bin/env -i"
[ ! -x "$FS_DIR/usr/bin/env" ] && LAUNCH_CMD=""

command="proot --link2symlink -0 -r $FS_DIR \$MOCK \$STORAGE -b /dev -b /proc -b /sys -b /data/data/com.termux -w $L_HOME \$LAUNCH_CMD HOME=$L_HOME PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games TERM=\$TERM USER=$L_USER LANG=C.UTF-8 $INT_SHELL --login"
if [ -z "\$1" ]; then exec \$command; else \$command -c "\$@"; fi
EOF
chmod +x "${SELECTED}.sh"
command -v termux-fix-shebang >/dev/null && termux-fix-shebang "${SELECTED}.sh"
log_info "Done. Run ./${SELECTED}.sh"
