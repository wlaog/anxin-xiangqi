"""Static ZIP / DEX / ELF inventory; never executes APK code.

Usage: python scripts/inspect-apk.py tiantian-xiangqi/base.apk.1
Raw output is private by default. This is an ordinary Python inspection,
not REA Evidence or a decompiler.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zipfile


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def elf_exports(data):
    if data[:6] != b'\x7fELF\x02\x01':
        raise ValueError('Expected a little-endian ELF64 file')
    section_offset = struct.unpack_from('<Q', data, 40)[0]
    size, count = struct.unpack_from('<HH', data, 58)
    sections = [struct.unpack_from('<IIQQQQIIQQ', data, section_offset + i * size)
                for i in range(count)]
    result = []
    for section in sections:
        if section[1] != 11:  # SHT_DYNSYM
            continue
        strings_section = sections[section[6]]
        strings = data[strings_section[4]:strings_section[4] + strings_section[5]]
        for offset in range(section[4], section[4] + section[5], section[9]):
            name, info, _, index, value, length = struct.unpack_from('<IBBHQQ', data, offset)
            if index == 0 or info >> 4 not in (1, 2):
                continue
            end = strings.find(b'\0', name)
            text = strings[name:end].decode('utf-8', errors='replace')
            if text.startswith('Java_') or text == 'JNI_OnLoad':
                result.append({'name': text, 'address': hex(value), 'bytes': length})
    return result


def dex_methods(data, descriptor):
    if not data.startswith(b'dex\n'):
        raise ValueError('Expected standard DEX')
    def u32(offset):
        return struct.unpack_from('<I', data, offset)[0]
    def leb(offset):
        value = 0
        for shift in range(0, 35, 7):
            byte = data[offset]
            offset += 1
            value |= (byte & 127) << shift
            if byte < 128:
                return value, offset
        raise ValueError('Invalid ULEB128')
    string_count, string_offset = u32(56), u32(60)
    strings = []
    for i in range(string_count):
        _, offset = leb(u32(string_offset + i * 4))
        strings.append(data[offset:data.index(0, offset)].decode('utf-8', errors='replace'))
    types = [strings[u32(u32(68) + i * 4)] for i in range(u32(64))]
    result = []
    for i in range(u32(88)):
        class_index, proto_index, name_index = struct.unpack_from('<HHI', data, u32(92) + i * 8)
        if types[class_index] != descriptor:
            continue
        proto = u32(76) + proto_index * 12
        return_type, parameters_offset = u32(proto + 4), u32(proto + 8)
        parameters = [] if not parameters_offset else [
            types[struct.unpack_from('<H', data, parameters_offset + 4 + n * 2)[0]]
            for n in range(u32(parameters_offset))]
        result.append({'name': strings[name_index], 'return': types[return_type],
                       'parameters': parameters, 'method_id': i})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--output', type=Path, default=Path('research/private/apk-inventory'))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    report = {'tool': 'Python stdlib ZIP/DEX/ELF inspection',
              'apk_sha256': sha256(args.apk), 'apk_bytes': args.apk.stat().st_size,
              'execution': 'not_performed', 'selected_members': [], 'dex_bridge_methods': []}
    selected = ['assets/application.js', 'assets/main.js', 'assets/src/settings.json',
                'lib/arm64-v8a/libpikafishso.so', 'lib/arm64-v8a/libgradishwrapper.so']
    with zipfile.ZipFile(args.apk) as archive:
        members = archive.namelist()
        report['member_count'] = len(members)
        report['native_libraries'] = [n for n in members if n.endswith('.so')]
        report['script_members'] = [n for n in members if n.endswith(('.js', '.jsc'))]
        for name in selected:
            if name not in members:
                continue
            if archive.getinfo(name).file_size > 32 * 1024 * 1024:
                raise ValueError(f'Selected member exceeds read budget: {name}')
            body = archive.read(name)
            record = {'member': name, 'bytes': len(body), 'sha256': hashlib.sha256(body).hexdigest()}
            # Fixed selected filenames avoid extracting arbitrary archive paths.
            (args.output / Path(name).name).write_bytes(body)
            if name.endswith('.so'):
                record['jni_exports'] = elf_exports(body)
            if name.endswith('settings.json'):
                report['cocos_engine_declaration'] = json.loads(body).get('CocosEngine')
            report['selected_members'].append(record)
        for name in (n for n in members if n.endswith('.dex')):
            if archive.getinfo(name).file_size > 64 * 1024 * 1024:
                raise ValueError(f'DEX exceeds read budget: {name}')
            methods = dex_methods(archive.read(name), 'Lcom/pikafish/androidso/PikafishUtils;')
            if methods:
                report['dex_bridge_methods'].append({'member': name, 'methods': methods})
        if 'assets/pikafish.nnue' in members:
            report['nnue_member'] = {'member': 'assets/pikafish.nnue',
                                     'bytes': archive.getinfo('assets/pikafish.nnue').file_size}
    destination = args.output / 'inventory.json'
    destination.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'report': str(destination), 'apk_sha256': report['apk_sha256'],
                      'cocos': report.get('cocos_engine_declaration'),
                      'bridge': report['dex_bridge_methods']}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
