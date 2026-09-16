-- Run real compiled bundle and loader in an isolated, non-game environment.
local build, loader = assert(arg[1]), assert(arg[2])
local pack = 'mods/cowboybingus/vanilla_plus_megapack'
local wwise = 'core/wwise/lua/wwise_flow_callbacks'
local names = {pack, 'mods/cowboybingus/better_stratagem_bounce',
    'mods/cowboybingus/hellpod_steering_unlocked', 'mods/cowboybingus/reinforcement_beacon_fix_data',
    'mods/cowboybingus/consistent_vaulting', 'mods/cowboybingus/shallow_water_dive',
    'mods/cowboybingus/sentry_aim_retention', 'mods/cowboybingus/corpse_collision_repair', 'mods/cowboybingus/hover_pack_cancel'}
local folders = {'', 'BetterStratagemBounce', 'HellpodSteeringUnlocked', 'ReinforcementBeaconsFixed',
    'ConsistentVaulting', 'ShallowWaterDiving', 'SentryAimRetention', 'EnemyCollisionSynchronized', 'ControllableHoverPack'}
local function read(path)
    local file = assert(io.open(path, 'rb'))
    local bytes = file:read('*a'); file:close(); return bytes
end
local sources = {}
for i, name in ipairs(names) do sources[name] = read(build .. '/' .. folders[i] .. '/mod.lua.main'):sub(9) end
local cases = 0
for _, installed_loader in ipairs({false, true}) do
  for _, installed_pack in ipairs({false, true}) do
    for failure = 0, #names * 2 do
        local env = {}; for key, value in pairs(_G) do env[key] = value end
        env._G, env.print = env, function() end
        env.os = {getenv = function() end, clock = os.clock}
        env.io = {open = function() return nil end}
        local available, count, loaded = {}, {}, {}
        for i, name in ipairs(names) do available[name] = installed_pack and failure ~= i end
        env.stingray = {Application = {build = function() return 'release' end,
            can_get = function(kind, name) assert(kind == 'lua'); return available[name] or false end}}
        local function execute(bytes)
            return setfenv(assert(loadstring(bytes)), env)()
        end
        env.loadstring = function(bytes, name)
            local chunk, reason = loadstring(bytes, name)
            if chunk then setfenv(chunk, env) end
            return chunk, reason
        end
        env.require = function(name)
            if loaded[name] ~= nil then return loaded[name] end
            if name == 'ffi' or name == 'bit' then return require(name) end
            if name == 'core/wwise/lua/wwise_visualization' or name == 'core/wwise/lua/wwise_bank_reference' then return {} end
            if name == wwise then
                return execute(read(loader .. (installed_loader and '/callbacks.ljbc' or '/vanilla-callbacks.ljbc')))
            end
            assert(available[name], 'Missing resource reached require')
            count[name] = (count[name] or 0) + 1
            if name == names[failure - #names] then error('injected load failure') end
            loaded[name] = execute(assert(sources[name], name)) or true
            return loaded[name]
        end
        execute(read(loader .. '/vanilla-boot.ljbc'))
        local updates = 0
        env.update = function(dt) assert(dt == 0.1); updates = updates + 1; return 1, nil, 3 end
        env.shutdown = function() return 'shutdown', nil, 7 end
        env.init()
        if installed_loader then
            assert(env.CowboyBingusModLoader.version >= 12 and env.CowboyBingusModLoader.api == 1)
            execute(read(loader .. '/callbacks.ljbc'))
            for i, name in ipairs(names) do
                assert((count[name] or 0) == (available[name] and 1 or 0), name)
                local status = env.CowboyBingusModLoader.modules[name]
                if not available[name] then assert(status == 'not installed')
                elseif failure == i + #names then assert(status:find('load failed:', 1, true))
                else assert(status == 'loaded', name .. ': ' .. status) end
            end
            local identity = env.CowboyBingusModLoader.megapack
            if installed_pack and failure ~= 1 and failure ~= #names + 1 then
                assert(identity.name == 'Vanilla Plus Megapack' and identity.revision == 'megapack-v6')
                assert(#identity.modules == #names - 1)
                for i = 2, #names do assert(identity.modules[i-1] == names[i]) end
            else assert(identity == nil) end
        else
            assert(env.CowboyBingusModLoader == nil and next(count) == nil)
        end
        local a, b, c = env.update(0.1)
        assert(a == 1 and b == nil and c == 3 and updates == 1)
        assert(select('#', env.update(0.1)) == 3 and updates == 2)
        local x, y, z = env.shutdown()
        assert(x == 'shutdown' and y == nil and z == 7)
        cases = cases + 1
    end
  end
end
print('PASS: ' .. cases .. ' compiled bundle/loader scenarios; missing/failing components isolated, one startup, callbacks preserved, no activation without loader')
