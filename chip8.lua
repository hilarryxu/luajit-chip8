local ffi = require "ffi"

local ffi_new, ffi_cast, ffi_copy = ffi.new, ffi.cast, ffi.copy

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
} chip8_t;
]]

local ENTRY_BASE = 0x200

local aux = {}
local _M = {}

function aux.class()
  local class = {}
  class.__index = class
  return class
end

local chip8_mt = aux.class()

ffi.metatype("chip8_t", chip8_mt)


local function Chip8(rom, rom_size)
  local vm = ffi_new "chip8_t"

  if rom ~= nil then
    rom_size = rom_size or #rom
    ffi_copy(vm.ram + ENTRY_BASE, rom, rom_size)
  end

  vm.screen = vm.ram + 0xf00
  vm.stack = ffi_cast("uint16_t *", vm.ram + 0xea0)
  vm.pc = ENTRY_BASE

  return vm
end

_M.Chip8 = Chip8

-- main
local argc = #arg
if true then
  local vm = Chip8()

  assert(vm.I == 0, "I == 0")
  assert(vm.pc == ENTRY_BASE, "vm.pc == ENTRY_BASE")
end
