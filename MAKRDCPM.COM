local shell = require("MON")
local tty = require("TTY")
local fs = _G.filesystem

if not _G.welcome then
  io.write("☺\n" .. _G._OSVERSION .. "\nCopyright 1980,81 Seattle Computer Products, Inc.\n")
  _G.welcome = true
end
io.write("\nCOMMAND v. 1.00\n\n")

--[[
if tty.isAvailable() then
  if io.stdout.tty then
    io.write("\27[40m\27[37m")
    tty.clear()
  end
end
]]--
--dofile("/etc/motd")
--[[
shell.setAlias("dir", "ls")
shell.setAlias("move", "mv")
shell.setAlias("rename", "mv")
shell.setAlias("copy", "cp")
shell.setAlias("del", "rm")
shell.setAlias("md", "mkdir")
shell.setAlias("cls", "clear")
shell.setAlias("rs", "redstone")
shell.setAlias("view", "edit -r")
shell.setAlias("help", "man")
shell.setAlias("cp", "cp -i")
shell.setAlias("l", "ls -lhp")
shell.setAlias("..", "cd ..")
shell.setAlias("df", "df -h")
shell.setAlias("grep", "grep --color")
]]--
os.setenv("EDITOR", "/EDLIN.COM")
os.setenv("HISTSIZE", "10")
os.setenv("HOME", "/")
os.setenv("IFS", " ")
--os.setenv("MANPATH", "/usr/man:.")
--os.setenv("PAGER", "/bin/more")
--os.setenv("PS1", "\27[40m\27[31m$HOSTNAME$HOSTNAME_SEPARATOR$PWD # \27[37m")
os.setenv("LS_COLORS", "di=0;36:fi=0:ln=0;33:*.lua=0;32")

shell.setWorkingDirectory(os.getenv("HOME"))
--[[
local home_shrc = shell.resolve(".shrc")
if fs.exists(home_shrc) then
  loadfile(shell.resolve("source", "lua"))(home_shrc)
end
]]--