#!/bin/bash
set -e

WINEPREFIX="$HOME/.wine-growtopia"
GROWTOPIA_EXE="$WINEPREFIX/drive_c/users/$USER/AppData/Local/Growtopia/Growtopia.exe"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        error "Cannot detect distro. /etc/os-release not found."
    fi
}

install_deps_arch() {
    info "Detected Arch Linux"

    # Enable multilib if not already enabled
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        warn "Enabling multilib repository..."
        sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    fi

    info "Syncing package database..."
    sudo pacman -Sy --noconfirm

    info "Installing Wine, winetricks, and dependencies..."
    sudo pacman -S --noconfirm --needed wine wine-mono winetricks lib32-gnutls

    info "Installing DXVK..."
    if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
        warn "No AUR helper found. Installing yay..."
        sudo pacman -S --noconfirm --needed git base-devel
        git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
        cd /tmp/yay-bin && makepkg -si --noconfirm
        cd -
    fi

    if command -v yay &>/dev/null; then
        yay -S --noconfirm dxvk-bin
    elif command -v paru &>/dev/null; then
        paru -S --noconfirm dxvk-bin
    fi
}

install_deps_ubuntu() {
    info "Detected Ubuntu/Debian"

    info "Enabling 32-bit architecture..."
    sudo dpkg --add-architecture i386

    info "Adding Wine repository..."
    sudo mkdir -pm755 /etc/apt/keyrings
    sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
    . /etc/os-release
    sudo wget -NP /etc/apt/sources.list.d/ "https://dl.winehq.org/wine-builds/ubuntu/dists/${UBUNTU_CODENAME}/winehq-stable.sources"

    info "Updating package list..."
    sudo apt update -y

    info "Installing Wine, winetricks, and dependencies..."
    sudo apt install -y --install-recommends winehq-stable winetricks libgnutls30:i386

    info "Installing DXVK..."
    sudo apt install -y dxvk || warn "DXVK not found in apt, skipping. You can install it manually."
}

install_deps_fedora() {
    info "Detected Fedora"

    info "Installing Wine and dependencies..."
    sudo dnf install -y wine winetricks gnutls.i686

    info "Installing DXVK..."
    sudo dnf install -y dxvk || warn "DXVK not available, skipping."
}

setup_wineprefix() {
    info "Setting up Wine prefix at $WINEPREFIX..."
    export WINEPREFIX
    export WINEARCH=win64
    wineboot --init 2>/dev/null

    info "Applying WebView2 fix..."
    wine reg add "HKEY_CURRENT_USER\Software\Wine\AppDefaults\msedgewebview2.exe" \
        /v Version /t REG_SZ /d win8 /f 2>/dev/null

    info "Installing WebView2 runtime..."
    TMP_WV2="/tmp/MicrosoftEdgeWebview2Setup.exe"
    curl -L "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -o "$TMP_WV2"
    wine "$TMP_WV2" 2>/dev/null

    info "Applying DXVK..."
    if command -v setup_dxvk &>/dev/null; then
        setup_dxvk install 2>/dev/null
    else
        warn "setup_dxvk not found, skipping DXVK setup."
    fi
}

install_growtopia() {
    info "Downloading Growtopia installer..."
    TMP_GT="/tmp/Growtopia-Installer.exe"
    curl -L "https://growtopiagame.com/Growtopia-Installer.exe" -o "$TMP_GT"

    info "Running Growtopia installer..."
    WINEPREFIX="$WINEPREFIX" wine "$TMP_GT" 2>/dev/null
}

create_launcher() {
    LAUNCHER="$HOME/.local/bin/growtopia"
    mkdir -p "$HOME/.local/bin"

    cat > "$LAUNCHER" <<EOF
#!/bin/bash
export WINEPREFIX="$WINEPREFIX"
exec wine "$GROWTOPIA_EXE" "\$@"
EOF
    chmod +x "$LAUNCHER"

    # Desktop entry
    DESKTOP="$HOME/.local/share/applications/growtopia.desktop"
    mkdir -p "$HOME/.local/share/applications"
    cat > "$DESKTOP" <<EOF
[Desktop Entry]
Name=Growtopia
Exec=$LAUNCHER
Type=Application
Categories=Game;
EOF

    info "Launcher created at $LAUNCHER"
    info "You can now run Growtopia by typing: growtopia"
    info "Or find it in your application menu."
}

main() {
    echo ""
    echo "  ██████╗ ██████╗  ██████╗ ██╗    ██╗████████╗ ██████╗ ██████╗ ██╗ █████╗ "
    echo " ██╔════╝ ██╔══██╗██╔═══██╗██║    ██║╚══██╔══╝██╔═══██╗██╔══██╗██║██╔══██╗"
    echo " ██║  ███╗██████╔╝██║   ██║██║ █╗ ██║   ██║   ██║   ██║██████╔╝██║███████║"
    echo " ██║   ██║██╔══██╗██║   ██║██║███╗██║   ██║   ██║   ██║██╔═══╝ ██║██╔══██║"
    echo " ╚██████╔╝██║  ██║╚██████╔╝╚███╔███╔╝   ██║   ╚██████╔╝██║     ██║██║  ██║"
    echo "  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚══╝╚══╝    ╚═╝    ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝"
    echo ""
    echo "           Growtopia Linux Installer — github.com/arvcx/growtopia-linux"
    echo ""

    DISTRO=$(detect_distro)

    case "$DISTRO" in
        arch|manjaro|endeavouros)   install_deps_arch ;;
        ubuntu|debian|linuxmint|pop) install_deps_ubuntu ;;
        fedora)                      install_deps_fedora ;;
        *)
            warn "Distro '$DISTRO' not officially supported. Trying Arch method..."
            install_deps_arch
            ;;
    esac

    setup_wineprefix
    install_growtopia
    create_launcher

    echo ""
    info "Installation complete! Run: growtopia"
    echo ""
}

main
