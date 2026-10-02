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
        byte("gate",1); byte("paddle_x",232); byte("bricks_left",1)
        byte("shot_active",1); byte("shot_y",28); byte("shot_x",8); word("BRICKS",0x8000)
    end,function() eq(mem:read_u8(sym.bricks_left),0,"no underflow after exit") end)
    -- The paddle leaves only with at least 1/6 of its width past the right screen edge.
    for _,c in ipairs({{0,229,false},{0,230,true},{16,215,false},{16,216,true}}) do
        add("gate exit wide "..c[1].." x "..c[2],"gate_step",function()
            byte("gate",1); byte("wide",c[1]); byte("paddle_x",c[2]); byte("bricks_left",5)
        end,function() eq(mem:read_u8(sym.bricks_left),c[3] and 0 or 5,"exit threshold") end)
    end
    for _,c in ipairs({{0,216,216},{1,216,220},{1,228,230}}) do
        add("paddle right gate "..c[1].." from "..c[2],"game_step",function()
            byte("gate",c[1]); byte("paddle_x",c[2]); byte("keys",sym.K_RIGHT)
            byte("bricks_left",5); byte("ball_state",1); word("ball_y",0x4000)
        end,function() eq(mem:read_u8(sym.paddle_x),c[3],"right limit") end)
    end
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
        eq(mem:read_u8(sym.GAME_SAT+8),0xd0,"sprite terminator")
        eq(mem:read_u16(sym.BRICKS),0xa55a,"sprites do not overwrite bricks")
    end)
    -- Every pixel row of the paddle must stay within the VDP's 4 sprites per line,
    -- also with the wide paddle, the ball resting on it, a capsule and a shot nearby.
    local function sprite_rows(pattern)
        local rows={}
        for r=0,15 do
            local a=sym.SPRITE_PATS+pattern*8
            rows[r]=mem:read_u8(a+r)|mem:read_u8(a+16+r)
        end
        return rows
    end
    local function check_sat(parts, ball_visible)
        local sat={}
        for i=0,31 do
            local a=sym.SPRATT+i*4
            local y=vram:read_u8(a)
            if y==0xd0 then break end
            sat[#sat+1]={y=y,x=vram:read_u8(a+1),p=vram:read_u8(a+2),c=vram:read_u8(a+3)}
        end
        eq(#sat>=parts+1 and 1 or 0,1,"paddle and ball in the table")
        for line=0,191 do
            local shown=0
            for i,sp in ipairs(sat) do
                local r=line-(sp.y+1)
                if r>=0 and r<16 then
                    shown=shown+1
                    local need=i<=parts or (ball_visible and i==parts+1)
                    if need and sprite_rows(sp.p)[r]~=0 then
                        eq(shown<=4 and 1 or 0,1,"sprite "..i.." dropped on line "..line)
                    end
                end
            end
        end
        return sat
    end
    for _,c in ipairs({{0,170,false,4},{16,170,false,6},{16,170,true,6},{16,183,true,6},{0,183,true,4}}) do
        add("paddle sprites wide "..c[1].." ball "..c[2]..(c[3] and " crowded" or ""),"put_game_sat",function()
            byte("wide",c[1]); byte("paddle_x",100)
            word("ball_x",113*256); word("ball_y",c[2]*256)
            -- GAME_SAT as game_sprites leaves it: capsule and shot
            local u=sym.GAME_SAT
            local function put(y,x,p,col)
                mem:write_u8(u,y); mem:write_u8(u+1,x); mem:write_u8(u+2,p); mem:write_u8(u+3,col); u=u+4
            end
            if c[3] then put(159,140,24,11); put(165,120,sym.PAT_SHOT,9) end
            mem:write_u8(u,0xd0)
        end,function()
            local sat=check_sat(c[4], c[2]==170)
            eq(sat[2].x,100,"left tip at paddle_x")
            eq(sat[3].x,116+c[1],"right tip follows width")
            eq(sat[c[4]+1].p,sym.PAT_BALL,"ball after the paddle")
        end)
    end
    add("ball sprite bottom aligned","put_game_sat",function()
        word("ball_x",120*256); word("ball_y",170*256); mem:write_u8(sym.GAME_SAT,0xd0)
    end,function()
        local a=sym.SPRATT+4*4
        eq(vram:read_u8(a),159,"ball Y"); eq(vram:read_u8(a+1),120,"ball X")
        eq(vram:read_u8(a+2),sym.PAT_BALL,"ball pattern"); eq(vram:read_u8(a+4),0xd0,"no extra sprites")
    end)
    -- Disruption (D): three balls; a life is lost only with the last one.
    for _,stuck in ipairs({false,true}) do
        add("disrupt capsule"..(stuck and " stuck ball" or ""),"power_step",function()
            byte("power_kind",7); byte("power_clock",1); byte("power_y",165)
            byte("power_x",120); byte("paddle_x",112); byte("sticky",1)
            byte("ball_state",stuck and 0 or 1); word("ball_x",0x6480); word("ball_y",0x5000)
            word("ball_dx",0x100); word("ball_dy",-0x200); word("speed",0x200)
        end,function()
            eq(mem:read_u8(sym.power_kind),0,"collected"); eq(mem:read_u8(sym.extra_balls),3,"two extra balls")
            eq(mem:read_u8(sym.sticky),0,"catch cancelled"); eq(mem:read_u8(sym.ball_state),1,"ball in play")
            for i,base in ipairs({sym.BALL2,sym.BALL3}) do
                eq(mem:read_u16(base),mem:read_u16(sym.ball_x),"same X")
                eq(mem:read_u16(base+2),mem:read_u16(sym.ball_y),"same Y")
                eq(mem:read_u16(base+4),i==1 and 0xfe55 or 0x01ab,"spread")
                eq(mem:read_u16(base+6),0xfe00,"upward")
            end
        end)
    end
    for _,c in ipairs({{3,sym.BALL2,2},{2,sym.BALL3,0}}) do
        add("primary lost promotes extra "..c[1],"primary_lost",function()
            byte("extra_balls",c[1]); byte("lives",3)
            for i=0,7 do mem:write_u8(c[2]+i,0x40+i) end
        end,function()
            for i=0,7 do eq(mem:read_u8(sym.ball_x+i),0x40+i,"promoted state") end
            eq(mem:read_u8(sym.extra_balls),c[3],"slot freed"); eq(mem:read_u8(sym.lives),3,"no life lost")
        end)
    end
    add("last ball loses life","primary_lost",function() byte("lives",3); byte("ball_state",1) end,function()
        eq(mem:read_u8(sym.lives),2,"life lost"); eq(mem:read_u8(sym.ball_state),0,"new serve")
    end)
    add("extra ball moves","multi_step",function()
        byte("extra_balls",1); word("BALL2",100*256)
        mem:write_u16(sym.BALL2+2,100*256); mem:write_u16(sym.BALL2+4,0x100); mem:write_u16(sym.BALL2+6,0xfe00)
        word("ball_x",0x1234); word("ball_y",0x5678); byte("lives",3)
    end,function()
        eq(mem:read_u16(sym.BALL2),101*256,"extra X"); eq(mem:read_u16(sym.BALL2+2),98*256,"extra Y")
        eq(mem:read_u16(sym.ball_x),0x1234,"primary X kept"); eq(mem:read_u16(sym.ball_y),0x5678,"primary Y kept")
        eq(mem:read_u8(sym.extra_balls),1,"still in play")
    end)
    add("extra ball lost","multi_step",function()
        byte("extra_balls",2); mem:write_u16(sym.BALL3,100*256); mem:write_u16(sym.BALL3+2,197*256)
        mem:write_u16(sym.BALL3+6,0x200); word("ball_x",0x1234); word("ball_y",0x5678); byte("lives",3)
    end,function()
        eq(mem:read_u8(sym.extra_balls),0,"extra gone"); eq(mem:read_u8(sym.lives),3,"no life lost")
        eq(mem:read_u16(sym.ball_y),0x5678,"primary kept")
    end)
    add("no capsule during multiball","power_spawn",function() byte("hitcnt",3); byte("extra_balls",1) end,
        function() eq(mem:read_u8(sym.power_kind),0,"no capsule") end)
    add("capsule cycle includes D","power_spawn",function() byte("hitcnt",23) end,
        function() eq(mem:read_u8(sym.power_kind),7,"disruption") end)
    for frame=0,1 do
        add("three ball sprites frame "..frame,"put_game_sat",function()
            byte("frame",frame); byte("extra_balls",3); byte("paddle_x",100)
            word("ball_x",50*256); word("ball_y",60*256)
            mem:write_u16(sym.BALL2,70*256); mem:write_u16(sym.BALL2+2,80*256)
            mem:write_u16(sym.BALL3,90*256); mem:write_u16(sym.BALL3+2,100*256)
            mem:write_u8(sym.GAME_SAT,0xd0)
        end,function()
            local xs=frame==0 and {50,70,90} or {90,70,50}
            for i=1,3 do
                local a=sym.SPRATT+(3+i)*4
                eq(vram:read_u8(a+1),xs[i],"ball order"); eq(vram:read_u8(a+2),sym.PAT_BALL,"ball pattern")
            end
            eq(vram:read_u8(sym.SPRATT+7*4),0xd0,"terminator")
        end)
    end
    add("new record has blank initials","hs_insert",function()
        for a=sym.HS_DATA,sym.HS_END-1 do mem:write_u8(a,0) end; score(500)
    end,function()
        eq(mem:read_u8(sym.hs_pos),0,"top position")
        for i=3,5 do eq(mem:read_u8(sym.HS_DATA+i),32,"blank initial") end
    end)
    add("wide laser centered","laser_step",function()
        byte("laser",1); byte("ball_state",1); byte("keys",sym.K_FIRE)
        byte("wide",16); byte("paddle_x",100)
    end,function() eq(mem:read_u8(sym.shot_x),121,"shot from paddle center") end)
    add("campaign completion","level_done",function() byte("level",32) end,function()
        eq(mem:read_u8(sym.level),33,"finished boss")
        eq(vram:read_u8(sym.NAMES+15*32+7),string.byte("C")-sym.FONT_FIRST,"victory message")
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
        eq(mem:read_u8(sym.power_kind),8,"fires hostile bolt")
        eq(mem:read_u8(sym.boss_bolt_dx),255,"aimed left")
        eq(mem:read_u8(sym.boss_mouth),sym.BOSS_MOUTH_TIME,"mouth opens to fire")
    end)
    add("boss projectile hurts","power_step",function()
        byte("level",32); byte("lives",3); byte("power_kind",8)
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
            eq(mem:read_u16(sym.ball_dx),direction==0 and 0xff00 or 0x100,"launch side")
        end)
    end
    for _,c in ipairs({{sym.AUTO_LAUNCH-2,0},{sym.AUTO_LAUNCH-1,1}}) do
        add("auto launch after "..c[1],"game_step",function()
            byte("serve_clock",c[1]); byte("bricks_left",1); word("speed",0x200); byte("paddle_x",112)
        end,function()
            eq(mem:read_u8(sym.ball_state),c[2],"ball launched")
            if c[2]==1 then eq(mem:read_u16(sym.ball_dy),0xfe00,"upward") end
        end)
    end
    local function text_at(addr, s)
        local accents={["\u{C1}"]="_",["\u{C7}"]="#",["\u{C3}"]="%"}
        local i=0
        for _,code in utf8.codes(s) do
            local ch=utf8.char(code); ch=accents[ch] or ch
            eq(vram:read_u8(addr+i),ch:byte()-sym.FONT_FIRST,"text "..s.." at "..i)
            i=i+1
        end
    end
    add("stage shown on serve","serve",function() byte("level",4) end,function()
        text_at(sym.NAMES+sym.MSG_ROW*32+12,"FASE 05")
        eq(mem:read_u8(sym.serve_clock),0,"auto-launch clock restarted")
    end)
    add("launch clears stage","game_step",function()
        byte("keys_new",sym.K_FIRE); byte("bricks_left",1); word("speed",0x200); byte("paddle_x",112)
        for a=sym.NAMES+sym.MSG_ROW*32,sym.NAMES+sym.MSG_ROW*32+31 do vram:write_u8(a,37) end
    end,function()
        for col=8,23 do eq(vram:read_u8(sym.NAMES+sym.MSG_ROW*32+col),0,"stage cleared") end
    end)
    add("centered score table","hs_draw",function()
        for i=0,9 do
            local a=sym.HS_DATA+i*6
            mem:write_u8(a,0); mem:write_u8(a+1,0x12); mem:write_u8(a+2,0x34)
            mem:write_u8(a+3,67); mem:write_u8(a+4,68); mem:write_u8(a+5,69)
        end
    end,function()
        text_at(sym.NAMES+3*32+8,"    NOME  PONTOS")
        for i=0,9 do text_at(sym.NAMES+(5+i)*32+8,string.format("%02d  CDE   001234",i+1)) end
        text_at(sym.NAMES+32+5,"QUEBRA-TIJOLO: TOP 10")
    end)
    for _,c in ipairs({{0,sym.T_CURSOR},{16,string.byte("Q")-sym.FONT_FIRST}}) do
        add("initial cursor phase "..c[1],"hs_cursor",function()
            byte("hs_pos",2); byte("hs_letter",1); byte("hs_blink",c[1]); byte("ticks",1)
            mem:write_u8(sym.HS_DATA+2*6+4,string.byte("Q"))
        end,function()
            eq(vram:read_u8(sym.NAMES+7*32+13),c[2],"blinking cell")
            eq(mem:read_u8(sym.hs_blink),c[1]+1,"blink clock")
        end)
    end
    -- Attract CPU runs to where the ball will reach the paddle (walls reflect it).
    for i,c in ipairs({{100,100,0,0x200,103},{100,100,0x100,0x200,138},
                       {230,100,0x200,0x200,187},{100,100,-0x100,-0x200,38}}) do
        add("cpu landing prediction "..i,"attract_update",function()
            word("attract_timer",600); byte("ticks",1); byte("ball_state",1); byte("hitcnt",0)
            word("ball_x",c[1]*256); word("ball_y",c[2]*256); word("ball_dx",c[3]); word("ball_dy",c[4])
            byte("paddle_x",100)
        end,function()
            eq(mem:read_u8(sym.tmp2),c[5]+8,"aim = landing + 8")
            local dir=(c[5]+8>116+3) and sym.K_RIGHT or ((c[5]+8<116-3) and sym.K_LEFT or 0)
            eq(mem:read_u8(sym.keys)&(sym.K_LEFT|sym.K_RIGHT),dir,"moves toward the landing point")
        end)
    end
    -- CLEAR erases the letter under the cursor, or goes back and erases the previous one.
    for _,c in ipairs({{"ABC",2,"AB ",2},{"AB ",2,"A  ",1},{"A  ",1,"   ",0},{"   ",0,"   ",0}}) do
        add("clear initials "..c[1]:gsub(" ","_").." at "..c[2],"hs_backspace",function()
            byte("hs_pos",1); byte("hs_letter",c[2])
            for i=1,3 do mem:write_u8(sym.HS_DATA+6+2+i,c[1]:byte(i)) end
        end,function()
            for i=1,3 do eq(mem:read_u8(sym.HS_DATA+6+2+i),c[3]:byte(i),"initial "..i) end
            eq(mem:read_u8(sym.hs_letter),c[4],"cursor position")
            if c[1]~=c[3] then eq(mem:read_u16(sym.HS),0x4232,"saved with signature") end
        end)
    end
    -- Leaving through the gate: paddle pieces past x=255 are moved below the screen.
    add("paddle pieces past the right edge","put_game_sat",function()
        byte("paddle_x",250); word("ball_y",100*256); mem:write_u8(sym.GAME_SAT,0xd0)
    end,function()
        local function y(i) return vram:read_u8(sym.SPRATT+i*4) end
        eq(y(0),0xc0,"shine hidden"); eq(y(1),sym.PADDLE_Y-1,"left tip visible")
        eq(y(2),0xc0,"right tip hidden"); eq(y(3),0xc0,"body hidden")
        eq(vram:read_u8(sym.SPRATT+1*4+1),250,"left tip X")
    end)
    -- New boss face: own tiles in banks 0 and 1, map with eye/mouth variants.
    local function unrle(addr)
        local out={}
        while true do
            local n=mem:read_u8(addr); addr=addr+1
            if n==0 then return out end
            if n<0x80 then
                for i=1,n do out[#out+1]=mem:read_u8(addr); addr=addr+1 end
            else
                local b=mem:read_u8(addr); addr=addr+1
                for i=1,n-0x7e do out[#out+1]=b end
            end
        end
    end
    add("boss tiles loaded","boss_init",function() end,function()
        local pat,col=unrle(sym.BOSS_PAT),unrle(sym.BOSS_COL)
        eq(#pat,(sym.BOSS_N+sym.BOSS_MOUTH_END-sym.BOSS_EYE0)*8,"tile count")
        for _,bank in ipairs({0,0x800}) do
            for i=1,#pat do
                eq(vram:read_u8(sym.PAT+bank+sym.BOSS_T0*8+i-1),pat[i],"pattern byte")
                eq(vram:read_u8(sym.COL+bank+sym.BOSS_T0*8+i-1),col[i],"color byte")
            end
        end
    end)
    for _,c in ipairs({{0,0,"normal"},{3,0,"hit eyes"},{0,5,"open mouth"}}) do
        add("boss face "..c[3],"boss_draw",function()
            byte("boss_col",12); byte("boss_flash",c[1]); byte("boss_mouth",c[2]); byte("bricks_left",24)
        end,function()
            local eyes,mouth=0,0
            for r=0,7 do
                eq(vram:read_u8(sym.NAMES+(4+r)*32+11),0,"left trail cleared")
                eq(vram:read_u8(sym.NAMES+(4+r)*32+20),0,"right trail cleared")
                for x=0,7 do
                    local t=mem:read_u8(sym.BOSS_MAP+r*8+x)
                    local want=t
                    if c[1]>0 and t>=sym.BOSS_EYE0 and t<sym.BOSS_EYE_END then want=t+sym.BOSS_N; eyes=eyes+1 end
                    if c[2]>0 and t>=sym.BOSS_MOUTH0 and t<sym.BOSS_MOUTH_END then want=t+sym.BOSS_N; mouth=mouth+1 end
                    eq(vram:read_u8(sym.NAMES+(4+r)*32+12+x),want,"face tile")
                end
            end
            if c[1]>0 then eq(eyes>0 and 1 or 0,1,"eye cells swapped") end
            if c[2]>0 then eq(mouth>0 and 1 or 0,1,"mouth cells swapped") end
            for i=0,23 do eq(vram:read_u8(sym.NAMES+13*32+4+i),sym.T_ENERGY,"full energy") end
        end)
    end
    add("boss energy bar","boss_energy",function() byte("bricks_left",10) end,function()
        for i=0,23 do eq(vram:read_u8(sym.NAMES+13*32+4+i),i<10 and sym.T_ENERGY or sym.T_ENERGY_OFF,"segment") end
    end)
    add("boss mouth closes","boss_step",function()
        byte("level",32); byte("bricks_left",24); byte("boss_col",12); byte("boss_dir",1)
        byte("boss_mouth",1); byte("boss_tick",5)
    end,function() eq(mem:read_u8(sym.boss_mouth),0,"closed again") end)
    for _,offset in ipairs({1,7,21,28}) do
        add("paddle angle "..offset,"ball_move",function()
            byte("paddle_x",112); word("ball_x",(112+offset)*256)
            word("ball_y",169*256); word("ball_dy",0x180); word("speed",0x180)
        end,function()
            eq(mem:read_u8(sym.ball_dx)>=128 and 1 or 0,offset<13 and 1 or 0,"bounce sign follows contact")
        end)
    end
end
