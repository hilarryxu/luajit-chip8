local ffi = require "ffi"
local string = require "string"

local ffi_new = ffi.new
local ffi_str = ffi.string
local ffi_cast = ffi.cast
local str_fmt = string.format

local mod = {}
local aux = {}

local is_luajit = pcall(require, "jit")
local bind_args
local clib

local load_clib, bind_clib -- Forward declaration

local function init(mod, name_or_args)
  if clib ~= nil then
    return mod
  end

  if type(name_or_args) == "table" then
    bind_args = name_or_args
    bind_args.name = bind_args.name or bind_args[1]
  elseif type(name_or_args) == "string" then
    bind_args = {}
    bind_args.path = name_or_args
  end

  clib = load_clib()
  bind_clib()

  return mod
end

function load_clib()
  if bind_args.clib ~= nil then
    return bind_args.clib
  end

  if type(bind_args.path) == "string" then
    return ffi.load(package.searchpath(bind_args.name or "csfml-window-2", bind_args.path))
  end

  -- If no library or name is provided, we just
  -- assume that the appropriate libraries
  -- are statically linked to the calling program
  return ffi.C
end

function bind_clib()
  -----------------------------------------------------------
  --  Namespaces
  -----------------------------------------------------------
  local consts = {} -- Table for contants
  local funcs = {} -- Table for functions
  local types = {} -- Table for types
  local cbs = {} -- Table for callbacks

  mod.consts = consts
  mod.funcs = funcs
  mod.types = types
  mod.cbs = cbs
  mod.clib = clib

  -- Access to funcs from module namespace by default
  aux.set_mt_method(mod, "__index", funcs)

  -----------------------------------------------------------
  --  Constants
  -----------------------------------------------------------

  -- For C pointers comparison
  if not is_luajit then
    consts.NULL = ffi.C.NULL
  end

  -----------------------------------------------------------
  --  Types
  -----------------------------------------------------------
  require "sfml.base"

  -----------------------------------------------------------
  --  Functions
  -----------------------------------------------------------
  ffi.cdef [[
    sfVideoMode sfVideoMode_getDesktopMode(void);
    sfBool sfVideoMode_isValid(sfVideoMode mode);
  ]]

  -- sfVideoMode
  function funcs.sfVideoMode_new(width, height, bitsPerPixel)
    bitsPerPixel = bitsPerPixel or 32

    return ffi_new("sfVideoMode", { width, height, bitsPerPixel })
  end

  function funcs.sfVideoMode_getDesktopMode()
    return clib.sfVideoMode_getDesktopMode()
  end

  function funcs.sfVideoMode_isValid(mode)
    return clib.sfVideoMode_isValid(mode)
  end

  -- sfMouse
  ffi.cdef [[
    sfBool sfMouse_isButtonPressed(sfMouseButton button);
    sfVector2i sfMouse_getPosition(const void* relativeTo);  // const sfWindow* relativeTo
    void sfMouse_setPosition(sfVector2i position, const void* relativeTo);  // const sfWindow* relativeTo
  ]]

  function funcs.sfMouse_isButtonPressed(button)
    return clib.sfMouse_isButtonPressed(button)
  end

  function funcs.sfMouse_getPosition(relativeTo)
    return clib.sfMouse_getPosition(relativeTo)
  end

  function funcs.sfMouse_setPosition(position, relativeTo)
    clib.sfMouse_setPosition(position, relativeTo)
  end

  -- sfKeyboard
  ffi.cdef [[
    sfBool sfKeyboard_isKeyPressed(sfKeyCode key);
  ]]

  function funcs.sfKeyboard_isKeyPressed(key)
    return clib.sfKeyboard_isKeyPressed(key)
  end

  --
  -----------------------------------------------------------
  --  Extended Functions
  -----------------------------------------------------------
  mod.VideoMode = funcs.sfVideoMode_new
  mod.sfVideoMode_getDesktopMode = funcs.sfVideoMode_getDesktopMode
  mod.sfVideoMode_isValid = funcs.sfVideoMode_isValid
  mod.sfMouse_isButtonPressed = funcs.sfMouse_isButtonPressed
  mod.sfMouse_getPosition = funcs.sfMouse_getPosition
  mod.sfMouse_setPosition = funcs.sfMouse_setPosition
  mod.sfKeyboard_isKeyPressed = funcs.sfKeyboard_isKeyPressed

  -----------------------------------------------------------
  --  Metatables
  -----------------------------------------------------------

  -----------------------------------------------------------
  --  Finalize types metatables
  -----------------------------------------------------------
end

-----------------------------------------------------------
--  Auxiliary
-----------------------------------------------------------
function aux.class()
  local class = {}
  class.__index = class
  return class
end

function aux.set_mt_method(t, k, v)
  local mt = getmetatable(t)
  if mt then
    mt[k] = v
  else
    setmetatable(t, { [k] = v })
  end
end

if is_luajit then
  -- LuaJIT way to compare with NULL
  function aux.is_null(ptr)
    return ptr == nil
  end
else
  -- LuaFFI way to compare with NULL
  function aux.is_null(ptr)
    return ptr == ffi.C.NULL
  end
end

function aux.wrap_string(cstr)
  if not aux.is_null(cstr) then
    return ffi_str(cstr)
  end
  return nil
end

function aux.wrap_bool(c_bool)
  return c_bool ~= 0
end

-- mod
return setmetatable(mod, { __call = init })
