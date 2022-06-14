local ffi = require "ffi"
local string = require "string"

local sfml = require "sfml"

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
    return ffi.load(package.searchpath(bind_args.name or "csfml-graphics-2", bind_args.path))
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

  local sfRenderWindow_mt = aux.class()
  local sfTexture_mt = aux.class()
  local sfSprite_mt = aux.class()
  local sfRectangleShape_mt = aux.class()

  -----------------------------------------------------------
  --  Functions
  -----------------------------------------------------------
  ffi.cdef [[
    sfRenderWindow* sfRenderWindow_create(sfVideoMode mode, const char* title, sfUint32 style, const sfContextSettings* settings);
    void sfRenderWindow_destroy(sfRenderWindow* renderWindow);

    sfBool sfRenderWindow_isOpen(const sfRenderWindow* renderWindow);
    void sfRenderWindow_display(sfRenderWindow* renderWindow);
    sfBool sfRenderWindow_pollEvent(sfRenderWindow* renderWindow, sfEvent* event);
    void sfRenderWindow_clear(sfRenderWindow* renderWindow, sfColor color);
    void sfRenderWindow_close(sfRenderWindow* renderWindow);
    void sfRenderWindow_setVerticalSyncEnabled(sfRenderWindow* renderWindow, sfBool enabled);
    void sfRenderWindow_setFramerateLimit(sfRenderWindow* renderWindow, unsigned int limit);

    void sfRenderWindow_drawSprite(sfRenderWindow* renderWindow, const sfSprite* object, const sfRenderStates* states);
    void sfRenderWindow_drawRectangleShape(sfRenderWindow* renderWindow, const sfRectangleShape* object, const sfRenderStates* states);
  ]]

  function funcs.sfColor_new(r, g, b, a)
    a = a or 0xFF

    return ffi_new("sfColor", { r, g, b, a })
  end

  -- sfRenderWindow
  function funcs.sfRenderWindow_create(mode, title, style, settings)
    style = style or clib.sfDefaultStyle

    return clib.sfRenderWindow_create(mode, title, style, settings)
  end

  function funcs.sfRenderWindow_destroy(thiz)
    clib.sfRenderWindow_destroy(thiz)
  end

  function funcs.sfRenderWindow_isOpen(thiz)
    return aux.wrap_bool(clib.sfRenderWindow_isOpen(thiz))
  end

  function funcs.sfRenderWindow_display(thiz)
    clib.sfRenderWindow_display(thiz)
  end

  function funcs.sfRenderWindow_pollEvent(thiz)
    local p_event = ffi_new "sfEvent[1]"
    local rv = aux.wrap_bool(clib.sfRenderWindow_pollEvent(thiz, p_event))
    return rv, p_event[0]
  end

  function funcs.sfRenderWindow_clear(thiz, color)
    clib.sfRenderWindow_clear(thiz, color)
  end

  function funcs.sfRenderWindow_close(thiz)
    clib.sfRenderWindow_close(thiz)
  end

  function funcs.sfRenderWindow_setVerticalSyncEnabled(thiz, enabled)
    clib.sfRenderWindow_setVerticalSyncEnabled(thiz, enabled)
  end

  function funcs.sfRenderWindow_setFramerateLimit(thiz, limit)
    clib.sfRenderWindow_setFramerateLimit(thiz, limit)
  end

  function funcs.sfRenderWindow_drawSprite(thiz, object, states)
    clib.sfRenderWindow_drawSprite(thiz, object, states)
  end

  function funcs.sfRenderWindow_drawRectangleShape(thiz, object, states)
    clib.sfRenderWindow_drawRectangleShape(thiz, object, states)
  end

  -- sfTexture
  ffi.cdef [[
    sfTexture* sfTexture_create(unsigned int width, unsigned int height);
    sfTexture* sfTexture_createFromFile(const char* filename, const sfIntRect* area);
    void sfTexture_destroy(sfTexture* texture);
  ]]

  function funcs.sfTexture_create(width, height)
    return clib.sfTexture_create(width, height)
  end

  function funcs.sfTexture_createFromFile(filename, area)
    return clib.sfTexture_createFromFile(filename, area)
  end

  function funcs.sfTexture_destroy(thiz)
    clib.sfTexture_destroy(thiz)
  end

  -- sfSprite
  ffi.cdef [[
    sfSprite* sfSprite_create(void);
    void sfSprite_destroy(sfSprite* sprite);

    void sfSprite_setTexture(sfSprite* sprite, const sfTexture* texture, sfBool resetRect);
    void sfSprite_setTextureRect(sfSprite* sprite, sfIntRect rectangle);
    void sfSprite_setPosition(sfSprite* sprite, sfVector2f position);
  ]]

  function funcs.sfSprite_create()
    return clib.sfSprite_create()
  end

  function funcs.sfSprite_setTexture(thiz, texture, resetRect)
    if resetRect == nil then
      resetRect = true
    end
    clib.sfSprite_setTexture(thiz, texture, aux.bool_to_int(resetRect))
  end

  function funcs.sfSprite_destroy(thiz)
    clib.sfSprite_destroy(thiz)
  end

  function funcs.sfSprite_setTextureRect(thiz, left, top, width, height)
    clib.sfSprite_setTextureRect(thiz, sfml.IntRect(left, top, width, height))
  end

  function funcs.sfSprite_setPosition(thiz, x, y)
    clib.sfSprite_setPosition(thiz, sfml.Vector2f(x, y))
  end

  -- sfRectangleShape
  ffi.cdef [[
    sfRectangleShape* sfRectangleShape_create();
    void sfRectangleShape_destroy(sfRectangleShape* shape);

    void sfRectangleShape_setSize(sfRectangleShape* shape, sfVector2f size);
    void sfRectangleShape_setFillColor(sfRectangleShape* shape, sfColor color);
    void sfRectangleShape_setScale(sfRectangleShape* shape, sfVector2f scale);
    void sfRectangleShape_setPosition(sfRectangleShape* shape, sfVector2f position);
  ]]

  function funcs.sfRectangleShape_create()
    return clib.sfRectangleShape_create()
  end

  function funcs.sfRectangleShape_setSize(thiz, width, height)
    clib.sfRectangleShape_setSize(thiz, sfml.Vector2f(width, height))
  end

  function funcs.sfRectangleShape_setFillColor(thiz, color)
    clib.sfRectangleShape_setFillColor(thiz, color)
  end

  function funcs.sfRectangleShape_setScale(thiz, scale_x, scale_y)
    clib.sfRectangleShape_setScale(thiz, sfml.Vector2f(scale_x, scale_y))
  end

  function funcs.sfRectangleShape_setPosition(thiz, x, y)
    clib.sfRectangleShape_setPosition(thiz, sfml.Vector2f(x, y))
  end

  -----------------------------------------------------------
  --  Extended Functions
  -----------------------------------------------------------
  mod.Color = funcs.sfColor_new
  mod.RenderWindow = funcs.sfRenderWindow_create
  mod.Texture = funcs.sfTexture_create
  mod.sfTexture_createFromFile = funcs.sfTexture_createFromFile
  mod.Sprite = funcs.sfSprite_create
  mod.RectangleShape = funcs.sfRectangleShape_create

  -----------------------------------------------------------
  --  Metatables
  -----------------------------------------------------------
  sfRenderWindow_mt.isOpen = funcs.sfRenderWindow_isOpen
  sfRenderWindow_mt.display = funcs.sfRenderWindow_display
  sfRenderWindow_mt.pollEvent = funcs.sfRenderWindow_pollEvent
  sfRenderWindow_mt.clear = funcs.sfRenderWindow_clear
  sfRenderWindow_mt.close = funcs.sfRenderWindow_close
  sfRenderWindow_mt.setVerticalSyncEnabled = funcs.sfRenderWindow_setVerticalSyncEnabled
  sfRenderWindow_mt.setFramerateLimit = funcs.sfRenderWindow_setFramerateLimit
  sfRenderWindow_mt.drawSprite = funcs.sfRenderWindow_drawSprite
  sfRenderWindow_mt.drawRectangleShape = funcs.sfRenderWindow_drawRectangleShape
  sfRenderWindow_mt.__gc = function(self)
    funcs.sfRenderWindow_destroy(self)
  end

  sfTexture_mt.__gc = function(self)
    funcs.sfTexture_destroy(self)
  end

  sfSprite_mt.setTexture = funcs.sfSprite_setTexture
  sfSprite_mt.setTextureRect = funcs.sfSprite_setTextureRect
  sfSprite_mt.setPosition = funcs.sfSprite_setPosition
  sfSprite_mt.__gc = function(self)
    funcs.sfSprite_destroy(self)
  end

  sfRectangleShape_mt.setSize = funcs.sfRectangleShape_setSize
  sfRectangleShape_mt.setFillColor = funcs.sfRectangleShape_setFillColor
  sfRectangleShape_mt.setScale = funcs.sfRectangleShape_setScale
  sfRectangleShape_mt.setPosition = funcs.sfRectangleShape_setPosition
  sfRectangleShape_mt.__gc = function(self)
    funcs.sfRectangleShape_destroy(self)
  end

  -----------------------------------------------------------
  --  Finalize types metatables
  -----------------------------------------------------------
  ffi.metatype("sfRenderWindow", sfRenderWindow_mt)
  ffi.metatype("sfTexture", sfTexture_mt)
  ffi.metatype("sfSprite", sfSprite_mt)
  ffi.metatype("sfRectangleShape", sfRectangleShape_mt)
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

function aux.bool_to_int(lua_bool)
  return lua_bool and 1 or 0
end

-- mod
return setmetatable(mod, { __call = init })
