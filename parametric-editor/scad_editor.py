"""
OpenSCAD Parametric Editor — local web UI with sliders.

Usage:
    python scad_editor.py path/to/model.scad
    python scad_editor.py                     # opens file picker in browser

Parses top-level variable assignments, shows sliders/inputs in the browser,
writes changes back to the .scad file, and can trigger OpenSCAD CLI renders.

Annotation comments (optional, on the same line as the assignment):
    wall = 3.0;  // [1:0.5:10] Wall thickness
                  //  ^min:step:max   ^label

If no annotation, defaults are inferred from the value.
"""

import argparse
import atexit
import hashlib
import html as html_mod
import json
import os
import re
import subprocess
import sys
import tempfile
import threading
import time
import webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse, parse_qs

# ---------------------------------------------------------------------------
# Parser
# ---------------------------------------------------------------------------

# Matches:  varname = value;  // optional [min:step:max] optional label
# Only matches non-indented lines (top-level scope), supports negative values.
_PARAM_RE = re.compile(
    r"^(\w+)\s*=\s*"                         # name =
    r"(-?[\d.]+(?:[eE][+\-]?\d+)?)"          # numeric value (incl. negative, sci notation)
    r"\s*;"                                    # ;
    r"(?:\s*//\s*"                             # optional comment
    r"(?:\[([^\]]+)\])?"                       # optional [min:step:max]
    r"\s*(.*?))?\s*$"                          # optional label
)


def _infer_range(value: float) -> dict:
    """Guess sensible min/max/step from a bare numeric value."""
    if value == 0:
        return {"min": -100, "max": 100, "step": 1}
    mag = abs(value)
    if mag < 1:
        return {"min": 0, "max": round(mag * 10, 4), "step": round(mag / 20, 4)}
    elif mag < 10:
        return {"min": 0, "max": round(mag * 4, 2), "step": 0.1}
    elif mag < 100:
        return {"min": 0, "max": round(mag * 3, 1), "step": 0.5}
    else:
        return {"min": 0, "max": round(mag * 3, 0), "step": 1}


def _parse_lines(lines: list[str]) -> list[dict]:
    """Extract parameters from lines. Only matches non-indented (top-level) assignments."""
    params: list[dict] = []
    seen: set[str] = set()

    for i, line in enumerate(lines):
        # Skip indented lines (local variables inside modules/functions)
        if line and line[0] in (" ", "\t"):
            continue
        m = _PARAM_RE.match(line.strip())
        if not m:
            continue
        name = m.group(1)
        if name.startswith("$") or name in seen:
            continue
        seen.add(name)

        raw_val = m.group(2)
        is_int = "." not in raw_val and "e" not in raw_val.lower()
        value = int(raw_val) if is_int else float(raw_val)

        # Parse [min:step:max] or [min:max]
        range_str = m.group(3)
        label = (m.group(4) or name.replace("_", " ").title()).strip()

        if range_str:
            parts = [float(x.strip()) for x in range_str.split(":")]
            if len(parts) == 3:
                rng = {"min": parts[0], "step": parts[1], "max": parts[2]}
            elif len(parts) == 2:
                rng = {"min": parts[0], "max": parts[1], "step": (1 if is_int else 0.1)}
            else:
                rng = _infer_range(value)
        else:
            rng = _infer_range(value)

        if is_int:
            rng["step"] = max(1, int(rng["step"]))
            rng["min"] = int(rng["min"])
            rng["max"] = int(rng["max"])

        params.append({
            "name": name,
            "value": value,
            "is_int": is_int,
            "label": label,
            "line": i,
            **rng,
        })

    return params


def parse_scad(path: str) -> tuple[list[dict], list[str]]:
    """Return (params, lines) from a .scad file."""
    lines = Path(path).read_text(encoding="utf-8").splitlines()
    return _parse_lines(lines), lines


def update_scad(path: str, lines: list[str], changes: dict[str, float]) -> list[str]:
    """Write changed values back into lines and save to path.

    Uses the in-memory lines for line indices (not a fresh disk read)
    to avoid desync with OneDrive or external edits.
    """
    params = _parse_lines(lines)
    param_map = {p["name"]: p for p in params}

    new_lines = list(lines)
    for name, new_val in changes.items():
        p = param_map.get(name)
        if not p:
            continue
        try:
            new_val = float(new_val)
        except (TypeError, ValueError):
            continue
        line_idx = p["line"]
        old_line = new_lines[line_idx]

        if p["is_int"]:
            fmt_val = str(int(new_val))
        else:
            fmt_val = f"{new_val:.4f}".rstrip("0").rstrip(".")
            if "." not in fmt_val:
                fmt_val += ".0"

        # Replace just the value portion: name = OLD_VALUE; ...
        new_line = re.sub(
            r"^(\s*" + re.escape(name) + r"\s*=\s*)" + r"-?[\d.]+(?:[eE][+\-]?\d+)?" + r"(\s*;)",
            rf"\g<1>{fmt_val}\2",
            old_line,
        )
        new_lines[line_idx] = new_line

    Path(path).write_text("\n".join(new_lines) + "\n", encoding="utf-8")
    return new_lines


# ---------------------------------------------------------------------------
# OpenSCAD renderer
# ---------------------------------------------------------------------------

OPENSCAD_EXE = None

def _find_openscad() -> str | None:
    global OPENSCAD_EXE
    if OPENSCAD_EXE:
        return OPENSCAD_EXE
    candidates = [
        r"C:\Program Files\OpenSCAD\openscad.com",
        r"C:\Program Files\OpenSCAD\openscad.exe",
        r"C:\Program Files (x86)\OpenSCAD\openscad.com",
    ]
    for c in candidates:
        if os.path.isfile(c):
            OPENSCAD_EXE = c
            return c
    # Try PATH
    import shutil
    found = shutil.which("openscad") or shutil.which("openscad.com")
    OPENSCAD_EXE = found
    return found


def render_preview(scad_path: str, width: int = 800, height: int = 600) -> bytes | None:
    """Render scad to PNG via CLI, return bytes or None on failure."""
    exe = _find_openscad()
    if not exe:
        return None
    tmp = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
    tmp.close()
    try:
        cmd = [exe, "-o", tmp.name,
               f"--imgsize={width},{height}",
               "--colorscheme=Tomorrow Night"]
        if PREVIEW_FN:
            cmd += ["-D", f"$fn={PREVIEW_FN}"]
        cmd.append(scad_path)
        subprocess.run(cmd, capture_output=True, timeout=60)
        data = Path(tmp.name).read_bytes()
        return data if len(data) > 100 else None
    except Exception:
        return None
    finally:
        try:
            os.unlink(tmp.name)
        except OSError:
            pass


# --- Render settings ---
PREVIEW_FN: int = 24       # Low $fn for fast preview renders
FULL_FN: int | None = None  # None = use whatever the .scad file specifies

# Cached STL: keyed by content hash so edits that don't change geometry hit cache
_stl_cache: dict[str, str | bytes] = {}  # keys: "hash", "path", "data"
_render_lock = threading.Lock()
_state_lock = threading.Lock()  # protects cls.lines / cls.params

# Last render error message, surfaced to the browser
last_render_error: str = ""
last_render_time: float = 0.0  # seconds


def _cleanup_stl_cache():
    p = _stl_cache.get("path")
    if p and isinstance(p, str):
        try:
            os.unlink(p)
        except OSError:
            pass


atexit.register(_cleanup_stl_cache)


def _content_hash(scad_path: str, preview: bool) -> str:
    """Hash the .scad file content + render mode for cache key."""
    content = Path(scad_path).read_bytes()
    tag = f"preview,fn={PREVIEW_FN}" if preview else "full"
    return hashlib.md5(content + tag.encode()).hexdigest()


def export_stl(scad_path: str, preview: bool = True) -> bytes | None:
    """Export scad to binary STL via CLI, return bytes or None.

    preview=True uses -D '$fn=N' for fast iteration (~7x faster).
    preview=False uses the file's own $fn for final quality.
    """
    global last_render_error, last_render_time
    exe = _find_openscad()
    if not exe:
        last_render_error = "OpenSCAD not found"
        return None

    content_hash = _content_hash(scad_path, preview)
    if _stl_cache.get("hash") == content_hash and _stl_cache.get("data"):
        last_render_error = ""
        last_render_time = 0.0
        return _stl_cache["data"]

    if not _render_lock.acquire(blocking=False):
        last_render_error = "Render already in progress"
        return None

    tmp = tempfile.NamedTemporaryFile(suffix=".stl", delete=False)
    tmp.close()
    t0 = time.monotonic()
    try:
        cmd = [exe, "-o", tmp.name]
        if preview and PREVIEW_FN:
            cmd += ["-D", f"$fn={PREVIEW_FN}"]
        cmd.append(scad_path)

        result = subprocess.run(cmd, capture_output=True, timeout=120)
        last_render_time = time.monotonic() - t0

        if result.returncode != 0:
            err = result.stderr.decode(errors="replace").strip()
            last_render_error = err or f"OpenSCAD exited with code {result.returncode}"
            print(f"[OpenSCAD error] {last_render_error}", file=sys.stderr)
            try:
                os.unlink(tmp.name)
            except OSError:
                pass
            return None

        data = Path(tmp.name).read_bytes()
        if len(data) < 84:  # minimal STL header
            last_render_error = "OpenSCAD produced empty output (geometry error?)"
            try:
                os.unlink(tmp.name)
            except OSError:
                pass
            return None

        # Update cache with content hash + in-memory data
        old = _stl_cache.get("path")
        if old and isinstance(old, str) and old != tmp.name:
            try:
                os.unlink(old)
            except OSError:
                pass
        _stl_cache["path"] = tmp.name
        _stl_cache["hash"] = content_hash
        _stl_cache["data"] = data
        last_render_error = ""
        return data
    except subprocess.TimeoutExpired:
        last_render_time = time.monotonic() - t0
        last_render_error = "OpenSCAD render timed out (>120s)"
        print(f"[OpenSCAD] {last_render_error}", file=sys.stderr)
        try:
            os.unlink(tmp.name)
        except OSError:
            pass
        return None
    except Exception as e:
        last_render_time = time.monotonic() - t0
        last_render_error = str(e)
        try:
            os.unlink(tmp.name)
        except OSError:
            pass
        return None
    finally:
        _render_lock.release()


# ---------------------------------------------------------------------------
# Web UI (embedded HTML/CSS/JS)
# ---------------------------------------------------------------------------

HTML_TEMPLATE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>OpenSCAD Parametric Editor</title>
<script type="importmap">
{
  "imports": {
    "three": "https://cdn.jsdelivr.net/npm/three@0.170.0/build/three.module.js",
    "three/addons/": "https://cdn.jsdelivr.net/npm/three@0.170.0/examples/jsm/"
  }
}
</script>
<style>
  :root {
    --bg: #1a1a2e;
    --card: #16213e;
    --accent: #0f3460;
    --highlight: #e94560;
    --text: #eee;
    --text-dim: #888;
    --input-bg: #0d1b2a;
    --slider-track: #334155;
    --slider-thumb: #e94560;
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
    background: var(--bg);
    color: var(--text);
    min-height: 100vh;
  }
  .app {
    display: grid;
    grid-template-columns: 380px 1fr;
    grid-template-rows: auto 1fr;
    height: 100vh;
    gap: 0;
  }
  header {
    grid-column: 1 / -1;
    background: var(--card);
    padding: 12px 24px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    border-bottom: 1px solid var(--accent);
    flex-wrap: wrap;
    gap: 8px;
  }
  header h1 {
    font-size: 18px;
    font-weight: 600;
    letter-spacing: -0.3px;
  }
  header h1 span { color: var(--highlight); }
  .file-name {
    font-size: 13px;
    color: var(--text-dim);
    font-family: 'Cascadia Code', 'Fira Code', monospace;
  }
  .header-actions { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
  .btn {
    background: var(--accent);
    color: var(--text);
    border: none;
    padding: 8px 16px;
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 500;
    transition: background 0.15s;
    white-space: nowrap;
  }
  .btn:hover { background: var(--highlight); }
  .btn:disabled { opacity: 0.4; cursor: not-allowed; }
  .btn-render { background: var(--highlight); }
  .btn-render:hover { background: #ff6b81; }

  .sidebar {
    background: var(--card);
    overflow-y: auto;
    padding: 16px;
    border-right: 1px solid var(--accent);
  }
  .sidebar::-webkit-scrollbar { width: 6px; }
  .sidebar::-webkit-scrollbar-thumb { background: var(--accent); border-radius: 3px; }

  .param-group { margin-bottom: 20px; }
  .param-group h3 {
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: var(--text-dim);
    margin-bottom: 12px;
    padding-bottom: 6px;
    border-bottom: 1px solid var(--accent);
  }
  .param { margin-bottom: 14px; }
  .param-header {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    margin-bottom: 4px;
  }
  .param-label { font-size: 13px; font-weight: 500; }
  .param-value-wrap { display: flex; align-items: center; gap: 4px; }
  .param-value {
    width: 72px;
    text-align: right;
    background: var(--input-bg);
    border: 1px solid var(--accent);
    color: var(--highlight);
    font-family: 'Cascadia Code', 'Fira Code', monospace;
    font-size: 13px;
    padding: 2px 6px;
    border-radius: 4px;
    outline: none;
  }
  .param-value:focus { border-color: var(--highlight); }
  .param-unit { font-size: 11px; color: var(--text-dim); }
  .param-range { display: flex; align-items: center; gap: 8px; }
  .range-label { font-size: 10px; color: var(--text-dim); min-width: 28px; }
  .range-label.max { text-align: right; }
  input[type="range"] {
    -webkit-appearance: none;
    flex: 1; height: 6px;
    background: var(--slider-track);
    border-radius: 3px; outline: none;
  }
  input[type="range"]::-webkit-slider-thumb {
    -webkit-appearance: none;
    width: 16px; height: 16px; border-radius: 50%;
    background: var(--slider-thumb); cursor: pointer;
    border: 2px solid var(--bg); transition: transform 0.1s;
  }
  input[type="range"]::-webkit-slider-thumb:hover { transform: scale(1.2); }
  input[type="range"]::-moz-range-thumb {
    width: 16px; height: 16px; border-radius: 50%;
    background: var(--slider-thumb); cursor: pointer;
    border: 2px solid var(--bg);
  }

  .preview-area {
    position: relative;
    overflow: hidden;
    background: var(--bg);
  }
  #threeCanvas {
    width: 100%; height: 100%;
    display: block;
  }
  .preview-placeholder {
    position: absolute; inset: 0;
    display: flex; flex-direction: column;
    align-items: center; justify-content: center;
    text-align: center; color: var(--text-dim);
    pointer-events: none;
  }
  .preview-placeholder p { margin: 8px 0; font-size: 14px; }
  .preview-placeholder .hint { font-size: 12px; }
  .preview-placeholder.hidden { display: none; }

  .spinner {
    display: none; position: absolute;
    top: 50%; left: 50%;
    transform: translate(-50%, -50%);
    z-index: 10; pointer-events: none;
  }
  .spinner.active { display: block; }
  .spinner::after {
    content: ''; display: block;
    width: 40px; height: 40px;
    border: 3px solid var(--accent);
    border-top-color: var(--highlight);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .toast {
    position: fixed; bottom: 20px; right: 20px;
    background: var(--card); border: 1px solid var(--highlight);
    color: var(--text); padding: 10px 20px;
    border-radius: 8px; font-size: 13px;
    opacity: 0; transition: opacity 0.3s;
    pointer-events: none; z-index: 100;
  }
  .toast.show { opacity: 1; }

  .auto-render-toggle {
    display: flex; align-items: center; gap: 6px;
    font-size: 12px; color: var(--text-dim);
  }
  .auto-render-toggle input { accent-color: var(--highlight); }

  /* File picker */
  .file-picker-wrap { position: relative; }
  .file-picker-btn {
    background: none; border: 1px solid var(--accent);
    color: var(--text); padding: 6px 12px; border-radius: 6px;
    cursor: pointer; font-size: 18px; display: flex; align-items: center;
    gap: 6px; transition: border-color 0.15s;
  }
  .file-picker-btn:hover { border-color: var(--highlight); }
  .file-picker-btn .label { font-size: 13px; }
  .file-dropdown {
    display: none; position: absolute; top: 100%; left: 0;
    margin-top: 4px; background: var(--card); border: 1px solid var(--accent);
    border-radius: 8px; min-width: 340px; max-height: 400px;
    overflow-y: auto; z-index: 50; box-shadow: 0 8px 32px rgba(0,0,0,0.5);
  }
  .file-dropdown.open { display: block; }
  .file-dropdown-search {
    width: 100%; padding: 10px 12px; background: var(--input-bg);
    border: none; border-bottom: 1px solid var(--accent);
    color: var(--text); font-size: 13px; outline: none;
    border-radius: 8px 8px 0 0;
  }
  .file-dropdown-search::placeholder { color: var(--text-dim); }
  .file-item {
    padding: 8px 12px; cursor: pointer; font-size: 13px;
    font-family: 'Cascadia Code', 'Fira Code', monospace;
    border-bottom: 1px solid rgba(255,255,255,0.03);
    transition: background 0.1s;
  }
  .file-item:hover { background: var(--accent); }
  .file-item.active { color: var(--highlight); background: rgba(233,69,96,0.1); }
  .file-item .file-dir { color: var(--text-dim); font-size: 11px; }

  /* Drop zone overlay */
  .drop-overlay {
    display: none; position: fixed; inset: 0; z-index: 200;
    background: rgba(26,26,46,0.92);
    flex-direction: column; align-items: center; justify-content: center;
  }
  .drop-overlay.active { display: flex; }
  .drop-overlay-inner {
    border: 3px dashed var(--highlight); border-radius: 20px;
    padding: 60px 80px; text-align: center;
  }
  .drop-overlay-inner svg { width: 64px; height: 64px; fill: var(--highlight); margin-bottom: 16px; }
  .drop-overlay-inner p { font-size: 18px; color: var(--text); }
  .drop-overlay-inner .hint { font-size: 13px; color: var(--text-dim); margin-top: 8px; }

  .view-controls {
    position: absolute; bottom: 12px; left: 50%;
    transform: translateX(-50%);
    display: flex; gap: 6px; z-index: 5;
  }
  .view-controls .btn { padding: 6px 12px; font-size: 11px; opacity: 0.8; }
  .view-controls .btn:hover { opacity: 1; }
  .view-controls .btn.active { opacity: 1; background: var(--highlight); }

  .render-info {
    position: absolute; top: 8px; right: 12px;
    font-size: 11px; color: var(--text-dim); z-index: 5;
  }
</style>
</head>
<body>
<div class="app">
  <header>
    <div>
      <h1><span>OpenSCAD</span> Parametric Editor</h1>
      <div class="file-name" id="fileName">&mdash;</div>
    </div>
    <div class="header-actions">
      <div class="file-picker-wrap">
        <button class="file-picker-btn" id="filePickerBtn" onclick="toggleFilePicker()">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M10 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z"/></svg>
          <span class="label">Open</span>
        </button>
        <div class="file-dropdown" id="fileDropdown">
          <input type="text" class="file-dropdown-search" id="fileSearch" placeholder="Search .scad files..." oninput="filterFiles()">
          <div id="fileList"></div>
        </div>
      </div>
      <label class="auto-render-toggle">
        <input type="checkbox" id="autoRender"> Auto-render
      </label>
      <button class="btn btn-render" id="renderBtn" onclick="doRender('preview')">Render 3D</button>
      <button class="btn" onclick="doRender('full')">Full Quality</button>
      <button class="btn" id="downloadBtn" onclick="downloadSTL()" disabled>Download STL</button>
      <button class="btn" onclick="resetAll()">Reset All</button>
      <button class="btn" onclick="openInOpenSCAD()">Open in OpenSCAD</button>
    </div>
  </header>

  <div class="sidebar" id="sidebar">
    <div class="preview-placeholder">
      <p>Loading parameters...</p>
    </div>
  </div>

  <div class="preview-area" id="previewArea">
    <canvas id="threeCanvas"></canvas>
    <div class="spinner" id="spinner"></div>
    <div class="preview-placeholder" id="previewPlaceholder">
      <p>Click <strong>Render 3D</strong> to see your model</p>
      <p class="hint">Drag to rotate &middot; Scroll to zoom &middot; Right-drag to pan</p>
    </div>
    <div class="render-info" id="renderInfo"></div>
    <div class="view-controls">
      <button class="btn" onclick="viewPreset('front')">Front</button>
      <button class="btn" onclick="viewPreset('top')">Top</button>
      <button class="btn" onclick="viewPreset('right')">Right</button>
      <button class="btn" onclick="viewPreset('iso')">Iso</button>
    </div>
  </div>
</div>

<div class="toast" id="toast"></div>

<div class="drop-overlay" id="dropOverlay">
  <div class="drop-overlay-inner">
    <svg viewBox="0 0 24 24"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM14 13v4h-4v-4H7l5-5 5 5h-3z"/></svg>
    <p>Drop .scad file here</p>
    <p class="hint">File will be saved to the project directory</p>
  </div>
</div>

<!-- Core UI logic — no CDN dependencies -->
<script>
// --- Utilities ---
function esc(s) {
    const d = document.createElement('div');
    d.textContent = s;
    return d.innerHTML;
}
function escAttr(s) {
    return s.replace(/&/g,'&amp;').replace(/"/g,'&quot;').replace(/'/g,'&#39;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

function showToast(msg) {
    const t = document.getElementById('toast');
    t.textContent = msg;
    t.classList.add('show');
    setTimeout(() => t.classList.remove('show'), 2000);
}

// --- Parameter & render logic ---
const API = '';
let params = [];
let originalValues = {};
let renderTimeout = null;

async function init() {
    const resp = await fetch(API + '/api/params');
    const data = await resp.json();
    document.getElementById('fileName').textContent = data.file || 'No file loaded';
    if (!data.file || !data.params.length) {
        document.getElementById('sidebar').innerHTML =
            '<div class="preview-placeholder"><p>Open a .scad file or drag one here</p>' +
            '<p class="hint" style="font-size:12px;margin-top:8px">Click the folder icon above</p></div>';
        return;
    }
    params = data.params;
    originalValues = {};
    params.forEach(p => { originalValues[p.name] = p.value; });
    renderParamUI();
    doRender();
}

function renderParamUI() {
    const sidebar = document.getElementById('sidebar');
    const groups = {};
    params.forEach(p => {
        const parts = p.name.split('_');
        let group = 'General';
        if (parts.length > 1) {
            group = parts.slice(0, -1).map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
        }
        if (!groups[group]) groups[group] = [];
        groups[group].push(p);
    });

    let html = '';
    for (const [groupName, groupParams] of Object.entries(groups)) {
        html += `<div class="param-group"><h3>${esc(groupName)}</h3>`;
        for (const p of groupParams) {
            html += `
            <div class="param">
              <div class="param-header">
                <span class="param-label">${esc(p.label)}</span>
                <div class="param-value-wrap">
                  <input type="number" class="param-value" id="val_${p.name}"
                         value="${p.value}" step="${p.step}" min="${p.min}" max="${p.max}">
                </div>
              </div>
              <div class="param-range">
                <span class="range-label">${p.min}</span>
                <input type="range" id="slider_${p.name}"
                       min="${p.min}" max="${p.max}" step="${p.step}" value="${p.value}">
                <span class="range-label max">${p.max}</span>
              </div>
            </div>`;
        }
        html += '</div>';
    }
    sidebar.innerHTML = html;

    params.forEach(p => {
        const slider = document.getElementById('slider_' + p.name);
        const input = document.getElementById('val_' + p.name);

        slider.addEventListener('input', () => {
            const v = p.is_int ? parseInt(slider.value) : parseFloat(slider.value);
            input.value = v;
            p.value = v;
            scheduleUpdate(p.name, v);
        });

        input.addEventListener('change', () => {
            const v = p.is_int ? parseInt(input.value) : parseFloat(input.value);
            if (isNaN(v)) return;
            slider.value = v;
            p.value = v;
            scheduleUpdate(p.name, v);
        });
    });
}

let pendingChanges = {};
let updateTimer = null;

function scheduleUpdate(name, value) {
    pendingChanges[name] = value;
    clearTimeout(updateTimer);
    updateTimer = setTimeout(flushChanges, 300);
}

async function flushChanges() {
    const changes = { ...pendingChanges };
    pendingChanges = {};
    try {
        await fetch(API + '/api/update', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(changes),
        });
        showToast('Saved');
        if (document.getElementById('autoRender').checked) {
            clearTimeout(renderTimeout);
            renderTimeout = setTimeout(doRender, 500);
        }
    } catch (e) {
        showToast('Save failed: ' + e.message);
    }
}

async function doRender(quality) {
    quality = quality || 'preview';
    const spinner = document.getElementById('spinner');
    const placeholder = document.getElementById('previewPlaceholder');
    const btn = document.getElementById('renderBtn');
    const info = document.getElementById('renderInfo');

    spinner.classList.add('active');
    btn.disabled = true;
    info.textContent = quality === 'full' ? 'Full quality render...' : 'Preview render...';

    const t0 = performance.now();
    try {
        const resp = await fetch(API + '/api/stl?quality=' + quality + '&t=' + Date.now());
        if (!resp.ok) {
            let msg = 'STL export failed';
            try { const j = await resp.json(); msg = j.error || msg; } catch {}
            throw new Error(msg);
        }
        const serverTime = resp.headers.get('X-Render-Time');
        const buffer = await resp.arrayBuffer();
        if (window._loadSTL) {
            window._loadSTL(buffer);
        } else {
            showToast('3D viewer not loaded (CDN issue?) — STL exported OK');
        }
        placeholder.classList.add('hidden');
        document.getElementById('downloadBtn').disabled = false;
        const totalMs = ((performance.now() - t0) / 1000).toFixed(1);
        const renderMs = serverTime ? parseFloat(serverTime).toFixed(1) : totalMs;
        const cached = serverTime && parseFloat(serverTime) < 0.01;
        const tag = quality === 'full' ? 'Full' : 'Preview';
        info.textContent = cached ? `${tag} (cached)` : `${tag} ${renderMs}s`;
    } catch (e) {
        showToast('Render error: ' + e.message);
        info.textContent = '';
    } finally {
        spinner.classList.remove('active');
        btn.disabled = false;
    }
}

function resetAll() {
    params.forEach(p => {
        p.value = originalValues[p.name];
        document.getElementById('val_' + p.name).value = p.value;
        document.getElementById('slider_' + p.name).value = p.value;
    });
    const changes = {};
    params.forEach(p => { changes[p.name] = p.value; });
    pendingChanges = changes;
    flushChanges();
}

async function openInOpenSCAD() {
    await fetch(API + '/api/open-editor');
    showToast('Opened in OpenSCAD');
}

async function downloadSTL() {
    const btn = document.getElementById('downloadBtn');
    btn.disabled = true;
    showToast('Exporting full-quality STL...');
    try {
        const resp = await fetch(API + '/api/stl?quality=full&t=' + Date.now());
        if (!resp.ok) throw new Error('STL export failed');
        const blob = await resp.blob();
        const fname = (document.getElementById('fileName').textContent || 'model').replace(/\.scad$/i, '') + '.stl';
        const a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = fname;
        a.click();
        URL.revokeObjectURL(a.href);
        showToast('Downloaded ' + fname);
    } catch (e) {
        showToast('Download failed: ' + e.message);
    } finally {
        btn.disabled = false;
    }
}

function viewPreset(name) {
    if (window._viewPreset) window._viewPreset(name);
}

// --- File picker ---
let allFiles = [];

function toggleFilePicker() {
    const dd = document.getElementById('fileDropdown');
    if (dd.classList.contains('open')) {
        dd.classList.remove('open');
        return;
    }
    dd.classList.add('open');
    document.getElementById('fileSearch').value = '';
    document.getElementById('fileSearch').focus();
    fetch(API + '/api/list-files')
        .then(r => r.json())
        .then(data => {
            allFiles = data.files;
            renderFileList(allFiles, data.current);
        })
        .catch(() => {
            document.getElementById('fileList').innerHTML = '<div class="file-item">Error loading files</div>';
        });
}

function renderFileList(files, current) {
    const list = document.getElementById('fileList');
    if (!files.length) {
        list.innerHTML = '<div class="file-item" style="color:var(--text-dim)">No .scad files found</div>';
        return;
    }
    list.innerHTML = files.map(f => {
        const parts = f.name.split('/');
        const fname = parts.pop();
        const dir = parts.join('/');
        const active = fname === current ? ' active' : '';
        const safePath = f.path.replace(/\\/g, '/');
        return `<div class="file-item${active}" data-path="${escAttr(safePath)}">${esc(fname)}${dir ? `<div class="file-dir">${esc(dir)}</div>` : ''}</div>`;
    }).join('');
    list.querySelectorAll('.file-item[data-path]').forEach(el => {
        el.addEventListener('click', () => loadFile(el.dataset.path));
    });
}

function filterFiles() {
    const q = document.getElementById('fileSearch').value.toLowerCase();
    const filtered = allFiles.filter(f => f.name.toLowerCase().includes(q));
    renderFileList(filtered, document.getElementById('fileName').textContent);
}

async function loadFile(path) {
    document.getElementById('fileDropdown').classList.remove('open');
    showToast('Loading...');
    try {
        const resp = await fetch(API + '/api/load-file', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ path }),
        });
        const data = await resp.json();
        if (data.ok) {
            showToast(`Loaded ${data.file} (${data.param_count} params)`);
            await init();
        } else {
            showToast('Error: ' + (data.error || 'unknown'));
        }
    } catch (e) {
        showToast('Load failed: ' + e.message);
    }
}

// Close dropdown on outside click
document.addEventListener('click', (e) => {
    const wrap = document.querySelector('.file-picker-wrap');
    if (wrap && !wrap.contains(e.target)) {
        document.getElementById('fileDropdown').classList.remove('open');
    }
});

// --- Drag and drop ---
let dragCounter = 0;

document.addEventListener('dragenter', (e) => {
    e.preventDefault();
    dragCounter++;
    document.getElementById('dropOverlay').classList.add('active');
});

document.addEventListener('dragleave', (e) => {
    e.preventDefault();
    dragCounter--;
    if (dragCounter <= 0) {
        dragCounter = 0;
        document.getElementById('dropOverlay').classList.remove('active');
    }
});

document.addEventListener('dragover', (e) => { e.preventDefault(); });

document.addEventListener('drop', async (e) => {
    e.preventDefault();
    dragCounter = 0;
    document.getElementById('dropOverlay').classList.remove('active');

    const files = Array.from(e.dataTransfer.files);
    const scadFile = files.find(f => f.name.endsWith('.scad'));
    if (!scadFile) {
        showToast('Only .scad files are supported');
        return;
    }

    showToast(`Uploading ${scadFile.name}...`);
    const content = await scadFile.text();
    try {
        const resp = await fetch(API + '/api/upload', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ filename: scadFile.name, content }),
        });
        const data = await resp.json();
        if (data.ok) {
            showToast(`Loaded ${data.file} (${data.param_count} params)`);
            await init();
        } else {
            showToast('Error: ' + (data.error || 'unknown'));
        }
    } catch (err) {
        showToast('Upload failed: ' + err.message);
    }
});

// Boot
init();
</script>

<!-- Three.js 3D viewer — loaded async, UI works without it -->
<script type="module">
try {
    const THREE = await import('three');
    const { OrbitControls } = await import('three/addons/controls/OrbitControls.js');
    const { STLLoader } = await import('three/addons/loaders/STLLoader.js');

    const canvas = document.getElementById('threeCanvas');
    const container = document.getElementById('previewArea');

    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x1a1a2e);

    const camera = new THREE.PerspectiveCamera(45, 1, 0.1, 10000);
    camera.position.set(200, 200, 300);

    const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
    renderer.setPixelRatio(window.devicePixelRatio);
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.0;

    const controls = new OrbitControls(camera, canvas);
    controls.enableDamping = true;
    controls.dampingFactor = 0.08;
    controls.rotateSpeed = 0.8;
    controls.zoomSpeed = 1.2;

    scene.add(new THREE.AmbientLight(0x404060, 0.6));
    const dirLight1 = new THREE.DirectionalLight(0xffffff, 1.0);
    dirLight1.position.set(200, 300, 200);
    scene.add(dirLight1);
    const dirLight2 = new THREE.DirectionalLight(0x8888ff, 0.4);
    dirLight2.position.set(-200, -100, -200);
    scene.add(dirLight2);

    const grid = new THREE.GridHelper(500, 50, 0x334155, 0x222244);
    grid.rotation.x = Math.PI / 2;
    scene.add(grid);
    scene.add(new THREE.AxesHelper(80));

    const material = new THREE.MeshPhongMaterial({
        color: 0xe94560, specular: 0x444444, shininess: 30, flatShading: false,
    });

    let currentMesh = null;

    function resize() {
        const w = container.clientWidth, h = container.clientHeight;
        camera.aspect = w / h;
        camera.updateProjectionMatrix();
        renderer.setSize(w, h);
    }
    window.addEventListener('resize', resize);
    resize();

    (function animate() {
        requestAnimationFrame(animate);
        controls.update();
        renderer.render(scene, camera);
    })();

    const loader = new STLLoader();

    window._loadSTL = function(buffer) {
        const geometry = loader.parse(buffer);
        geometry.computeVertexNormals();
        if (currentMesh) { scene.remove(currentMesh); currentMesh.geometry.dispose(); }
        currentMesh = new THREE.Mesh(geometry, material);
        scene.add(currentMesh);

        const box = new THREE.Box3().setFromObject(currentMesh);
        const center = box.getCenter(new THREE.Vector3());
        const size = box.getSize(new THREE.Vector3());
        const maxDim = Math.max(size.x, size.y, size.z);
        controls.target.copy(center);
        const dist = maxDim * 1.8;
        camera.position.set(center.x + dist * 0.6, center.y + dist * 0.4, center.z + dist * 0.8);
        camera.lookAt(center);
        controls.update();

        const gs = Math.ceil(maxDim * 2 / 50) * 50;
        grid.scale.set(gs / 500, gs / 500, gs / 500);

        const triCount = geometry.attributes.position.count / 3;
        document.getElementById('renderInfo').textContent =
            `${triCount.toLocaleString()} triangles | ${size.x.toFixed(1)} x ${size.y.toFixed(1)} x ${size.z.toFixed(1)} mm`;
    };

    window._viewPreset = function(name) {
        if (!currentMesh) return;
        const box = new THREE.Box3().setFromObject(currentMesh);
        const center = box.getCenter(new THREE.Vector3());
        const size = box.getSize(new THREE.Vector3());
        const d = Math.max(size.x, size.y, size.z) * 2;
        const positions = {
            front: [center.x, center.y - d, center.z],
            top:   [center.x, center.y, center.z + d],
            right: [center.x + d, center.y, center.z],
            iso:   [center.x + d*0.6, center.y - d*0.6, center.z + d*0.5],
        };
        const pos = positions[name] || positions.iso;
        camera.position.set(...pos);
        controls.target.copy(center);
        controls.update();
    };

    console.log('[3D viewer] three.js loaded OK');
} catch (err) {
    console.warn('[3D viewer] three.js failed to load:', err.message, '— UI still works');
    document.getElementById('previewPlaceholder').innerHTML =
        '<p>3D viewer unavailable</p><p class="hint">Check internet connection (three.js loads from CDN)</p>';
}
</script>
</body>
</html>"""


# ---------------------------------------------------------------------------
# HTTP Server
# ---------------------------------------------------------------------------

class ScadHandler(BaseHTTPRequestHandler):
    scad_path: str = ""
    lines: list[str] = []
    params: list[dict] = []
    scan_root: str = ""  # directory to scan for .scad files

    def log_message(self, format, *args):
        pass  # silence request logs

    def _send_json(self, data: dict, status: int = 200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

    def _send_html(self, html: str):
        body = html.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

    def _send_png(self, data: bytes):
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", len(data))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(data)

    def _send_binary(self, data: bytes, content_type: str):
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", len(data))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = urlparse(self.path).path

        if path == "/" or path == "":
            self._send_html(HTML_TEMPLATE)
            return

        if path == "/api/params":
            cls = type(self)
            with _state_lock:
                self._send_json({
                    "file": os.path.basename(cls.scad_path) if cls.scad_path else "",
                    "params": list(cls.params),
                })
            return

        if path == "/api/render":
            cls = type(self)
            if not cls.scad_path:
                self._send_json({"error": "no file"}, 400)
                return
            png = render_preview(cls.scad_path)
            if png:
                self._send_png(png)
            else:
                self._send_json({"error": "render failed"}, 500)
            return

        if path == "/api/stl":
            cls = type(self)
            if not cls.scad_path:
                self._send_json({"error": "no file"}, 400)
                return
            qs = parse_qs(urlparse(self.path).query)
            preview = qs.get("quality", ["preview"])[0] != "full"
            stl = export_stl(cls.scad_path, preview=preview)
            if stl:
                stl_name = Path(cls.scad_path).stem + ".stl"
                self.send_response(200)
                self.send_header("Content-Type", "application/octet-stream")
                self.send_header("Content-Length", len(stl))
                self.send_header("Content-Disposition", f'attachment; filename="{stl_name}"')
                self.send_header("Cache-Control", "no-cache")
                self.send_header("X-Render-Time", f"{last_render_time:.2f}")
                self.end_headers()
                self.wfile.write(stl)
            else:
                self._send_json({"error": last_render_error or "STL export failed"}, 500)
            return

        if path == "/api/open-editor":
            cls = type(self)
            exe = _find_openscad()
            if exe and cls.scad_path:
                subprocess.Popen([exe, cls.scad_path])
            self._send_json({"ok": True})
            return

        if path == "/api/list-files":
            cls = type(self)
            root = cls.scan_root or os.getcwd()
            files = []
            for p in sorted(Path(root).rglob("*.scad")):
                rel = str(p.relative_to(root)).replace("\\", "/")
                files.append({"path": str(p), "name": rel})
            self._send_json({"files": files, "current": os.path.basename(cls.scad_path) if cls.scad_path else ""})
            return

        self.send_error(404)

    def do_POST(self):
        path = urlparse(self.path).path

        if path == "/api/update":
            length = int(self.headers.get("Content-Length", 0))
            if length > 1_048_576:
                self.send_error(413, "Payload too large")
                return
            body = self.rfile.read(length)
            try:
                changes = json.loads(body)
            except (json.JSONDecodeError, ValueError):
                self._send_json({"error": "invalid JSON"}, 400)
                return
            cls = type(self)
            with _state_lock:
                cls.lines = update_scad(cls.scad_path, cls.lines, changes)
                cls.params = _parse_lines(cls.lines)
            self._send_json({"ok": True})
            return

        if path == "/api/load-file":
            length = int(self.headers.get("Content-Length", 0))
            if length > 1_048_576:
                self.send_error(413, "Payload too large")
                return
            body = self.rfile.read(length)
            try:
                data = json.loads(body)
            except (json.JSONDecodeError, ValueError):
                self._send_json({"error": "invalid JSON"}, 400)
                return
            file_path = data.get("path", "")
            if not os.path.isfile(file_path):
                self._send_json({"error": f"File not found: {file_path}"}, 404)
                return
            cls = type(self)
            abs_path = os.path.abspath(file_path)
            with _state_lock:
                cls.scad_path = abs_path
                cls.params, cls.lines = parse_scad(cls.scad_path)
                _stl_cache.clear()
            self._send_json({"ok": True, "file": os.path.basename(abs_path), "param_count": len(cls.params)})
            return

        if path == "/api/upload":
            length = int(self.headers.get("Content-Length", 0))
            if length > 10_485_760:  # 10MB limit
                self.send_error(413, "File too large (max 10MB)")
                return
            body = self.rfile.read(length)
            try:
                data = json.loads(body)
            except (json.JSONDecodeError, ValueError):
                self._send_json({"error": "invalid JSON"}, 400)
                return
            filename = data.get("filename", "uploaded.scad")
            content = data.get("content", "")
            if not filename.endswith(".scad"):
                self._send_json({"error": "Only .scad files allowed"}, 400)
                return
            # Save to scan_root or cwd
            cls = type(self)
            save_dir = cls.scan_root or os.getcwd()
            save_path = os.path.join(save_dir, os.path.basename(filename))
            Path(save_path).write_text(content, encoding="utf-8")
            abs_path = os.path.abspath(save_path)
            with _state_lock:
                cls.scad_path = abs_path
                cls.params, cls.lines = parse_scad(cls.scad_path)
                _stl_cache.clear()
            self._send_json({"ok": True, "file": os.path.basename(abs_path), "param_count": len(cls.params)})
            return

        self.send_error(404)

    def do_OPTIONS(self):
        # No CORS needed — UI is same-origin
        self.send_response(204)
        self.end_headers()


def main():
    parser = argparse.ArgumentParser(description="OpenSCAD Parametric Editor")
    parser.add_argument("file", nargs="?", help="Path to .scad file (optional — pick in browser)")
    parser.add_argument("-p", "--port", type=int, default=8042, help="Port (default 8042)")
    parser.add_argument("--no-browser", action="store_true", help="Don't auto-open browser")
    parser.add_argument("-d", "--dir", help="Root directory to scan for .scad files")
    parser.add_argument("--preview-fn", type=int, default=24,
                        help="$fn override for preview renders (default 24, 0=disable)")
    args = parser.parse_args()

    global PREVIEW_FN
    PREVIEW_FN = args.preview_fn if args.preview_fn > 0 else None

    scan_root = os.path.abspath(args.dir) if args.dir else os.getcwd()
    ScadHandler.scan_root = scan_root

    if args.file:
        scad_path = os.path.abspath(args.file)
        if not os.path.isfile(scad_path):
            print(f"Error: File not found: {scad_path}")
            sys.exit(1)
        ScadHandler.scad_path = scad_path
        ScadHandler.params, ScadHandler.lines = parse_scad(scad_path)
        print(f"Loading: {scad_path}")
        print(f"Found {len(ScadHandler.params)} parameters")
    else:
        print("No file specified — use the browser to pick or drop a .scad file")

    server = HTTPServer(("127.0.0.1", args.port), ScadHandler)
    url = f"http://127.0.0.1:{args.port}"
    print(f"Server running at {url}")
    print(f"Scanning: {scan_root}")
    print("Press Ctrl+C to stop\n")

    if not args.no_browser:
        threading.Timer(0.5, lambda: webbrowser.open(url)).start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
        server.server_close()


if __name__ == "__main__":
    main()
