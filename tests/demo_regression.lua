-- Execute the assembled 6809 routines in MAME; see tests/README.md.
local machine = manager.machine
local cpu = machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local sym = {}
for line in io.lines(os.getenv("VET_TEST_SYM")) do
    local name, value = line:match("^(%S+)%s+equ%s+(%d+)")
    if name then sym[name] = tonumber(value) end
end
local f = assert(io.open(os.getenv("VET_CART"), "rb"))
local cart = f:read("*a")
f:close()
-- Return from the level transition before waits/redrawing the next level.
local overrides = {[sym.pause_frames] = 0x39,
    [sym.new_level] = 0x7e, [sym.new_level + 1] = 1, [sym.new_level + 2] = 0x19}
vet_test_tap = mem:install_read_tap(0x4000, 0x7fff, "test_cart", function(a)
    return overrides[a] or cart:byte(a - 0x4000 + 1)
end)
local vram
for _, dev in pairs(machine.devices) do
    if dev.shortname == "tms9128" then vram = dev.spaces["vram"] end
end
assert(vram, "TMS9128 VRAM not found")
local function byte(name, value) mem:write_u8(assert(sym[name]), value) end
local function word(name, value) mem:write_u16(assert(sym[name]), value & 0xffff) end
local function eq(actual, expected, message)
    assert(actual == expected, message .. ": " .. actual .. " ~= " .. expected)
end
local tests = {}
for level = 0, 255 do
    tests[#tests + 1] = {"HUD " .. (level + 1), "draw_status", function()
        byte("level", level)
    end, function()
        local digits = string.format("%03d", level + 1)
        for i = 1, 3 do
            eq(vram:read_u8(sym.NAMES + 28 + i), digits:byte(i) - sym.FONT_FIRST, "digit")
        end
    end}
end
for _, side in ipairs({{0x0880, -0x01c0, 0x0800, 0x01c0},
                         {0xf280, 0x01c0, 0xf200, -0x01c0}}) do
    tests[#tests + 1] = {"wall " .. side[1], "ball_move", function()
        word("ball_x", side[1]); word("ball_dx", side[2])
        word("ball_y", 0x2000); word("ball_dy", 0x0100)
        for a = sym.BRICKS, sym.BRICKS + 11 do mem:write_u8(a, 0xff) end
        byte("bricks_left", 90)
    end, function()
        eq(mem:read_u16(sym.ball_x), side[3], "clamped X")
        eq(mem:read_u16(sym.ball_dx), side[4] & 0xffff, "inward dx")
        eq(mem:read_u8(sym.bricks_left), 89, "Y still removes the edge brick")
    end}
end
tests[#tests + 1] = {"last brick score", "level_done", function()
    byte("level", 8); byte("dirty", 1)
    mem:write_u8(sym.score, 0x01); mem:write_u8(sym.score + 1, 0x23)
    mem:write_u8(sym.score + 2, 0x60)
end, function()
    for i = 1, 6 do
        eq(vram:read_u8(sym.NAMES + 6 + i), ("012360"):byte(i) - sym.FONT_FIRST, "score")
    end
    eq(mem:read_u8(sym.level), 9, "next level")
    eq(vram:read_u8(sym.NAMES + 31), string.byte("9") - sym.FONT_FIRST, "completed level")
end}
local bf = assert(io.open(os.getenv("VET_TEST_BARS"), "rb"))
local bars = bf:read("*a"); bf:close()
for phase = 0, 255 do
    tests[#tests + 1] = {"bars " .. phase, "build_bars", function()
        byte("bar_phase", phase)
    end, function()
        for y = 0, 63 do
            local color = bars:byte(phase * 64 + y + 1)
            eq(mem:read_u8(sym.BARBUF + y), color * 17, "bar scanline " .. y)
        end
    end}
end
local index, active = 0, false
vet_test_frame = emu.add_machine_frame_notifier(function()
    local ok, err = pcall(function()
        if active then
            eq(mem:read_u8(0x1ff), 1, "routine returned: " .. tests[index][1])
            tests[index][4]()
        end
        index = index + 1
        if index > #tests then
            print("PASS: " .. #tests .. " MAME regression cases")
            machine:exit(); return
        end
        for a = 0, 0xff do mem:write_u8(a, 0) end
        -- Idle at JMP $0100. A RAM trampoline changes its destination back before
        -- calling the routine, avoiding PC changes mid-instruction between cases.
        local code = {0xcc, 0x01, 0x00, 0xfd, 0x01, 0x01, 0xbd, 0, 0,
                      0x86, 1, 0xb7, 1, 0xff, 0x7e, 1, 0}
        for i, b in ipairs(code) do mem:write_u8(0x10f + i, b) end
        mem:write_u16(0x117, assert(sym[tests[index][2]]))
        mem:write_u8(0x1ff, 0)
        mem:write_u8(0x100, 0x7e)
        mem:write_u16(0x101, 0x110)
        if not active then
            cpu.state.S.value = 0x1ef0
            cpu.state.DP.value = 0
            cpu.state.CC.value = 0x50
            cpu.state.PC.value = 0x100
        end
        tests[index][3]()
        active = true
    end)
    if not ok then print("FAIL: " .. tostring(err)); machine:exit() end
end)
