# 🌱 Growtopia on Linux

Run Growtopia on Linux using Wine — supports Arch, Ubuntu/Debian, and Fedora.

> Growtopia now uses WebView2 for its login screen, which requires some extra setup on Linux. This script handles everything automatically.

---

## ⚡ Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/arvcx/growtopia-linux/main/install.sh | bash
```

That's it. The script will:
- Install Wine and dependencies
- Set up a dedicated Wine prefix
- Install WebView2 runtime
- Apply DXVK (improves rendering performance)
- Download and install Growtopia
- Create a `growtopia` launcher command + desktop entry

---

## 📋 Requirements

| Distro | Status |
|--------|--------|
| Arch Linux / Manjaro / EndeavourOS | ✅ Tested |
| Ubuntu / Debian / Linux Mint / Pop!_OS | ✅ Supported |
| Fedora | ✅ Supported |
| Other | ⚠️ May work |

- 64-bit system
- ~2GB free disk space
- Internet connection

---

## 🛠️ Manual Install (Step by Step)

### Arch Linux

```bash
# Enable multilib in /etc/pacman.conf first, then:
sudo pacman -Sy wine wine-mono winetricks lib32-gnutls
yay -S dxvk-bin

export WINEPREFIX=$HOME/.wine-growtopia
export WINEARCH=win64
wineboot --init

# Install WebView2
curl -L "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -o /tmp/webview2.exe
wine /tmp/webview2.exe

# Fix WebView2 rendering
wine reg add "HKEY_CURRENT_USER\Software\Wine\AppDefaults\msedgewebview2.exe" /v Version /t REG_SZ /d win8 /f

# Apply DXVK
setup_dxvk install

# Install Growtopia
curl -L "https://growtopiagame.com/Growtopia-Installer.exe" -o /tmp/growtopia.exe
wine /tmp/growtopia.exe
```

### Ubuntu / Debian

```bash
sudo dpkg --add-architecture i386
sudo mkdir -pm755 /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
# Add WineHQ repo for your Ubuntu version, then:
sudo apt update
sudo apt install -y winehq-stable winetricks libgnutls30:i386 dxvk

# Then follow the same Wine prefix steps as Arch above
```

---

## 🚀 Running Growtopia

After install, just run:

```bash
growtopia
```

Or find it in your application menu.

---

## 🐛 Known Issues

**WebView2 login screen blinking** — This is a known limitation of Wine. The login screen (WebView2) will flicker/blink until you interact with it (click or type). This is caused by Wine's incomplete implementation of DirectComposition (`DCompositionCreateDevice3`), which is an open bug in WineHQ. The game itself works fine after login — only the login screen is affected. There is currently no fix for this.

**WebView2 fails to download during install** — Make sure `lib32-gnutls` (Arch) or `libgnutls30:i386` (Ubuntu) is installed.

**Game not found after install** — The installer sometimes puts Growtopia in a different path. Find it with:
```bash
find $HOME/.wine-growtopia/drive_c -name "Growtopia.exe"
```

---

## 📁 File Locations

| File | Path |
|------|------|
| Wine prefix | `~/.wine-growtopia/` |
| Growtopia exe | `~/.wine-growtopia/drive_c/users/$USER/AppData/Local/Growtopia/Growtopia.exe` |
| Launcher | `~/.local/bin/growtopia` |
| Desktop entry | `~/.local/share/applications/growtopia.desktop` |

---

## 🗑️ Uninstall

```bash
rm -rf ~/.wine-growtopia
rm ~/.local/bin/growtopia
rm ~/.local/share/applications/growtopia.desktop
```

---

Made by [arvcx](https://github.com/arvcx)
