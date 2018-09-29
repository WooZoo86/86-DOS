local event = require("EVENT")
local shell = require("MON")
local tty = require("TTY")
local text = require("TEXT")
local sh = require("CPMTAB")

local args, options = shell.parse(...)

shell.prime()
local needs_profile = io.input().tty
local has_prompt = needs_profile and io.output().tty and not options.c
local input_handler = {hint = sh.hintHandler}

if #args == 0 then
  while true do
    if has_prompt then
      while not tty.isAvailable() do
        event.pull("term_available")
      end
      if needs_profile then -- first time run AND interactive
        needs_profile = nil
        dofile("/MAKRDCPM.COM")
      end
      io.write(sh.expand(os.getenv("PS1") or (string.char(_G.currentDrive) .. ':')))
    end
    local command = tty.read(input_handler)
    if command then
      command = text.trim(command)
      if string.lower(command) == "exit" or string.lower(command) == "shutdown" then
        computer.shutdown()
      elseif string.lower(command) == "reboot" then
        computer.shutdown(true)
      elseif command ~= "" then
        local result, reason = sh.execute(_ENV, command)
        if not result then
          io.write("Bad command or file name\n\n")
        end
      end
    elseif command == nil then -- false only means the input was interrupted
      return -- eof
    end
    if has_prompt and tty.getCursor() > 1 then
      io.write("\n")
    end
  end
else
  -- execute command.
  local result = table.pack(sh.execute(...))
  if not result[1] then
    error(result[2], 0)
  end
  return table.unpack(result, 2)
end
