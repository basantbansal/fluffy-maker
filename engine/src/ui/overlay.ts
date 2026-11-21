import type { App } from '../app';
import { events, state } from '../state';

export function initOverlay(app: App): void {
  const params = new URLSearchParams(window.location.search);
  const imageUrl = params.get('image');
  const isOverlay = params.has('overlay') || !!imageUrl;

  if (!isOverlay) return;

  document.body.classList.add('overlay-mode');

  const btnClose = document.getElementById('fluffyBtnClose') as HTMLButtonElement | null;
  const pill = document.getElementById('fluffyPill');
  const btnPaint = document.getElementById('fluffyBtnPaint') as HTMLButtonElement | null;
  const btnPlay = document.getElementById('fluffyBtnPlay') as HTMLButtonElement | null;
  const brushSize = document.getElementById('fluffyBrushSize') as HTMLInputElement | null;

  if (btnClose) btnClose.hidden = false;
  if (pill) pill.hidden = false;

  function updateModeUI() {
    if (state.mode === 'paint') {
      btnPaint?.classList.add('active');
      btnPlay?.classList.remove('active');
    } else if (state.mode === 'play') {
      btnPaint?.classList.remove('active');
      btnPlay?.classList.add('active');
    }
  }

  events.on('mode', updateModeUI);
  updateModeUI();

  // 1. Paint button
  btnPaint?.addEventListener('click', (e) => {
    e.stopPropagation();
    app.maskTool.erasing = false;
    app.enterPaint();
    updateModeUI();
  });

  // 2. Play! button (Squish mode)
  btnPlay?.addEventListener('click', (e) => {
    e.stopPropagation();
    state.maskEnabled = true;
    app.enterPlay(false);
    updateModeUI();
  });

  // 3. Brush Size slider
  brushSize?.addEventListener('input', (e) => {
    e.stopPropagation();
    if (!brushSize) return;
    app.maskTool.brushRadius = parseFloat(brushSize.value);
    app.updateBrushCursorSize();
    app.showBrushPreview();
  });

  // Close widget function
  function closeWidget() {
    fetch('/close', { method: 'POST' }).catch(() => {});
    try {
      (window as any).webkit?.messageHandlers?.close?.postMessage('close');
    } catch {}
    try {
      window.close();
    } catch {}
  }

  btnClose?.addEventListener('click', (e) => {
    e.stopPropagation();
    closeWidget();
  });

  // ---- Window Movement via Hyprland IPC ----
  function sendWindowMove(dx: number, dy: number) {
    if (dx === 0 && dy === 0) return;
    try {
      (window as any).webkit?.messageHandlers?.move?.postMessage(`${dx},${dy}`);
    } catch {
      fetch(`/move?dx=${dx}&dy=${dy}`).catch(() => {});
    }
  }

  // Suppress context menu so Right-Click is reserved for window movement
  window.addEventListener('contextmenu', (e) => {
    e.preventDefault();
  });

  let isMovingWindow = false;
  let moveLastScreenX = 0;
  let moveLastScreenY = 0;

  // Right-click drag anywhere on canvas or window to move the Hyprland overlay
  window.addEventListener('pointerdown', (e) => {
    if (e.button === 2) {
      isMovingWindow = true;
      moveLastScreenX = e.screenX;
      moveLastScreenY = e.screenY;
      try {
        (e.target as HTMLElement).setPointerCapture(e.pointerId);
      } catch {}
      e.preventDefault();
    }
  });

  window.addEventListener('pointermove', (e) => {
    if (!isMovingWindow) return;
    const dx = e.screenX - moveLastScreenX;
    const dy = e.screenY - moveLastScreenY;
    moveLastScreenX = e.screenX;
    moveLastScreenY = e.screenY;
    sendWindowMove(dx, dy);
  });

  window.addEventListener('pointerup', (e) => {
    if (isMovingWindow && e.button === 2) {
      isMovingWindow = false;
    }
  });

  window.addEventListener('pointercancel', () => {
    isMovingWindow = false;
  });

  // ---- Keyboard Shortcuts ----
  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      e.preventDefault();
      closeWidget();
    } else if (e.key === '1' || e.key.toLowerCase() === 'p') {
      app.maskTool.erasing = false;
      app.enterPaint();
      updateModeUI();
    } else if (e.key === '2' || e.key.toLowerCase() === 's' || e.code === 'Space') {
      if (e.code === 'Space') e.preventDefault();
      state.maskEnabled = true;
      app.enterPlay(false);
      updateModeUI();
    } else if (e.key === '[') {
      if (brushSize) {
        brushSize.value = String(Math.max(0.01, parseFloat(brushSize.value) - 0.01));
        brushSize.dispatchEvent(new Event('input'));
      }
    } else if (e.key === ']') {
      if (brushSize) {
        brushSize.value = String(Math.min(0.25, parseFloat(brushSize.value) + 0.01));
        brushSize.dispatchEvent(new Event('input'));
      }
    }
  });

  // Auto-load screenshot if provided
  if (imageUrl) {
    void app.loadImageFromUrl(imageUrl);
  }
}
