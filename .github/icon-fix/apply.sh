#!/usr/bin/env bash
set -euo pipefail

base64 -d .github/icon-fix/icon_bundle.b64 > /tmp/icon_bundle.tar.gz
tar -xzf /tmp/icon_bundle.tar.gz -C .

rm -f android/app/src/main/res/drawable-nodpi/ic_launcher.png

python3 - <<'PY'
from pathlib import Path
import json, re

stamp = '20260909-3'

manifest = Path('web/manifest.json')
data = json.loads(manifest.read_text())
data['icons'] = [{
    'src': f'assets/assets/icons/app_icon.png?v={stamp}',
    'sizes': '192x192',
    'type': 'image/png',
    'purpose': 'any maskable',
}]
manifest.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')

for path in [Path('web/index.html'), Path('web/404.html')]:
    if path.exists():
        text = path.read_text()
        text = re.sub(r'assets/icons/app_icon\.png(?:\?v=[^"\']+)?', f'assets/icons/app_icon.png?v={stamp}', text)
        path.write_text(text)

sw = Path('web/pwa_service_worker_v5.js')
s = sw.read_text()
s = s.replace("const CACHE_NAME = 'astshara-pwa-v6';", "const CACHE_NAME = 'astshara-pwa-v7';")
if 'const isIconAsset' not in s:
    s = s.replace(
        "  const isNavigation = event.request.mode === 'navigate' ||\n      url.pathname.endsWith('/index.html') ||\n      url.pathname.endsWith('/flutter_bootstrap.js');",
        "  const isNavigation = event.request.mode === 'navigate' ||\n      url.pathname.endsWith('/index.html') ||\n      url.pathname.endsWith('/flutter_bootstrap.js');\n  const isIconAsset = url.pathname.endsWith('/app_icon.png');"
    )
s = s.replace(
    "fetch(event.request, isNavigation ? { cache: 'no-store' } : undefined)",
    "fetch(event.request, (isNavigation || isIconAsset) ? { cache: 'no-store' } : undefined)"
)
s = s.replace("icon: data.icon || './icons/Icon-192.png',", "icon: data.icon || './assets/assets/icons/app_icon.png?v=20260909-3',")
s = s.replace("badge: data.badge || './icons/Icon-192.png',", "badge: data.badge || './assets/assets/icons/app_icon.png?v=20260909-3',")
sw.write_text(s)
PY

python3 - <<'PY'
from pathlib import Path
paths = [
    Path('assets/icons/app_icon.png'),
    *Path('android/app/src/main/res').glob('mipmap-*/ic_launcher.png'),
]
for p in paths:
    b = p.read_bytes()
    assert b.startswith(b'\x89PNG\r\n\x1a\n'), f'Invalid PNG: {p}'
    print('validated', p, len(b))
PY
