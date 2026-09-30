-- Additional real 6809 execution cases. Included by demo_regression.lua.
return function(tests, sym, mem, vram, byte, word, eq)
    local function add(name, routine, setup, check)
        tests[#tests+1] = {name, routine, setup, check}
    end
    local function score(n)
        local s = string.format("%06d", n)
        for i=0,2 do mem:write_u8(sym.score+i, tonumber(s:sub(i*2+1,i*2+2),16)) end
    end
    local function entry(i)
        local a = sym.HS_DATA+i*6
        return tonumber(string.format("%02x%02x%02x", mem:read_u8(a), mem:read_u8(a+1), mem:read_u8(a+2)))
    end
    add("invalid SRAM", "hs_init", function()
        for a=sym.HS,sym.HS_END-1 do mem:write_u8(a,0xff) end
    end, function()
        eq(mem:read_u16(sym.HS), 0x4232, "signature")
        for i=0,9 do eq(entry(i),0,"empty score") end
    end)
    for n=1,12 do
        add("insert record "..n, "hs_insert", function() score(n*100) end, function()
            eq(mem:read_u8(sym.hs_pos),0,"top position")
            for i=0,math.min(n,10)-1 do eq(entry(i),(n-i)*100,"descending") end
        end)
    end
    add("lowest rejected", "hs_insert", function() score(1) end, function()
        eq(mem:read_u8(sym.hs_pos),10,"no place"); eq(entry(9),300,"last unchanged")
    end)
    add("tie follows existing", "hs_insert", function() score(800) end, function()
        eq(mem:read_u8(sym.hs_pos),5,"tie position"); eq(entry(4),800,"old tie"); eq(entry(5),800,"new tie")
    end)
    add("last place", "hs_insert", function() score(450) end, function()
        eq(mem:read_u8(sym.hs_pos),9,"last position"); eq(entry(9),450,"last record")
    end)
    add("valid checksum reload", "hs_init", function() end, function() eq(entry(0),1200,"retained") end)
    add("corrupt payload", "hs_init", function() mem:write_u8(sym.HS_DATA,0xff) end,
        function() eq(entry(0),0,"corruption cleared") end)
    add("zero rejected", "hs_insert", function() score(0) end,
        function() eq(mem:read_u8(sym.hs_pos),10,"zero") end)
    for pos=0,9 do
        add("insert at "..pos, "hs_insert", function()
            for i=0,9 do
                local a=sym.HS_DATA+i*6
                mem:write_u8(a,0); mem:write_u8(a+1,0x10-i); mem:write_u8(a+2,0)
            end
            -- BCD ranks 1000, 900, ..., 100.
            for i=1,9 do mem:write_u8(sym.HS_DATA+i*6+1,10-i) end
            score(1050-pos*100)
        end, function()
            eq(mem:read_u8(sym.hs_pos),pos,"position")
            eq(entry(pos),1050-pos*100,"inserted value")
        end)
    end
    for kind=1,3 do
        add("catch capsule "..kind, "power_step", function()
            byte("power_kind",kind); byte("power_clock",1); byte("power_y",167)
            byte("power_x",120); byte("paddle_x",112); byte("lives",4)
        end, function()
            eq(mem:read_u8(sym.power_kind),0,"caught")
            eq(mem:read_u8(sym.wide),kind==1 and 16 or 0,"wide")
            eq(mem:read_u8(sym.slow),kind==2 and 1 or 0,"slow")
            eq(mem:read_u8(sym.lives),kind==3 and 5 or 4,"life")
        end)
    end
    add("life cap", "power_step", function()
        byte("power_kind",3); byte("power_clock",1); byte("power_y",167)
        byte("power_x",120); byte("paddle_x",112); byte("lives",9)
    end, function() eq(mem:read_u8(sym.lives),9,"capped") end)
    add("miss capsule", "power_step", function()
        byte("power_kind",1); byte("power_clock",1); byte("power_y",176)
        byte("power_x",10); byte("paddle_x",112)
    end, function() eq(mem:read_u8(sym.power_kind),0,"expired"); eq(mem:read_u8(sym.wide),0,"no effect") end)
    add("armored first hit", "brick_hit", function()
        word("BRICKS",0x8000); word("ARMOR",0x8000)
        word("ball_x",0x0800); word("ball_y",0x1800); byte("bricks_left",1)
    end, function()
        eq(mem:read_u16(sym.BRICKS),0x8000,"brick survives")
        eq(mem:read_u16(sym.ARMOR),0,"armor broken")
        eq(mem:read_u8(sym.bricks_left),1,"remaining")
        eq(vram:read_u8(sym.NAMES+3*32+1),sym.T_BRICK,"colored brick")
        eq(mem:read_u8(sym.score+2),0,"no premature points")
    end)
    add("armored second hit", "brick_hit", function()
        word("BRICKS",0x8000); word("ball_x",0x0800); word("ball_y",0x1800); byte("bricks_left",1)
    end, function()
        eq(mem:read_u16(sym.BRICKS),0,"removed"); eq(mem:read_u8(sym.score+2),0x60,"points")
    end)
    add("score saturates", "brick_hit", function()
        word("BRICKS",0x8000); word("ball_x",0x0800); word("ball_y",0x1800); score(999990)
    end, function()
        for i=0,2 do eq(mem:read_u8(sym.score+i),0x99,"maximum score") end
    end)
    add("slow physics", "ball_move", function()
        word("ball_x",0x6400); word("ball_y",0x6400)
        word("ball_dx",0x100); word("ball_dy",-0x200); byte("slow",1)
    end, function()
        eq(mem:read_u16(sym.ball_x),0x6480,"half dx"); eq(mem:read_u16(sym.ball_y),0x6300,"half dy")
    end)
    add("serve clears effects", "serve", function()
        byte("wide",16); byte("slow",1); byte("power_kind",3)
    end, function()
        eq(mem:read_u8(sym.wide),0,"wide reset"); eq(mem:read_u8(sym.slow),0,"slow reset")
        eq(mem:read_u8(sym.power_kind),0,"capsule reset")
    end)
    add("armor rendering", "draw_bricks", function()
        word("BRICKS",0xc000); word("ARMOR",0x8000)
    end, function()
        eq(vram:read_u8(sym.NAMES+97),84,"silver tile")
        eq(vram:read_u8(sym.NAMES+99),sym.T_BRICK,"normal tile")
    end)
    local f=assert(io.open(os.getenv("VET_TEST_LEVELS"),"rb"))
    local levels=f:read("*a"); f:close()
    for level=0,31 do
        add("decode court "..level, "load_level", function() byte("level",level) end, function()
            local count=0
            for block,base in ipairs({sym.ARMOR,sym.GOLD,sym.BRICKS}) do
                for i=0,19 do
                    eq(mem:read_u8(base+i),levels:byte(level*60+(block-1)*20+i+1),"decoded mask")
                end
            end
            for i=0,19 do
                local b=mem:read_u8(sym.BRICKS+i) & (~mem:read_u8(sym.GOLD+i)&255)
                for bit=0,7 do if b & (1<<bit)~=0 then count=count+1 end end
            end
            eq(mem:read_u8(sym.bricks_left),count,"gold excluded")
            eq(mem:read_u8(sym.dbg_warm),0,"decoder stays below debug RAM")
        end)
        add("draw court "..level,"draw_bricks",function()
            for block,base in ipairs({sym.ARMOR,sym.GOLD,sym.BRICKS}) do
                for i=0,19 do mem:write_u8(base+i,levels:byte(level*60+(block-1)*20+i+1)) end
            end
        end,function()
            for y=0,9 do for x=0,14 do
                local mask=0x8000>>x
                local tile=0
                if mem:read_u16(sym.BRICKS+y*2)&mask~=0 then
                    tile=sym.T_BRICK+(y%6)*2
                    if mem:read_u16(sym.ARMOR+y*2)&mask~=0 then tile=84 end
                    if mem:read_u16(sym.GOLD+y*2)&mask~=0 then tile=86 end
                end
                eq(vram:read_u8(sym.NAMES+(y+3)*32+1+x*2),tile,"brick tile")
            end end
        end)
    end
    for _,row in ipairs({0,5,9}) do
        add("gold reflects row "..row,"brick_hit",function()
            mem:write_u16(sym.BRICKS+row*2,0x8000); mem:write_u16(sym.GOLD+row*2,0x8000)
            word("ball_x",0x800); word("ball_y",(24+row*8)*256); byte("bricks_left",5)
        end,function()
            eq(mem:read_u8(sym.bricks_left),5,"gold not destroyed")
            eq(mem:read_u16(sym.BRICKS+row*2),0x8000,"gold remains")
            eq(mem:read_u8(sym.score+2),0,"gold gives no points")
        end)
    end
    for kind=4,6 do
        add("new capsule "..kind,"power_step",function()
            byte("power_kind",kind); byte("power_clock",1); byte("power_y",165)
            byte("power_x",120); byte("paddle_x",112)
        end,function()
            eq(mem:read_u8(sym.power_kind),0,"collected")
            eq(mem:read_u8(sym.sticky),kind==4 and 1 or 0,"catch effect")
            eq(mem:read_u8(sym.gate),kind==5 and 1 or 0,"gate effect")
            eq(mem:read_u8(sym.laser),kind==6 and 1 or 0,"laser effect")
        end)
    end
    add("gate completes immediately","game_step",function()
        byte("gate",1); byte("paddle_x",216); byte("bricks_left",1)
        byte("shot_active",1); byte("shot_y",28); byte("shot_x",8); word("BRICKS",0x8000)
    end,function() eq(mem:read_u8(sym.bricks_left),0,"no underflow after exit") end)
    add("sticky rebound","ball_move",function()
        byte("sticky",1); byte("paddle_x",112); byte("ball_state",1)
        word("ball_x",125*256); word("ball_y",169*256); word("ball_dy",0x180); word("speed",0x180)
    end,function()
        eq(mem:read_u8(sym.ball_state),0,"caught ball"); eq(mem:read_u8(sym.sticky),1,"catch remains active")
    end)
    for _,kind in ipairs({"normal","silver","gold"}) do
        add("laser vs "..kind,"laser_step",function()
            byte("shot_active",1); byte("shot_y",28); byte("shot_x",8)
            word("BRICKS",0x8000); byte("bricks_left",1)
            if kind=="silver" then word("ARMOR",0x8000) end
            if kind=="gold" then word("GOLD",0x8000) end
            word("ball_x",0x6400); word("ball_y",0x8000)
        end,function()
            eq(mem:read_u8(sym.shot_active),0,"shot consumed")
            eq(mem:read_u8(sym.bricks_left),kind=="normal" and 0 or 1,"destruction")
            eq(mem:read_u16(sym.ARMOR),0,"armor broken")
            eq(mem:read_u16(sym.ball_x),0x6400,"ball X preserved")
            eq(mem:read_u16(sym.ball_y),0x8000,"ball Y preserved")
        end)
    end
    add("maximum sprite table","game_sprites",function()
        byte("wide",16); byte("power_kind",6); byte("shot_active",1)
        word("BRICKS",0xa55a)
    end,function()
        eq(mem:read_u8(sym.GAME_SAT+24),0xd0,"sprite terminator")
        eq(mem:read_u16(sym.BRICKS),0xa55a,"sprites do not overwrite bricks")
    end)
    add("campaign completion","level_done",function() byte("level",32) end,function()
        eq(mem:read_u8(sym.level),33,"finished boss")
        eq(vram:read_u8(sym.NAMES+15*32+6),string.byte("C")-sym.FONT_FIRST,"victory message")
    end)
    add("boss entry","load_level",function() byte("level",32) end,function()
        eq(mem:read_u8(sym.bricks_left),24,"boss energy")
        eq(mem:read_u8(sym.boss_col),12,"boss centered")
    end)
    add("boss laser provided","serve",function() byte("level",32) end,function()
        eq(mem:read_u8(sym.laser),1,"boss equipment")
    end)
    for _,flash in ipairs({0,5}) do
        add("boss damage cooldown "..flash,"brick_hit",function()
            byte("level",32); byte("bricks_left",24); byte("boss_col",12); byte("boss_flash",flash)
            word("ball_x",120*256); word("ball_y",80*256)
        end,function()
            eq(mem:read_u8(sym.bricks_left),flash==0 and 23 or 24,"HP")
            eq(mem:read_u8(sym.score+1),flash==0 and 1 or 0,"100 points per hit")
        end)
    end
    add("boss final hit","brick_hit",function()
        byte("level",32); byte("bricks_left",1); byte("boss_col",12)
        word("ball_x",120*256); word("ball_y",80*256)
    end,function() eq(mem:read_u8(sym.bricks_left),0,"boss defeated") end)
    add("boss motion and attack","boss_step",function()
        byte("level",32); byte("bricks_left",24); byte("boss_col",19); byte("boss_dir",1)
        byte("boss_tick",63); byte("ball_state",1); byte("paddle_x",100)
    end,function()
        eq(mem:read_u8(sym.boss_col),20,"moves")
        eq(mem:read_u8(sym.boss_dir),255,"turns inward")
        eq(mem:read_u8(sym.power_kind),7,"fires hostile bolt")
        eq(mem:read_u8(sym.boss_bolt_dx),255,"aimed left")
    end)
    add("boss projectile hurts","power_step",function()
        byte("level",32); byte("lives",3); byte("power_kind",7)
        byte("power_x",120); byte("power_y",167); byte("paddle_x",112)
    end,function()
        eq(mem:read_u8(sym.lives),2,"life lost")
        eq(mem:read_u8(sym.power_kind),0,"bolt gone")
        eq(mem:read_u8(sym.ball_state),0,"safe new serve")
    end)
    local sf=assert(io.open(os.getenv("VET_TEST_SCROLL"),"rb"))
    local scroll=sf:read("*a"); sf:close()
    for i,shift in ipairs({0,2,4,6}) do
        add("compact scroll font "..shift,"put_scroller",function()
            word("scroll_ptr",sym.SCROLL_TEXT); byte("scroll_s",shift)
        end,function()
            for offset=0,255 do
                eq(vram:read_u8(sym.PAT+0x1000+sym.SCROLL_ROW*256+offset),scroll:byte((i-1)*256+offset+1),"shifted glyph")
            end
        end)
    end
    local matrix={" QA  UJN"," WS  IKM"," ED  OL "," RF  P  "," TG     "," YH     ","ZXC   VB"}
    local selected,alpha_row,alpha_mask=255,nil,0
    vet_alpha_write=mem:install_write_tap(0x8002,0x8002,"alpha_select",function(a,d) selected=d end)
    vet_alpha_read=mem:install_read_tap(0x8002,0x8002,"alpha_matrix",function(a,d)
        if alpha_row and selected==alpha_row then return d & (~alpha_mask & 255) end
    end)
    for row,letters in ipairs(matrix) do
        for bit=0,7 do
            local letter=letters:sub(bit+1,bit+1)
            if letter~=" " then
                add("direct initial "..letter,"read_alpha",function()
                    alpha_row=255-(1<<(row-1)); alpha_mask=1<<bit
                end,function()
                    alpha_row=nil
                    eq(mem:read_u8(sym.alpha_last),letter:byte(),"physical letter")
                end)
            end
        end
    end
    for direction=0,1 do
        add("alternate launch "..direction,"game_step",function()
            byte("launch_dir",direction); byte("keys_new",sym.K_FIRE)
            byte("bricks_left",1); word("speed",0x180); byte("paddle_x",112)
        end,function()
            eq(mem:read_u16(sym.ball_dx),direction==0 and 0xff40 or 0xc0,"launch side")
        end)
    end
    for _,offset in ipairs({1,7,21,28}) do
        add("paddle angle "..offset,"ball_move",function()
            byte("paddle_x",112); word("ball_x",(112+offset)*256)
            word("ball_y",169*256); word("ball_dy",0x180); word("speed",0x180)
        end,function()
            eq(mem:read_u8(sym.ball_dx)>=128 and 1 or 0,offset<13 and 1 or 0,"bounce sign follows contact")
        end)
    end
end
