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
    return ffi.load(package.searchpath(bind_args.name or "csfml-system-2", bind_args.path))
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

  local sfClock_mt = aux.class()
  local sfTime_mt = aux.class()

  -----------------------------------------------------------
  --  Functions
  -----------------------------------------------------------
  ffi.cdef [[
    void sfSleep(sfTime duration);
  ]]

  function funcs.sfSleep(ms)
    local tm = ffi_new("sfTime", { ms * 1000 })
    clib.sfSleep(tm)
  end

  -- sfClock
  ffi.cdef [[
    sfClock* sfClock_create(void);
    void sfClock_destroy(sfClock* clock);

    sfTime sfClock_getElapsedTime(const sfClock* clock);
    sfTime sfClock_restart(sfClock* clock);
  ]]

  function funcs.sfClock_create()
    return clib.sfClock_create()
  end

  function funcs.sfClock_destroy(thiz)
    clib.sfClock_destroy(thiz)
  end

  function funcs.sfClock_getElapsedTime(thiz)
    return clib.sfClock_getElapsedTime(thiz)
  end

  function funcs.sfClock_restart(thiz)
    return clib.sfClock_restart(thiz)
  end

  -- sfTime
  ffi.cdef [[
    sfTime sfSeconds(float amount);
    sfTime sfMilliseconds(sfInt32 amount);
    sfTime sfMicroseconds(sfInt64 amount);

    float sfTime_asSeconds(sfTime time);
    sfInt32 sfTime_asMilliseconds(sfTime time);
    sfInt64 sfTime_asMicroseconds(sfTime time);
  ]]

  function funcs.sfTime_asSeconds(thiz)
    return clib.sfTime_asSeconds(thiz)
  end

  function funcs.sfTime_asMilliseconds(thiz)
    return clib.sfTime_asMilliseconds(thiz)
  end

  function funcs.sfTime_asMicroseconds(thiz)
    return clib.sfTime_asMicroseconds(thiz)
  end

  -----------------------------------------------------------
  --  Extended Functions
  -----------------------------------------------------------
  mod.Sleep = funcs.sfSleep
  mod.Clock = funcs.sfClock_create
  mod.Time = setmetatable({
    CreateFromSeconds = function(amount)
      return clib.sfSeconds(amount)
    end,
    CreateFromMilliseconds = function(amount)
      return clib.sfMilliseconds(amount)
    end,
    CreateFromMicroseconds = function(amount)
      return clib.sfMicroseconds(amount)
    end,
  }, {})

  -----------------------------------------------------------
  --  Metatables
  -----------------------------------------------------------
  sfClock_mt.getElapsedTime = funcs.sfClock_getElapsedTime
  sfClock_mt.restart = funcs.sfClock_restart
  sfClock_mt.__gc = function(self)
    funcs.sfClock_destroy(self)
  end

  sfTime_mt.asSeconds = funcs.sfTime_asSeconds
  sfTime_mt.asMilliseconds = funcs.sfTime_asMilliseconds
  sfTime_mt.asMicroseconds = funcs.sfTime_asMicroseconds

  -----------------------------------------------------------
  --  Finalize types metatables
  -----------------------------------------------------------
  ffi.metatype("sfClock", sfClock_mt)
  ffi.metatype("sfTime", sfTime_mt)
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
