local Util = {}

local class_metatable = {}

function class_metatable.__call(class, ...)
   local obj = setmetatable({}, class)

   if class.__init then
      class.__init(obj, ...)
   end

   return obj
end

function Util.class()
   local class = setmetatable({}, class_metatable)
   class.__index = class
   return class
end

function Util.is_instance(object, class)
   return rawequal(debug.getmetatable(object), class)
end

return Util
