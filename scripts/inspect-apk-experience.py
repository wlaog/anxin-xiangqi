"""Inspect selected Cocos packed UI declarations without executing the APK.

This is Python inspection, not REA Evidence or a runtime observation. Output
contains reference-product data and belongs in the ignored private directory.
Only packed compiled-JSON v1 literals and property names are interpreted;
references, custom deserializers and omitted defaults remain unresolved.

Format reference: cocos/cocos-engine v3.8.8, cocos/serialization/deserialize.ts
(IClass, IMask, IPackedFileData, deserializeCCObject, parseArray, parseInstances).
"""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile


DEFAULT_ASSETS = [
    'Bundle-QipuAI:QiPuAI/QiPuMoveStatisticPanelForPotrait',
    'Bundle-QipuAI:QiPuAI/QipuMenuComponent',
    'Bundle-QipuAI:QiPuAI/QipuStatisticsItem',
    'Bundle-BattleBase:ChessPreviewPanel',
]
MAX_MEMBER_BYTES = 32 * 1024 * 1024
LITERAL_FIELDS = {'_name', '_string', 'title', 'handler', '_active'}


def read_json(archive, name):
    matches = [i for i in archive.infolist() if i.filename == name]
    if len(matches) != 1:
        raise ValueError(f'Expected one exact archive member: {name}')
    info = matches[0]
    if info.file_size > MAX_MEMBER_BYTES:
        raise ValueError(f'Selected JSON exceeds read budget: {name}')
    body = archive.read(info)
    return json.loads(body), {
        'member': name, 'bytes': len(body),
        'sha256': hashlib.sha256(body).hexdigest(),
    }


def inspect_section(packed, index):
    if not isinstance(packed, list) or len(packed) != 6 or packed[0] != 1:
        raise ValueError('Only Cocos packed compiled-JSON v1 is supported')
    classes, masks = packed[3], packed[4]
    section = packed[5][index]
    instances, extra_types = section[0], section[1]
    if len(section) != 6:
        raise ValueError('Unexpected packed section layout')
    count = len(instances) - (len(extra_types) if isinstance(extra_types, list) else 0)
    if instances and type(instances[-1]) is int:
        count -= 1  # RootInfo, rather than a serialized object.
    literals, observed_fields, unresolved = [], set(), {}
    object_count = 0

    def visit_value(kind, value, pointer):
        if kind == 4:
            visit_object(value, pointer)
        elif kind == 9:
            for i, item in enumerate(value):
                visit_object(item, f'{pointer}/{i}')
        elif kind == 12:
            if len(value) != len(value[0]) + 1:
                raise ValueError(f'Unexpected typed array at {pointer}')
            for i, item in enumerate(value[0]):
                visit_value(value[i + 1], item, f'{pointer}/0/{i}')
        elif kind == 11:
            if (len(value) - 1) % 3:
                raise ValueError(f'Unexpected typed dictionary at {pointer}')
            for i in range(1, len(value), 3):
                visit_value(value[i + 1], value[i + 2], f'{pointer}/{i + 2}')
        elif kind not in (0, 5, 7, 8):
            # References and custom classes are counted, never instantiated.
            unresolved[str(kind)] = unresolved.get(str(kind), 0) + 1

    def visit_object(data, pointer):
        nonlocal object_count
        if not isinstance(data, list) or not data or type(data[0]) is not int:
            raise ValueError(f'Unexpected object at {pointer}')
        if not 0 <= data[0] < len(masks):
            raise ValueError(f'Unknown object mask at {pointer}')
        mask = masks[data[0]]
        schema = classes[mask[0]]
        if not isinstance(schema, list) or len(data) != len(mask) - 1:
            raise ValueError(f'Unexpected object schema at {pointer}')
        object_count += 1
        for i, value in enumerate(data[1:], 1):
            key = schema[1][mask[i]]
            observed_fields.add(key)
            kind = 0 if i < mask[-1] else schema[mask[i] + schema[2]]
            location = f'{pointer}/{i}'
            if kind == 0 and key in LITERAL_FIELDS:
                literals.append({'class': schema[0], 'field': key,
                                 'value': value, 'json_pointer': location})
            visit_value(kind, value, location)

    for i in range(count):
        visit_object(instances[i], f'/5/{index}/0/{i}')
    return {
        'objects_examined': object_count,
        'fields_present': sorted(observed_fields),
        'literals': literals,
        'unresolved_advanced_values_by_type': unresolved,
        'uninterpreted_extra_instances': len(extra_types) if isinstance(extra_types, list) else 0,
    }


def inspect_asset(archive, selection):
    bundle, asset = selection.split(':', 1)
    config_name = f'assets/assets/{bundle}/cc.config.json'
    config, config_identity = read_json(archive, config_name)
    candidates = [(int(key), value) for key, value in config['paths'].items()
                  if value[0] == asset]
    if len(candidates) != 1:
        raise ValueError(f'Expected one selected resource: {selection}')
    asset_index, entry = candidates[0]
    packs = [(key, ids.index(asset_index)) for key, ids in config['packs'].items()
             if asset_index in ids]
    if len(packs) != 1:
        raise ValueError(f'Selected resource is not in one known pack: {selection}')
    pack, section_index = packs[0]
    # The exact member comes from observed pack identity, not a guessed UUID.
    prefix = f'assets/assets/{bundle}/import/'
    members = [i.filename for i in archive.infolist()
               if i.filename.startswith(prefix)
               and Path(i.filename).name == f'{pack}.json']
    if len(members) != 1:
        raise ValueError(f'Expected one selected packed JSON: {selection}')
    packed, packed_identity = read_json(archive, members[0])
    return {'selection': selection, 'asset_index': asset_index,
            'asset_uuid': config['uuids'][asset_index],
            'asset_type': config['types'][entry[1]],
            'config': config_identity, 'packed_json': packed_identity,
            'section_index': section_index,
            **inspect_section(packed, section_index)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--asset', action='append', help='Exact Bundle:asset/path')
    parser.add_argument('--output', type=Path,
                        default=Path('research/private/apk-round4/resource-experience.json'))
    args = parser.parse_args()
    with args.apk.open('rb') as source:
        digest = hashlib.file_digest(source, 'sha256').hexdigest()
    with zipfile.ZipFile(args.apk) as archive:
        report = {
            'tool': 'Python stdlib Cocos packed UI declaration inspection',
            'apk_path': str(args.apk), 'apk_bytes': args.apk.stat().st_size,
            'apk_sha256': digest, 'execution': 'not_performed',
            'resources': [inspect_asset(archive, s) for s in args.asset or DEFAULT_ASSETS],
            'limitations': [
                'Static serialized declarations do not establish runtime behavior.',
                'Only explicitly selected packed compiled-JSON v1 resources are examined.',
                'References, custom deserializers, extra instances and omitted defaults remain unresolved.',
                'Property names and handler strings do not establish that a handler is reachable.',
                'This output is ordinary Python inspection, not REA Evidence.',
            ],
        }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'report': str(args.output), 'apk_sha256': digest,
                      'selected_resources': len(report['resources']),
                      'objects_examined': sum(r['objects_examined'] for r in report['resources'])},
                     ensure_ascii=False))


if __name__ == '__main__':
    main()
