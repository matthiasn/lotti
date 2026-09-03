"""Run the plaza dev harness in PLAZA_TOUR mode and grab a PNG per tour stop.

Linux/X11 only (uses python-Xlib XGetImage on the app window; under a
Wayland session the harness is launched with GDK_BACKEND=x11 so it is an X
client). Build the harness first:

    fvm flutter build linux --debug -t lib/features/plaza/dev_main.dart

Then, from the repo root:

    python3 tool/plaza/capture_tour.py docs/plaza/screenshots

Optional: PLAZA_CLICK="<stop-name>:<x>,<y>" clicks that window-relative point
after capturing the named stop and grabs a second frame as <stop>-ticked.png
(used for the live-checkbox screenshot). Any other PLAZA_* variable is
passed through to the harness. Output PNGs land in a directory named
`screenshots`, which .gitignore keeps out of the repository.

The script keys on the `PLAZA_TOUR ready <i> <name>` lines the harness prints
once a stop has settled, writes <out_dir>/<name>.png, and exits after
`PLAZA_TOUR done` (or a 240 s timeout).
"""
import os, re, subprocess, sys, time
from pathlib import Path
from PIL import Image
from Xlib import display, X
from Xlib.ext import xtest

out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, GDK_BACKEND='x11', PLAZA_TOUR='1',
           FLUTTER_ENGINE_SWITCHES='1', FLUTTER_ENGINE_SWITCH_1='enable-flutter-gpu',
           LOTTI_WINDOW_SIZE=os.environ.get('LOTTI_WINDOW_SIZE', '1600x1000'))
extra = {k: v for k, v in os.environ.items() if k.startswith('PLAZA_')}
env.update(extra)
proc = subprocess.Popen(['build/linux/arm64/debug/bundle/lotti'], env=env,
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
d = display.Display()
root = d.screen().root

def find_window():
    def walk(w):
        try:
            name = w.get_wm_name()
        except Exception:
            name = None
        if name and 'lotti' in str(name).lower():
            g = w.get_geometry()
            if g.width > 400:
                return w
        for c in w.query_tree().children:
            r = walk(c)
            if r: return r
        return None
    return walk(root)

def grab(w, path):
    g = w.get_geometry()
    raw = w.get_image(0, 0, g.width, g.height, X.ZPixmap, 0xffffffff)
    img = Image.frombytes('RGB', (g.width, g.height), raw.data, 'raw', 'BGRX')
    img.save(path)
    print(f'captured {path} {g.width}x{g.height}', flush=True)

win = None
deadline = time.time() + 240
for line in proc.stdout:
    line = line.rstrip()
    if 'PLAZA_TOUR' in line or 'Error' in line or 'error' in line:
        print(line, flush=True)
    m = re.search(r'PLAZA_TOUR ready (\d+) (\S+)', line)
    if m:
        for _ in range(20):
            win = win or find_window()
            if win: break
            time.sleep(0.5)
        if not win:
            print('no window found', flush=True); continue
        grab(win, out / f'{m.group(2)}.png')
        click = os.environ.get('PLAZA_CLICK', '')
        if click.startswith(m.group(2) + ':'):
            rx, ry = (int(v) for v in click.split(':')[1].split(','))
            origin = win.translate_coords(root, 0, 0)
            ax, ay = -origin.x, -origin.y
            xtest.fake_input(d, X.MotionNotify, x=ax + rx, y=ay + ry); d.sync()
            time.sleep(0.3)
            xtest.fake_input(d, X.ButtonPress, 1); d.sync(); time.sleep(0.1)
            xtest.fake_input(d, X.ButtonRelease, 1); d.sync()
            time.sleep(1.5)
            grab(win, out / f'{m.group(2)}-ticked.png')
    if 'PLAZA_TOUR done' in line or time.time() > deadline:
        break
proc.terminate()
try: proc.wait(5)
except Exception: proc.kill()
print('finished', flush=True)
