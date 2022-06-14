local ffi = require "ffi"
local bit = require "bit"
local string = require "string"
local math = require "math"
local io = require "io"

local C = ffi.C
local sfml = require "sfml"
local sfml_system = require "sfml.system" { path = "./3rd/?.dll" }
local sfml_window = require "sfml.window" { path = "./3rd/?.dll" }
local sfml_graphics = require "sfml.graphics" { path = "./3rd/?.dll" }

local Sleep, Clock = sfml_system.Sleep, sfml_system.Clock
local VideoMode, sfKeyboard_isKeyPressed = sfml_window.VideoMode, sfml_window.sfKeyboard_isKeyPressed
local RenderWindow, Sprite, Color = sfml_graphics.RenderWindow, sfml_graphics.Sprite, sfml_graphics.Color

local ffi_new, ffi_cast, ffi_copy = ffi.new, ffi.cast, ffi.copy
local bnot = bit.bnot
local band, bor, bxor = bit.band, bit.bor, bit.bxor
local lshift, rshift = bit.lshift, bit.rshift
local str_fmt = string.format
local floor = math.floor

ffi.cdef [[
typedef struct chip8 {
  uint8_t ram[4096];
  uint8_t *screen;  // ram[0xf00 ~ 0xfff]

  uint8_t V[16];
  uint16_t I;
  uint16_t pc;
  uint8_t sp;

  uint8_t dt;
  uint8_t st;

  uint16_t *stack;  // ram[0xea0 ~ 0xeff]

  uint8_t keystate[16];

  uint16_t rom_size;  // ROM size in bytes
} chip8_t;
]]

local ENTRY_BASE = 0x200

local SCREEN_WIDTH = 64
local SCREEN_HEIGHT = 32

local aux = {}
local _M = {}

local function _p(fmt, ...)
  print(str_fmt(fmt, ...))
end

function aux.class()
  local class = {}
  class.__index = class
  return class
end

local opcode_map = {
  -- 0...
  [0x0] = function(vm, opcode)
    local low_byte = band(opcode, 0xff)

    if low_byte == 0xE0 then
      -- 00E0 - CLS
      vm:clear_screen()
    else
      assert(false, str_fmt("invalid opcode: %04x", opcode))
    end
  end,
  -- 1nnn - JP addr
  [0x1] = function(vm, opcode)
    vm.pc = band(opcode, 0xfff)
  end,
  -- 6xkk - LD Vx, byte
  [0x6] = function(vm, opcode)
    vm.V[band(rshift(opcode, 8), 0xf)] = band(opcode, 0xff)
  end,
  -- 7xkk - ADD Vx, byte
  [0x7] = function(vm, opcode)
    local x = band(rshift(opcode, 8), 0xf)
    vm.V[x] = band(vm.V[x] + band(opcode, 0xff), 0xff)
  end,
  -- Annn - LD I, addr
  [0xA] = function(vm, opcode)
    vm.I = band(opcode, 0xfff)
  end,
  -- Dxyn - DRW Vx, Vy, nibble
  [0xD] = function(vm, opcode)
    assert(false, str_fmt("invalid opcode: %04x", opcode))
  end,
}

local chip8_mt = aux.class()

function chip8_mt.get_next_opcode(vm)
  assert(vm.pc >= ENTRY_BASE and vm.pc < ENTRY_BASE + vm.rom_size)

  local opcode = bor(lshift(vm.ram[vm.pc], 8), vm.ram[vm.pc + 1])
  vm.pc = vm.pc + 2
  return opcode
end

function chip8_mt.execute_next_opcode(vm)
  local opcode = vm:get_next_opcode()
  _p("pc: 0x%03x, opcode: %04x", vm.pc - 2, opcode)

  if opcode ~= nil then
    local op = rshift(opcode, 12)
    opcode_map[op](vm, opcode)
  end
end

function chip8_mt.clear_screen(vm)
  for i = 0, 255 do
    vm.screen[i] = 0
  end
end

function chip8_mt.get_pixel(vm, x, y)
  local index = (y * SCREEN_WIDTH) + x
  local byte_index = floor(index / 8)
  local offset = index % 8
  return band(vm.screen[byte_index], rshift(0x80, offset))
end

function chip8_mt.set_pixel(vm, x, y, on)
  local index = (y * SCREEN_WIDTH) + x
  local byte_index = floor(index / 8)
  local offset = index % 8
  local value = vm.screen[byte_index]
  local mask = rshift(0x80, offset)

  if on then
    value = bor(value, mask)
  else
    value = band(value, bnot(mask))
  end

  vm.screen[byte_index] = value
end

function chip8_mt.run(vm)
  local scale_x, scale_y = 10, 10
  local app = RenderWindow(VideoMode(SCREEN_WIDTH * scale_x, SCREEN_HEIGHT * scale_y), "CHIP-8")

  local rect_shape = sfml_graphics.RectangleShape()
  rect_shape:setSize(scale_x, scale_y)
  rect_shape:setFillColor(Color(0x8F, 0x91, 0x85))

  local fps = 60
  local fps_interval_ms = 1000.0 / fps -- ms
  local clock = Clock()
  clock:restart()

  while app:isOpen() do
    repeat
      local has_event, evt = app:pollEvent()
      if has_event then
        if evt.type == C.sfEvtClosed then
          app:close()
          break
        end
      end
    until has_event == false

    if clock:getElapsedTime():asMilliseconds() >= fps_interval_ms then
      app:clear(Color(0x11, 0x1D, 0x2B))
      for y = 0, SCREEN_HEIGHT - 1 do
        for x = 0, SCREEN_WIDTH - 1 do
          local screen_pixel = vm:get_pixel(x, y)
          if screen_pixel ~= 0 then
            rect_shape:setPosition(x * scale_x, y * scale_y)
            app:drawRectangleShape(rect_shape)
          end
        end
      end
      app:display()
      clock:restart()
    end

    Sleep(1)
  end
end

ffi.metatype("chip8_t", chip8_mt)

local function Chip8(rom, rom_size)
  local vm = ffi_new "chip8_t"

  if rom ~= nil then
    rom_size = rom_size or #rom
    ffi_copy(vm.ram + ENTRY_BASE, rom, rom_size)
    vm.rom_size = rom_size
  end

  vm.screen = vm.ram + 0xf00
  vm.stack = ffi_cast("uint16_t *", vm.ram + 0xea0)
  vm.pc = ENTRY_BASE

  return vm
end

_M.Chip8 = Chip8

local function readfile(filename)
  local file = io.open(filename, "rb")
  if file then
    local content = file:read "*a"
    file:close()
    return content
  end
end

-- tests
local function test_00e0()
  local vm = Chip8 "\x00\xe0"

  vm.screen[10] = 1
  vm:execute_next_opcode()
  for i = 0, 255 do
    assert(vm.screen[i] == 0)
  end
end

-- main
local mod_name = ...
local argc = #arg
if mod_name == nil then
  local rom = readfile "roms/IBM"
  local vm = Chip8(rom)

  vm:run()
end

return _M
