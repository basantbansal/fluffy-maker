#!/usr/bin/env bash
# ==============================================================================
# Fluffy Maker - Interactive Installer
# ==============================================================================
set -euo pipefail

# ANSI color formatting
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BOLD}${CYAN}🥟 Fluffy Maker Installer${RESET}\n"

# 1. Check system dependencies
MISSING_PKGS=()

check_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo -e "  ${RED}✗${RESET} Missing: $1"
        return 1
    else
        echo -e "  ${GREEN}✓${RESET} Found: $1 ($(command -v "$1"))"
        return 0
    fi
}

echo -e "${BOLD}Checking system tools:${RESET}"
check_cmd "hyprctl" || MISSING_PKGS+=("hyprland")
check_cmd "slurp"   || MISSING_PKGS+=("slurp")
check_cmd "grim"    || MISSING_PKGS+=("grim")
check_cmd "python3" || MISSING_PKGS+=("python3")

echo -e "\n${BOLD}Checking Python GI & WebKit2:${RESET}"
PYTHON_BIN=""
for py in "/usr/bin/python3" "/usr/bin/python" "python3"; do
    if command -v "$py" >/dev/null 2>&1; then
        if "$py" -c "import gi; gi.require_version('WebKit2', '4.1'); from gi.repository import WebKit2, Gtk; import cairo" >/dev/null 2>&1; then
            PYTHON_BIN="$py"
            break
        fi
    fi
done

if [ -n "$PYTHON_BIN" ]; then
    echo -e "  ${GREEN}✓${RESET} PyGObject & WebKit2 (4.1) available via $PYTHON_BIN"
else
    echo -e "  ${RED}✗${RESET} PyGObject or WebKit2 (4.1) is missing from python3"
    MISSING_PKGS+=("python-gobject" "webkit2gtk-4.1")
fi

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}${BOLD}! Missing dependencies detected.${RESET}"
    echo -e "Please install them using your package manager:\n"
    if command -v pacman >/dev/null 2>&1; then
        echo -e "  ${BOLD}sudo pacman -S grim slurp python-gobject webkit2gtk-4.1${RESET}"
    elif command -v dnf >/dev/null 2>&1; then
        echo -e "  ${BOLD}sudo dnf install grim slurp python3-gobject webkit2gtk4.1${RESET}"
    elif command -v apt-get >/dev/null 2>&1; then
        echo -e "  ${BOLD}sudo apt install grim slurp python3-gi gir1.2-webkit2-4.1${RESET}"
    elif command -v xbps-install >/dev/null 2>&1; then
        echo -e "  ${BOLD}sudo xbps-install -S grim slurp python3-gobject webkit2gtk-4.1${RESET}"
    else
        echo -e "  Install: ${MISSING_PKGS[*]}"
    fi
    echo ""
    read -rp "Continue installation anyway? [y/N] " yn
    if [[ ! $yn =~ ^[Yy]$ ]]; then
        echo -e "${RED}Installation aborted.${RESET}"
        exit 1
    fi
fi

# 2. Make scripts executable & Symlink to ~/.local/bin
echo -e "\n${BOLD}Setting up launcher:${RESET}"
chmod +x "$SCRIPT_DIR/fluffy-maker.sh" "$SCRIPT_DIR/wrapper.py"

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
ln -sf "$SCRIPT_DIR/fluffy-maker.sh" "$BIN_DIR/fluffy-maker"
echo -e "  ${GREEN}✓${RESET} Symlinked: $BIN_DIR/fluffy-maker -> $SCRIPT_DIR/fluffy-maker.sh"

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo -e "  ${YELLOW}! Note: $BIN_DIR is not in your \$PATH. Add 'export PATH=\"\$HOME/.local/bin:\$PATH\"' to your ~/.zshrc or ~/.bashrc.${RESET}"
fi

# 3. Detect Hyprland configuration
echo -e "\n${BOLD}Configuring Hyprland:${RESET}"
HYPR_CONFIG_DIR="$HOME/.config/hypr"
USER_CONFIGS_DIR="$HYPR_CONFIG_DIR/UserConfigs"

KEYBINDS_FILE=""
WINDOWRULES_FILE=""

if [ -d "$USER_CONFIGS_DIR" ]; then
    [ -f "$USER_CONFIGS_DIR/UserKeybinds.conf" ] && KEYBINDS_FILE="$USER_CONFIGS_DIR/UserKeybinds.conf"
    [ -f "$USER_CONFIGS_DIR/WindowRules.conf" ]   && WINDOWRULES_FILE="$USER_CONFIGS_DIR/WindowRules.conf"
fi

if [ -z "$KEYBINDS_FILE" ]; then
    if [ -f "$HYPR_CONFIG_DIR/hyprland.conf" ]; then
        KEYBINDS_FILE="$HYPR_CONFIG_DIR/hyprland.conf"
        WINDOWRULES_FILE="$HYPR_CONFIG_DIR/hyprland.conf"
    fi
fi

if [ -n "$KEYBINDS_FILE" ]; then
    ALREADY_CONFIGURED=0
    if grep -q "fluffy-maker" "$KEYBINDS_FILE" 2>/dev/null; then
        ALREADY_CONFIGURED=1
    fi

    if [ "$ALREADY_CONFIGURED" -eq 1 ]; then
        echo -e "  ${GREEN}✓${RESET} Fluffy Maker keybind already present in: $KEYBINDS_FILE"
    else
        echo -e "  Found Hyprland config: ${CYAN}$KEYBINDS_FILE${RESET}"
        read -rp "  Add 'SUPER, F' keybinding & window rules to your Hyprland config? [Y/n] " add_cfg
        add_cfg=${add_cfg:-Y}

        if [[ $add_cfg =~ ^[Yy]$ ]]; then
            # Append keybinding
            cat << 'EOF' >> "$KEYBINDS_FILE"

# Fluffy Maker interactive squishy screen overlay (SUPER + F)
bind = SUPER, F, exec, fluffy-maker
EOF
            echo -e "  ${GREEN}✓${RESET} Added 'SUPER, F' keybinding to $KEYBINDS_FILE"

            # Append window rules
            if [ -n "$WINDOWRULES_FILE" ] && ! grep -q "class:.*fluffy-maker" "$WINDOWRULES_FILE" 2>/dev/null; then
                cat << 'EOF' >> "$WINDOWRULES_FILE"

# Fluffy Maker overlay window rules
windowrule = match:class ^(fluffy-maker)$, float on
windowrule = match:class ^(fluffy-maker)$, border_size 0
windowrule = match:class ^(fluffy-maker)$, no_blur on
windowrule = match:class ^(fluffy-maker)$, no_shadow on
EOF
                echo -e "  ${GREEN}✓${RESET} Added window rules to $WINDOWRULES_FILE"
            fi

            # Reload Hyprland
            if command -v hyprctl >/dev/null 2>&1; then
                hyprctl reload >/dev/null 2>&1 || true
                echo -e "  ${GREEN}✓${RESET} Hyprland reloaded successfully."
            fi
        else
            echo -e "  ${YELLOW}! Skipped automatic config modification.${RESET}"
        fi
    fi
else
    echo -e "  ${YELLOW}! Could not detect Hyprland configuration directory at ~/.config/hypr/${RESET}"
fi

echo -e "\n${GREEN}${BOLD}✨ Installation complete!${RESET}"
echo -e "You can now run Fluffy Maker by pressing ${CYAN}${BOLD}SUPER + F${RESET} or typing ${CYAN}${BOLD}fluffy-maker${RESET} in any terminal."
