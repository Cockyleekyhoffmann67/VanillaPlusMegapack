# v11 discovery migration

The standard and Rows packages require Bingus Shared Loader v15 or newer, with
API 1 unchanged. The pack identity requires internal loader version 16. Both
manager GUIDs and all ten option folders retain their previous identities.

Each public Lua resource now begins with `-- HD2-Addon: <resource name>`. The
rest is a plaintext wrapper containing the original compiled implementation as
three-digit decimal escapes. It uses `loadstring` and forwards `...`, preserving
the module's incoming arguments and every return value. No implementation path
is renamed and no additional resource or startup replacement is introduced.

The builder first recreates and hash-checks each pinned compiled gameplay
resource. `build/<component>/mod.lua.main` remains that original artifact;
`entry.lua.main` is its deployed discovery entry. Final ZIP tests reconstruct
the embedded bytecode and prove it is identical. Entry-envelope hashes change;
gameplay source and implementation hashes do not. The pack identity changes
only its revision and minimum loader version.

Existing public resource names preserve standalone override behavior. A higher
priority old compiled standalone can hide a pack declaration; Loader v15's
legacy list still loads that resource. When the declared pack entry wins, it
executes the same implementation under the same public name. Existing per-mod
guards prevent callback stacking even if require caching is bypassed.

Tests exercise normal startup and a compiled copy of Loader v15 with its legacy
registry removed. The latter scans the actual per-option archives, proving that
the pack identity and components can start through declarations alone. Both
paths cover all 1024 selections, absent loader, missing modules and load errors.

Upgrade with the game closed: retain Loader v15, replace v10.1 with the v11
standard or Rows package, review options, then Purge / Deploy. Keep only one
pack variant enabled. Disabling a pack option does not disable a separate
standalone copy of that feature.

Rollback: replace v11 with the retained v10.1 ZIP, restore your selections and
Purge / Deploy. Loader v15 supports that older pack. No saved data or component
configuration is migrated. The loader's preliminary user-reported in-game
success does not establish validation of this newly packaged Megapack.

## Offline validation on 2026-09-18

Both variants passed 54 upstream gameplay/cross-module test processes, 2,140
normal-loader scenarios, 2,140 discovery-only scenarios and 2,048 duplicate
installation/priority combinations. Finished-ZIP checks covered all 1,024 option
selections and proved every embedded gameplay implementation matches its pin.
Direct comparisons against the retained v10.1 ZIPs confirmed unchanged manager
GUIDs, option names/order/folders, public resource IDs and all ten gameplay
implementations. Only the forecast entry differs between standard and Rows.

Arsenal's existing backend fixture passed all 1,024 subsets for each final ZIP.
HD2MM's pinned source backend (commit
`21838c31a77a6b459da93d224e1827f1f3998f91`) also passed all subsets, including
profile round trips. Both verified deployed bytes, purge, re-enable and removal
using isolated folders. Results are in `build/v11-arsenal`, `build/v11-hd2mm`
and their `build/rows` equivalents. No live profile or game directory was used.

Final ZIP SHA-256 values:

- Standard: `87D24EAAAF9BEBA4AC4CF896F7E7D4C920B7195F7BEE34AA46D2DE164116AA16`
- Rows: `4F9B475669C4037F0F2B50288983924005D3AF49CA304DF68D1BB258BDBFCE79`

The source/ZIP audit also passed. In-game validation of these two ZIPs remains
pending; their provenance retains `runtime_verified: false`.
