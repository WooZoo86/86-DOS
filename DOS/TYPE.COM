local args = {...}
if #args == 0 then
    io.write("File not found\n")
else
    for i = 1, #args do
        local file, reason = io.open(args[i],"rb")
        if not file then
            io.stderr:write((reason or "Unknown error") .. '\n')
            return
        end
        repeat
            local line = file:read("*L")
            if line then
                io.write(line)
            end
        until not line
        file:close()
        io.stderr:write("\n")
    end
end
