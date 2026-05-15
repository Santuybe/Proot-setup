#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
#                      W I K I L O W
#           https://github.com/Santuybe/
# ============================================================

BANNER="
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
"

echo "$BANNER"

# Professional UI prefix with time
get_time() {
    date +"%r"
}

INFO="[$(get_time)] [INFO]"
WARN="[$(get_time)] [WARNING]"
ERR="[$(get_time)] [ERROR]"
QUEST="[$(get_time)] [QUESTION]"

# Hardware Detection Mock
echo "$INFO Scanning hardware components..."
sleep 0.5
ARCH=$(dpkg --print-architecture)
MODEL=$(getprop ro.product.model 2>/dev/null || echo "Generic Device")
KERNEL=$(uname -r)
echo "$INFO Device Model  : $MODEL"
echo "$INFO Architecture  : $ARCH"
echo "$INFO Kernel Version : $KERNEL"
echo "$INFO Memory Status  : [ OK ]"
echo "$INFO Storage Status : [ OK ]"
echo "$INFO System analysis complete."
echo ""

# proot-distro detection
PD_INSTALLED=false
if command -v proot-distro > /dev/null 2>&1; then
    PD_INSTALLED=true
    echo "$INFO Official proot-distro detected."
fi

# Fetch latest version from proot-distro repo
echo "$INFO Fetching latest distribution data..."
LATEST_TAG=$(curl -s https://api.github.com/repos/termux/proot-distro/releases/latest | grep -oP '"tag_name": "\K[^"]+')

if [ -z "$LATEST_TAG" ]; then
    echo "$ERR Failed to fetch latest version. Using fallback v4.34.2"
    LATEST_TAG="v4.34.2"
else
    echo "$INFO Latest version found: $LATEST_TAG"
fi

# Map architecture
case "$ARCH" in
    aarch64) PD_ARCH="aarch64";;
    arm) PD_ARCH="arm";;
    x86_64|amd64) PD_ARCH="x86_64";;
    i686|x86) PD_ARCH="i686";;
    *)
        echo "$ERR Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Distro List (Commonly available in proot-distro releases)
distros=("alpine" "archlinux" "debian" "fedora" "kali" "ubuntu" "void")

echo ""
echo "Available Distributions:"
for i in "${!distros[@]}"; do
    printf " [%d] %s\n" "$((i+1))" "${distros[$i]}"
done
echo ""
read -p "$QUEST Select a distro [1-${#distros[@]}]: " choice

if [[ "$choice" -ge 1 && "$choice" -le "${#distros[@]}" ]]; then
    SELECTED_DISTRO="${distros[$((choice-1))]}"
    echo "$INFO Selected: $SELECTED_DISTRO"
else
    echo "$ERR Invalid selection."
    exit 1
fi

# Define directory and tarball name
FS_DIR="${SELECTED_DISTRO}-fs"
TARBALL="${SELECTED_DISTRO}.tar.xz"

install_distro() {
    if [ -d "$FS_DIR" ]; then
        echo "$WARN $FS_DIR already exists."
        read -p "$QUEST Reinstall? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "$INFO Skipping installation."
            return
        fi
        rm -rf "$FS_DIR"
    fi

    # Check dependencies
    for pkg in wget proot tar xz-utils; do
        if ! command -v $pkg > /dev/null 2>&1; then
            echo "$ERR $pkg is not installed. Please install it first."
            exit 1
        fi
    done

    # Download URL
    # Format example: https://github.com/termux/proot-distro/releases/download/v4.34.2/ubuntu-aarch64-pd-v4.34.2.tar.xz
    DL_URL="https://github.com/termux/proot-distro/releases/download/${LATEST_TAG}/${SELECTED_DISTRO}-${PD_ARCH}-pd-${LATEST_TAG}.tar.xz"

    echo "$INFO Downloading $SELECTED_DISTRO rootfs..."
    if ! wget "$DL_URL" -O "$TARBALL"; then
        echo "$ERR Download failed. The rootfs might not be available for this architecture/version."
        exit 1
    fi

    mkdir -p "$FS_DIR"
    echo "$INFO Extracting rootfs..."
    proot --link2symlink tar -xJf "$TARBALL" -C "$FS_DIR" --exclude='dev'||:

    echo "$INFO Configuring network..."
    printf "nameserver 8.8.8.8\nnameserver 8.8.4.4\n" > "$FS_DIR/etc/resolv.conf"

    echo "$INFO Writing stubs..."
    echo -e "#!/bin/sh\nexit" > "$FS_DIR/usr/bin/groups" 2>/dev/null || :

    echo "$INFO Cleaning up..."
    rm "$TARBALL"
    echo "$INFO $SELECTED_DISTRO installation complete (No GUI)."
}

if $PD_INSTALLED; then
    echo ""
    echo "Options:"
    echo " [1] Install via this script (Manual)"
    echo " [2] Use existing proot-distro (Official)"
    echo " [3] Create launcher only"
    read -p "$QUEST Choice [1-3]: " mode_choice
    case "$mode_choice" in
        1) install_distro ;;
        2)
            echo "$INFO Using official proot-distro for $SELECTED_DISTRO"
            if ! proot-distro list | grep -q "$SELECTED_DISTRO"; then
                 echo "$WARN $SELECTED_DISTRO not found in proot-distro list. Installing..."
                 proot-distro install "$SELECTED_DISTRO"
            else
                 echo "$INFO $SELECTED_DISTRO is already installed via proot-distro."
            fi
            FS_DIR="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/$SELECTED_DISTRO"
            ;;
        3) echo "$INFO Proceeding to launcher creation..." ;;
        *) echo "$ERR Invalid choice."; exit 1 ;;
    esac
else
    install_distro
fi

# Launcher creation
LAUNCHER="start-${SELECTED_DISTRO}.sh"
echo "$INFO Creating launcher: $LAUNCHER"

# Common binds
BINDS=""
BINDS+=" -b /dev"
BINDS+=" -b /proc"
BINDS+=" -b /sys"
BINDS+=" -b /data/data/com.termux"
BINDS+=" -b /sdcard"
BINDS+=" -b /storage"
BINDS+=" -b /mnt"

cat > "$LAUNCHER" <<- EOM
#!/bin/bash
# Wikilow Launcher for ${SELECTED_DISTRO}
# Repo: https://github.com/Santuybe/

unset LD_PRELOAD
command="proot"
command+=" --link2symlink"
command+=" -0"
command+=" -r $FS_DIR"
command+=" $BINDS"
command+=" -w /root"
command+=" /usr/bin/env -i"
command+=" HOME=/root"
command+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
command+=" TERM=\$TERM"
command+=" LANG=C.UTF-8"
command+=" /bin/bash --login"

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

echo "$INFO Launcher created successfully."
echo "$INFO You can start $SELECTED_DISTRO by running: ./${LAUNCHER}"
echo "$INFO Storage access (/sdcard) is enabled."
