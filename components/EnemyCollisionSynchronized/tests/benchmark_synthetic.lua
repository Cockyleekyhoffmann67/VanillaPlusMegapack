-- Synthetic hotspot benchmark for Enemy Collision Synchronized.
--
--   luajit tests/benchmark_synthetic.lua <src> <tests> [report-directory]
--
-- Every scenario runs against the synthetic scene in this process: no game
-- process, no game files and no native calls. Wall time comes from the Windows
-- performance counter; reads, bytes, pointer decodes and allocations are counted
-- per structure, so a hotspot is named rather than inferred.
--
-- Two measurement windows run per scenario at identical addresses. The first
-- holds the collector to attribute allocation; the second is the timed window.
-- Guard-batched byte counts depend on address adjacency, so compare revisions on
-- whole-scenario totals and decision counters, not on a single class.
local source, tests = assert(arg[1]), assert(arg[2])
local output = arg[3]
local ffi = require('ffi')
ffi.cdef('int QueryPerformanceCounter(void *); int QueryPerformanceFrequency(void *);')
local kernel = ffi.load('kernel32')
local frequency, counter = ffi.new('int64_t[1]'), ffi.new('int64_t[1]')
assert(kernel.QueryPerformanceFrequency(frequency)~=0)
local ticks = tonumber(frequency[0])
local function wall()
    kernel.QueryPerformanceCounter(counter)
    return tonumber(counter[0])/ticks
end
local M = dofile(source..'/corpse_data.lua')
local S = dofile(tests..'/synthetic_scene.lua')
local P = dofile(tests..'/synthetic_profiler.lua')
local production = dofile(source..'/windows_api.lua')()
local function api()
    return {pointer=production.pointer,address=production.address,distance=production.distance}
end
local WARMS, WINDOW, ALLOC_POLLS = 30, 120, 30
local ROSTER = {'Bile Titan','Impaler','Charger tier 2','Automaton assault walker','Illuminate tripod'}
-- Recorder snapshot time / read count includes Python decoding, allocations and
-- descheduling. Use it only as a workload model, not measured native read latency.
-- The shipped profiler's sampled_read_ms / sampled_reads measures actual reads.
local MODEL_READ_MS = 0.0158
-- Population sizes come from the ten recorded missions, not from guesses:
-- corpse peaks 48-106, ragdoll peaks 20-124, medians 34 and 24. The live_ group
-- runs at the assumed per-read cost to exercise the mod's 1 ms poll budget;
-- the open_ group disables that budget to price one
-- structure in isolation. See artifacts/ecs-hotspots/session-reduction.txt.

-- drive(scene,index) runs after the poll clock advances, so a scenario can stage
-- a repair burst or renewed corpse motion at a known point in the window.
local SCENARIOS = {
    {name='ship_empty',open=true,config={profile='Bile Titan'},
        note='no entities: fixed overhead only'},
    {name='open_living_256',open=true,config={living=256},
        note='living crowd: no corpse may be inspected'},
    {name='open_living_1500',open=true,config={living=1500},
        note='large living crowd: exposes scan growth with manager count'},
    {name='open_ragdoll_static_8',open=true,config={ragdolls=8},
        note='remote settled ragdolls on the arming path'},
    {name='open_ragdoll_moving_8',open=true,config={ragdolls=8},
        note='renewed motion after settling: expects verified stops',
        drive=function(scene,index)
            if index==WARMS+8 then
                for _,unit in ipairs(scene.controls.units) do scene.controls.move(unit,4) end
            end
        end},
    {name='open_corpse_8',open=true,config={corpses=8},
        note='aligned corpses: inspection without repair'},
    {name='open_corpse_repair_8',open=true,config={corpses=8},
        note='ongoing auxiliary repair churn',
        drive=function(scene,index)
            if index%5==0 then
                for _,unit in ipairs(scene.controls.units) do scene.controls.displace_aux(unit,index) end
            end
        end},
    {name='open_mixed_8',open=true,config={ragdolls=8,corpses=8},
        note='both managers under rotation'},
    {name='tripod_disabled_8',config={profile='Illuminate tripod',corpses=8,author_disabled=true},
        note='every main body authored disabled'},
    {name='walker_dynamic_8',config={profile='Automaton assault walker',corpses=8,
        author_disabled=true,dynamic_mains=true},
        note='declared dynamic main bodies alongside disabled hosts'},
    {name='stopped_8',config={ragdolls=8,stopped=8},
        note='engine already stopped every ragdoll'},
    {name='recycled_8',config={corpses=8,recycled=4},
        note='half the handles are stale and must be rejected'},
    {name='expired_pool',config={corpses=8,expired_pool=true},
        note='actor pool generation no longer matches'},
    {name='heterogeneous_10',config={profiles=ROSTER,corpses=10,author_disabled=true},
        note='mixed profiles inside one manager'},
    {name='open_crowd_and_corpses',open=true,config={living=1500,corpses=8},
        note='realistic worst case: crowd plus corpses'},
    {name='open_crowd_and_corpses_repair',open=true,config={living=1500,corpses=8},
        note='crowd plus corpses while repair churn continues',
        drive=function(scene,index)
            if index%5==0 then
                for _,unit in ipairs(scene.controls.units) do scene.controls.displace_aux(unit,index) end
            end
        end},
    {name='open_slow_reads_crowd',open=true,config={living=1500,corpses=8,
        region_cost={entity_pointers=0.00002,body_rows=0.000004}},
        note='expensive reads: proves the deadline still bounds one slice'},
    -- Assumed per-read cost; this models the deadline rather than reproducing
    -- live mission timing.
    {name='live_quiet',config={ragdolls=24,corpses=44,profiles=ROSTER},
        note='median recorded populations under the live read budget'},
    {name='live_mission',config={living=600,ragdolls=100,corpses=92,profiles=ROSTER},
        note='peak recorded populations under the live read budget'},
    {name='live_mission_repair',config={living=600,ragdolls=100,corpses=92,profiles=ROSTER},
        note='peak populations with repair churn under the live read budget',
        drive=function(scene,index)
            if index%5==0 then
                for _,unit in ipairs(scene.controls.units) do scene.controls.displace_aux(unit,index) end
            end
        end},
    {name='live_crowd_only',config={living=1200,profiles=ROSTER},
        note='crowd with nothing to repair under the live read budget'},
}

local function run_window(scene,target,profiler,state,count,drive,start)
    for i=1,count do
        local index = (start or 0)+i
        scene.controls.tick(index/30)
        if drive then drive(scene,index) end
        profiler.begin(state)
        local ok, message = pcall(M.apply,target,scene.game,scene.exe,state)
        profiler.finish(state)
        if not ok then return false,message end
    end
    return true
end
local function percentile(sorted,fraction)
    return sorted[math.max(1,math.ceil(#sorted*fraction))]
end
local function scene_shape(scene,corpse)
    local count = 0
    for _,unit in ipairs(scene.controls.units) do
        if scene.controls.is_corpse(unit)==corpse then count = count+1 end
    end
    return count
end
local function class_summary(profiler)
    local classes, sizes = {}, {}
    for class,row in pairs(profiler.classes) do
        classes[#classes+1]=string.format('%s reads=%d bytes=%d',class,row.reads,row.bytes)
    end
    for size,count in pairs(profiler.sizes) do
        if type(size)=='number' then sizes[#sizes+1]=string.format('%d:%d',size,count) end
    end
    table.sort(classes);table.sort(sizes)
    return table.concat(sizes,','),table.concat(classes,'\n')
end

io.stdout:setvbuf('no')
print('# Enemy Collision Synchronized synthetic benchmark; warmup='..WARMS..' window='..WINDOW)
print('scenario,units,corpses,ragdolls,mean_ms,p95_ms,max_ms,reads_per_poll,bytes_per_poll,'..
    'modeled_read_ms_per_poll,pointer_decodes_per_poll,alloc_kb_per_poll,inspected_per_poll,'..
    'validations_per_poll,native_per_poll')
local aggregate, failures = {}, {}
for _, scenario in ipairs(SCENARIOS) do
    collectgarbage('collect')
    -- `open` scenarios price one structure in isolation with the poll deadline
    -- effectively disabled; everything else runs at the assumed read cost.
    local config = scenario.config
    if scenario.open then
        config = {}
        for key, value in pairs(scenario.config) do config[key] = value end
        config.read_cost = 0
    end
    local scene = S.build(M,api(),config)
    local function prepare(clock)
        scene.controls.reset()
        local target=scene.attach(api())
        local warm_profiler=P.new(target,'warmup',{regions=scene.regions})
        local state={native=scene.state.native}
        local ok,message=run_window(scene,target,warm_profiler,state,WARMS,scenario.drive)
        assert(ok,scenario.name..' warmup: '..tostring(message))
        -- Retain warmed mod state, but start all measurement counters together.
        target=scene.attach(api())
        local profiler=P.new(target,'synthetic',{regions=scene.regions,clock=clock,max_units_hint=M.max_units})
        return target,profiler,state
    end
    -- 1. Allocation window: warmed mod with the collector held throughout.
    local alloc_profiler
    do
        local target,profiler,state=prepare()
        alloc_profiler=profiler
        alloc_profiler.hold_gc()
        local ok, message = run_window(scene,target,alloc_profiler,state,ALLOC_POLLS,scenario.drive,WARMS)
        alloc_profiler.release_gc()
        if not ok then failures[#failures+1]=scenario.name..' allocation window: '..tostring(message) end
    end
    -- 2. Timed window: reset scene, identical warmup and addresses, real counter.
    local target,profiler,state=prepare(wall)
    local times, inspected, commands = {}, 0, 0
    for i=1,WINDOW do
        scene.controls.tick((WARMS+i)/30)
        if scenario.drive then scenario.drive(scene,WARMS+i) end
        local native_before = scene.commands.pose+scene.commands.disable+
            scene.commands.stop_sync+scene.commands.request_completion
        local before = wall()
        profiler.begin(state)
        local applied, err = pcall(M.apply,target,scene.game,scene.exe,state)
        profiler.finish(state)
        times[#times+1] = (wall()-before)*1000
        inspected = inspected+profiler.last_inspected
        commands = commands+(scene.commands.pose+scene.commands.disable+
            scene.commands.stop_sync+scene.commands.request_completion-native_before)
        if not applied then
            failures[#failures+1]=scenario.name..' poll '..i..': '..tostring(err)
            break
        end
    end
    table.sort(times)
    local total = 0
    for i=1,#times do total=total+times[i] end
    print(string.format('%s,%d,%d,%d,%.4f,%.4f,%.4f,%.1f,%.1f,%.3f,%.1f,%.3f,%.2f,%.1f,%.2f',
        scenario.name,#scene.controls.units,
        scene_shape(scene,true),scene_shape(scene,false),
        total/#times,percentile(times,.95),times[#times],
        profiler.reads/profiler.polls,profiler.bytes/profiler.polls,
        profiler.reads/profiler.polls*MODEL_READ_MS,
        profiler.pointer_decodes/profiler.polls,alloc_profiler.alloc_kb/ALLOC_POLLS,
        inspected/#times,(profiler.rows.validation.reads or 0)/profiler.polls,commands/#times))
    assert(profiler.polls==#times,'Read counters and wall times used different windows')
    if scenario.name=='open_ragdoll_moving_8' then
        assert(state.fling_stops_verified==8,'Renewed-motion scenario did not stop all eight ragdolls')
    end
    if scenario.note then print('# '..scenario.name..': '..scenario.note) end
    for class,row in pairs(profiler.classes) do
        local entry = aggregate[class]
        if not entry then entry={reads=0,bytes=0};aggregate[class]=entry end
        entry.reads = entry.reads+row.reads/profiler.polls
        entry.bytes = entry.bytes+row.bytes/profiler.polls
    end
    if output then
        local sizes, classes = class_summary(alloc_profiler)
        local file = assert(io.open(output..'/'..scenario.name..'-synthetic.txt','w'))
        file:write(profiler.report())
        file:write('alloc_window read_sizes='..sizes..'\n')
        file:write(string.format('alloc_window polls=%d alloc_kb=%.3f\n',alloc_profiler.polls,alloc_profiler.alloc_kb))
        file:write(classes..'\n')
        file:close()
    end
end
print('')
print('# Hotspot ranking sums the per-poll cost of every scenario above.')
local ranked = {}
for class,entry in pairs(aggregate) do ranked[#ranked+1]={class=class,reads=entry.reads,bytes=entry.bytes} end
table.sort(ranked,function(a,b)
    if a.bytes==b.bytes then return a.class<b.class end
    return a.bytes>b.bytes
end)
for rank,row in ipairs(ranked) do
    print(string.format('HOTSPOT rank=%d class=%s bytes_per_poll=%.0f reads_per_poll=%.1f',
        rank,row.class,row.bytes,row.reads))
end
print('')
if #failures>0 then
    for _,message in ipairs(failures) do print('FAIL '..message) end
    print('VERDICT scenarios='..#SCENARIOS..' failures='..#failures)
    os.exit(1)
end
print(string.format('VERDICT scenarios=%d failures=0 window=%d warmup=%d',#SCENARIOS,WINDOW,WARMS))
