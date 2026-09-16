# v8

- Adds an optional Rows package with the verified static constellation forecast. All other bundled payloads match the standard v8 package exactly.
- Updates Enemy Collision Synchronized to v2.9 with lower inspection overhead and expanded performance diagnostics.
- Preserves corpse-check frequency, repair guards, enemy coverage and stabilization behavior.
- Retains all other bundled gameplay payloads and compatibility with the separate Bingus Shared Loader v12 or newer.
- Keeps duplicate-install protection when standalone packages are also enabled.

# v7

- Adds Know Your Constellation v3.12 for local enemy forecasts on mission previews and briefing.
- Requires the separate Bingus Shared Loader v12 or newer.
- Preserves the eight existing component payloads byte for byte.
- Keeps one-copy startup when standalone packages are also installed.
- Individual component behavior is unchanged. The combined bundle has offline validation, with full in-game bundle validation pending.

# v6

- Adds Controllable Hover Pack v1 with native landing assistance.
- Requires Bingus Shared Loader v11 or newer.
- Retains published Enemy Collision Synchronized v2.7 and the other seven-component release payloads unchanged.
- Preserves one-copy startup when standalone mods are also installed.

# v4

- Updated Enemy Collision Synchronized to v2.7.
- Reduced corpse-inspection overhead and spread checks across updates during crowded fights.
- Added automatic collision performance logging while retaining existing repairs and ragdoll safeguards.
- Preserved duplicate-install protection and compatibility with Bingus Shared Loader v9 or newer.

# v3

- Updates Sentry Aim Retention from v1.0.1 to v1.0.7.
- Reduces pauses between nearby targets and requests a new target search sooner after a target is lost.
- Stops shots when the target is lost, aim is stale, or solid terrain blocks the target point. preserves normal firing through destructible cover.
- Fixes an aim-hold restoration bug that could freeze sentry rotation.

# v2

- Includes Enemy Collision Synchronized v2.6.
- Requires the separately installed Bingus Shared Loader v9 or newer.
- Supports overlapping standalone installations with one active copy of each gameplay module.
