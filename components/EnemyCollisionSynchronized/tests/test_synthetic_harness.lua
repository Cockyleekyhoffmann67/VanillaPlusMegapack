-- Harness self-tests. A hotspot number is only worth acting on when the scene
-- the mod ran against and the profiler that measured it are both trustworthy.
-- These assertions run before any optimization compares two revisions.
local source, tests = assert(arg[1]), assert(arg[2])
local ffi = require('ffi')
local M = dofile(source..'/corpse_data.lua')
local S = dofile(tests..'/synthetic_scene.lua')
local P = dofile(tests..'/synthetic_profiler.lua')
local production = dofile(source..'/windows_api.lua')()
local function api()
    return {pointer=production.pointer,address=production.address,distance=production.distance}
end
local function entry(M, name)
    for key, value in pairs(M.profiles) do if value.name==name then return key,value end end
    error('Unknown profile '..tostring(name))
end

-- 1. Catalog coverage. Every shipped profile must stage a scene the mod really
-- inspects and consumes. A profile the harness cannot build would silently drop
-- out of every measurement and hide its own hotspots.
local names = S.names(M)
assert(#names==21,'Catalog size changed: '..#names)
for _, name in ipairs(names) do
    local _, profile = entry(M, name)
    local a = api()
    local s = S.build(M, a, {profile=name,corpses=1,author_disabled=next(profile.disabled_main)~=nil})
    assert(s.controls.unit_count==1,'Scene did not stage exactly one inspected unit')
    for i=1,120 do
        s.controls.tick(i/30)
        assert(M.apply(a,s.game,s.exe,s.state),name..' apply failed')
    end
    assert(s.state.deep_inspections and s.state.deep_inspections>0,name..' was never inspected')
    assert(s.state.observed==1,name..' was never consumed')
    assert(not s.state.skipped,name..' retained a skip: '..tostring(s.state.last_skip))
    -- Scenes own a large arena; release each one before building the next.
    s = nil
    collectgarbage('collect')
end

-- 2. Region coverage. The profiler can only attribute a read when the scene
-- declared the structure it lives in. Names here are the vocabulary every
-- hotspot report uses, so a rename must fail loudly rather than degrade to
-- 'unknown'.
do
    local a = api()
    local s = S.build(M,a,{profile='Bile Titan',ragdolls=1,corpses=1})
    local seen = {}
    for _, region in ipairs(s.regions) do seen[region.name] = (seen[region.name] or 0)+1 end
    for _, required in ipairs({'game_image','exe_image','mission_mode','registry','generations','slots',
        'actortables','actor_pool','actor_rows','body_rows','physics_world','physics_vtable',
        'node_matrices','ragdoll_manager','entity_pointers','ragdoll_runtime','ragdoll_sync',
        'corpse_manager','corpse_runtime','corpse_sync','unit_object','actor_handles','entity_record'}) do
        assert(seen[required],'Scene region missing from the profiler vocabulary: '..required)
    end
    assert(seen.node_matrices==2,'One node matrix region per inspected unit expected')
    -- Every declared region must be a usable half-open numeric range.
    for _, region in ipairs(s.regions) do
        assert(type(region.from)=='number' and type(region.to)=='number' and region.to>region.from,
            'Malformed region '..region.name)
    end
end

-- 3. Classification. A read inside a declared structure must land in exactly
-- that class with exact byte accounting; anything else must report 'unknown'
-- rather than borrow a neighbouring class.
do
    local unregistered = ffi.new('uint8_t[64]')
    local a = api()
    local s = S.build(M,a,{profile='Bile Titan',corpses=1})
    local profiler = P.new(a,'test',{regions=s.regions})
    local unit = s.controls.units[1]
    local entity = s.controls.entities[unit]
    a.read(entity,24)
    assert(profiler.classes.entity_record.reads==1,'Entity record read was not classified')
    assert(profiler.classes.entity_record.bytes==24,'Entity record bytes are not exact')
    a.read(entity,24)
    assert(profiler.classes.entity_record.bytes==48,'Repeated reads must keep accumulating')
    a.read(unregistered,8)
    assert(profiler.classes.unknown.reads==1,'Undeclared memory must report as unknown')
    assert(profiler.classes.entity_record.reads==2,'Unknown memory leaked into a declared class')
    assert(profiler.sizes[24]==2 and profiler.sizes[8]==1,'Read size histogram is wrong')
    assert(profiler.reads==3 and profiler.bytes==24+24+8,'Total read accounting is wrong')
end

-- 4. Phase and unit attribution. Phase rows must stay exclusive while nested
-- scopes restore their caller, and per-enemy costs must be attributed to the
-- enemy the mod was inspecting.
do
    local a = api()
    local s = S.build(M,a,{profile='Bile Titan',corpses=1})
    local profiler = P.new(a,'test',{regions=s.regions})
    local state = s.state
    for i=1,40 do s.controls.tick(i/30);profiler.begin(state);M.apply(a,s.game,s.exe,state);profiler.finish(state) end
    assert(profiler.polls==40,'Polls were not counted')
    assert(profiler.rows.snapshot and profiler.rows.snapshot.reads>0,'Snapshot phase unmeasured')
    assert(profiler.rows.discovery and profiler.rows.discovery.calls>=40,'Discovery phase unmeasured')
    assert(profiler.rows.validation and profiler.rows.validation.reads>0,'Validation phase unmeasured')
    local total = 0
    for _, row in pairs(profiler.rows) do total = total+row.reads end
    assert(total==profiler.reads,'Phase reads must sum to the profiler total: '..total..' vs '..profiler.reads)
    local unit = s.controls.units[1]
    local enemy = profiler.enemies['Bile Titan']
    assert(enemy and enemy.inspections>0,'Enemy attribution missing')
    assert(enemy.bytes>0,'Enemy attribution counted no bytes')
end

-- 5. Pointer decode accounting. The mod decodes pointers far more often than it
-- reads, so a hotspot report that only counts reads cannot see that cost.
do
    local a = api()
    local s = S.build(M,a,{profile='Bile Titan',corpses=1})
    local profiler = P.new(a,'test',{regions=s.regions})
    for i=1,20 do s.controls.tick(i/30);profiler.begin(s.state);M.apply(a,s.game,s.exe,s.state);profiler.finish(s.state) end
    assert(profiler.pointer_decodes>0,'Pointer decodes were not counted')
end

-- 6. Allocation accounting. A change that leaves the read count untouched can
-- still make the frame stutter through garbage, so the harness must measure
-- allocation with the collector held, and the number must follow the workload.
do
    local function measure(corpses)
        local a = api()
        local s = S.build(M,a,{profile='Bile Titan',corpses=corpses})
        local profiler = P.new(a,'test',{regions=s.regions})
        local function work()
            for i=1,40 do
                s.controls.tick(i/30);profiler.begin(s.state)
                M.apply(a,s.game,s.exe,s.state);profiler.finish(s.state)
            end
        end
        profiler.hold_gc()
        local used = profiler.allocated_kb(work)
        profiler.release_gc()
        return used
    end
    local small, large = measure(1), measure(8)
    assert(small>0,'Allocation accounting measured nothing')
    assert(large>small,'A larger scene must allocate more than a smaller one: '..large..' vs '..small)
end

-- 7. Report determinism. Two identical scenarios must produce byte-identical
-- reports, otherwise no revision comparison can separate signal from noise.
do
    local function scenario()
        local a = api()
        local s = S.build(M,a,{profile='Charger tier 2',ragdolls=4,corpses=4,read_cost=0.000004})
        local profiler = P.new(a,'test',{regions=s.regions})
        for i=1,90 do s.controls.tick(i/30);profiler.begin(s.state);M.apply(a,s.game,s.exe,s.state);profiler.finish(s.state) end
        return profiler.report()
    end
    local first, second = scenario(), scenario()
    assert(first==second,'Synthetic reports are not reproducible')
    assert(first:find('class=entity_pointers',1,true),'Report omits the entity pointer class')
    assert(first:find('phase=snapshot',1,true),'Report omits phase rows')
end

-- 8. Bounded output. A long session must not grow the report or the held tables
-- without limit, and numeric identities must never reach the report text.
do
    local a = api()
    local s = S.build(M,a,{profile='Impaler',corpses=2})
    local profiler = P.new(a,'test',{regions=s.regions})
    local short
    for i=1,600 do
        s.controls.tick(i/30);profiler.begin(s.state);M.apply(a,s.game,s.exe,s.state);profiler.finish(s.state)
        if i==60 then short = profiler.report() end
    end
    local long = profiler.report()
    local function lines(text) local n=0 for _ in text:gmatch('\n') do n=n+1 end return n end
    assert(lines(long)-lines(short)<=4,'Report grows with session length')
    for key in pairs(profiler.classes) do assert(type(key)=='string','Class keys must stay symbolic') end
    local entity = s.controls.entities[s.controls.units[1]]
    assert(not long:find(tostring(api().address(entity)),1,true),'Report leaked a raw address')
    assert(profiler.poll_count==600,'Poll counter drifted')
end

-- 9. Production contract. The harness profiler must be installable in the mod's
-- own slot, so a measured scenario and the shipped telemetry agree.
do
    local a = api()
    local s = S.build(M,a,{profile='Bile Titan',ragdolls=2,corpses=2})
    local profiler = P.new(a,'v-synthetic',{regions=s.regions})
    a.profiler = profiler
    local start = profiler.update_started()
    for i=1,80 do s.controls.tick(i/30);profiler.begin(s.state);M.apply(a,s.game,s.exe,s.state);profiler.finish(s.state) end
    profiler.update_finished(start,true)
    local text = profiler.text(s.state)
    assert(type(text)=='string' and #text>0,'text() must return a report')
    assert(text:find('v-synthetic',1,true),'text() must name the revision it measured')
    assert(text:find('phase=snapshot',1,true),'text() must expose phase rows')
    assert(profiler.rows.snapshot.ms>0,'Wall time was not recorded for the shipped contract')
    assert(profiler.read_start and profiler.byte_start,'Loader accounting contract is missing')
    profiler.flush(s.state,true)
    local partial_ok, partial_text = pcall(profiler.text,{})
    assert(partial_ok and type(partial_text)=='string' and #partial_text>0,
        'text() must survive a partial state table')
end

-- 10. Failure isolation. A profiler must never turn a failed read into work the
-- mod would not otherwise do, and the mod must skip rather than mutate.
do
    local a = api()
    local s = S.build(M,a,{profile='Bile Titan',corpses=1,
        hostile={mode='nil',region='entity_pointers',after=0}})
    local profiler = P.new(a,'test',{regions=s.regions})
    s.controls.tick(1/30);profiler.begin(s.state)
    local ok = pcall(M.apply,a,s.game,s.exe,s.state)
    profiler.finish(s.state)
    assert(not ok,'A nil read must abort the poll instead of fabricating data')
    assert(s.commands.pose==0 and s.commands.disable==0,'Failed reads must not issue commands')
    assert(profiler.errors==0,'The profiler itself must not error')
    assert(profiler.reads>0,'The profiler must have observed the failing poll')
end
-- GC hold must stop collection, and nested measurement must not count the same
-- allocations twice. Use a controlled heap counter to make accounting exact.
do
    local real_gc, heap, stopped = collectgarbage, 100, false
    collectgarbage=function(command)
        if command=='count' then return heap end
        if command=='stop' then stopped=true end
        if command=='restart' then stopped=false end
    end
    local a={clock=function()return 0 end,read=function()return '' end}
    local profiler=P.new(a,'test')
    local ok,err=pcall(function()
        profiler.hold_gc()
        assert(stopped,'hold_gc did not stop the collector')
        assert(profiler.allocated_kb(function()heap=112 end)==12)
        heap=120
        profiler.release_gc()
        assert(not stopped,'release_gc did not restart the collector')
        assert(profiler.alloc_kb==20,'Allocation counted more than once')
    end)
    collectgarbage=real_gc
    assert(ok,err)
end

-- Snapshot sections exclude validation and discovery reads, and a new poll
-- must not attribute the idle time between polls to its first enemy.
do
    local now=0
    local a={clock=function()return now end,read=function()return 'x' end}
    local profiler=P.new(a,'test')
    for _,start in ipairs({0,10}) do
        now=start;profiler.begin({});profiler.phase('snapshot');profiler.detail('bodies')
        a.read(1,1);now=now+.001
        profiler.phase('validation');a.read(1,1)
        profiler.unit('test',start,0,{})
        profiler.finish({})
    end
    assert(profiler.sections.bodies.reads==2,'Non-snapshot reads leaked into a snapshot section')
    assert(math.abs(profiler.enemies.test.ms-2)<.00001,'Enemy timing includes inter-poll idle time')
end

-- Commands change future observations, and resetting a scene restores exactly
-- the original memory without changing the addresses used by guard batching.
do
    local a=api()
    local s=S.build(M,a,{profile='Bile Titan',corpses=1,read_cost=0})
    s.controls.displace_aux(s.controls.units[1],1)
    s.controls.tick(0);M.apply(a,s.game,s.exe,s.state)
    assert(s.commands.pose>0,'Repair setup issued no commands')
    local poses=s.commands.pose
    s.controls.tick(.1);M.apply(a,s.game,s.exe,s.state)
    assert(s.commands.pose==poses,'Already repaired actors were repaired again')
    s.controls.reset()
    assert(s.commands.pose==0,'Reset retained command counts')
    s.controls.tick(0);M.apply(a,s.game,s.exe,{native=s.state.native})
    assert(s.commands.pose==0,'Reset did not restore the aligned scene')
    local pool
    for _,r in ipairs(s.regions) do if r.name=='actor_pool' then pool=r end end
    local profiler=P.new(a,'test',{regions=s.regions})
    assert(s.classify(pool.from)=='actor_pool' and profiler.classify(pool.from)=='actor_pool',
        'Embedded actor pool was attributed to the surrounding executable')
end
do
    local a=api()
    local s=S.build(M,a,{profile='Impaler',corpses=1,read_cost=0})
    s.controls.tick(0);M.apply(a,s.game,s.exe,s.state)
    assert(s.commands.disable==3,'Impaler did not disable its three claws')
    s.controls.tick(.1);M.apply(a,s.game,s.exe,s.state)
    assert(s.commands.disable==3,'Disabled claws were commanded again')
    s.controls.reset()
    s.controls.tick(0);M.apply(a,s.game,s.exe,{native=s.state.native})
    assert(s.commands.disable==3,'Reset did not restore enabled claws')
end
print('PASS: catalog, regions, exclusive attribution, GC accounting, scene reset, native effects and failure isolation')
