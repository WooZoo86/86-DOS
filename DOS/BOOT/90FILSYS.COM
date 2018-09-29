local event = require("EVENT")
local fs = _G.filesystem
local shell = require("MON")
local tmp = computer.tmpAddress()

local pendingAutoruns = {}

local function onComponentAdded(_, address, componentType)
  if componentType == "filesystem" and tmp ~= address and _G.lastDrive ~= string.byte('Z') then
    local proxy = fs.proxy(address)
    if proxy then
      --[[local name = address:sub(1, 3)
      while fs.exists(fs.concat("/", name)) and
            name:len() < address:len() -- just to be on the safe side
      do
        name = address:sub(1, name:len() + 1)
      end
      name = fs.concat("/", name)]]--
      local name = "a"
      if computer.getBootAddress() ~= address then
        _G.lastDrive = _G.lastDrive + 1
        name = string.lower(string.char(_G.lastDrive))
      end
      if fs.exists(fs.concat("/", name)) then
        if not fs.remove(fs.concat("/", name)) then
          error("Can't mount drive " .. name)
          return
        end
      end
      _G.drives[name] = address
      fs.mount(proxy, name)
      if fs.isAutorunEnabled() then
        local file = shell.resolve(fs.concat(name, "autorun"), "lua") or
                      shell.resolve(fs.concat(name, ".autorun"), "lua")
        if file then
          local run = {file, _ENV, proxy}
          if pendingAutoruns then
            table.insert(pendingAutoruns, run)
          else
            xpcall(shell.execute, event.onError, table.unpack(run))
          end
        end
      end
    end
  end
end

local function onComponentRemoved(_, address, componentType)
  if componentType == "filesystem" then
    if fs.get(shell.getWorkingDirectory()).address == address then
      shell.setWorkingDirectory("/")
    end
    fs.umount(address)
  end
end

event.listen("init", function()
  for _, run in ipairs(pendingAutoruns) do
    xpcall(shell.execute, event.onError, table.unpack(run))
  end
  pendingAutoruns = nil
  return false
end)

event.listen("component_added", onComponentAdded)
event.listen("component_removed", onComponentRemoved)

_G.package.delay(fs, "/DOS/LIB/CORE/FULLFLST.ASM")
