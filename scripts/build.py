"""Build all pinned gameplay resources into one independently installable ZIP."""
import json
import os
from pathlib import Path
import struct
import subprocess
import sys

sys.dont_write_bytecode = True
from archive import ARCHIVE, LUA, EXE_SHA, GAME_DLL_SHA, make_archive, resource_hash, sha
from package import package_release

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
MODULE = 'mods/cowboybingus/vanilla_plus_megapack'
REVISION = 'megapack-v7'
GUID = '876060ae-0640-4ac5-95b6-ec7c9a0567d3'


def run(args):
    env = dict(os.environ, LUA_PATH=str(LUA.parent / '?.lua') + ';;')
    result = subprocess.run(list(map(str, args)), capture_output=True, text=True, env=env)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout


def compile_resource(source, directory):
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / 'mod.wrapper.lua'
    path.write_text(source, encoding='utf-8', newline='\n')
    run([LUA, '-bsdW', path, directory / 'mod.ljbc'])
    bytecode = (directory / 'mod.ljbc').read_bytes()
    if bytecode[:5] != b'\x1bLJ\x02\x02':
        raise ValueError('Use the pinned LuaJIT build in non-GC64 mode')
    resource = struct.pack('<II', len(bytecode), 2) + bytecode
    (directory / 'mod.lua.main').write_bytes(resource)
    return resource


def build_component(component):
    root = ROOT / 'components' / component['slug']
    for relative, expected in component['source_sha256'].items():
        if sha((root / relative).read_bytes()) != expected:
            raise ValueError('Pinned source changed: ' + component['slug'] + '/' + relative)
    if component['slug'] == 'KnowYourConstellation':
        import importlib.util
        spec = importlib.util.spec_from_file_location('constellation_module', root / 'scripts/module.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        payload = compile_resource(module.wrapper(root, GAME_DLL_SHA, EXE_SHA), BUILD / component['slug'])
        if sha(payload) != component['resource_sha256']:
            raise ValueError('Constellation runtime differs from the tested standalone release')
        return payload
    if component['slug'] == 'ControllableHoverPack':
        source = ''
        for variable, filename in [('create_api','windows_api.lua'),('policy','cancel.lua'),('settings','settings.lua'),('patch','hover_data.lua'),('install','archive_loader.lua')]:
            source += f'local {variable}=(function()\n{(root / "src" / filename).read_text()}\nend)()\n'
        source += 'patch.policy=policy;patch.settings=settings\n'
        source += f"install(create_api,patch,{{revision='v1',game_sha256='{GAME_DLL_SHA}',exe_sha256='{EXE_SHA}'}})\n"
        payload = compile_resource(source, BUILD / component['slug'])
        if sha(payload) != component['resource_sha256']:
            raise ValueError('Hover resource differs from verified standalone release')
        return payload
    parts = [('create_api', 'windows_api.lua'), ('patch', component['patch'])]
    vaulting = component['slug'] == 'ConsistentVaulting'
    if vaulting:
        parts.append(('assistance', 'slope_assist.lua'))
    collision = component['slug'] == 'EnemyCollisionSynchronized'
    if collision:
        parts.append(('profiler', 'profiler.lua'))
    parts.append(('install_loader', 'archive_loader.lua'))
    source = ''
    for variable, filename in parts:
        source += f'local {variable} = (function()\n{(root / "src" / filename).read_text(encoding="utf-8")}\nend)()\n'
    if vaulting:
        source += 'patch.assistance = assistance\nassistance.candidate = patch.assist_candidate\n'
    if collision:
        source += 'patch.profiler = profiler\n'
    source += f"install_loader(create_api, patch, {{revision = '{component['revision']}', "
    source += f"exe_sha256 = '{EXE_SHA}', game_sha256 = '{GAME_DLL_SHA}'" + '})\n'
    payload = compile_resource(source, BUILD / component['slug'])
    if sha(payload) != component['resource_sha256']:
        raise ValueError('Gameplay bytecode differs from pinned release: ' + component['slug'])
    return payload


def main():
    components = json.loads((ROOT / 'components.lock.json').read_text(encoding='utf-8'))
    if not components or len({c['module'] for c in components}) != len(components):
        raise ValueError('Expected distinct gameplay components')
    resources = {resource_hash(c['module']): build_component(c) for c in components}
    resources[resource_hash(MODULE)] = compile_resource(
        (ROOT / 'src/megapack.lua').read_text(encoding='utf-8'), BUILD)
    tests = run([sys.executable, ROOT / 'tests/test_components.py'])
    loader_build = Path(os.environ.get('HD2_SHARED_LOADER_BUILD', ROOT.parent / 'BingusSharedLoader/build'))
    tests += run([LUA, ROOT / 'tests/test_loader.lua', BUILD, loader_build])
    duplicate_args = [value for c in components for value in (c['module'], c['slug'])]
    tests += run([LUA, ROOT / 'tests/test_duplicates.lua', ROOT, BUILD, loader_build, *duplicate_args])
    for suffix, data in [('', make_archive(resources)), ('.stream', b''), ('.gpu_resources', b'')]:
        (BUILD / (ARCHIVE + suffix)).write_bytes(data)
    files = {f'data/{ARCHIVE}{s}': f'build/{ARCHIVE}{s}' for s in ('', '.stream', '.gpu_resources')}
    report = {
        'name': 'Vanilla Plus Megapack', 'slug': 'VanillaPlusMegapack', 'revision': REVISION, 'guid': GUID,
        'description': 'All CowboyBingus gameplay mods in one package: Better Stratagem Bounce, Hellpod Steering Unlocked, Reinforcement Beacons Fixed, Consistent Vaulting, Shallow Water Diving, Sentry Aim Retention, Enemy Collision Synchronized, Controllable Hover Pack and Know Your Constellation. Requires the separate Bingus Shared Loader v12 or newer. Current individual copies can remain installed; give the pack winning priority over them to use its bundled versions. Enable the pack and loader, then Purge / Deploy. With default Arsenal priority put the loader last.',
        'requires': [{'name': 'Bingus Shared Loader', 'guid': '612eaf70-d682-43c7-9efd-16dcc695f977', 'api': 1, 'revision': 'loader-v12'}],
        'game_exe_sha256': EXE_SHA, 'game_dll_sha256': GAME_DLL_SHA,
        'deployment_files': files, 'files': {p: sha((ROOT / p).read_bytes()) for p in files.values()},
        'runtime_verified': False, 'boot_replaced': False, 'loader_bundled': False,
        'components': [{k: c[k] for k in ('name', 'slug', 'revision', 'module', 'resource_sha256')} for c in components],
        'resource_sha256': {f'{key:016x}': sha(value) for key, value in sorted(resources.items())},
    }
    release = package_release(ROOT, BUILD, report)
    tests += run([sys.executable, ROOT / 'tests/test_package.py', release])
    report['offline_tests'] = tests.strip()
    report['release_sha256'] = sha(release.read_bytes())
    (BUILD / 'build-report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    (BUILD / 'offline-tests.txt').write_text(tests, encoding='utf-8')
    print(tests.strip())
    print('Built ' + str(release) + '; gameplay resources match all pinned releases. Live validation pending.')


if __name__ == '__main__':
    main()
