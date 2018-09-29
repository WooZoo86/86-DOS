local fs = _G.filesystem
local args = {...}
local dir = "a"
local tab = 12

function isDrive(name)
    local code = string.byte(name, 1, 1)
    return #name == 1 and code >= string.byte("A") and code <= _G.lastDrive
end
function digits(num)
    return tostring(num):len()
end
function fileCount(directory)
    local r = 0
    for file in fs.list(directory) do
        file = string.lower(fs.name(file))
        if fs.isDirectory(directory .. "/" .. file)  then
            r = r + fileCount(directory .. "/" .. file)
        else
            r = r + 1
        end
    end
    return r
end

if args and #args > 0 and args[1] then
    dir = string.lower(args[1])
    if dir:sub(#dir) == ":" then
        dir = dir:sub(1, #dir - 1)
    end
    if not isDrive(string.upper(dir)) then
        io.write('Drive must be specified (e.g., "B:")\n')
        return
    end
end
io.write("Address: " .. _G.drives[dir] .. '\n')
local ans1 = fileCount(dir)
local proxy = _G.component.proxy(_G.drives[dir])
if not proxy then
    io.write("Bad proxy\n")
    return
end
local ans2 = proxy.spaceTotal()
local ans3 = ans2 - proxy.spaceUsed()
io.write(string.rep(' ', tab - digits(ans1)) .. ans1 .. " disk files\n")
io.write(string.rep(' ', tab - digits(ans2)) .. math.floor(ans2) .. " bytes total disk space\n")
io.write(string.rep(' ', tab - digits(ans3)) .. math.floor(ans3) .. " bytes remain available\n")
io.write("\n")
local ans4 = computer.totalMemory()
local ans5 = computer.freeMemory()
io.write(string.rep(' ', tab - digits(ans4)) .. math.floor(ans4) .. " bytes total system RAM\n")
io.write(string.rep(' ', tab - digits(ans5)) .. math.floor(ans5) .. " bytes free\n")
io.write("\n")
