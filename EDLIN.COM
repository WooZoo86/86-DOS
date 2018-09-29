io.write("\nEDLIN  version 1.00\n")

local args = {...}
local fs = _G.filesystem
local text = {}
local cur = 1

function parseLine(str)
    if str == "#" then
        return #text + 1
    elseif str == "." then
        return cur
    else
        return tonumber(str)
    end
end
function parseRange(str)
    local comma = string.find(str, ',')
    local first, last
    if comma then
        first = parseLine(string.sub(str, 1, comma - 1))
        last = parseLine(string.sub(str, comma + 1, #str))
    else
        first = parseLine(string.sub(str, 1, #str))
        last = nil
    end
    return first, last
end
function prompt()
    local cmd2 = io.read()
    while type(cmd2) == "boolean" do
        cmd2 = io.read()
    end
    cmd2 = cmd2:gsub(' ', '')
    return string.lower(cmd2) == "y" or #cmd2 == 0
end
function replace(str, what, with)
    what = string.gsub(what, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
    with = string.gsub(with, "[%%]", "%%%%")
    return string.gsub(str, what, with)
end

if args and #args > 0 and args[1] then
    args[1] = string.lower(args[1])
    if args[1]:sub(#args[1] - 3, #args[1]) == ".bak" then
        io.write("Cannot edit .BAK file--rename file\n")
        return
    end
    if not fs.exists(args[1]) then
        io.write("New file\n")
    end
else
    io.write("File name must be specified\n")
    return
end
local file, reason = io.open(args[1], "rb")
if not file then
    io.stderr:write((reason or "Reading error") .. '\n')
    return
end
repeat
    local line = file:read("*L")
    if line then
        if line:sub(#line) == '\n' then
            line = line:sub(1, #line - 1)
        end
        table.insert(text, line)
    end
until not line
file:close()
io.write("End of input file\n")
local dot = #args[1]
for i = #args[1], 1, -1 do
    local c = args[1]:sub(i, i)
    if c == "/" then
        break
    elseif c == "." then
        dot = i
        break
    end
end
local backup = args[1]:sub(1, dot) .. "BAK"
if fs.exists(backup) then
    local result, reason = fs.remove(backup)
    if not result then
        io.write("Can't remove old backup")
        if reason then
            io.write(": " .. reason)
        end
        io.write('\n')
    end
end
local result, reason = fs.rename(args[1], backup)
if not result then
    io.write("Can't make backup")
    if reason then
        io.write(": " .. reason)
    end
    io.write('\n')
end
while true do
    io.write('*')
    local cmd = io.read()
    if type(cmd) == "boolean" then
        cmd = "q"
    end
    cmd = string.lower(string.gsub(cmd, ' ', ''))
    local letter = cmd:sub(#cmd)
    if cmd == "q" or cmd == "e" then
        io.write("Abort edit (Y/N)? ")
        if prompt() then
            local file, reason = io.open(args[1], "w")
            if not file then
                io.stderr:write((reason or "Writing error") .. '\n')
            else
                for i = 1, #text do
                    file:write(text[i] .. '\n')
                end
            end
            file:close()
            return
        end
    elseif letter == "d" then
        local first, last = parseRange(string.sub(cmd, 1, #cmd - 1))
        first = first or cur
        last = last or first
        cur = first
        first = math.max(first, 1)
        last = math.min(last, #text)
        for i = 1, last - first + 1 do
            table.remove(text, first)
        end
    elseif letter == "l" then
        local first, last = parseRange(string.sub(cmd, 1, #cmd - 1))
        first = first or cur
        if not last then
            first = first - 11
            last = first + 22
        end
        first = math.max(first, 1)
        last = math.min(last, #text)
        local len = tostring(last):len()
        for i = first, last do
            local num = tostring(i)
            local mark = ' '
            if i == cur then
                mark = '*'
            end
            io.write(string.rep(' ', len - num:len()) .. num .. mark .. text[i] .. '\n')
        end
    elseif letter == "i" then
        local t = parseLine(string.sub(cmd, 1, #cmd - 1)) or cur
        t = math.max(t, 1)
        t = math.min(t, #text + 1)
        for i = t, math.huge do
            io.write(i .. ':')
            local newLine = io.read()
            if type(newLine) == "boolean" then
                break
            end
            while newLine:sub(#newLine) == '\n' and #newLine > 0 do
                newLine = newLine:sub(1, #newLine - 1)
            end
            table.insert(text, i, newLine)
            cur = i + 1
        end
    elseif letter == "s" then
        local q = false
        if cmd:sub(#cmd - 1, #cmd - 1) == "?" then
            q = true
            cmd = cmd:gsub('?', '')
        end
        local first, last = parseRange(cmd:sub(1, #cmd - 1))
        first = first or 1
        last = last or #text
        first = math.max(first, 1)
        last = math.min(last, #text)
        io.write("Text to search:")
        local toSearch = io.read()
        if type(toSearch) == "string" and #toSearch > 0 then
            local found = false
            for i = first, last do
                if text[i]:find(toSearch, 1, true) then
                    io.write(i .. ':' .. text[i] .. '\n')
                    if not q then
                        found = true
                        cur = i
                        break
                    else
                        io.write("Is this the correct occurence (Y/N)? ")
                        if prompt() then
                            found = true
                            break
                        end
                    end
                end
            end
            if not found then
                io.write("Not found\n")
            end
        end
    elseif letter == "r" then
        local q = false
        if cmd:sub(#cmd - 1, #cmd - 1) == "?" then
            q = true
            cmd = cmd:gsub('?', '')
        end
        local first, last = parseRange(cmd:sub(1, #cmd - 1))
        first = first or 1
        last = last or #text
        first = math.max(first, 1)
        last = math.min(last, #text)
        io.write("Text to search:")
        local toSearch = io.read()
        if type(toSearch) == "string" and #toSearch > 0 then
            io.write("Replace with:")
            local toReplace = io.read()
            if type(toReplace) == "boolean" then
                toReplace = ""
            end
            for i = first, last do
                if text[i]:find(toSearch, 1, true) then
                    local newText = replace(text[i], toSearch, toReplace)
                    io.write(i .. ':' .. newText .. '\n')
                    if q then
                        io.write("Is this correct (Y/N)? ")
                        if prompt() then
                            text[i] = newText
                        end
                    else
                        text[i] = newText
                    end
                end
            end
        end
    else
        local t = parseLine(cmd)
        if #cmd == 0 then
            t = cur + 1
        end
        if t == nil then
            io.write("Entry error\n")
        else
            t = math.max(t, 1)
            t = math.min(t, #text)
            io.write(t .. ':' .. text[t] .. '\n' .. t .. ':')
            local newLine = io.read()
            if type(newLine) == "string" and #newLine > 0 then
                text[t] = newLine
            end
        end
    end
end