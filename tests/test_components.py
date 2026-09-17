"""Exercise the vendored upstream gameplay tests in isolated LuaJIT processes."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from build import ROOT, BUILD, LUA, run, sha


def main():
    build = Path(sys.argv[1]) if len(sys.argv)>1 else BUILD
    mods = ROOT / 'components'
    bounce = mods / 'BetterStratagemBounce'
    steering = mods / 'HellpodSteeringUnlocked'
    digest = sha(LUA.read_bytes())
    commands = [
        [bounce / 'tests/test_archive.lua', bounce / 'src', build / 'BetterStratagemBounce/mod.ljbc', digest],
        [steering / 'tests/test_data.lua', steering / 'src', build / 'HellpodSteeringUnlocked', digest, bounce / 'src'],
    ]
    for order in ('hellpod-ball', 'ball-hellpod'):
        commands.append([bounce / 'tests/test_windows_interop.lua', bounce / 'src', steering / 'src', order,
                         build / 'BetterStratagemBounce/mod.ljbc', digest])
    for order in ('hellpod-first', 'bounce-first'):
        commands.append([steering / 'tests/test_api_coexistence.lua', steering / 'src', bounce / 'src', order])
    suites = {
        'KnowYourConstellation': [(n,None) for n in ('test_resolve','test_panel','test_install','test_mission','test_heavy','test_presentation','test_rows')],
        'ControllableHoverPack': [(n,None) for n in ('test_cancel','test_snapshot','test_settings','test_loader','test_replay')],
        'ReinforcementBeaconsFixed': [('test_data', 'solo_scenarios'), ('test_startup', None)],
        'ConsistentVaulting': [(n, None) for n in ('test_vault', 'test_geometry', 'test_slope', 'test_loader')],
        'ShallowWaterDiving': [('test_dive', None), ('test_loader', None)],
        'SentryAimRetention': [('test_aim', 'gatling_target_loss'), ('test_firing', 'firing_sweeps'),
                               ('test_loader', None), ('test_snapshot', None), ('test_windows_api', None)],
    }
    for slug, suite in suites.items():
        root = mods / slug
        for test, fixture in suite:
            command = [root / 'tests' / (test + '.lua'), root / 'src']
            if fixture:
                command.append(root / 'tests' / (fixture + '.lua'))
            commands.append(command)
    corpse = mods / 'EnemyCollisionSynchronized'
    print(run([sys.executable, corpse / 'tests/test_profiles.py']).strip())
    for name in ('repair', 'snapshot', 'fling', 'settlement', 'completion', 'loader'):
        commands.append([corpse / 'tests' / ('test_' + name + '.lua'), corpse / 'src'])
    commands.append([corpse / 'tests/test_performance.lua', corpse / 'src', corpse / 'tests'])
    commands.append([corpse / 'tests/test_profiler.lua', corpse / 'src'])
    commands.append([corpse / 'tests/test_profiler_detail.lua', corpse / 'src'])
    commands.append([corpse / 'tests/test_profiler_behavior.lua', corpse / 'src', corpse / 'tests'])
    commands.append([corpse / 'tests/test_metadata_cache.lua', corpse / 'src', corpse / 'tests'])
    for name in ['test_policy', 'test_install', 'test_images', 'test_partial_images', 'test_image_keys', 'test_v10_images', 'test_v10_policy', 'test_prewarm_recency', 'test_material_synthetic']:
        commands.append([mods/'ArmoryPreviewCache/tests'/(name+'.lua'),mods/'ArmoryPreviewCache'])
    for command in commands:
        result = run([LUA, *command])
        print(result.strip())
    print(f'PASS: {len(commands)} upstream gameplay and cross-module test processes')


if __name__ == '__main__':
    main()
