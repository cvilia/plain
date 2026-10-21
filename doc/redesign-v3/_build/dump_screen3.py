import json, sys

with open(r'C:\Users\lizhenyu\WorkBuddy\Dev\PlainApp\redesign-v3\_build\spec.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

sc = data[2]  # screen 3 = add
print(f'Screen 3 [{sc["title"]}] canvas={sc["canvas"]} items={len(sc["items"])}')
print()

for it in sc['items']:
    d = it.get('d', 0)
    if d > 5: continue
    indent = '  ' * d
    cls = it.get('cls') or ''
    tag = it.get('tag') or ''
    x, y, w, h = it.get('x',0), it.get('y',0), it.get('w',0), it.get('h',0)
    pad = it.get('pad')
    gap = it.get('gap')
    bg = it.get('bg') or ''
    rad = it.get('rad') or ''
    fs = it.get('fs') or ''
    fw = it.get('fw') or ''
    txt = ''
    if it.get('txt') and it['txt'].get('v'):
        txt = it['txt']['v'][:45]
    parts = [f'{x:.0f},{y:.0f} {w:.0f}x{h:.0f}']
    if pad: parts.append(f'pad{pad}')
    if gap: parts.append(f'gap{gap}')
    if rad and rad != '0px': parts.append(f'r={rad}')
    if bg: parts.append(f'bg={bg[:20]}')
    if fs: parts.append(f'fs={fs}')
    if fw: parts.append(f'fw={fw}')
    meta = ' '.join(parts)
    print(f'{indent}[{tag:5s}] .{cls:24s} {meta:58s} {txt}')
