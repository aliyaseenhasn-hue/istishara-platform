#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import json

old = 'assets/icons/app_icon.png'
new = 'assets/icons/app_icon_v2.png'

# Flutter assets + all in-app references.
pubspec = Path('pubspec.yaml')
s = pubspec.read_text()
if 'assets/icons/app_icon_v2.png' not in s:
    s = s.replace('    - assets/icons/app_icon.png\n', '    - assets/icons/app_icon.png\n    - assets/icons/app_icon_v2.png\n')
pubspec.write_text(s)

for path in Path('lib').rglob('*.dart'):
    text = path.read_text()
    if old in text:
        path.write_text(text.replace(old, new))

# PWA manifest points to the built Flutter asset with a unique filename.
manifest = Path('web/manifest.json')
data = json.loads(manifest.read_text())
data['icons'] = [{
    'src': 'assets/assets/icons/app_icon_v2.png',
    'sizes': '192x192',
    'type': 'image/png',
    'purpose': 'any'
}]
manifest.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')

# Browser / iOS home-screen metadata.
for filename in ['web/index.html', 'web/404.html']:
    path = Path(filename)
    if not path.exists():
        continue
    text = path.read_text()
    text = text.replace('assets/icons/app_icon.png', 'assets/assets/icons/app_icon_v2.png')
    text = text.replace('assets/assets/icons/app_icon.png', 'assets/assets/icons/app_icon_v2.png')
    path.write_text(text)

# Force installed PWAs to activate a fresh cache and always refresh icon assets.
sw = Path('web/pwa_service_worker_v5.js')
text = sw.read_text()
text = text.replace("const CACHE_NAME = 'astshara-pwa-v6';", "const CACHE_NAME = 'astshara-pwa-v7';")
text = text.replace("icon: data.icon || './icons/Icon-192.png',", "icon: data.icon || './assets/assets/icons/app_icon_v2.png',")
text = text.replace("badge: data.badge || './icons/Icon-192.png',", "badge: data.badge || './assets/assets/icons/app_icon_v2.png',")
needle = "  const isNavigation = event.request.mode === 'navigate' ||\n      url.pathname.endsWith('/index.html') ||\n      url.pathname.endsWith('/flutter_bootstrap.js');"
replacement = needle + "\n  const isIconAsset = url.pathname.endsWith('/app_icon.png') || url.pathname.endsWith('/app_icon_v2.png');"
if 'const isIconAsset' not in text:
    text = text.replace(needle, replacement)
text = text.replace(
    "fetch(event.request, isNavigation ? { cache: 'no-store' } : undefined)",
    "fetch(event.request, (isNavigation || isIconAsset) ? { cache: 'no-store' } : undefined)"
)
sw.write_text(text)

# Deployment assertion follows the new asset.
deploy = Path('.github/workflows/deploy.yml')
if deploy.exists():
    text = deploy.read_text().replace(
        'build/web/assets/assets/icons/app_icon.png',
        'build/web/assets/assets/icons/app_icon_v2.png'
    )
    deploy.write_text(text)
PY

# Validate binary assets before committing.
python3 - <<'PY'
from pathlib import Path
for p in [Path('assets/icons/app_icon.png'), Path('assets/icons/app_icon_v2.png'), Path('android/app/src/main/res/drawable-nodpi/ic_launcher.png')]:
    b = p.read_bytes()
    assert b.startswith(b'\x89PNG\r\n\x1a\n'), f'Invalid PNG: {p}'
    print('validated', p, len(b))
PY
