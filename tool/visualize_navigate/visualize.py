import sys
import json
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.widgets import Slider, Button
import networkx as nx


TYPE_COLORS = {
    'start':        '#4CAF50',
    'resource':     '#2196F3',
    'exit':         '#FF9800',
    'keyPosition':  '#F44336',
    'keyTransport': '#9C27B0',
    'unknown':      '#9E9E9E',
}
TYPE_LABELS = {
    'start':        'Start',
    'resource':     'Resource',
    'exit':         'Exit',
    'keyPosition':  'KeyResource.Position',
    'keyTransport': 'KeyResource.Transport',
    'unknown':      'Unknown',
}


def load_stdin():
    landmarks = None
    events = []
    for lineno, raw in enumerate(sys.stdin, 1):
        line = raw.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError as e:
            print(f"[warn] line {lineno}: {e}", file=sys.stderr)
            continue
        if isinstance(obj, dict) and 'nodes' in obj and 'edges' in obj:
            landmarks = obj
        elif isinstance(obj, dict) and 'action' in obj:
            events.append(obj)
        else:
            print(f"[warn] line {lineno} 结构未知，跳过", file=sys.stderr)
    return landmarks, events


def build_layout_graph(nodes, edges):
    g = nx.Graph()
    for n in nodes:
        g.add_node(n['index'])
    best = {}
    for e in edges:
        a, b, d = e['from'], e['to'], e['dist']
        key = (min(a, b), max(a, b))
        if key not in best or d < best[key]:
            best[key] = d
    for (a, b), d in best.items():
        g.add_edge(a, b, dist=d)
    return g, best


class SearchViewer:
    def __init__(self, landmarks, events):
        self.lm = landmarks
        self.events = events
        self.nodes = landmarks['nodes']
        self.edges = landmarks['edges']

        g, best = build_layout_graph(self.nodes, self.edges)
        self.best = best
        if len(self.nodes) == 1:
            self.pos = {self.nodes[0]['index']: (0.0, 0.0)}
        else:
            self.pos = nx.spring_layout(
                g, seed=42, k=2.0 / max(len(self.nodes), 2) ** 0.5
            )

        self.fig, self.ax = plt.subplots(figsize=(14, 10))
        plt.subplots_adjust(bottom=0.16, right=0.82, left=0.03, top=0.93)

        self._draw_base()
        self.dyn_artists = []

        # 滑块
        if len(self.events) > 0:
            self.slider_ax = self.fig.add_axes([0.15, 0.06, 0.6, 0.03])
            self.slider = Slider(
                self.slider_ax, 'step',
                0, max(len(self.events) - 1, 0),
                valinit=0, valstep=1,
            )
            self.slider.on_changed(self._on_slider)
        else:
            self.slider = None

        # 播放按钮
        self.play_ax = self.fig.add_axes([0.78, 0.06, 0.08, 0.04])
        self.play_btn = Button(self.play_ax, 'Play')
        self.play_btn.on_clicked(self._on_play)

        # 状态栏
        self.status_ax = self.fig.add_axes([0.15, 0.115, 0.7, 0.03])
        self.status_ax.axis('off')
        self.status_text = self.status_ax.text(
            0.0, 0.5, '', fontsize=10, va='center', family='monospace',
        )

        self.fig.canvas.mpl_connect('key_press_event', self._on_key)

        self.current_step = 0
        self._timer = None
        self._update()

    def _draw_base(self):
        ax = self.ax
        for (a, b), d in self.best.items():
            x1, y1 = self.pos[a]
            x2, y2 = self.pos[b]
            ax.plot([x1, x2], [y1, y2], color='#CCCCCC',
                    lw=1.0, alpha=0.6, zorder=1)
            mx, my = (x1 + x2) / 2, (y1 + y2) / 2
            ax.text(mx, my, str(d), fontsize=7, color='#666666',
                    ha='center', va='center', zorder=1.5,
                    bbox=dict(boxstyle='round,pad=0.1',
                              fc='white', ec='none', alpha=0.7))

        for n in self.nodes:
            i = n['index']
            x, y = self.pos[i]
            color = TYPE_COLORS.get(n['type'], '#9E9E9E')
            ax.scatter(x, y, s=800, c=color, edgecolors='black',
                       linewidths=1.2, zorder=3)
            ax.text(x, y, str(i), color='white', fontsize=10,
                    ha='center', va='center', zorder=4, fontweight='bold')
            ax.text(x, y - 0.08, n['id'], fontsize=6, color='#333333',
                    ha='center', va='top', zorder=4)

        patches = [
            mpatches.Patch(color=TYPE_COLORS[t], label=TYPE_LABELS[t])
            for t in ['start', 'resource', 'exit',
                      'keyPosition', 'keyTransport', 'unknown']
        ]
        ax.legend(handles=patches, loc='upper right', framealpha=0.9)

        ax.set_title(
            f"Landmark A* Search  start={self.lm.get('startLandmark')}  "
            f"exits={self.lm.get('exitLandmarks')}  "
            f"keyPos={self.lm.get('keyPositionLandmark')}  "
            f"keyTrans={self.lm.get('keyTransportLandmark')}",
            fontsize=11,
        )
        ax.axis('off')

    def _clear_dynamic(self):
        for a in self.dyn_artists:
            try:
                a.remove()
            except Exception:
                pass
        self.dyn_artists.clear()

    def _draw_edge(self, e, current=False):
        frm = e['from']['landmark']
        to = e['to']['landmark']
        if frm == to:
            return
        x1, y1 = self.pos[frm]
        x2, y2 = self.pos[to]
        if e['action'] == 'expand':
            color, style = '#2E7D32', '-'
        else:
            color, style = '#90A4AE', '--'
        alpha = 1.0 if current else 0.28
        lw = 2.2 if current else 1.0
        arr = self.ax.annotate(
            '', xy=(x2, y2), xytext=(x1, y1),
            arrowprops=dict(arrowstyle='->', color=color, lw=lw,
                            alpha=alpha, linestyle=style,
                            shrinkA=18, shrinkB=18),
            zorder=5,
        )
        self.dyn_artists.append(arr)

        if current:
            mx, my = (x1 + x2) / 2, (y1 + y2) / 2
            txt = f"f={e.get('f', 0):.1f}"
            t = self.ax.text(
                mx, my + 0.02, txt, fontsize=8, color=color,
                ha='center', va='bottom', zorder=6,
                bbox=dict(boxstyle='round,pad=0.15', fc='white',
                          ec=color, alpha=0.95),
            )
            self.dyn_artists.append(t)

    def _draw_current_marker(self, e):
        action = e['action']
        if action in ('pop', 'stale', 'break', 'updateBest'):
            lm = e['from']['landmark']
            x, y = self.pos[lm]
            if action == 'pop':
                c = self.ax.scatter(x, y, s=1700, facecolors='none',
                                    edgecolors='red', linewidths=2.5, zorder=6)
                self.dyn_artists.append(c)
                t = self.ax.text(x, y + 0.09, f"pop f={e.get('f', 0):.1f}",
                                 fontsize=9, color='red',
                                 ha='center', va='bottom',
                                 fontweight='bold', zorder=7)
                self.dyn_artists.append(t)
            elif action == 'stale':
                c = self.ax.scatter(x, y, s=1400, facecolors='none',
                                    edgecolors='#B0BEC5', linewidths=2.0,
                                    zorder=6, alpha=0.7)
                self.dyn_artists.append(c)
            elif action == 'break':
                t = self.ax.text(x, y + 0.09, 'BREAK  f>=best',
                                 fontsize=10, color='#B71C1C',
                                 ha='center', va='bottom',
                                 fontweight='bold', zorder=7)
                self.dyn_artists.append(t)
            elif action == 'updateBest':
                c = self.ax.scatter(x, y, s=2100, facecolors='none',
                                    edgecolors='#FFD600', linewidths=3.5,
                                    zorder=7)
                self.dyn_artists.append(c)
                t = self.ax.text(
                    x, y + 0.09,
                    f"newBest={e.get('newBestCost', 0):.1f}",
                    fontsize=9, color='#F57F17',
                    ha='center', va='bottom',
                    fontweight='bold', zorder=7,
                )
                self.dyn_artists.append(t)
        elif action == 'start':
            lm = e['to']['landmark']
            x, y = self.pos[lm]
            c = self.ax.scatter(x, y, s=1500, facecolors='none',
                                edgecolors='#4CAF50', linewidths=2.5, zorder=6)
            self.dyn_artists.append(c)

    def _update(self):
        if not self.events:
            self.fig.canvas.draw_idle()
            return

        self._clear_dynamic()
        for step in range(self.current_step + 1):
            e = self.events[step]
            if e['action'] in ('expand', 'prune'):
                self._draw_edge(e, current=False)

        e = self.events[self.current_step]
        if e['action'] in ('expand', 'prune'):
            self._draw_edge(e, current=True)
        self._draw_current_marker(e)

        self.status_text.set_text(
            f"step={e['step']:>4}  action={e['action']:<11}  "
            f"g={_fmt(e.get('g'))}  h={_fmt(e.get('h'))}  f={_fmt(e.get('f'))}  "
            f"bestCost={_fmt(e.get('bestCost'))}  label={e.get('label', '')}"
        )
        self.fig.canvas.draw_idle()

    def _on_slider(self, val):
        self.current_step = int(round(val))
        self._update()

    def _on_key(self, event):
        if event.key == 'right':
            self._set_step(self.current_step + 1)
        elif event.key == 'left':
            self._set_step(self.current_step - 1)

    def _set_step(self, step):
        step = max(0, min(step, len(self.events) - 1))
        if self.slider is not None:
            self.slider.set_val(step)
        else:
            self.current_step = step
            self._update()

    def _on_play(self, event):
        if self._timer is not None:
            self._timer.stop()
            self._timer = None
        self.current_step = 0
        if self.slider is not None:
            self.slider.set_val(0)
        self._timer = self.fig.canvas.new_timer(interval=250)

        def _step():
            if self.current_step < len(self.events) - 1:
                self._set_step(self.current_step + 1)
            else:
                self._timer.stop()
                self._timer = None

        self._timer.add_callback(_step)
        self._timer.start()

    def show(self):
        plt.show()


def _fmt(v):
    if v is None:
        return '  -  '
    return f"{v:7.2f}"


if __name__ == '__main__':
    landmarks, events = load_stdin()
    if landmarks is None:
        print("stdin 里没读到 landmarks（含 nodes/edges 的对象）", file=sys.stderr)
        sys.exit(1)
    print(f"loaded {len(landmarks.get('nodes', []))} landmarks, "
          f"{len(events)} search events", file=sys.stderr)
    SearchViewer(landmarks, events).show()
