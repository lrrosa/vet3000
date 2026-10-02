local m=manager.machine
local mem=m.devices[":maincpu"].spaces.program
local sym={}
for line in io.lines(os.getenv("VET_TEST_SYM")) do
    local n,v=line:match("^(%S+)%s+equ%s+(%d+)")
    if n then sym[n]=tonumber(v) end
end
local ranking_takeover=os.getenv("VET_ATTRACT_RANKING")=="1"
local frame,cycles,old_mode,cpu_start,rank_start,takeover=0,0,0,0,0,nil
local baseline,stages={},{}
local paddle_positions={}
local space=m.ioport.ports[":ROW3"]:field(128)
local vram
for _,dev in pairs(m.devices) do if dev.shortname=="tms9128" then vram=dev.spaces["vram"] end end
local function row_text(row)
    local t={}
    for col=0,31 do t[#t+1]=string.char(vram:read_u8(sym.NAMES+row*32+col)+sym.FONT_FIRST) end
    return table.concat(t)
end
local failed=false
attract_test_frame=emu.add_machine_frame_notifier(function()
    if failed then return end
    local ok,err=pcall(function()
        frame=frame+1
        if frame==90 then
            for a=sym.HS,sym.HS_END-1 do baseline[a]=mem:read_u8(a) end
        end
        if frame<=90 then return end
        local mode=mem:read_u8(sym.attract_mode)
        if not takeover and mode~=old_mode then
            if mode==1 then
                assert(mem:read_u8(sym.scroll_done)~=0,"CPU started before the scroller ended")
                if cycles==0 then
                    local minimum=(sym.SCROLL_WRAP-sym.SCROLL_TEXT)*2
                    assert(frame>=minimum,"title duration shortened")
                end
                cpu_start=frame; stages={}; paddle_positions={}
            elseif mode==2 then
                local count=0; for _ in pairs(stages) do count=count+1 end
                assert(count>=2,"not enough varied CPU courts")
                count=0; for _ in pairs(paddle_positions) do count=count+1 end
                assert(count>10,"CPU paddle did not play")
                rank_start=frame
            elseif mode==0 and old_mode==2 then
                assert(frame-rank_start>=470,"ranking shown too briefly")
                cycles=cycles+1
                for a,b in pairs(baseline) do assert(mem:read_u8(a)==b,"CPU changed saved scores") end
            end
            old_mode=mode
        end
        if mode==2 and frame==rank_start+10 then
            -- ranking: only how to play, without the CPU-game caption
            assert(row_text(21):find("ESPA#O: JOGAR",1,true),"ranking hint missing")
            assert(not row_text(21):find("DEMONSTRA",1,true),"CPU caption on the ranking")
        end
        if mode==1 and frame-cpu_start>20 then
            stages[mem:read_u8(sym.level)]=true
            paddle_positions[mem:read_u8(sym.paddle_x)]=true
        end
        if cycles==1 and not takeover and ((not ranking_takeover and mode==1 and frame-cpu_start>100)
                or (ranking_takeover and mode==2 and frame-rank_start>30)) then
            space:set_value(1); takeover=frame
        end
        if takeover and frame==takeover+4 then space:clear_value() end
        if takeover and frame==takeover+30 then
            assert(mode==0,"SPACE did not stop attract mode")
            assert(mem:read_u8(sym.level)==0,"takeover did not start phase 01")
            assert(mem:read_u8(sym.lives)==4,"takeover life count")
            assert(mem:read_u16(sym.score)==0 and mem:read_u8(sym.score+2)==0,"CPU score carried over")
            for a,b in pairs(baseline) do assert(mem:read_u8(a)==b,"saved scores changed") end
            print("PASS: full attract cycle and "..(ranking_takeover and "ranking" or "CPU").." takeover")
            m:exit()
        end
    end)
    if not ok then failed=true; print("FAIL: frame "..frame..": "..tostring(err)); m:exit() end
end)
