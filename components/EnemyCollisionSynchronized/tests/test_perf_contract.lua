-- Behavioural contracts that must survive any performance work on Enemy
-- Collision Synchronized, plus the edge cases the synthetic scene can stage but
-- the recorded snapshots cannot: expired handles, recycled units, hostile reads,
-- disabled hosts, stopped ragdolls, mission exit and heterogeneous managers.
local source, tests = assert(arg[1]), assert(arg[2])
local M = dofile(source..'/corpse_data.lua')
local S = dofile(tests..'/synthetic_scene.lua')
local P = dofile(tests..'/synthetic_profiler.lua')
local production = dofile(source..'/windows_api.lua')()
local function api()
    return {pointer=production.pointer,address=production.address,distance=production.distance}
end
local function run(s,a,polls,from,profiler)
    for i=(from or 0)+1,(from or 0)+polls do
        s.controls.tick(i/30)
        if profiler then profiler.begin(s.state) end
        local ok = M.apply(a,s.game,s.exe,s.state)
        if profiler then profiler.finish(s.state) end
        assert(ok,'apply failed on poll '..i)
    end
end

-- 1. A living crowd must never pay inspection reads. Only the rotation window
-- may be scanned, and no Havok body may be touched without a corpse.
do
    local a = api()
    local s = S.build(M,a,{profile='Bile Titan',living=1500})
    local profiler = P.new(a,'test',{regions=s.regions})
    for i=1,40 do s.controls.tick(i/30);profiler.begin(s.state);M.apply(a,s.game,s.exe,s.state);profiler.finish(s.state) end
    assert((s.state.deep_inspections or 0)==0 and s.state.observed==0,'A living crowd was inspected')
    assert(s.state.budget_yields>=40,'The rotation budget never yielded')
    assert(s.commands.pose==0 and s.commands.stop_sync==0,'A living crowd received commands')
    assert(profiler.classes.body_rows==nil,'A living crowd read Havok bodies')
    assert(profiler.classes.node_matrices==nil,'A living crowd read skeletons')
end

-- 2. Manager fairness. A crowded corpse manager must not starve the ragdoll
-- manager or the tail of its own rotation: every staged unit is eventually seen.
do
    local a = api()
    local s = S.build(M,a,{profile='Impaler',ragdolls=64,corpses=64})
    local profiler = P.new(a,'test',{regions=s.regions})
    local seen = {}
    local plan = M.plan
    M.plan = function(unit) seen[unit.unit] = true;return plan(unit) end
    for i=1,900 do
        s.controls.tick(i/30);profiler.begin(s.state);M.apply(a,s.game,s.exe,s.state);profiler.finish(s.state)
        if i>1 then
            local previous = profiler.polls>1 and profiler.last_inspected or 0
            assert(previous<=M.max_units,'Deep inspections exceeded the per-poll unit budget: '..previous)
        end
    end
    M.plan = plan
    for _, unit in ipairs(s.controls.units) do
        assert(seen[unit],'Unit '..unit..' starved out of the rotation')
    end
    assert(s.state.observed>0,'Manager fairness check consumed nothing')
end

-- 3. Recycled unit handles must be rejected without touching the new unit's
-- storage, and a recycled handle must not inherit the previous repair history.
do
    local a = api()
    local s = S.build(M,a,{profile='Bile Titan',corpses=2})
    local target = s.controls.units[1]
    run(s,a,90)
    assert(s.state.observed>0,'Baseline scene consumed nothing')
    local accepted = s.state.accepted_units
    s.controls.recycle(target)
    run(s,a,60,90)
    assert(s.commands.pose==0 and s.commands.disable==0,'A recycled handle was mutated')
    assert(s.state.skipped,'A recycled handle was not skipped')
    assert(s.state.accepted_units>accepted,'The healthy unit stopped being consumed')
end

-- 4. Authored disabled hosts. Tripod corpses disable every main body; the mod
-- must not read a disabled Havok slot and must not repair anything but the
-- auxiliary actors the profile still allows.
do
    local a = api()
    local s = S.build(M,a,{profile='Illuminate tripod',corpses=2,author_disabled=true})
    local profiler = P.new(a,'test',{regions=s.regions})
    for i=1,120 do s.controls.tick(i/30);profiler.begin(s.state);M.apply(a,s.game,s.exe,s.state);profiler.finish(s.state) end
    assert(s.state.observed>0,'Disabled-host scene consumed nothing')
    assert((s.state.realignments or 0)==0,'A disabled host was repaired')
    -- A tripod authors 10 disabled main bodies and 37 auxiliary actors, so a full
    -- inspection may touch at most the 37 enabled bodies. Reading 47 would mean
    -- the disabled Havok slots were touched.
    local bodies = profiler.classes.body_rows
    local tripod = profiler.enemies['Illuminate tripod']
    assert(bodies and tripod,'Disabled hosts still need auxiliaries inspected')
    assert(tripod.inspections>0 and profiler.polls>0,'Disabled hosts were never inspected')
    assert(bodies.reads<=37*tripod.inspections,
        'Disabled main bodies were read: '..bodies.reads..' > '..37*tripod.inspections)
end

-- 5. Stopped ragdolls. A unit the engine already stopped must cost snapshot work
-- once and then no native command, however long the mission runs.
do
    local a = api()
    local s = S.build(M,a,{profile='Charger tier 2',ragdolls=8,stopped=8})
    run(s,a,120)
    assert(s.commands.stop_sync==0 and s.commands.request_completion==0,'A stopped ragdoll was commanded')
    assert(s.commands.pose==0,'A stopped ragdoll was posed')
end

-- 6. Hostile reads outside a unit inspection. A manager-level read that fails
-- must abort the whole poll for a retry, retain no partial unit and issue no
-- command; the next healthy poll must fully recover.
do
    local a = api()
    local s = S.build(M,a,{profile='Bile Titan',corpses=2,
        hostile={mode='nil',region='entity_pointers',after=0}})
    for i=1,20 do
        s.controls.tick(i/30)
        local ok = pcall(M.apply,a,s.game,s.exe,s.state)
        assert(not ok,'A failed manager read must abort the poll for a retry')
        assert((s.state.observed or 0)==0,'An aborted poll consumed a unit')
        assert(s.commands.pose==0 and s.commands.stop_sync==0,'An aborted poll issued a command')
    end
    s.controls.accept_reads()
    run(s,a,60,20)
    assert(s.state.observed>0,'A healthy poll after a failure was not consumed')
end

-- 7. Hostile reads inside a unit inspection. The unit must be skipped instead of
-- half-built, the poll must still succeed, and no command may be issued.
do
    for _, mode in ipairs({'nil','short'}) do
        local a = api()
        local s = S.build(M,a,{profile='Bile Titan',corpses=2,
            hostile={mode=mode,region='actor_rows',after=0}})
        for i=1,20 do
            s.controls.tick(i/30)
            local ok = pcall(M.apply,a,s.game,s.exe,s.state)
            assert(ok,'A failed unit inspection must not abort the poll: '..mode)
            assert((s.state.observed or 0)==0,'A half-built unit was consumed: '..mode)
            assert(s.state.skipped,'A failed inspection was not counted as a skip: '..mode)
            assert(s.commands.pose==0 and s.commands.disable==0,'A failed inspection issued a command: '..mode)
        end
        s.controls.accept_reads()
        run(s,a,60,20)
        assert(s.state.observed>0,'Recovery after '..mode..' never consumed a unit')
    end
end

-- 8. Identity races between native commands. Once an entity changes, the rest
-- of the planned writes for that unit must be abandoned.
do
    local a = api()
    local s = S.build(M,a,{profile='Bile Titan',corpses=1})
    local unit = s.controls.units[1]
    s.controls.displace_aux(unit,1)
    local issued = 0
    s.state.native.pose = function() issued = issued+1;s.controls.recycle(unit) end
    run(s,a,4)
    assert(issued==1,'Identity change did not cancel the remaining commands: '..issued)
end

-- 9. Mission exit. Leaving the mission must clear every retained identity and
-- stop reading entity storage until a mission flag returns.
do
    local a = api()
    local s = S.build(M,a,{profile='Bile Titan',ragdolls=8,corpses=8})
    run(s,a,120)
    assert(s.state.fling_history and next(s.state.fling_history),'Fling history was never built')
    local stopped = s.commands.pose+s.commands.stop_sync+s.commands.disable
    s.controls.leave_mission()
    local profiler = P.new(a,'test',{regions=s.regions})
    for i=121,200 do s.controls.tick(i/30);profiler.begin(s.state);M.apply(a,s.game,s.exe,s.state);profiler.finish(s.state) end
    assert(not next(s.state.fling_history),'Fling history survived mission exit')
    assert(not next(s.state.fling_stopped),'Stop bookkeeping survived mission exit')
    assert(not next(s.state.cursors),'Rotation cursors survived mission exit')
    assert(profiler.classes.entity_pointers==nil,'Entity storage was read outside a mission')
    assert(profiler.classes.body_rows==nil,'Havok bodies were read outside a mission')
    assert(s.commands.pose+s.commands.stop_sync+s.commands.disable==stopped,
        'Native commands were issued outside a mission')
end

-- 10. Heterogeneous managers. Corpses of different profiles inside one manager
-- must each be measured against their own skeleton, not the first unit's.
do
    local a = api()
    local s = S.build(M,a,{profile='Bile Titan',profiles={'Bile Titan','Impaler','Charger tier 2',
        'Automaton assault walker','Illuminate tripod'},corpses=10,author_disabled=true})
    local profiler = P.new(a,'test',{regions=s.regions})
    run(s,a,400,0,profiler)
    assert(s.state.observed>0,'Heterogeneous scene consumed nothing')
    assert(s.state.skipped==nil,'A heterogeneous manager produced a skip: '..tostring(s.state.last_skip))
    assert(profiler.enemies['Bile Titan'] and profiler.enemies['Impaler'],'Not every profile was inspected')
end

-- 11. Determinism. Two measurement windows over one scene share every address,
-- so the guard batcher must group identically and every counter must agree
-- exactly. Two freshly built scenes are allowed to differ in batched bytes
-- because the allocator moves their addresses, but the mod's decisions and its
-- per-enemy inspection counts must still be identical, otherwise a before/after
-- comparison measures placement instead of a change.
do
    local shape = {profile='Bile Spewer tier 2',ragdolls=6,corpses=6}
    local s = S.build(M,api(),shape)
    local function window()
        local target = s.attach(api())
        local profiler = P.new(target,'test',{regions=s.regions})
        local state = {native=s.state.native}
        for i=1,150 do
            s.controls.tick(i/30);profiler.begin(state)
            M.apply(target,s.game,s.exe,state);profiler.finish(state)
        end
        return profiler, state
    end
    local first, first_state = window()
    local second, second_state = window()
    local counted = 0
    for name, row in pairs(first.classes) do
        counted = counted+1
        assert(second.classes[name],'Class '..name..' disappeared at identical addresses')
        assert(second.classes[name].reads==row.reads and second.classes[name].bytes==row.bytes,
            'Class '..name..' is not reproducible at identical addresses')
    end
    local other = 0
    for _ in pairs(second.classes) do other = other+1 end
    assert(counted==other,'Identical addresses produced a different class vocabulary')
    assert(first.reads==second.reads and first.bytes==second.bytes,
        'Identical addresses produced different work')
    assert(first_state.accepted_units==second_state.accepted_units,'Decisions differ across windows')
    local fresh = S.build(M,api(),shape)
    local fresh_target = fresh.attach(api())
    local fresh_profiler = P.new(fresh_target,'test',{regions=fresh.regions})
    local fresh_state = {native=fresh.state.native}
    for i=1,150 do
        fresh.controls.tick(i/30);fresh_profiler.begin(fresh_state)
        M.apply(fresh_target,fresh.game,fresh.exe,fresh_state);fresh_profiler.finish(fresh_state)
    end
    assert(fresh_state.accepted_units==first_state.accepted_units,'A fresh scene decided differently')
    assert(fresh_profiler.polls==first.polls,'A fresh scene ran a different poll count')
    for name, row in pairs(first.enemies) do
        assert(fresh_profiler.enemies[name] and fresh_profiler.enemies[name].inspections==row.inspections,
            'Enemy '..name..' inspections differ across scenes')
    end
    assert((fresh_state.realignments or 0)==(first_state.realignments or 0),'Repairs differ across scenes')
end

-- 12. Equal work. Optimization must not buy speed by inspecting fewer enemies.
-- The read budget may shape one poll, but over a full rotation every inspected
-- unit must still be fully validated before its commands are issued.
do
    local a = api()
    local s = S.build(M,a,{profile='Bile Titan',ragdolls=16,corpses=16})
    local profiler = P.new(a,'test',{regions=s.regions})
    run(s,a,300,0,profiler)
    local validations = profiler.rows.validation.reads
    assert(profiler.rows.snapshot.reads>0,'Snapshot work was not measured')
    assert(validations>profiler.polls,'Every consumed unit must be revalidated before commands')
    print(string.format('EQUAL_WORK units=%d validations_per_poll=%.2f body_rows_per_poll=%.2f',
        s.controls.unit_count,validations/profiler.polls,
        (profiler.classes.body_rows and profiler.classes.body_rows.reads or 0)/profiler.polls))
end
print('PASS: living-crowd isolation, manager fairness, recycled handles, disabled hosts, stopped ragdolls, hostile and short reads, between-command races, mission exit, heterogeneous managers, determinism and equal work')
