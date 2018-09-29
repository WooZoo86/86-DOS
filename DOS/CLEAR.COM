local fs = _G.filesystem
local args = {...}

function isDrive(name)
    local code = string.byte(name, 1, 1)
    return #name == 1 and code >= string.byte("A") and code <= _G.lastDrive
end
local function prompt(message)
    io.write(message .. " (Y/N)? ")
    local result = io.read()
    return result and (result == "" or result:sub(1, 1):lower() == "y")
end

if args and #args > 0 and args[1] then
    args[1] = string.lower(args[1])
    while args[1]:sub(#args[1]) == ":" do
        args[1] = args[1]:sub(1, #args[1] - 1)
    end
    if not isDrive(string.upper(args[1])) then
        io.write("Bad drive specification\n")
        return
    end
    if _G.component.proxy(_G.drives[args[1]]).isReadOnly() then
        io.write("Drive is read-only\n")
        return
    end
else
    io.write('Drive must be specified (e.g., "B:")\n')
    return
end
if prompt("Erase all files on drive " .. string.upper(args[1])) then
    local c = 0
    for file in fs.list(args[1]) do
        local result, reason = fs.remove(args[1] .. "/" .. file)
        if not result then
            io.stderr:write((reason or "Unknown error") .. '\n')
            return
        end
        c = c + 1
    end
    if c == 0 then
        io.write("Drive is already empty\n")
    end
end
