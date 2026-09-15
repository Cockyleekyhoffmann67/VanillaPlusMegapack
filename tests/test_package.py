"""Prove one manager entry contains exactly the pinned gameplay payloads, without a loader."""
import json
from pathlib import Path
import struct
import sys
import zipfile
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from build import ARCHIVE, BUILD, GUID, MODULE, REVISION, ROOT, resource_hash, sha


def resources(data):
    assert struct.unpack_from('<III', data) == (0xF0000011, 1, 8)
    assert struct.unpack_from('<Q', data, 32)[0] == len(data)
    assert struct.unpack_from('<I', data, 88)[0] == 8
    result = {}
    occupied = set()
    for index in range(8):
        entry = struct.unpack_from('<7Q6I', data, 104 + 80 * index)
        key, kind, offset = entry[:3]
        size = entry[7]
        assert kind == 0xA14E8DFA2CD117E2 and key not in result and entry[-1] == index
        assert offset % 16 == 0 and 104 + 80 * 8 <= offset < offset + size <= len(data)
        assert not occupied.intersection(range(offset, offset + size))
        occupied.update(range(offset, offset + size))
        payload = data[offset:offset + size]
        assert struct.unpack_from('<II', payload) == (size - 8, 2)
        assert payload[8:13] == b'\x1bLJ\x02\x02'
        result[key] = payload
    return result


def main():
    components = json.loads((ROOT / 'components.lock.json').read_text())
    with zipfile.ZipFile(sys.argv[1]) as package:
        expected = {f'data/{ARCHIVE}{s}' for s in ('', '.stream', '.gpu_resources')}
        expected |= {'manifest.json', 'thumbnail.png', 'VanillaPlusMegapack-manifest.json', 'VanillaPlusMegapack-README.txt'}
        assert len(package.namelist()) == len(expected) and set(package.namelist()) == expected
        manager = json.loads(package.read('manifest.json'))
        assert manager['Version'] == 1 and manager['Name'] == 'Vanilla Plus Megapack - v2' and manager['Guid'] == GUID
        assert len(manager['Options']) == 1 and manager['Options'][0]['Include'] == ['data']
        assert manager['IconPath'] == manager['Options'][0]['Image'] == 'thumbnail.png'
        png = package.read('thumbnail.png')
        assert png[:8] == b'\x89PNG\r\n\x1a\n'
        width, height = struct.unpack_from('>II', png, 16)
        assert width == height and width >= 512
        report = json.loads(package.read('VanillaPlusMegapack-manifest.json'))
        assert report['revision'] == REVISION and report['runtime_verified'] is False
        assert report['requires'][0]['revision'] == 'loader-v9'
        assert report['loader_bundled'] is False and report['boot_replaced'] is False
        assert len(report['components']) == 7
        for name, digest in report['files'].items():
            assert sha(package.read(name)) == digest
        payloads = resources(package.read('data/' + ARCHIVE))
        assert set(payloads) == {resource_hash(c['module']) for c in components} | {resource_hash(MODULE)}
        for component in components:
            assert sha(payloads[resource_hash(component['module'])]) == component['resource_sha256']
        assert payloads[resource_hash(MODULE)] == (BUILD / 'mod.lua.main').read_bytes()
        assert resource_hash('boot') not in payloads
        assert resource_hash('core/wwise/lua/wwise_flow_callbacks') not in payloads
        for suffix in ('.stream', '.gpu_resources'):
            assert package.read('data/' + ARCHIVE + suffix) == b''
        for name in package.namelist():
            data = package.read(name).lower()
            assert b'users\\' not in data and b'users/' not in data
    print('PASS: one Arsenal entry, square icon, eight resources, exact seven-release payloads, no boot or shared loader')


if __name__ == '__main__':
    main()
