-- Verify the patched driver without installing a cartridge read tap.
local machine = manager.machine
local cpu = machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local cart
local path = os.getenv("VET_NATIVE_CART")
if path and path ~= "" then
    local f = assert(io.open(path, "rb"))
    cart = f:read("*a")
    f:close()
end
local frames, cart_frames, last_frame, changes = 0, 0, nil, 0
local function check_frame()
    frames = frames + 1
    if frames == 1 then
        local hz = machine.screens[":screen"].refresh
        assert(math.abs(hz - 59.9227) < 0.01, "unexpected refresh: " .. hz)
        for offset = 0, 0x3fff do
            local expected = cart and cart:byte(offset + 1) or 0xff
            assert(mem:read_u8(0x4000 + offset) == expected,
                string.format("cartridge mismatch at $%04X", 0x4000 + offset))
        end
        print(string.format("Native slot: 16384 bytes checked; refresh=%.6f Hz", hz))
    end
    if frames > 120 then
        local pc = cpu.state["PC"].value
        if pc >= 0x4000 and pc < 0x8000 then cart_frames = cart_frames + 1 end
        local current = mem:read_u8(1) -- demo's frame counter
        if last_frame and current ~= last_frame then changes = changes + 1 end
        last_frame = current
    end
    if frames == 240 then
        if cart then
            assert(cart_frames > 60, "demo did not execute from native cartridge")
            assert(changes > 60, "demo frame counter did not advance")
        else
            assert(cart_frames == 0, "firmware entered the empty cartridge slot")
        end
        print("PASS: native slot " .. (cart and "cartridge boot" or "empty slot boot"))
        machine:exit()
    end
end
local failed = false
native_cart_notifier = emu.add_machine_frame_notifier(function()
    if failed then return end
    local ok, message = pcall(check_frame)
    if not ok then
        failed = true
        print("FAIL: " .. tostring(message))
        machine:exit()
    end
end)
