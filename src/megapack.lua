-- Bundle identity only. Bingus Shared Loader starts the gameplay resources
-- through its normal registry, exactly once, preserving their existing order.
-- Do not require them here: that would duplicate startup and failure handling.
local loader = assert(rawget(_G, 'CowboyBingusModLoader'), 'Bingus Shared Loader is required')
assert(type(loader.api) == 'number' and loader.api >= 1, 'Shared loader API 1 is required')
assert(type(loader.version) == 'number' and loader.version >= 14, 'Bingus Shared Loader loader-v13 is required')
local pack = {
    name = 'Vanilla Plus Megapack',
    revision = 'megapack-v10',
    -- Available component inventory; installed choices are in loader.modules.
    modules = {
        'mods/cowboybingus/better_stratagem_bounce',
        'mods/cowboybingus/hellpod_steering_unlocked',
        'mods/cowboybingus/reinforcement_beacon_fix_data',
        'mods/cowboybingus/consistent_vaulting',
        'mods/cowboybingus/shallow_water_dive',
        'mods/cowboybingus/sentry_aim_retention',
        'mods/cowboybingus/corpse_collision_repair',
        'mods/cowboybingus/hover_pack_cancel',
        'mods/cowboybingus/enemy_intelligence',
        'mods/cowboybingus/armory_preview_cache',
    },
}
loader.megapack = pack
return pack
