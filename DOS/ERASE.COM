local fs = _G.filesystem
local shell = require("MON")

local args, options = shell.parse(...)
if #args < 1 then
    io.write("File not found\n")
    return
end

local result, reason = fs.remove(args[1])
if not result then
    io.stderr:write((reason or "Unknown error") .. '\n')
end
