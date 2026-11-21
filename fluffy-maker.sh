#!/usr/bin/env bash
# ==============================================================================
# Fluffy Maker - Interactive Squishy Desktop Widget for Hyprland
# ==============================================================================
set -euo pipefail

PROJECT_DIR="/mnt/hdd/basant-data/Projects/Fluffy_maker"
PYTHON_BIN="/usr/bin/python"
CAPTURE_FILE="/tmp/fluffy_capture.png"
LOCK_FILE="/tmp/fluffy_maker.lock"

# 1. Prevent duplicate instances
if pgrep -f "wrapper.py" > /dev/null 2>&1; then
    # Bring to focus or exit cleanly
    hyprctl dispatch focuswindow class:fluffy-maker >/dev/null 2>&1 || true
    exit 0
fi

# Ensure clean lock handling
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    exit 0
fi

# 2. Select screen region with slurp
GEOM=$(slurp -f "%x %y %w %h" 2>/dev/null || true)
if [ -z "$GEOM" ]; then
    # User cancelled (e.g. Esc or clicked away)
    exit 0
fi

read -r X Y W H <<< "$GEOM"

# Ignore accidental micro-clicks (< 10x10)
if [ "$W" -le 10 ] || [ "$H" -le 10 ]; then
    exit 0
fi

# 3. Capture that region using grim
grim -g "${X},${Y} ${W}x${H}" "$CAPTURE_FILE"

if [ ! -s "$CAPTURE_FILE" ]; then
    echo "Failed to capture screen region." >&2
    exit 1
fi

# 4. Set Hyprland window rules dynamically to place and size window immediately on spawn
hyprctl keyword windowrule "match:class ^(fluffy-maker)$, float on" >/dev/null 2>&1 || true
hyprctl keyword windowrule "match:class ^(fluffy-maker)$, border_size 0" >/dev/null 2>&1 || true
hyprctl keyword windowrule "match:class ^(fluffy-maker)$, no_blur on" >/dev/null 2>&1 || true
hyprctl keyword windowrule "match:class ^(fluffy-maker)$, no_shadow on" >/dev/null 2>&1 || true
hyprctl keyword windowrule "match:class ^(fluffy-maker)$, move ${X} ${Y}" >/dev/null 2>&1 || true
hyprctl keyword windowrule "match:class ^(fluffy-maker)$, size ${W} ${H}" >/dev/null 2>&1 || true

# 5. Launch desktop wrapper
exec "$PYTHON_BIN" "$PROJECT_DIR/wrapper.py" "$CAPTURE_FILE" "$X" "$Y" "$W" "$H"
