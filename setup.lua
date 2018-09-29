local component = require("component")
local computer = require("computer")
local fs = require("filesystem")
local internet = require("internet")
local github = "https://raw.githubusercontent.com/DarikXPlay/86-DOS/master"
local dirs = {
    "/DOS/BOOT/",
    "/DOS/LIB/CORE/DEVFS/ADAPTERS/",
    "/DOS/LIB/TOOLS/"
}
local list = {
    "/DOS/BOOT/00BASE.COM",
    "/DOS/BOOT/01PROCES.COM",
    "/DOS/BOOT/02OS.COM",
    "/DOS/BOOT/03IO.COM",
    "/DOS/BOOT/04COMPON.COM",
    "/DOS/BOOT/10DEVFS.COM",
    "/DOS/BOOT/90FILSYS.COM",
    "/DOS/BOOT/91GPU.COM",
    "/DOS/BOOT/92KEYBRD.COM",
    "/DOS/BOOT/93TERM.COM",
    "/DOS/LIB/CORE/DEVFS/ADAPTERS/COMPUTER.ASM",
    "/DOS/LIB/CORE/DEVFS/ADAPTERS/EEPROM.ASM",
    "/DOS/LIB/CORE/DEVFS/ADAPTERS/FILESYST.ASM",
    "/DOS/LIB/CORE/DEVFS/ADAPTERS/GPU.ASM",
    "/DOS/LIB/CORE/DEVFS/ADAPTERS/INTERNET.ASM",
    "/DOS/LIB/CORE/DEVFS/ADAPTERS/MODEM.ASM",
    "/DOS/LIB/CORE/DEVFS/ADAPTERS/SCREEN.ASM",
    "/DOS/LIB/CORE/DEVFS/01HW.ASM",
    "/DOS/LIB/CORE/DEVFS/02UTILS.ASM",
    "/DOS/LIB/CORE/DVCLABEL.ASM",
    "/DOS/LIB/CORE/FULLBUFF.ASM",
    "/DOS/LIB/CORE/FULLEVNT.ASM",
    "/DOS/LIB/CORE/FULLFLST.ASM",
    "/DOS/LIB/CORE/FULLKBRD.ASM",
    "/DOS/LIB/CORE/FULLSH.ASM",
    "/DOS/LIB/CORE/FULLSHEL.ASM",
    "/DOS/LIB/CORE/FULLTEXT.ASM",
    "/DOS/LIB/CORE/FULLTRNS.ASM",
    "/DOS/LIB/CORE/FULLTTY.ASM",
    "/DOS/LIB/CORE/FULLVT.ASM",
    "/DOS/LIB/TOOLS/FSMOD.ASM",
    "/DOS/LIB/TOOLS/PRGLOCAT.ASM",
    "/DOS/LIB/BUFFER.ASM",
    "/DOS/LIB/DEVFS.ASM",
    "/DOS/LIB/EVENT.ASM",
    "/DOS/LIB/FILESYST.ASM",
    "/DOS/LIB/KEYBOARD.ASM",
    "/DOS/LIB/PIPE.ASM",
    "/DOS/LIB/PROCESS.ASM",
    "/DOS/LIB/SERLZATN.ASM",
    "/DOS/LIB/TERM.ASM",
    "/DOS/LIB/TEXT.ASM",
    "/DOS/LIB/TRNSFRMS.ASM",
    "/DOS/LIB/TTY.ASM",
    "/DOS/LIB/VT100.ASM",
    "/DOS/CLEAR.COM",
    "/DOS/COPY.COM",
    "/DOS/DIR.COM",
    "/DOS/ERASE.COM",
    "/DOS/PAUSE.COM",
    "/DOS/RENAME.COM",
    "/DOS/TYPE.COM",
    "/ASM.COM",
    "/BOOT.ASM",
    "/CHKDSK.COM",
    "/COMMAND.COM",
    "/CPMTAB.ASM",
    "/DEBUG.COM",
    "/DINIT.ASM",
    "/DOSIO.ASM",
    "/EDLIN.COM",
    "/init.lua",
    "/MAKRDCPM.COM",
    "/MON.ASM",
    "/NEW.BAT",
    "/NEWS.DOC",
    "/RDCPM.COM",
    "/SYS.COM",
    "/TRANS.COM"
}

local function prompt(message)
    io.write(message .. " (Y/N)? ")
    local result = io.read()
    return result and (result == "" or result:sub(1, 1):lower() == "y")
end
local function select_prompt(devs2)
    if #devs2 == 0 then
        io.write("No available devices\n")
        return
    end
    table.sort(devs2, function(a, b) return a.address < b.address end)
    local devs = { devs2[1] }
    for i = 2, #devs2 do
        if devs2[i].address ~= devs2[i - 1].address then
            table.insert(devs, devs2[i])
        end
    end
    local num_devs = #devs
    if num_devs < 2 then
        return devs[1]
    end
    io.write("Available devices:",'\n')
    for i = 1, num_devs do
        local src = devs[i]
        local selection_label = src.getLabel()
        if selection_label then
            selection_label = string.format("%s (%s...)", selection_label, src.address:sub(1, 8))
        else
            selection_label = src.address
        end
        io.write(string.format("%d) %s at %s [r%s]\n", i, selection_label, src.path, src.isReadOnly() and 'o' or 'w'))
    end

    io.write("Please enter a number between 1 and " .. num_devs .. '\n')
    io.write("Enter 'q' to cancel the installation: ")
    for _=1,5 do
        local result = io.read() or "q"
        if result == "q" then
            os.exit()
        end
        local number = tonumber(result)
        if number and number > 0 and number <= num_devs then
            return devs[number]
        else
            io.write("Invalid input, please try again: ")
            os.sleep(0)
        end
    end
    print("\ntoo many bad inputs, aborting")
    os.exit(1)
end
function download(file, directory)
    local preexisted
    if fs.exists(directory .. file) then
        preexisted = true
    end
    local f, reason = io.open(directory .. file, "a")
    if not f then
        return nil, "failed opening file for writing: " .. reason
    end
    f:close()
    f = nil
    local result, response = pcall(internet.request, github .. file)
    if result then
        local result, reason = pcall(function()
            for chunk in response do
                if not f then
                    f, reason = io.open(directory .. file, "wb")
                    assert(f, "failed opening file for writing: " .. tostring(reason))
                end
                f:write(chunk)
            end
        end)
        if not result then
            if f then
                f:close()
                if not preexisted then
                    fs.remove(directory .. file)
                end
            end
            return nil, reason
        end
        if f then
            f:close()
        end
    else
        return nil, response
    end
    return true
end

if not component.isAvailable("internet") then
    io.stderr:write("This program requires an internet card to run")
    return
end
local devices = {}
for dev, path in fs.mounts() do
    table.insert(devices, dev)
    devices[#devices].path = path
end
local target = select_prompt(devices)
if prompt("Install 86-DOS on " .. (target.getLabel() or target.address)) then
    local drive = target.path
    while drive:sub(#drive) == "/" do
        drive = drive:sub(1, #drive - 1)
    end
    for i = 1, #dirs do
        if not fs.exists(drive .. dirs[i]) then
            local result, reason = fs.makeDirectory(drive .. dirs[i])
            if not result then
                io.stderr:write((reason or ("Can't make directory " .. dirs[i])) .. '\n')
                return
            else
                io.write(dirs[i] .. '\n')
                os.sleep(0)
            end
        end
    end
    for i = 1, #list do
        local result, reason = download(list[i], drive)
        if not result then
            io.stderr:write((reason or ("Can't download file " .. list[i])) .. '\n')
            return
        else
            io.write(list[i] .. '\n')
            os.sleep(0)
        end
    end
    io.write("READY!")
    computer.setBootAddress(target.address)
    computer.shutdown(true)
end
