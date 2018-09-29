local fs = _G.filesystem
local args = {...}
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
if prompt("Install 86-DOS on drive " .. string.upper(args[1])) then
    for i = 1, #dirs do
        local result, reason = fs.makeDirectory("/" .. args[1] .. dirs[i])
        if not result then
            io.stderr:write((reason or "Unknown error") .. '\n')
            return
        else
            io.write(args[1]:upper() .. ':' .. dirs[i] .. '\n')
            os.sleep(0)
        end
    end
    for i = 1, #list do
        local result, reason = fs.copy(list[i], "/" .. args[1] .. list[i])
        if not result then
            io.stderr:write((reason or "Unknown error") .. '\n')
            return
        else
            io.write(args[1]:upper() .. ':' .. list[i] .. '\n')
            os.sleep(0)
        end
    end
    io.write("READY!")
    computer.setBootAddress(_G.drives[args[1]])
    computer.shutdown(true)
end
