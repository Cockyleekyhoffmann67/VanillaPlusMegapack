"""Exercise the vendored upstream gameplay tests in isolated LuaJIT processes."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from build import ROOT, BUILD, LUA, run, sha


def main():
    mods = ROOT / 'components'
    bounce = mods / 'BetterStratagemBounce'
    steering = mods / 'HellpodSteeringUnlocked'
    digest = sha(LUA.read_bytes())
    commands = [
        [bounce / 'tests/test_archive.lua', bounce / 'src', BUILD / 'BetterStratagemBounce/mod.ljbc', digest],
        [steering / 'tests/test_data.lua', steering / 'src', BUILD / 'HellpodSteeringUnlocked', digest, bounce / 'src'],
    ]
    for order in ('hellpod-ball', 'ball-hellpod'):
        commands.append([bounce / 'tests/test_windows_interop.lua', bounce / 'src', steering / 'src', order,
                         BUILD / 'BetterStratagemBounce/mod.ljbc', digest])
    for order in ('hellpod-first', 'bounce-first'):
        commands.append([steering / 'tests/test_api_coexistence.lua', steering / 'src', bounce / 'src', order])
    suites = {
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
    for command in commands:
        result = run([LUA, *command])
        print(result.strip())
    print(f'PASS: {len(commands)} upstream gameplay and cross-module test processes')


if __name__ == '__main__':
    main()
