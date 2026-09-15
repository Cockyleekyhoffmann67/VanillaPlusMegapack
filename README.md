![Vanilla Plus Megapack](assets/banner.png)

# Vanilla Plus Megapack

All CowboyBingus Helldivers 2 gameplay mods in one install. Better stratagem placement, hellpod steering, reinforcement placement, vaulting, shallow-water diving, sentry aim retention and synchronized enemy corpse collision.

**Requires the separately built Bingus Shared Loader v9 or newer.** Install two ZIPs: `Vanilla-Plus-Megapack-v2.zip` and `Bingus-Shared-Loader-v9.zip`. Mod managers do not install the dependency automatically.

[Download v2](https://github.com/CowboyBingus/VanillaPlusMegapack/releases/tag/v2). Download [Bingus Shared Loader](https://github.com/CowboyBingus/BingusSharedLoader/releases/latest) from its own repository.

## Install with Arsenal or HD2MM

1. Close Helldivers 2. Use one mod manager.
2. Replace any previous loader entry with v9 or newer. You can leave current standalone gameplay packages installed.
3. Import `Vanilla-Plus-Megapack-v2.zip` and `Bingus-Shared-Loader-v9.zip`, then enable both.
4. With Arsenal's default priority, put **Bingus Shared Loader last**, at the bottom. If first-mod priority is enabled, put the loader first.
5. **Purge → Deploy**, then launch the game normally.

The pack enables all mods together. To choose individual features, disable the pack and use the standalone packages with the loader instead. Current standalone copies can remain enabled: overlapping gameplay resources run once, and their callbacks do not stack. If the versions differ, your mod manager selects the winning version. Give the pack winning priority over standalone copies to use its bundled versions.

## Included in v2

| Mod | Version | Effect |
| --- | --- | --- |
| [Better Stratagem Bounce](https://github.com/CowboyBingus/BetterStratagemBounce) | v15 | Allows stratagem balls to stick on more usable surfaces. |
| [Hellpod Steering Unlocked](https://github.com/CowboyBingus/HellpodSteeringUnlocked) | v7 | Removes the hellpod steering restriction near high ground. |
| [Reinforcement Beacons Fixed](https://github.com/CowboyBingus/ReinforcementBeaconsFixed) | v4 | Centers queued reinforcements over their beacon or solo anchor. |
| [Consistent Vaulting](https://github.com/CowboyBingus/ConsistentVaulting) | v8 | Adds fresh obstacle checks, higher ledge detection and bounded steep-surface support. |
| [Shallow Water Diving](https://github.com/CowboyBingus/ShallowWaterDiving) | v3 | Preserves the standing water reference during a local airborne dive. |
| [Sentry Aim Retention](components/SentryAimRetention/src) | v1.0.0 | Retains sentry aim through target loss and pauses broad Gatling/machine-gun firing sweeps. |
| [Enemy Collision Synchronized](components/EnemyCollisionSynchronized/src) | v2.6 | Aligns displaced corpse collision and curbs renewed movement after large remote corpses settle. |

All gameplay components are pinned to the source and compiled-resource hashes in `components.lock.json`. Third-party HUD mods and the reserved, unreleased Wide Angle Stratagems module are not included. The shared loader remains a separate dependency with its own repository and updates.

Supported game: Steam build 24826606 / EXE 1.8.45317.0. Each bundled mod retains its behavior and compatibility checks.

## Compatibility and updates

The pack preserves all gameplay resource names and bytecode exactly. It contains no shared startup loader, `boot` replacement or Wwise callback replacement. Existing HUD+ and supported HUD Ballistic Trajectory Overlay compatibility is handled by Bingus Shared Loader. Give the loader winning priority over the supported overlay as described in its instructions.

Replace the megapack ZIP to update its bundled gameplay versions. Updating an individual mod repository does not silently change this pinned pack. The loader can be updated separately.

Check `%LOCALAPPDATA%/BingusSharedLoader.log` for `mods/cowboybingus/vanilla_plus_megapack: loaded` and the gameplay module entries. Each gameplay mod retains its own existing logs. For removal, disable the pack and Purge / Deploy; keep the loader enabled if other dependent mods remain.

[Build from source](CONTRIBUTING.md) · [Technical details](docs/TECHNICAL.md) · [Release notes](docs/RELEASE_NOTES.md) · [Third-party notices](THIRD_PARTY.md) · [Artwork and prompts](assets/ARTWORK.md)

**AI disclosure:** GPT-6 Astra assisted with implementation, tests, documentation and artwork.
