# v3

- Updates Sentry Aim Retention from v1.0.1 to v1.0.7.
- Reduces pauses between nearby targets and requests a new target search sooner after a target is lost.
- Stops shots when the target is lost, aim is stale, or solid terrain blocks the target point; preserves normal firing through destructible cover.
- Fixes an aim-hold restoration bug that could freeze sentry rotation.

# v2

- Includes Enemy Collision Synchronized v2.6 as the seventh gameplay component.
- Requires the separately installed Bingus Shared Loader v9 or newer.
- Supports overlapping standalone installations with one active copy of each gameplay module.
