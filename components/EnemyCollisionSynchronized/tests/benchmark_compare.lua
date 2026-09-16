-- Off-game ABBA comparison in identical resident memory. Native commands are
-- stubs; completed work is equal with only the benchmark's budgets disabled.
local baseline,candidate,fixtures=assert(arg[1]),assert(arg[2]),assert(arg[3])
local ffi=require('ffi')
local modules,apis,profilers={},{},{}
for i,path in ipairs({baseline,candidate})do
    modules[i]=dofile(path..'/corpse_data.lua')
    modules[i].max_units=math.huge;modules[i].max_entities=math.huge;modules[i].budget_seconds=math.huge
    apis[i]=dofile(path..'/windows_api.lua')()
    profilers[i]=dofile(path..'/profiler.lua')
end
local file=assert(io.open(fixtures..'/perf_scene.lua','rb'));local scene_text=file:read('*a');file:close()
io.stdout:setvbuf('no')
print('round,version,scene,mean_ms,p95_ms,max_ms,reads_per_poll,pointer_decodes_per_poll,units_per_poll,commands_per_poll')
for _,config in ipairs({{'living1500',1500,0,0,'Bile Titan'},
    {'titan_corpses8',0,0,8,'Bile Titan'}, {'titan_ragdolls8',0,8,0,'Bile Titan'},
    {'charger_corpses8',0,0,8,'Charger tier 2'}, {'spewer_mixed8',0,2,6,'Bile Spewer tier 2'},
    {'impaler_corpses8',0,0,8,'Impaler'}, {'titan_repair_burst',0,0,1,'Bile Titan',true}})do
    collectgarbage('collect')
    local scene=assert(loadstring(scene_text:gsub("value.name == 'Bile Titan'","value.name == '"..config[5].."'")))()
    local _,g,e,initial,f=scene(modules[1],apis[1],config[2],config[3],config[4]);apis[2].time=apis[1].time
    if config[6] then
        for _,unit in ipairs(f.units)do for i=16,#f.bodies[unit]do f.matrix(f.bodies[unit][i],2)end end
    end
    local original_read,original_pointer={apis[1].read,apis[2].read},{apis[1].pointer,apis[2].pointer}
    local expected_reads,expected_commands
    for round,index in ipairs({1,2,2,1})do
        collectgarbage('collect')
        local api,M=apis[index],modules[index];local reads,pointers,commands=0,0,0
        api.read=function(at,size)reads=reads+1;return original_read[index](at,size)end
        api.pointer=function(...)pointers=pointers+1;return original_pointer[index](...)end
        local p=profilers[index].new(api,'benchmark');api.profiler=p
        local state={native={}}
        for _,name in ipairs({'pose','disable','stop_sync','request_completion'})do
            state.native[name]=function()commands=commands+1 end
        end
        local function apply(i)
            f.tick(i/30);p.begin(state);assert(M.apply(api,g,e,state));p.finish(state)
            assert(state.observed==config[3]+config[4] and not state.skipped and not state.retries)
        end
        for i=1,30 do apply(i)end
        reads,pointers,commands=0,0,0;local times,total={},0
        for i=31,130 do
            local start=api.clock();apply(i);local ms=(api.clock()-start)*1000
            times[#times+1]=ms;total=total+ms
        end
        expected_reads=expected_reads or reads;expected_commands=expected_commands or commands
        assert(reads==expected_reads and commands==expected_commands,'Benchmark work changed across variants')
        table.sort(times)
        print(string.format('%d,%s,%s,%.6f,%.6f,%.6f,%.2f,%.2f,%d,%.2f',round,index==1 and 'baseline' or 'candidate',config[1],
            total/#times,times[95],times[100],reads/#times,pointers/#times,state.observed,commands/#times))
        api.read=original_read[index];api.pointer=original_pointer[index];api.profiler=nil
    end
end
