# v15

- Adds Arc Thrower Revamped v1 as a twelfth independent option: hold the fire
  button and the ARC-3 Arc Thrower keeps firing through its own charge cycle.
- Arc Thrower Revamped keeps stock charge times, cadence, damage and arc
  settings, follows a second thrower called down mid-mission, and shares a
  re-entry guard with its standalone package.
- Keeps the other eleven pinned gameplay implementations unchanged; standard and
  Rows packages carry identical components.
- Requires Bingus Shared Loader v15 or newer. Arc Thrower Revamped is loaded
  through declared-entry discovery because the shared loader's built-in
  registry predates it.

# v14

- Updates the bundled Clickable Scrollbars to v2.2.
- Scales the scrollbar geometry to the display height, so 1080p, 1440p and 4K screens keep the same relative behaviour.
- Keeps the verified 1440p values as the reference and follows a resolution or monitor change on the next click.
- Finds a thumb taller than the capture strip with one doubled retry pass instead of ignoring the click.
- Keeps the other ten pinned gameplay implementations unchanged; standard and Rows packages carry identical components.
- Requires Bingus Shared Loader v15 or newer.

# v13

- Adds Clickable Scrollbars v2.1 as an eleventh independent option.
- Lets a track click move the item-list scrollbar thumb to the pointer, and a press on the thumb drag it with the mouse.
- Keeps the other ten pinned gameplay implementations unchanged; standard and Rows packages carry identical components.
- Requires Bingus Shared Loader v15 or newer.

# v12

- Updates the bundled Armory Preview Cache to v18.
- Refreshes a weapon's preview when the game re-renders it, so changing a pattern or attachment updates the thumbnail.
- Retires the previous preview immediately after a weapon is re-configured instead of waiting for the whole category to rebuild.
- Keeps the other nine pinned gameplay implementations unchanged; standard and Rows packages carry identical components.
- Requires Bingus Shared Loader v15 or newer.

# v11

- Adds plaintext discovery entries for the pack identity and all ten components.
- Preserves original module names, arguments and the exact pinned gameplay bytecode.
- Requires Bingus Shared Loader v15 or newer, retaining API 1 and both manager GUIDs.
- Standard and Rows keep ten independent options.
- Rollback: replace this package with v10.1, review options, then Purge / Deploy. Loader v15 supports the previous pack.

# v10.1

- Updates all ten bundled mods to their latest versions.
- Includes the hover-pack recovery and mission-type fixes for hover, reinforcement placement, vaulting and shallow-water diving.
- Updates both the standard and Rows packages; independent mod options are preserved.
- Moves logs to `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs`.
- Requires Bingus Shared Loader v14 for the shared log folder.
