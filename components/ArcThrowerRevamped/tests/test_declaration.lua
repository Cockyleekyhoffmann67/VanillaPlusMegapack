-- Loads the shipped addon under a stub loader and checks its contract.
local path = arg[1] or '../src/arc_thrower_auto.lua'
local file = assert(io.open(path, 'rb'))
local body = file:read('*a')
file:close()

assert(body:match('^[^\r\n]*') == '-- HD2-Addon: mods/cowboybingus/arc_thrower_auto',
       'addon declaration must be the first line')
assert(body:find("open_log('ArcThrowerAuto.log')", 1, true),
       'addon must keep its log resource name')
assert(not body:find('VirtualProtect', 1, true) or
       body:find('VirtualProtectEx', 1, true), 'unexpected protection call')

local writes = {}
local loader = {api = 1, open_log = function(name)
    return {write = function(_, text) writes[#writes + 1] = text end,
            flush = function() end}
end}
local env = setmetatable({CowboyBingusModLoader = loader, require = require},
                         {__index = _G})
env._G = env
env.update = function() return 1, nil, 3 end

local chunk = assert(loadfile(path))
debug.setfenv(chunk, env)
chunk()
assert(type(env.update) == 'function', 'update callback must stay installed')
assert(#writes > 0 and writes[1]:find('Arc Thrower Revamped', 1, true),
       'addon must report its initialisation')
print('arc thrower addon: declaration, log resource and callbacks verified')
