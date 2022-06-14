local ffi = require "ffi"

require "sfml.base"

local ffi_new = ffi.new

local _M = {}

function _M.IntRect(left, top, width, height)
  return ffi_new("sfIntRect", { left, top, width, height })
end

function _M.Vector2i(x, y)
  return ffi_new("sfVector2i", { x, y })
end

function _M.Vector2f(x, y)
  return ffi_new("sfVector2f", { x, y })
end

return _M
