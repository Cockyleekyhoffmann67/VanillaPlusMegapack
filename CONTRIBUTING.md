# Build from source

Use Windows x64, Python 3.10+ and the LuaJIT commit pinned in `dependencies.json`, built using `msvcbuild.bat nogc64` from an x64 Visual Studio Native Tools prompt. Set `HD2_LUAJIT` to the resulting executable.

```powershell
$env:HD2_LUAJIT = 'D:\tools\LuaJIT\src\luajit.exe'
python -B scripts/build.py
```

The output is the workspace root `releases/Vanilla-Plus-Megapack-v7.zip` (or local `releases/` when built standalone). Generated wrappers, component bytecode, checksums and test reports stay in ignored `build/`. The build does not install mods, access a live game process, or launch the game. Gameplay sources are vendored. Build Bingus Shared Loader first; its compiled fixtures are used by the startup integration gate. For standalone checkouts, set `HD2_SHARED_LOADER_BUILD` to the loader build directory. The compiled modules retain their existing runtime game-fingerprint checks.

`components/` contains the reviewed Lua source and test snapshots. `components.lock.json` pins their revisions, source hashes and original standalone resource hashes. The builder recreates the original wrappers and requires every compiled gameplay resource to match its original release byte for byte. A changed source or mismatched compiler fails the build. The pack adds only `src/megapack.lua`, its bundle identity resource.

Git attributes preserve component snapshot bytes, including upstream line endings, so the source hashes remain stable after cloning on Windows or Linux.

The normal build runs all 38 upstream gameplay/interoperability test processes and package checks. Those tests use synthetic data in the test process. They do not test live gameplay.

To test the actual compiled loader with the pack, first build Bingus Shared Loader v12, then run:

```powershell
& $env:HD2_LUAJIT tests/test_loader.lua build D:\source\BingusSharedLoader\build
```

For future component updates, import the reviewed source/tests, rebuild the standalone mod, then update its lock entry from that verified release. Do not update hashes merely to bypass a mismatch. Keep the manager GUID and resource names stable. Never commit build outputs, compiler binaries, private recordings or game files. The Enemy Collision Synchronized component uses the public synthetic suite; raw recorded snapshots are excluded. No repository-wide license has been selected.
