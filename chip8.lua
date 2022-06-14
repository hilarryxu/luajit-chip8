local ffi = require "ffi"
local bit = require "bit"
local string = require "string"

local ffi_new, ffi_cast, ffi_copy = ffi.new, ffi.cast, ffi.copy
local bnot = bit.bnot
local band, bor, bxor = bit.band, bit.bor, bit.bxor
local lshift, rshift = bit.lshift, bit.rshift
local str_fmt = string.format

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
  -- _p("pc: 0x%03x, opcode: %04x", vm.pc - 2, opcode)

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
  test_00e0()
end

return _M
