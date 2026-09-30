-- Exercise the actual menu/input flow, firmware return, and two process boots.
local m = manager.machine
local mem = m.devices[":maincpu"].spaces.program
local sym = {}
for line in io.lines(os.getenv("VET_TEST_SYM")) do
    local n,v = line:match("^(%S+)%s+equ%s+(%d+)")
    if n then sym[n]=tonumber(v) end
end
local readback = os.getenv("VET_READBACK") == "1"
local frame, held, failed = 0, {}, false
local saw_laser = false
local min_stack = 0x200
breakout_stack_tap=mem:install_write_tap(0x190,0x1ff,"stack_guard",function(a,data)
    local s=m.devices[":maincpu"].state.S.value
    min_stack=math.min(min_stack,s)
end)
local function key(row, mask)
    local f=m.ioport.ports[":ROW"..row]:field(mask)
    f:set_value(1); held[#held+1]=f
end
local function check_scores()
    assert(mem:read_u16(sym.HS)==0x4232,"record signature lost")
    assert(mem:read_u16(sym.HS_DATA)==0x1234 and mem:read_u8(sym.HS_DATA+2)==0x50,"score lost")
    for i,c in ipairs({65,66,67}) do assert(mem:read_u8(sym.HS_DATA+2+i)==c,"initials lost") end
end
local function check_titles()
    for a=0xa0,0x18f do assert(mem:read_u8(a)==((a%15)+1)*16,"title attributes changed") end
    for a=0x200,0x1fff do assert(mem:read_u8(a)==0x41+a%26,"title text changed") end
end
local function snap(name)
    m.screens[":screen"]:snapshot(os.getenv("VET_SNAP_DIR").."/"..name..".png")
end
local actions = {
    [80]=function() key(3,0x80) end, -- title: play
    [350]=function() key(1,4) end, -- A directly
    [360]=function() key(7,128) end, -- B directly
    [370]=function() key(7,4) end, -- C directly
    [400]=function() key(4,64) end, -- RETURN confirms ABC
    [420]=function() key(3,0x80) end, -- return to title
    [440]=function() key(3,8) end, -- firmware
    [600]=function() key(3,0x80) end, -- dismiss firmware title / editor
    [720]=function() key(1,8); key(3,8) end, -- SHIFT+EXT MODE
    [860]=function() key(3,0x80) end,
    [1190]=function() key(3,0x80) end,
    [1410]=function() key(3,0x80) end,
}
breakout_persist_frame=emu.add_machine_frame_notifier(function()
    if failed then return end
    local ok,err=pcall(function()
        frame=frame+1
        if frame%10==4 then for _,f in ipairs(held) do f:clear_value() end; held={} end
        if readback then
            if frame==90 then check_scores(); check_titles(); print("PASS: SRAM second process boot"); m:exit() end
            return
        end
        if frame==1 then
            for i=1,5 do mem:write_u8(0x2f+i,("POWER"):byte(i)) end
            for a=0xa0,0x18f do mem:write_u8(a,((a%15)+1)*16) end
            for a=0x200,0x1fff do mem:write_u8(a,0x41+a%26) end
        end
        if actions[frame] then actions[frame]() end
        if frame==115 then
            assert(mem:read_u8(sym.lives)==4,"game did not start")
            assert(mem:read_u16(sym.ARMOR)~=0,"armor not initialized")
            snap("breakout_game")
        end
        if frame>=130 and frame<=136 then
            mem:write_u16(sym.score,0x1234); mem:write_u8(sym.score+2,0x50)
            if frame==130 then mem:write_u8(sym.lives,1) end
            if mem:read_u8(sym.lives)>0 then
                mem:write_u8(sym.ball_state,1)
                mem:write_u16(sym.ball_y,0xc500); mem:write_u16(sym.ball_dy,0x100)
                mem:write_u16(sym.ball_dx,0)
            end
        end
        if frame==340 then snap("breakout_initials") end
        if frame==415 then check_scores(); check_titles(); snap("breakout_scores") end
        if frame==680 then
            assert(m.devices[":maincpu"].state.PC.value>=0xc000,"not in firmware")
            check_scores(); check_titles()
        end
        if frame==850 then
            assert(m.devices[":maincpu"].state.PC.value<0x8000,"did not return to demo")
            check_scores(); check_titles()
            assert(min_stack>=sym.HS_END,"stack entered record storage")
            print(string.format("Lowest observed stack: $%04X (scores end at $%04X)",min_stack,sym.HS_END-1))
        end
        if frame==900 or frame==1040 then
            mem:write_u8(sym.level,frame==900 and 6 or 18)
            mem:write_u8(sym.bricks_left,0)
        end
        if frame==1030 then
            assert(mem:read_u8(sym.level)==7,"phase 8 transition failed")
            snap("arkanoid_phase08")
        end
        if frame==1170 then
            assert(mem:read_u8(sym.level)==19,"phase 20 transition failed")
            snap("arkanoid_phase20")
        end
        if frame==1180 then
            mem:write_u8(sym.power_kind,6); mem:write_u8(sym.power_x,120)
            mem:write_u8(sym.power_y,165); mem:write_u8(sym.power_clock,1)
        end
        if frame>=1191 and frame<=1210 and mem:read_u8(sym.shot_active)==1 then saw_laser=true end
        if frame==1210 then
            assert(mem:read_u8(sym.laser)==1,"laser capsule not caught")
            assert(saw_laser,"SPACE did not fire laser")
            snap("arkanoid_laser")
        end
        if frame==1250 then
            mem:write_u8(sym.level,31); mem:write_u8(sym.bricks_left,0)
        end
        if frame==1380 then
            assert(mem:read_u8(sym.level)==32,"boss arena not reached")
            assert(mem:read_u8(sym.bricks_left)==24,"boss energy not initialized")
            snap("arkanoid_boss")
        end
        if frame==1520 then snap("arkanoid_boss_fight") end
        if frame>=1600 and frame<=1605 and mem:read_u8(sym.level)==32 then
            mem:write_u8(sym.bricks_left,1); mem:write_u8(sym.boss_flash,0)
            mem:write_u8(sym.shot_active,1); mem:write_u8(sym.shot_y,80)
            mem:write_u8(sym.shot_x,mem:read_u8(sym.boss_col)*8+25)
        end
        if frame==1620 then
            assert(mem:read_u8(sym.level)==33,"boss defeat did not finish campaign")
            snap("arkanoid_victory")
        end
        if frame==1900 then
            check_scores(); check_titles()
            assert(min_stack>=sym.HS_END,"stack entered record storage")
            print("PASS: initials, firmware, phases, laser, final boss, victory and SRAM first process"); m:exit()
        end
    end)
    if not ok then failed=true; print("FAIL: frame "..frame..": "..tostring(err)); m:exit() end
end)
