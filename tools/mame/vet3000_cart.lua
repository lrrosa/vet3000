-- Copyright (C) 2026 Leonardo Roman da Rosa
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Software livre sob a GNU GPL versão 3 ou (a seu critério) posterior; veja LICENSE.
--
-- vet3000_cart.lua - cartucho no conector CN1 do VET 3000 para o MAME (sem recompilar)
--
-- O driver vet3000 do MAME (0.289) não mapeia $4000-$7FFF. Este script instala um
-- "read tap" nessa faixa e devolve os bytes da imagem do cartucho; a ROM original
-- encontra a assinatura "OBJECT"/"FONT" no boot como no aparelho real.
--
-- Uso:
--   set VET_CART=caminho\cartucho.bin
--   mame vet3000 -autoboot_script vet3000_cart.lua
--
-- Variáveis de ambiente opcionais:
--   VET_KEYS     roteiro de teclas: nomes separados por espaço, '+' = simultâneas,
--                'wN' = espera N quadros, 'snap' = snapshot, 'quit' = sair.
--                Nomes: 0-9 A-Z : SHIFT CONTROL EXTMODE SPACE RETURN BORDER CURSOR
--                AUTOCENTER COLOR YC UPDOWN OBJ PAGE LEFTRIGHT CLEAR
--   VET_WAIT     quadros antes de começar o roteiro (padrão 40)
--   VET_HOLD     quadros que cada tecla fica apertada (padrão 3)
--   VET_PEEK     endereços (hexa) de palavras de RAM a imprimir ao sair; no build
--                DEBUG da demo: "9A,9C" = voltas por quadro e menor sobra (x13 ciclos)
--   VET_TRACE    arquivo para o trace de instruções (rodar com -debug -debugger none)

if vet_cart_loaded then return end
vet_cart_loaded = true

local machine = manager.machine
local cpu = machine.devices[":maincpu"]
local space = cpu.spaces["program"]

-- cartucho --------------------------------------------------------------------
local path = os.getenv("VET_CART")
if path and path ~= "" then
  local f = assert(io.open(path, "rb"), "não abriu " .. path)
  vet_cart = f:read("*a")
  f:close()
  vet_cart_tap = space:install_read_tap(0x4000, 0x7fff, "vet_cart", function(offset, data, mask)
    local i = offset - 0x4000 + 1
    if i <= #vet_cart then return vet_cart:byte(i) end
    return 0xff
  end)
  print(string.format("[vet3000] cartucho %s (%d bytes) em $4000-$7FFF", path, #vet_cart))
end

-- trace de instruções (precisa de -debug; use -debugger none para não abrir janela)
local tracefile = os.getenv("VET_TRACE")
if tracefile and tracefile ~= "" and machine.debugger then
  machine.debugger:command("trace " .. tracefile .. ",maincpu,noloop")
  machine.debugger:command("go")
end

-- teclado ---------------------------------------------------------------------
local keymap = {
  {"1","Q","A","SHIFT","7","U","J","N"},
  {"2","W","S","CONTROL","8","I","K","M"},
  {"3","E","D","EXTMODE","9","O","L","SPACE"},
  {"4","R","F","-","0","P","RETURN","BORDER"},
  {"5","T","G","-",":","CURSOR","AUTOCENTER","COLOR"},
  {"6","Y","H","YC","UPDOWN","OBJ","-","PAGE"},
  {"Z","X","C","-","LEFTRIGHT","CLEAR","V","B"}}
local keys = {}
for row = 1, 7 do
  local port = machine.ioport.ports[":ROW" .. row]
  for bit = 0, 7 do
    local name = keymap[row][bit + 1]
    if name ~= "-" then keys[name] = port:field(1 << bit) end
  end
end

local seq = {}
for tok in string.gmatch(os.getenv("VET_KEYS") or "", "%S+") do seq[#seq + 1] = tok end
local step, wait, held = 1, tonumber(os.getenv("VET_WAIT") or "40"), nil
local hold = tonumber(os.getenv("VET_HOLD") or "3")
local frames = 0

-- leitura de RAM no fim (VET_PEEK="9A,9C": palavras de 16 bits em hexa) ---------
local function report()
  local peek = os.getenv("VET_PEEK")
  if peek and peek ~= "" then
    for a in string.gmatch(peek, "[^,]+") do
      local addr = tonumber(a, 16)
      print(string.format("[vet3000] $%04X = %d", addr, space:read_u16(addr)))
    end
  end
end

vet_frame_sub = emu.add_machine_frame_notifier(function()
  frames = frames + 1
  if wait > 0 then wait = wait - 1 return end
  if held then
    for _, f in ipairs(held) do f:clear_value() end
    held = nil
    wait = hold
    return
  end
  if step > #seq then
    if #seq > 0 then report() machine:exit() end
    return
  end
  local tok = seq[step]
  step = step + 1
  if tok:match("^w%d+$") then wait = tonumber(tok:sub(2)) return end
  if tok == "snap" then machine.video:snapshot() return end
  if tok == "quit" then report() machine:exit() return end
  held = {}
  for k in string.gmatch(tok, "[^+]+") do
    local f = keys[k]
    if not f then print("[vet3000] tecla desconhecida: " .. k)
    else f:set_value(1) held[#held + 1] = f end
  end
  wait = hold
end)
