#!/usr/bin/env python3
"""Keep the reviewed property catalogue and generated runtime copies identical."""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'frontend/assets/config/app_properties.json'
BACKEND = ROOT / 'backend/src/config/app-properties.defaults.json'
DART = ROOT / 'frontend/lib/core/config/property_defaults.dart'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    values = json.loads(SOURCE.read_text(encoding='utf-8'))
    if not all(isinstance(k, str) and isinstance(v, str) for k, v in values.items()):
        raise ValueError('Properties must map string keys to string defaults')
    canonical = json.dumps(values, indent=2, ensure_ascii=False) + '\n'
    # JSON string escaping is compatible with Dart after escaping interpolation.
    dart = '// Generated from assets/config/app_properties.json. Run scripts/properties/sync.py.\n'
    dart += 'const propertyDefaults = <String, String>{\n'
    for key, value in values.items():
        dart += '  ' + json.dumps(key, ensure_ascii=False) + ': ' + json.dumps(value, ensure_ascii=False).replace('$', r'\$') + ',\n'
    dart += '};\n'
    if args.check:
        if SOURCE.read_bytes() != BACKEND.read_bytes():
            raise ValueError('Frontend and backend property defaults differ. Run sync.py.')
        # Dart formatter may wrap long strings; compare generated map contents by
        # normalizing whitespace outside JSON literals rather than file layout.
        actual = DART.read_text(encoding='utf-8')
        pairs = re.findall(r'("(?:[^"\\]|\\.)*")\s*:\s*("(?:[^"\\]|\\.)*")', actual)
        parsed = {json.loads(k): json.loads(v.replace(r'\$', '$')) for k, v in pairs}
        if parsed != values:
            raise ValueError('Generated Dart defaults are stale. Run sync.py.')
        for path in (ROOT / 'frontend/lib').rglob('*.dart'):
            if path == DART:
                continue
            content = path.read_text(encoding='utf-8')
            keys = re.findall(r"AppCopy\.text\(\s*'([^']+)'", content)
            missing = set(keys) - values.keys()
            if missing:
                raise ValueError(f'{path}: unknown property keys {sorted(missing)}')
        for path in (ROOT / 'backend/src').rglob('*.ts'):
            content = path.read_text(encoding='utf-8')
            if 'getServerCopy' not in content:
                continue
            keys = re.findall(r"(?:\bcopy|\(await getServerCopy\(\)\))\(\s*'([^']+)'", content)
            if set(keys) - values.keys():
                raise ValueError(f'{path}: unknown server template keys')
        print(f'Property contract passed: {len(values)} defaults and all static Dart references match.')
    else:
        SOURCE.write_text(canonical, encoding='utf-8')
        BACKEND.write_text(canonical, encoding='utf-8')
        DART.write_text(dart, encoding='utf-8')
        inventory = []
        reference = re.compile(r"(?:AppCopy\.text|AppProperties\.instance\.color|PropertyImage)\(\s*'([^']+)'")
        for path in sorted((ROOT / 'frontend/lib').rglob('*.dart')):
            if path == DART:
                continue
            content = path.read_text(encoding='utf-8')
            for match in reference.finditer(content):
                inventory.append({'file': path.relative_to(ROOT).as_posix(),
                                  'line': content.count('\n', 0, match.start()) + 1,
                                  'key': match.group(1)})
        (ROOT / 'docs/reference/property-inventory.json').write_text(json.dumps(inventory, indent=2) + '\n', encoding='utf-8')
        print(f'Synchronized {len(values)} properties.')

if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
