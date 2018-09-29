local fs = _G.filesystem
local unicode = _G.unicode
local args, opts = require("MON").parse(...)
local dir = "/"

function isDrive(name)
    local code = string.byte(name, 1, 1)
    return #name == 1 and code >= string.byte("A") and code <= _G.lastDrive
end

if args and #args > 0 and args[1] then
    dir = string.lower(args[1])
    while dir:sub(#dir) == ":" do
        dir = dir:sub(1, #dir - 1)
    end
    if fs.isDirectory(dir) then
        if dir:sub(#dir) ~= "/" then
            dir = dir .. "/"
        end
    else
        io.write("File not found\n")
        return
    end
end

for file in fs.list(dir) do
    file = unicode.upper(fs.name(file))
    if not isDrive(file) then
        if fs.isDirectory(dir .. file) then
            file = file .. '/'
        end
        local dot
        for i = #file, 1, -1 do
            if file:byte(i, i) == string.byte(".") then
                dot = i
                break
            end
        end
        if dot then
            io.write(string.sub(file, 1, dot - 1)
                    .. string.rep(' ', 10 - dot)
                    .. string.sub(file, dot + 1))
        else
            io.write(file .. '\t')
        end
        io.write('\t')
        file = dir .. file
        if not fs.isDirectory(file) then
            io.write(math.floor(fs.size(file)) .. '\t' .. os.date("%d-%m-%Y", fs.lastModified(file)))
        end
        io.write('\n')
    end
end
io.write('\n')
