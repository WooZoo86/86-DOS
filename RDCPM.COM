local fs = _G.filesystem
local shell = require("MON")

local args, options = shell.parse(...)
if #args < 2 then
    io.write("File not found\n")
    return
end

local from = {}
for i = 1, #args - 1 do
    table.insert(from, string.lower(args[i]))
end
local to = string.lower(args[#args])

local result, reason
local c = 0

local function areEqual(path1, path2)
    local f1 = io.open(path1, "rb")
    if not f1 then
        return nil, "could not open `" .. path1 .. "' for update test"
    end
    local f2 = io.open(path2, "rb")
    if not f2 then
        f1:close()
        return nil, "could not open `" .. path2 .. "' for update test"
    end
    local result = true
    local chunkSize = 4 * 1024
    repeat
        local s1, s2 = f1:read(chunkSize), f2:read(chunkSize)
        if s1 ~= s2 then
            result = false
            break
        end
    until not s1 or not s2
    f1:close()
    f2:close()
    return result
end

local function isMount(path)
    path = fs.canonical(path)
    for _, mountPath in fs.mounts() do
        if path == fs.canonical(mountPath) then
            return true
        end
    end
end

local function recurse(fromPath, toPath)
    if fs.isDirectory(fromPath) then
        --if not options.r then
        --    return true
        --end
        if fs.canonical(fromPath) == fs.canonical(fs.path(toPath)) then
            return nil, "cannot copy a directory, `" .. fromPath .. "', into itself, `" .. toPath .. "'\n"
        end
        if fs.exists(toPath) and not fs.isDirectory(toPath) then
            return nil, "cannot overwrite non-directory `" .. toPath .. "' with directory `" .. fromPath .. "'"
        end
        if options.x and isMount(fromPath) then
            return true
        end
        fs.makeDirectory(toPath)
        for file in fs.list(fromPath) do
            local result, reason = recurse(fs.concat(fromPath, file), fs.concat(toPath, file))
            if not result then
                return nil, reason
            end
        end
        return true
    else
        if fs.exists(toPath) then
            if fs.canonical(fromPath) == fs.canonical(toPath) then
                return nil, "`" .. fromPath .. "' and `" .. toPath .. "' are the same file"
            end
            if fs.isDirectory(toPath) then
                if options.i then
                    --if not prompt("overwrite `" .. toPath .. "'?") then
                    --    return true
                    --end
                elseif options.n then
                    return true
                else
                    return nil, "cannot overwrite directory `" .. toPath .. "' with non-directory"
                end
            else
                if options.u then
                    if areEqual(fromPath, toPath) then
                        return true
                    end
                end
                if options.i then
                    --if not prompt("overwrite `" .. toPath .. "'?") then
                    --    return true
                    --end
                elseif options.n then
                    return true
                end
            end
            fs.remove(toPath)
        end
        local a, b = fs.copy(fromPath, toPath)
        if a then
            c = c + 1
        end
        return a, b
    end
end
for _, fromPath in ipairs(from) do
    local toPath = to
    if fs.isDirectory(toPath) then
        toPath = fs.concat(toPath, fs.name(fromPath))
    end
    result, reason = recurse(fromPath, toPath)
    if not result then
        io.stderr:write((reason or "Unknown error") .. '\n')
    end
end
local cnt = tostring(c)
io.write(string.rep(' ', 12 - #cnt) .. cnt .. " File(s) copied\n")
