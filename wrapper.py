#!/usr/bin/env python3
"""
Fluffy Maker - Lightweight Desktop Overlay Wrapper
Using system WebKit2GTK (4.1) on Wayland/Hyprland.
"""

import sys
import os
import signal
import subprocess
import threading
import http.server
import socketserver
import mimetypes
import urllib.parse
import cairo

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
gi.require_version('WebKit2', '4.1')
from gi.repository import Gtk, Gdk, WebKit2, GLib

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DIST_DIR = os.path.join(SCRIPT_DIR, "engine", "dist")

if not os.path.isdir(DIST_DIR):
    print(f"Error: Engine dist directory not found at {DIST_DIR}", file=sys.stderr)
    sys.exit(1)

IMAGE_PATH = sys.argv[1] if len(sys.argv) > 1 else "/tmp/fluffy_capture.png"
X = sys.argv[2] if len(sys.argv) > 2 else "0"
Y = sys.argv[3] if len(sys.argv) > 3 else "0"
W = int(sys.argv[4]) if len(sys.argv) > 4 else 400
H = int(sys.argv[5]) if len(sys.argv) > 5 else 300

class FluffyHTTPHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        # Silence access logs
        pass

    def do_POST(self):
        if self.path == "/close":
            self.send_response(200)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(b"ok")
            GLib.idle_add(cleanup_and_quit)
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        if self.path.startswith("/move"):
            try:
                query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
                dx = int(query.get("dx", [0])[0])
                dy = int(query.get("dy", [0])[0])
                subprocess.run(
                    ["hyprctl", "dispatch", "movewindowpixel", f"{dx} {dy}", "class:fluffy-maker"],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
                )
            except Exception:
                pass
            self.send_response(200)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(b"ok")
            return

        if self.path.startswith("/image"):
            if os.path.isfile(IMAGE_PATH):
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                with open(IMAGE_PATH, "rb") as f:
                    self.wfile.write(f.read())
            else:
                self.send_response(404)
                self.end_headers()
            return

        clean = self.path.split("?")[0].lstrip("/") or "index.html"
        fp = os.path.join(DIST_DIR, clean)
        if os.path.isfile(fp):
            self.send_response(200)
            mime, _ = mimetypes.guess_type(fp)
            self.send_header("Content-Type", mime or "application/octet-stream")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            with open(fp, "rb") as f:
                self.wfile.write(f.read())
        else:
            self.send_response(404)
            self.end_headers()

# Start local server on ephemeral port
server = socketserver.TCPServer(("127.0.0.1", 0), FluffyHTTPHandler)
port = server.server_address[1]
threading.Thread(target=server.serve_forever, daemon=True).start()

def cleanup_and_quit():
    try:
        if os.path.exists(IMAGE_PATH) and IMAGE_PATH.startswith("/tmp/"):
            os.remove(IMAGE_PATH)
    except Exception as e:
        print(f"Error removing temporary capture: {e}", file=sys.stderr)
    try:
        server.shutdown()
    except Exception:
        pass
    Gtk.main_quit()
    sys.exit(0)

# Wayland app_id configuration
GLib.set_prgname("fluffy-maker")
GLib.set_application_name("fluffy-maker")

window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
window.set_title("Fluffy Maker")
window.set_decorated(False)
window.set_resizable(False)
window.set_default_size(W, H)
window.set_app_paintable(True)

# Transparent background on Gtk window
screen = window.get_screen()
visual = screen.get_rgba_visual()
if visual and screen.is_composited():
    window.set_visual(visual)

# Paint window with transparent cairo surface to eliminate any GTK default background flash
def on_draw(widget, cr):
    cr.set_source_rgba(0, 0, 0, 0)
    cr.set_operator(cairo.OPERATOR_SOURCE)
    cr.paint()
    return False

window.connect("draw", on_draw)

webview = WebKit2.WebView()
settings = webview.get_settings()
settings.set_enable_webgl(True)
settings.set_enable_write_console_messages_to_stdout(False)

# Transparent background on WebKit
transparent = Gdk.RGBA()
transparent.parse("rgba(0,0,0,0)")
webview.set_background_color(transparent)

# Script message handlers for IPC close and move
ucm = webview.get_user_content_manager()
ucm.register_script_message_handler("close")
ucm.register_script_message_handler("move")

def on_script_message(manager, js_result):
    cleanup_and_quit()

def on_move_message(manager, js_result):
    try:
        val = js_result.get_js_value().to_string()
        dx, dy = val.split(",")
        subprocess.run(
            ["hyprctl", "dispatch", "movewindowpixel", f"{int(dx)} {int(dy)}", "class:fluffy-maker"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
    except Exception:
        pass

ucm.connect("script-message-received::close", on_script_message)
ucm.connect("script-message-received::move", on_move_message)

# Global Escape key handler
def on_key_press(widget, event):
    if event.keyval == Gdk.KEY_Escape:
        cleanup_and_quit()
        return True
    return False

window.connect("key-press-event", on_key_press)
window.connect("destroy", lambda w: cleanup_and_quit())

window.add(webview)

# Re-enforce Hyprland window position & size after window maps
def enforce_hyprland_geometry():
    try:
        subprocess.run(
            ["hyprctl", "dispatch", "movewindowpixel", f"exact {X} {Y}", "class:fluffy-maker"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        subprocess.run(
            ["hyprctl", "dispatch", "resizewindowpixel", f"exact {W} {H}", "class:fluffy-maker"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
    except Exception:
        pass
    return False

# Seamless reveal once WebKit commits the frame to avoid any launch flash
shown = False
def on_load_changed(view, event):
    global shown
    if not shown and event in (WebKit2.LoadEvent.COMMITTED, WebKit2.LoadEvent.FINISHED):
        shown = True
        window.show_all()
        GLib.idle_add(enforce_hyprland_geometry)

webview.connect("load-changed", on_load_changed)

# Safety fallback reveal
def fallback_reveal():
    global shown
    if not shown:
        shown = True
        window.show_all()
        GLib.idle_add(enforce_hyprland_geometry)
    return False

GLib.timeout_add(150, fallback_reveal)

# Load the adapted WebGL app with captured image
url = f"http://127.0.0.1:{port}/?image=/image&fit=1.0&overlay=1"
webview.load_uri(url)

signal.signal(signal.SIGINT, lambda *args: cleanup_and_quit())
signal.signal(signal.SIGTERM, lambda *args: cleanup_and_quit())

Gtk.main()
