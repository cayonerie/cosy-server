local Model = require "cosy.server.model"
local Util  = require "lapis.util"

do
  local Function = debug.getmetatable (function () end) or {}
  function Function.__concat (lhs, rhs)
    assert (type (lhs) == "function")
    assert (type (rhs) == "function")
    return lhs (rhs)
  end
  debug.setmetatable (function () end, Function)
end

local Decorators = {}

function Decorators.optional (option)
  return function (f)
    return function (self)
      local result = option (f) (self)
      if type (result) == "table" and result.status ~= 404 then
        return result
      end
      return f (self)
    end
  end
end

function Decorators.is_authentified (f)
  return function (self)
    if not self.token then
      return { status = 401 }
    end
    local id = Model.identities:find (self.token.sub)
    if not id then
      return { status = 401 }
    end
    self.authentified = id:get_user ()
    return f (self)
  end
end

function Decorators.param_is_identifier (parameter)
  return function (f)
    return function (self)
      self.params [parameter] = Util.unescape (self.params [parameter])
      if not self.params [parameter]:match "[%w-_]+" then
        return { status = 400 }
      end
      return f (self)
    end
  end
end

function Decorators.param_is_serial (parameter)
  return function (f)
    return function (self)
      self.params [parameter] = Util.unescape (self.params [parameter])
      if not tonumber (self.params [parameter]) then
        return { status = 400 }
      end
      return f (self)
    end
  end
end

function Decorators.param_is_user (parameter)
  return function (f)
    return Decorators.param_is_serial (parameter) ..
           function (self)
      local id   = self.params [parameter]
      local user = Model.users:find (id)
      if not user then
        return { status = 404 }
      end
      self.user = user
      return f (self)
    end
  end
end

function Decorators.param_is_project (parameter)
  return function (f)
    return Decorators.param_is_serial (parameter) ..
           function (self)
      local id      = self.params [parameter]
      local project = Model.projects:find (id)
      if not project then
        return { status = 404 }
      end
      self.project = project
      return f (self)
    end
  end
end

function Decorators.param_is_tag (parameter)
  return function (f)
    return Decorators.param_is_identifier (parameter) ..
           function (self)
      local id  = self.params [parameter]
      local tag = Model.tags:find {
        id         = id,
        project_id = self.project.id,
      }
      if not tag then
        return { status = 404 }
      end
      self.tag = tag
      return f (self)
    end
  end
end

function Decorators.param_is_resource (parameter)
  return function (f)
    return Decorators.param_is_serial (parameter) ..
           function (self)
      local id       = self.params [parameter]
      local resource = Model.resources:find (id)
      if not resource then
        return { status = 404 }
      end
      if resource.project_id ~= self.project.id then
        return { status = 404 }
      end
      self.resource = resource
      return f (self)
    end
  end
end

return Decorators
