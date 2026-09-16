# Bundle contract

One manager GUID (`876060ae-0640-4ac5-95b6-ec7c9a0567d3`) and one option deploy one archive triplet: `data/9ba626afa44a3aa3.patch_0`, its empty `.stream`, and its empty `.gpu_resources` companions. Arsenal renumbers the archive on deployment through its normal backend.

The archive contains the stable gameplay resources listed in `components.lock.json`, plus `mods/cowboybingus/vanilla_plus_megapack`. Gameplay resource bytes must match the original standalone release hashes. Packing changes neither implementation nor per-mod state guards, API checks, logging or update wrappers.

Loader v11 registers the megapack identity before the existing gameplay entries. The identity publishes the name, revision and component inventory to `CowboyBingusModLoader.megapack`. It does not install another update wrapper or recursively start components. The shared coordinator continues to check and require each gameplay resource exactly once, in the existing order, with lookup/load failure isolation. A failed identity does not prevent gameplay entries or the optional overlay from being attempted.

The pack deliberately does not own `boot` or `core/wwise/lua/wwise_flow_callbacks`. The latter belongs to the separately installed loader. Earlier loader registries may start whichever bundled gameplay names they recognize, but cannot report the megapack identity; only loader v11 or newer is supported for this package.

The standalone packages overlap the pack at their corresponding resource IDs. Identical revisions have identical bytes. Each resource resolves once, and each gameplay entry point claims a global state before installing callbacks. Re-entering an entry point preserves that state and does not wrap callbacks again. Mixed revisions follow manager priority; give the pack winning priority to select its bundled versions. Legacy packages that replace startup scripts still require the loader migration described in the loader instructions. This is not a runtime mechanism for selecting optional features.

Source and compiled-resource hash checks, upstream synthetic tests, strict archive/manager checks and compiled startup integration provide offline evidence. They do not establish live frame timing, native gameplay correctness, or multiplayer compatibility. Supported build fingerprints remain those embedded by each component: Steam 24826606 / EXE 1.8.45317.0.
