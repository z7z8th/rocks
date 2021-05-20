-- require "ngxlogex"

local tspec = arg[1]
local modname, fname = string.match(tspec, "([^:]+):?([^:]+)")
local m = require(modname)

for k, func in pairs(m) do
	if not fname and k:match("test_") or fname and k:match(fname) then
		ngx.say("\n>>== runing ", k, "\n")
		ngx.flush()
		func()
		ngx.say("\n")
		ngx.flush()
	end
end

