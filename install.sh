#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
#  Growtopia Linux Installer
#  github.com/arvcx/growtopia-linux
# ─────────────────────────────────────────────

WINEPREFIX="${WINEPREFIX:-$HOME/.wine-growtopia}"
GROWTOPIA_EXE="$WINEPREFIX/drive_c/users/$USER/AppData/Local/Growtopia/Growtopia.exe"
LOG_FILE="/tmp/growtopia-install.log"
VERSION="1.0.0"

# ── Colors ────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Logging ───────────────────────────────────
info()    { echo -e "${GREEN}  ✔${NC}  $1"; }
warn()    { echo -e "${YELLOW}  ⚠${NC}  $1"; }
error()   { echo -e "${RED}  ✖${NC}  $1" >&2; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}▶ $1${NC}"; }
log()     { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"; }

# ── Spinner ───────────────────────────────────
_SPINNER_PID=""

spinner_start() {
    local msg="$1"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    (
        while true; do
            printf "\r${CYAN}  ${frames[$i]}${NC}  %s" "$msg"
            i=$(( (i + 1) % ${#frames[@]} ))
            sleep 0.08
        done
    ) &
    _SPINNER_PID=$!
    disown "$_SPINNER_PID" 2>/dev/null || true
}

spinner_stop() {
    local status="${1:-ok}"
    if [[ -n "$_SPINNER_PID" ]] && kill -0 "$_SPINNER_PID" 2>/dev/null; then
        kill "$_SPINNER_PID" 2>/dev/null
        wait "$_SPINNER_PID" 2>/dev/null || true
        _SPINNER_PID=""
    fi
    if [[ "$status" == "ok" ]]; then
        printf "\r${GREEN}  ✔${NC}  %-50s\n" "$2"
    else
        printf "\r${RED}  ✖${NC}  %-50s\n" "$2"
    fi
}

# run_silent CMD MSG — runs CMD silently with spinner, logs output
run_silent() {
    local cmd="$1"
    local msg="$2"
    spinner_start "$msg"
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        spinner_stop ok "$msg"
    else
        spinner_stop fail "$msg"
        echo -e "${DIM}  See log: $LOG_FILE${NC}"
        exit 1
    fi
}

# ── Banner ────────────────────────────────────
print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
  ██████╗ ██████╗  ██████╗ ██╗    ██╗████████╗ ██████╗ ██████╗ ██╗ █████╗ 
 ██╔════╝ ██╔══██╗██╔═══██╗██║    ██║╚══██╔══╝██╔═══██╗██╔══██╗██║██╔══██╗
 ██║  ███╗██████╔╝██║   ██║██║ █╗ ██║   ██║   ██║   ██║██████╔╝██║███████║
 ██║   ██║██╔══██╗██║   ██║██║███╗██║   ██║   ██║   ██║██╔═══╝ ██║██╔══██║
 ╚██████╔╝██║  ██║╚██████╔╝╚███╔███╔╝   ██║   ╚██████╔╝██║     ██║██║  ██║
  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚══╝╚══╝    ╚═╝    ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝
EOF
    echo -e "${NC}"
    echo -e "${DIM}         Growtopia Linux Installer v${VERSION} — github.com/arvcx/growtopia-linux${NC}"
    echo ""
}

# ── Distro Detection ──────────────────────────
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    else
        error "Cannot detect distro. /etc/os-release not found."
    fi
}

# ── Arch / Manjaro / EndeavourOS ──────────────
install_deps_arch() {
    # Enable multilib if missing
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        warn "Enabling multilib repository..."
        sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    fi

    run_silent "sudo pacman -Sy --noconfirm" "Syncing package database"

    # Detect wine conflict BEFORE spawning subshell
    local has_staging=0
    pacman -Qq wine-staging &>/dev/null && has_staging=1

    if [[ $has_staging -eq 1 ]]; then
        warn "wine-staging detected — using it instead of wine (conflict avoided)"
        run_silent "sudo pacman -S --noconfirm --needed wine-staging wine-mono winetricks lib32-gnutls" "Installing Wine & dependencies"
    else
        run_silent "sudo pacman -S --noconfirm --needed wine wine-mono winetricks lib32-gnutls" "Installing Wine & dependencies"
    fi

    # AUR helper check for DXVK
    if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
        warn "No AUR helper found. Installing yay..."
        run_silent "sudo pacman -S --noconfirm --needed git base-devel" "Installing build tools"
        (
            git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin >> "$LOG_FILE" 2>&1
            cd /tmp/yay-bin
            makepkg -si --noconfirm >> "$LOG_FILE" 2>&1
        )
        spinner_stop ok "Building yay"
    fi

    if command -v yay &>/dev/null; then
        run_silent "yay -S --noconfirm dxvk-bin" "Installing DXVK (yay)"
    elif command -v paru &>/dev/null; then
        run_silent "paru -S --noconfirm dxvk-bin" "Installing DXVK (paru)"
    else
        warn "No AUR helper available, skipping DXVK"
    fi
}

# ── Ubuntu / Debian ───────────────────────────
install_deps_ubuntu() {
    run_silent "sudo dpkg --add-architecture i386" "Enabling 32-bit architecture"
    run_silent "sudo mkdir -pm755 /etc/apt/keyrings && sudo wget -q -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key" "Adding WineHQ GPG key"

    . /etc/os-release
    run_silent "sudo wget -qNP /etc/apt/sources.list.d/ 'https://dl.winehq.org/wine-builds/ubuntu/dists/${UBUNTU_CODENAME}/winehq-stable.sources'" "Adding WineHQ repository"
    run_silent "sudo apt update -y" "Updating package list"
    run_silent "sudo apt install -y --install-recommends winehq-stable winetricks libgnutls30:i386" "Installing Wine & dependencies"
    run_silent "sudo apt install -y dxvk" "Installing DXVK" || warn "DXVK not found in apt, skipping."
}

# ── Fedora ────────────────────────────────────
install_deps_fedora() {
    run_silent "sudo dnf install -y wine winetricks gnutls.i686" "Installing Wine & dependencies"
    run_silent "sudo dnf install -y dxvk" "Installing DXVK" || warn "DXVK not available, skipping."
}

# ── Wine Prefix Setup ─────────────────────────
setup_wineprefix() {
    export WINEPREFIX
    export WINEARCH=win64

    run_silent "wineboot --init" "Initializing Wine prefix"

    run_silent "wine reg add 'HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\msedgewebview2.exe' /v Version /t REG_SZ /d win8 /f" "Applying WebView2 registry fix"

    local tmp_wv2="/tmp/MicrosoftEdgeWebview2Setup.exe"
    run_silent "curl -fsSL 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -o '$tmp_wv2'" "Downloading WebView2 runtime"
    run_silent "wine '$tmp_wv2'" "Installing WebView2 runtime"

    if command -v setup_dxvk &>/dev/null; then
        run_silent "setup_dxvk install" "Applying DXVK to prefix"
    else
        warn "setup_dxvk not found, skipping DXVK prefix setup."
    fi
}

# ── Growtopia Install / Update ────────────────
download_and_run_installer() {
    local tmp_gt="/tmp/Growtopia-Installer.exe"
    run_silent "curl -fsSL 'https://growtopiagame.com/Growtopia-Installer.exe' -o '$tmp_gt'" "Downloading Growtopia installer"
    run_silent "WINEPREFIX='$WINEPREFIX' wine '$tmp_gt'" "Running Growtopia installer"
}

install_growtopia() {
    download_and_run_installer
}

update_growtopia() {
    if [[ ! -f "$GROWTOPIA_EXE" ]]; then
        error "Growtopia is not installed. Run the installer first (without --update)."
    fi
    info "Found existing installation at: $GROWTOPIA_EXE"
    download_and_run_installer
}

# ── Launcher & Desktop Entry ──────────────────
create_launcher() {
    local launcher="$HOME/.local/bin/growtopia"
    local desktop="$HOME/.local/share/applications/growtopia.desktop"

    mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"

    cat > "$launcher" << EOF
#!/bin/bash
export WINEPREFIX="$WINEPREFIX"
exec wine "$GROWTOPIA_EXE" "\$@"
EOF
    chmod +x "$launcher"

    cat > "$desktop" << EOF
[Desktop Entry]
Name=Growtopia
Comment=Play Growtopia via Wine
Exec=$launcher
Terminal=false
Type=Application
Categories=Game;
EOF

    # Ensure ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        warn "~/.local/bin is not in PATH. Add this to your shell profile:"
        echo -e "    ${DIM}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    fi

    info "Launcher created at $launcher"
    info "Desktop entry created at $desktop"
}

# ── Usage ─────────────────────────────────────
print_usage() {
    echo -e "Usage: $0 [OPTIONS]"
    echo ""
    echo -e "  ${BOLD}(no args)${NC}     Fresh install Growtopia"
    echo -e "  ${BOLD}--update${NC}      Re-download installer and update Growtopia"
    echo -e "  ${BOLD}--prefix PATH${NC} Custom Wine prefix path (default: ~/.wine-growtopia)"
    echo -e "  ${BOLD}--help${NC}        Show this help"
    echo ""
}

# ── Summary Box ───────────────────────────────
print_summary() {
    local mode="$1"
    echo ""
    echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
    if [[ "$mode" == "update" ]]; then
        echo -e "${CYAN}│${NC}  ${GREEN}${BOLD}Growtopia updated successfully!${NC}               ${CYAN}│${NC}"
    else
        echo -e "${CYAN}│${NC}  ${GREEN}${BOLD}Growtopia installed successfully!${NC}             ${CYAN}│${NC}"
    fi
    echo -e "${CYAN}├──────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC}  Run:    ${BOLD}growtopia${NC}                            ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  Update: ${BOLD}bash install.sh --update${NC}             ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  Log:    ${DIM}$LOG_FILE${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
    echo ""
}

# ── Main ──────────────────────────────────────
main() {
    print_banner

    # Init log
    echo "=== Growtopia Linux Installer - $(date) ===" > "$LOG_FILE"

    # Parse args
    local mode="install"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --update)  mode="update" ;;
            --prefix)  shift; WINEPREFIX="$1"; GROWTOPIA_EXE="$WINEPREFIX/drive_c/users/$USER/AppData/Local/Growtopia/Growtopia.exe" ;;
            --help|-h) print_usage; exit 0 ;;
            *) warn "Unknown option: $1"; print_usage; exit 1 ;;
        esac
        shift
    done

    if [[ "$mode" == "update" ]]; then
        step "Updating Growtopia"
        update_growtopia
        print_summary update
        exit 0
    fi

    # ── Fresh Install ──
    local distro
    distro=$(detect_distro)

    step "Installing system dependencies"
    case "$distro" in
        arch|manjaro|endeavouros|cachyos)   install_deps_arch ;;
        ubuntu|debian|linuxmint|pop)        install_deps_ubuntu ;;
        fedora)                             install_deps_fedora ;;
        *)
            warn "Distro '$distro' not officially supported. Trying Arch method..."
            install_deps_arch
            ;;
    esac

    step "Setting up Wine prefix"
    setup_wineprefix

    step "Installing Growtopia"
    install_growtopia

    step "Creating launcher"
    create_launcher

    print_summary install
}

main "$@"
