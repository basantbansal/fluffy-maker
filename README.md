# 🥟 Fluffy Maker

> **Interactive squishy cheek physics overlay for Hyprland (Wayland)**  
> Capture any character, avatar, or anime girl on your screen and stretch, pinch, and wobble their cheeks in real-time with WebGL2 physics and sound effects.

Adapted from the squishy cheek engine created by [@saba383810](https://github.com/saba383810) ([moti_hoppe_maker](https://github.com/saba383810/moti_hoppe_maker)).

---

## ✨ Features

- **Pixel-Perfect Screen Overlay**: Press `SUPER + F` and drag a rectangle with `slurp`. Fluffy Maker captures the region with `grim` and immediately spawns a borderless, floating overlay snapped exactly over the captured area.
- **WebGL2 Squish Physics**: Spring dynamics, quintic falloff distortion, and synthetic WebAudio sound effects running at a smooth 60–144+ FPS.
- **Ultra-Clean Pastel Aesthetic**: Minimal frosted-glass pill floating at the bottom with a 3-control layout (`Paint`, brush slider, and `Play!`).
- **Showcase & Rice Ready (r/unixporn / r/hyprland)**: When in `Play!` mode, UI controls softly fade out (`opacity: 0.35`) so your screen recordings and rice showcases remain clean and unobstructed. Hovering reveals full opacity.
- **Zero Launch Flash**: Transparent RGBA Cairo background and deferred WebKit commit rendering prevent any white flash on Wayland.
- **Movable & Workspace-Bound**: Stays strictly on the workspace where captured. Move anytime via Hyprland's `SUPER + Left-Click-Drag` or simply **Right-Click-Drag** anywhere on the canvas.

---

## 📦 Dependencies

On Arch Linux / CachyOS / EndeavourOS:

```bash
sudo pacman -S grim slurp python-gobject webkit2gtk-4.1
```

*(Node.js and npm are only required if rebuilding the `engine/` web assets).*

---

## 🚀 3-Step Hyprland Setup

### 1. Keybinding
Add this line to `~/.config/hypr/UserConfigs/UserKeybinds.conf`:

```hyprlang
# Fluffy Maker interactive squishy overlay (Super + F)
bindd = $mainMod, F, Fluffy Maker squishy overlay, exec, /mnt/hdd/basant-data/Projects/Fluffy_maker/fluffy-maker.sh
```

### 2. Window Rules
Add these rules to `~/.config/hypr/UserConfigs/WindowRules.conf`:

```hyprlang
# Fluffy Maker Interactive Overlay
windowrule = match:class ^(fluffy-maker)$, float on
windowrule = match:class ^(fluffy-maker)$, border_size 0
windowrule = match:class ^(fluffy-maker)$, no_blur on
windowrule = match:class ^(fluffy-maker)$, no_shadow on
```

### 3. Reload Hyprland
```bash
hyprctl reload
```

---

## 🎮 Controls & Shortcuts

| Action | Control |
|---|---|
| **Trigger Fluffy Maker** | `SUPER + F` (click & drag area with mouse; `Esc` to cancel) |
| **Paint Mask Mode** | `🖌️ Paint` button, or press `P` / `1` |
| **Squish / Play Mode** | `✨ Play!` button, or press `Space` / `S` / `2` |
| **Resize Brush Circle** | **Scroll mouse wheel** on canvas in Paint mode, or use `[` / `]` |
| **Squish & Pull Cheeks** | Left-Click-Drag on painted region in Play mode |
| **Move Overlay Window** | **Right-Click-Drag** anywhere, or `SUPER + Left-Click-Drag` |
| **Close Overlay** | Top-right `✕` button, or press `Escape` |

---

## 🛠️ Project Structure

```
Fluffy_maker/
├── fluffy-maker.sh     # Self-contained launcher script (prevents duplicates, slurp + grim)
├── wrapper.py          # Native GTK3/WebKit2 transparent Wayland wrapper
├── engine/             # Adapted WebGL2 squishy engine (Vite + TypeScript)
│   ├── dist/           # Pre-built production client assets
│   └── src/            # Physics, WebGL shaders, mask tools, and overlay UI
├── README.md           # Documentation
└── .gitignore          # Clean repository rules
```

To modify and rebuild the engine:
```bash
cd engine
npm install
npm run build
```

---

## 💖 Credits & Acknowledgements

- **Physics & WebGL2 Engine**: Created by [@saba383810](https://github.com/saba383810) in [moti_hoppe_maker](https://github.com/saba383810/moti_hoppe_maker).
- **Hyprland Wrapper**: Built with Python GTK3, WebKit2GTK 4.1, `slurp`, and `grim`.
