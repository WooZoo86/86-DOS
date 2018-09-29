io.write("Stike a key when ready . . .\n")
for i = 1, 2 do
    require("EVENT").pull("key")
end
