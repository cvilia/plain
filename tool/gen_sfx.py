# -*- coding: utf-8 -*-
"""Plain / 素记 -- bookkeeping confirmation SFX generator.

Synthesises candidate "record saved" sounds as 44.1 kHz / 16-bit / mono WAV.
Two families:
  confirm  -- restrained, "professional" set (round 1)
  playful  -- 俏皮 set, ordered light -> cartoon (round 2)
Deterministic: rerun the script to regenerate. Never hand-edit the WAVs.

Run:
    C:\\Users\\lizhenyu\\.workbuddy\\binaries\\python\\envs\\default\\Scripts\\python.exe tool/gen_sfx.py

Design constraints (a sound that fires on every save, tens of times a day):
  * short      -- <= 450 ms
  * immediate  -- audible energy from sample 0; peak must not sit late
  * safe       -- zero DC, zero start/end discontinuity, peak <= -1.0 dBFS
  * fair       -- candidates loudness-matched (A-weighted RMS, +-2.5 dB trim)

Playful vocabulary actually used here: pitch glide (portamento), leap intervals,
band-limited square (chip flavour), music-box partials, vibrato / tremolo.
"""

import os
import wave

import numpy as np

SR = 44100
BASE_PEAK_DBFS = -3.0     # all candidates start here
PEAK_CEIL_DBFS = -1.0     # never hotter than this
MAX_TRIM_DB = 2.5         # loudness-match trim limit
OUT_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
)


# --------------------------------------------------------------------------- #
# primitives
# --------------------------------------------------------------------------- #
def _t(dur):
    return np.arange(int(round(dur * SR))) / SR


def tone(freq, amp, tau, dur, phase=0.0):
    """Exponentially decaying sine partial."""
    t = _t(dur)
    return amp * np.exp(-t / tau) * np.sin(2.0 * np.pi * freq * t + phase)


def bell(freq, dur, tau=0.11, amp=1.0,
         ratios=(1.0, 2.0, 2.76, 5.40), amps=(1.0, 0.42, 0.24, 0.10)):
    """Struck-metal flavour: slightly inharmonic partials, upper ones decay faster."""
    out = np.zeros(int(round(dur * SR)))
    for ratio, a in zip(ratios, amps):
        out += tone(freq * ratio, a, tau / max(1.0, ratio ** 0.65), dur)
    return amp * out


def music_box(freq, dur, tau=0.095, amp=1.0):
    """Music-box / celesta tine: sparse inharmonic partials, fast upper decay."""
    ratios = (1.0, 2.0, 3.01, 4.20, 5.43, 7.10)
    amps = (1.0, 0.46, 0.20, 0.10, 0.038, 0.014)
    return bell(freq, dur, tau=tau, amp=amp, ratios=ratios, amps=amps)


def wood_hit(freq, dur, tau=0.030, amp=1.0, seed=7):
    """Percussive knock: band-limited noise burst + resonant body."""
    t = _t(dur)
    rng = np.random.default_rng(seed)
    k = 18  # ~0.4 ms moving average -> low-pass near 2.4 kHz, woody not hissy
    noise = np.convolve(rng.normal(0.0, 1.0, len(t)), np.ones(k) / k, mode="same")
    body = np.exp(-t / tau) * np.sin(2.0 * np.pi * freq * t)
    click = np.exp(-t / (tau * 0.35)) * noise
    return amp * (0.95 * body + 0.32 * click)


def glide(f0, f1, dur, amp=1.0, tau=None, curve="exp",
          vib_hz=0.0, vib_depth=0.0, vib_ramp_ms=30.0):
    """Portamento tone. Phase is integrated so a swept pitch never clicks.

    curve: 'exp'  -- constant-ratio sweep, slow to arrive
           'sqrt' -- front-loaded sweep, most of the rise happens early
           'lin'  -- linear in Hz
    """
    t = _t(dur)
    k = t / t[-1]
    if curve == "exp":
        f = f0 * (f1 / f0) ** k
    elif curve == "sqrt":
        f = f0 + (f1 - f0) * np.sqrt(k)
    else:
        f = f0 + (f1 - f0) * k
    if vib_hz > 0.0 and vib_depth > 0.0:
        ramp = np.clip(t / (vib_ramp_ms / 1000.0), 0.0, 1.0)
        f = f * (1.0 + vib_depth * ramp * np.sin(2.0 * np.pi * vib_hz * t))
    omega = 2.0 * np.pi * f / SR
    phase = np.concatenate(([0.0], np.cumsum(omega[:-1])))
    env = np.exp(-t / tau) if tau else np.ones_like(t)
    return amp * env * np.sin(phase)


def bl_square(freq, dur, amp=1.0, tau=0.06, nharm=9, blend=0.75):
    """Band-limited square (odd harmonics, 1/n) -- classic chip flavour."""
    t = _t(dur)
    out = np.zeros(len(t))
    for h in range(1, nharm + 1, 2):
        out += np.sin(2.0 * np.pi * freq * h * t) / h
    out *= 4.0 / np.pi
    out = blend * out + (1.0 - blend) * np.sin(2.0 * np.pi * freq * t)
    return amp * np.exp(-t / tau) * out


def noise_burst(dur, tau, amp=1.0, lp=24, seed=0):
    """Short filtered noise -- used as a "pop" transient."""
    t = _t(dur)
    rng = np.random.default_rng(seed)
    n = np.convolve(rng.normal(0.0, 1.0, len(t)), np.ones(lp) / lp, mode="same")
    peak = float(np.max(np.abs(n)))
    if peak > 0:
        n = n / peak
    return amp * np.exp(-t / tau) * n


def tremolo(x, hz, depth, ramp_ms=20.0):
    t = _t(len(x) / SR)[: len(x)]
    ramp = np.clip(t / (ramp_ms / 1000.0), 0.0, 1.0)
    return x * (1.0 + depth * ramp * np.sin(2.0 * np.pi * hz * t))


def place(track, seg, at_ms):
    i = int(round(at_ms / 1000.0 * SR))
    if i >= len(track):
        return track
    j = min(len(track), i + len(seg))
    track[i:j] += seg[: j - i]
    return track


def track(dur):
    return np.zeros(int(round(dur * SR)))


# --------------------------------------------------------------------------- #
# family A -- confirm (restrained)
# --------------------------------------------------------------------------- #
def sfx_chime():
    """Bright rising fifth bell (C6 -> G6)."""
    tr = track(0.34)
    place(tr, bell(1046.50, 0.24, tau=0.070, amp=1.15), 0.0)   # C6, the hit you feel
    place(tr, bell(1567.98, 0.30, tau=0.115, amp=0.72), 55.0)  # G6, the lift
    return tr


def sfx_wood():
    """Two-tone wooden knock (rising fifth)."""
    tr = track(0.22)
    place(tr, wood_hit(780.0, 0.13, tau=0.028), 0.0)
    place(tr, wood_hit(1170.0, 0.15, tau=0.032, seed=11), 42.0)
    return tr


def sfx_soft():
    """Single soft ping."""
    dur = 0.24
    return tone(784.0, 1.0, 0.115, dur) + tone(1568.0, 0.16, 0.075, dur)


def sfx_up():
    """Major-third rise, odd harmonics."""
    def tri(freq, tau, d):
        out = np.zeros(int(round(d * SR)))
        for h, a in ((1, 1.0), (3, 1 / 9.0), (5, 1 / 25.0)):
            out += tone(freq * h, a, tau / h ** 0.6, d)
        return out

    tr = track(0.30)
    place(tr, tri(880.00, 0.085, 0.20), 0.0)     # A5
    place(tr, tri(1108.73, 0.130, 0.24), 70.0)   # C#6
    return tr


CONFIRM = [
    ("sfx_confirm_chime.wav", sfx_chime, "清脆铃声", "上行纯五度 C6→G6，明亮、收束干净"),
    ("sfx_confirm_wood.wav", sfx_wood, "木质轻敲", "上行五度双击，最克制"),
    ("sfx_confirm_soft.wav", sfx_soft, "柔和单音", "单音轻叮，最不打扰"),
    ("sfx_confirm_up.wav", sfx_up, "大三度上行", "A5→C#6，完成感最强"),
]


# --------------------------------------------------------------------------- #
# family B -- playful (light -> cartoon)
# --------------------------------------------------------------------------- #
def sfx_play_box():
    """Music-box arpeggio E6-G#6-B6. Light, pretty, the most re-listenable."""
    tr = track(0.42)
    for i, (f, a) in enumerate(zip((1318.51, 1661.22, 1975.53),  # E6 G#6 B6
                                   (1.00, 0.84, 0.74))):
        place(tr, music_box(f, 0.30, tau=0.105, amp=a), i * 62.0)
    return tr


def sfx_play_coin():
    """Chip-style coin: B5 -> E6, band-limited square. Highest recognition."""
    tr = track(0.26)
    place(tr, bl_square(987.77, 0.070, tau=0.020, amp=0.80, nharm=5, blend=0.70), 0.0)
    place(tr, bl_square(1318.51, 0.190, tau=0.082, amp=1.00, nharm=7, blend=0.70), 64.0)
    return tr


def sfx_play_pop():
    """Bubble pop: front-loaded 540 -> 1550 Hz sweep + crackle transient.

    'sqrt' curve matters here -- an exponential sweep lingers near the start
    frequency and the result reads as a dull 'woo' instead of a bright 'pop'.
    """
    tr = track(0.25)
    place(tr, glide(540.0, 1550.0, 0.22, amp=1.0, tau=0.070, curve="sqrt"), 0.0)
    place(tr, noise_burst(0.014, tau=0.0035, amp=0.30, lp=10, seed=3), 0.0)
    return tr


def sfx_play_chirp():
    """Bird chirp: up-sweep then down-sweep, with vibrato on the tail."""
    tr = track(0.28)
    place(tr, glide(1480.0, 2150.0, 0.080, amp=1.0, tau=0.032, curve="exp",
                    vib_hz=48.0, vib_depth=0.035, vib_ramp_ms=20.0), 0.0)
    place(tr, glide(2150.0, 1180.0, 0.150, amp=0.92, tau=0.048, curve="exp",
                    vib_hz=42.0, vib_depth=0.045, vib_ramp_ms=12.0), 72.0)
    return tr


def sfx_play_boing():
    """Cartoon boing: downward sweep with tremolo. Most exaggerated of the set."""
    tr = track(0.34)
    body = glide(1300.0, 420.0, 0.32, amp=1.0, tau=0.130, curve="exp",
                 vib_hz=24.0, vib_depth=0.06, vib_ramp_ms=18.0)
    place(tr, tremolo(body, 15.0, 0.30, ramp_ms=16.0), 0.0)
    place(tr, noise_burst(0.010, tau=0.003, amp=0.16, lp=8, seed=5), 0.0)
    return tr


PLAYFUL = [
    ("sfx_play_box.wav", sfx_play_box, "八音盒琶音", "E6→G#6→B6 三音上行，轻快优雅，最耐听的俏皮"),
    ("sfx_play_coin.wav", sfx_play_coin, "金币叮", "B5→E6 芯片音，游戏感与识别度最高"),
    ("sfx_play_pop.wav", sfx_play_pop, "气泡啵", "430→1150Hz 急速上滑，可爱又极短（200ms）"),
    ("sfx_play_chirp.wav", sfx_play_chirp, "小鸟啾", "双向滑音 + 颤音，像小鸟叫，活泼可爱"),
    ("sfx_play_boing.wav", sfx_play_boing, "弹簧蹦", "下滑 + 颤动，卡通夸张，俏皮度最高"),
]

FAMILIES = [
    ("playful", "俏皮版", "本轮方向", PLAYFUL),
    ("confirm", "稳重版", "上一轮", CONFIRM),
]


# --------------------------------------------------------------------------- #
# processing
# --------------------------------------------------------------------------- #
def prep(x, attack_ms=2.0, release_ms=8.0):
    """Anti-click fades -> DC removal -> peak normalise -> gentle soft clip."""
    a = int(round(attack_ms / 1000.0 * SR))
    if a > 0:
        x[:a] *= np.linspace(0.0, 1.0, a)
    r = int(round(release_ms / 1000.0 * SR))
    if r > 0:
        x[-r:] *= np.linspace(1.0, 0.0, r)
    x = x - float(np.mean(x))
    peak = float(np.max(np.abs(x)))
    if peak > 0:
        x = x / peak
    return np.tanh(x * 1.15) / np.tanh(1.15)


def a_weighted_rms_db(x, sr=SR):
    """Perceptual level proxy (IEC 61672 A-weighting, applied in the frequency domain)."""
    fr = np.fft.rfftfreq(len(x), 1.0 / sr)
    fr_safe = np.maximum(fr, 1e-6)
    num = 12194.0 ** 2 * fr_safe ** 4
    den = (fr_safe ** 2 + 20.6 ** 2) * np.sqrt(
        (fr_safe ** 2 + 107.7 ** 2) * (fr_safe ** 2 + 737.9 ** 2)
    ) * (fr_safe ** 2 + 12194.0 ** 2)
    w = 10.0 ** ((20.0 * np.log10(num / den) + 2.0) / 20.0)
    xw = np.fft.irfft(np.fft.rfft(x) * w, n=len(x))
    return 20.0 * np.log10(max(float(np.sqrt((xw ** 2).mean())), 1e-9))


def write_wav(path, x):
    data = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


# --------------------------------------------------------------------------- #
# sheets
# --------------------------------------------------------------------------- #
PREVIEW = """<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>素记 · 记账音效试听</title>
<style>
:root{{--bg:#f6f7f8;--card:#fff;--ink:#1b1f23;--ink2:#5b6570;--line:#e4e7ea;
--brand:#0F9E90;--softer:#f0fbf8;--warm:#C2410C;--warmbg:#fff7ed;}}
*{{box-sizing:border-box}}
body{{margin:0;padding:32px 20px 48px;background:var(--bg);color:var(--ink);
font:14px/1.55 -apple-system,"Segoe UI","Microsoft YaHei",sans-serif}}
h1{{margin:0 0 6px;font-size:20px;font-weight:600;letter-spacing:.01em}}
.sub{{color:var(--ink2);margin:0 0 26px;font-size:13px}}
h2{{display:flex;align-items:center;gap:9px;margin:26px 0 12px;font-size:15px;font-weight:600}}
h2:first-of-type{{margin-top:8px}}
h2 em{{font-style:normal;font-size:11px;font-weight:500;color:#fff;background:var(--brand);
border-radius:99px;padding:2px 9px;letter-spacing:.02em}}
h2.warm em{{background:var(--warm)}}
.grid{{display:grid;gap:12px;max-width:780px}}
.card{{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px 18px;
display:grid;grid-template-columns:1fr auto;gap:5px 16px;align-items:center}}
.card.warm{{background:var(--warmbg);border-color:#f5d9c2}}
.name{{font-weight:600}}
.meta{{font-size:12px;color:var(--ink2);font-variant-numeric:tabular-nums}}
.desc{{color:var(--ink2);font-size:12.5px;grid-column:1}}
button{{grid-row:1/3;grid-column:2;width:60px;height:60px;border-radius:50%;border:1px solid var(--line);
background:#fff;color:var(--brand);font-size:18px;cursor:pointer;transition:.15s}}
.card.warm button{{color:var(--warm)}}
button:hover{{border-color:currentColor;background:var(--softer)}}
button:active{{transform:scale(.96)}}
button.on{{background:var(--brand);border-color:var(--brand);color:#fff}}
.card.warm button.on{{background:var(--warm);border-color:var(--warm)}}
audio{{display:none}}
</style></head><body>
<h1>素记 · 记账确认音效</h1>
<p class="sub">44.1 kHz / 16-bit / 单声道 &nbsp;·&nbsp; 峰值统一 −3 dBFS &nbsp;·&nbsp; A 加权响度已对齐 &nbsp;·&nbsp; 点击圆形按钮试听</p>
{sections}
{audios}
<script>
document.querySelectorAll('button').forEach(b=>{{
  const a=document.getElementById(b.dataset.a);
  b.addEventListener('click',()=>{{
    document.querySelectorAll('audio').forEach(o=>{{if(o!==a){{o.pause();o.currentTime=0;}}}});
    document.querySelectorAll('button').forEach(o=>o.classList.remove('on'));
    a.currentTime=0;a.play();b.classList.add('on');
  }});
  a.addEventListener('ended',()=>b.classList.remove('on'));
}});
</script>
</body></html>
"""

SECTION = """<h2{cls}>{title}<em>{note}</em></h2>
<div class="grid">
{cards}
</div>"""

CARD = """  <div class="card{cls}">
    <button data-a="{aid}" title="播放">&#9654;</button>
    <div class="name">{title}</div>
    <div class="meta">{dur} ms · {kb} KB · {peak} dBFS</div>
    <div class="desc">{desc}</div>
  </div>"""

ENV_FONT = "-apple-system,Segoe UI,Microsoft YaHei,sans-serif"


def build_preview(groups):
    sections, audios = [], []
    for key, title, note, rows in groups:
        cards = []
        for i, (fn, ctitle, cdesc, ms, kb, pk) in enumerate(rows):
            aid = f"{key}{i}"
            cards.append(CARD.format(
                cls="" if key == "playful" else " warm",
                aid=aid, title=ctitle, dur=ms, kb=kb, peak=pk, desc=cdesc))
            audios.append(f'<audio id="{aid}" src="{fn}" preload="auto"></audio>')
        sections.append(SECTION.format(
            cls="" if key == "playful" else ' class="warm"',
            title=title, note=note, cards="\n".join(cards)))
    return PREVIEW.format(sections="\n".join(sections), audios="\n".join(audios))


def write_envelope_svg(items, path, width=680, panel_h=78, buckets=170, amp=42.0):
    """Amplitude-envelope comparison sheet (SVG, no external deps)."""
    pad_l, pad_r, pad_t = 108, 18, 16
    height = pad_t + panel_h * len(items) + 10
    plot_w = width - pad_l - pad_r
    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}">',
        f'<rect width="{width}" height="{height}" fill="#ffffff"/>',
        f'<text x="{pad_l}" y="11" font-family="{ENV_FONT}" font-size="10.5" fill="#8a929b">'
        f'amplitude envelope</text>',
    ]
    for i, (fn, title, x) in enumerate(items):
        top = pad_t + i * panel_h
        base = top + 46
        step = max(1, len(x) // buckets)
        env = np.array([np.abs(x[j * step:(j + 1) * step]).max()
                        for j in range(min(buckets, len(x) // step))])
        env = env / max(float(env.max()), 1e-9)
        pts = " ".join(
            f"{pad_l + plot_w * j / (len(env) - 1):.1f},{base - v * amp:.1f}"
            for j, v in enumerate(env))
        out += [
            f'<line x1="{pad_l}" y1="{base}" x2="{pad_l + plot_w}" y2="{base}" '
            f'stroke="#e4e7ea" stroke-width="1"/>',
            f'<polyline fill="none" stroke="#0F9E90" stroke-width="1.6" points="{pts}"/>',
            f'<text x="{pad_l - 14}" y="{top + 16}" text-anchor="end" font-family="{ENV_FONT}" '
            f'font-size="12.5" font-weight="600" fill="#1b1f23">{title}</text>',
            f'<text x="{pad_l - 14}" y="{top + 31}" text-anchor="end" font-family="{ENV_FONT}" '
            f'font-size="10.5" fill="#8a929b">{fn.replace("sfx_", "").replace(".wav", "")}</text>',
            f'<text x="{pad_l + plot_w}" y="{base + 13}" text-anchor="end" font-family="{ENV_FONT}" '
            f'font-size="10.5" fill="#8a929b">{int(round(len(x) / SR * 1000))} ms</text>',
        ]
    out.append("</svg>")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(out))


# --------------------------------------------------------------------------- #
def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print("out:", OUT_DIR)

    groups, all_env = [], {}
    for key, title, note, fam in FAMILIES:
        print("[%s]" % key)
        base = {fn: prep(gen()) * 10.0 ** (BASE_PEAK_DBFS / 20.0) for fn, gen, _, _ in fam}
        lvl = {fn: a_weighted_rms_db(x) for fn, x in base.items()}
        target = float(np.median(list(lvl.values())))
        ceil = 10.0 ** (PEAK_CEIL_DBFS / 20.0)
        print("  loudness target %.2f dB" % target)

        rows = []
        final = {}
        for fn, _, ctitle, cdesc in fam:
            trim = float(np.clip(target - lvl[fn], -MAX_TRIM_DB, MAX_TRIM_DB))
            x = base[fn] * 10.0 ** (trim / 20.0)
            peak = float(np.max(np.abs(x)))
            if peak > ceil:
                x *= ceil / peak
            write_wav(os.path.join(OUT_DIR, fn), x)
            final[fn] = x
            ms = int(round(len(x) / SR * 1000))
            kb = round(os.path.getsize(os.path.join(OUT_DIR, fn)) / 1024.0, 1)
            pk = 20.0 * np.log10(max(float(np.max(np.abs(x))), 1e-9))
            rows.append((fn, ctitle, cdesc, ms, kb, "%.1f" % pk))
            print("    %-26s %4d ms %6.1f KB  trim %+5.2f dB  peak %6.2f dBFS  A %6.2f dB"
                  % (fn, ms, kb, trim, pk, a_weighted_rms_db(x)))
        spread = max(a_weighted_rms_db(v) for v in final.values()) - \
            min(a_weighted_rms_db(v) for v in final.values())
        print("  loudness spread: %.2f dB" % spread)
        groups.append((key, title, note, rows))
        all_env[key] = (fam, final)

    preview = os.path.join(OUT_DIR, "preview.html")
    with open(preview, "w", encoding="utf-8") as f:
        f.write(build_preview(groups))
    print("preview:", preview)

    for key, title, note, fam in FAMILIES:
        src, final = all_env[key]
        items = [(fn, ctitle, final[fn]) for fn, _, ctitle, _ in src]
        path = os.path.join(OUT_DIR, "envelope-%s.svg" % key)
        write_envelope_svg(items, path)
        print("envelope:", path)


if __name__ == "__main__":
    main()
