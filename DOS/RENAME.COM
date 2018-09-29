local fs = _G.filesystem
local shell = require("MON")

local args, options = shell.parse(...)
if #args < 2 then
  io.write("File not found\n")
  return
end

local result, reason = fs.rename(args[1], args[2])
if not result then
  io.stderr:write((reason or "Unknown error") .. '\n')
end
