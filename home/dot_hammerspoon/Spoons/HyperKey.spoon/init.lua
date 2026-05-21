--- HyperKey.spoon
--- Maps right command to hyper (ctrl + alt + shift + cmd)

local obj = {}
obj.__index = obj

obj.name    = "HyperKey"
obj.version = "1.0"
obj.author  = "Jack Jennings"
obj.license = "MIT"

function obj:init()
  local hyperActive  = false
  local prevRawFlags = 0

  self._watcher = hs.eventtap.new({
    hs.eventtap.event.types.flagsChanged,
    hs.eventtap.event.types.keyDown,
    hs.eventtap.event.types.keyUp,
  }, function(event)
    local t = event:getType()

    if t == hs.eventtap.event.types.flagsChanged then
      local rawFlags   = event:rawFlags()
      local wasRightCmd = (prevRawFlags & 0x000010) ~= 0
      local isRightCmd  = (rawFlags     & 0x000010) ~= 0
      prevRawFlags = rawFlags

      if isRightCmd and not wasRightCmd then
        hyperActive = true
        return true  -- suppress right-cmd down
      elseif not isRightCmd and wasRightCmd then
        hyperActive = false
        return true  -- suppress right-cmd up
      end
      return false

    elseif hyperActive and (t == hs.eventtap.event.types.keyDown or
                            t == hs.eventtap.event.types.keyUp) then
      event:setFlags({ ctrl = true, alt = true, shift = true, cmd = true })
      return false  -- let the re-flagged event through
    end
  end)

  return self
end

function obj:start()
  self._watcher:start()
  return self
end

function obj:stop()
  self._watcher:stop()
  return self
end

return obj
