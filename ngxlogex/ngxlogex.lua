-- inspect is 10x more expensive than json.decode
-- local inspect = require 'inspect'
local json = require 'cjson.safe'
local errlog = require 'ngx.errlog'
local errlog_level = errlog.get_sys_filter_level()

local ngx_log = ngx.log

if ngx.__log then
	ngx_log(ngx.ERR, 'ngxlogex already loaded, or you are requiring with a different name.')
	return nil
end

local _M = {
	serializers = {
		table = json.encode,
		cdata = tostring,
		userdata = tostring,
		lightuserdata = tostring,
		['function'] = tostring,
		thread = tostring,
		--TODO: other types?
	}
}

function _M.init(serializers)
	for k, v in pairs(serializers) do
		_M.serializers[k] = v
	end
end

-- @description: wrap ngx.log, if the arg is a table, print the inspected table.
-- @notice: tail call is used to avoid stack depth increase,
--          if param `level' is larger than sys errlog level, will do nothing.
--          Need to replace `(ins|inspect)\(([^)]+)\)' with $2 of ngx.log(....)
--          in VSCode one by one,
--          DO NOT replace inspect that are for test purpose.
-- References:
-- Tail Calls: https://www.lua.org/pil/6.3.html
-- Vararg: http://lua-users.org/wiki/VarargTheSecondClassCitizen
local function logex(level, ...)
	if level > errlog_level then
		return nil
	end

	local args = {...}
	local argc = select("#", ...)

	for i = 1, argc do
		local v = select(i, ...)
		local ser = _M.serializers[type(v)]
		if ser then
			local out, err = ser(v)  -- json.encode may fail
			args[i] = out or err
		end
	end

	return ngx_log(level, unpack(args, 1, argc))
end

-- ngx.say('ngx ', inspect(ngx))

ngx.__log = ngx_log
ngx.log = logex
_M.logex = logex


-- transform previous usage to new helperss:
-- ngx.log\s*\(\s*ngx\.DEBUG\s*,\s*   => ngx.debug(
-- ngx.log\s*\(\s*ngx\.INFO\s*,\s*    => ngx.info(
-- ngx.log\s*\(\s*ngx\.WARN\s*,\s*    => ngx.warn(
-- ngx.log\s*\(\s*ngx\.ERR\s*,\s*     => ngx.error(

_M.log_levels = {
	debug  = ngx.DEBUG,
	info   = ngx.INFO,
	notice = ngx.NOTICE,
	warn   = ngx.WARN,
	error  = ngx.ERR,
	crit   = ngx.CRIT,
	alert  = ngx.ALERT,
	emerg  = ngx.EMERG,
}

local function init_log_helpers()
	for fname, lvl in pairs(_M.log_levels) do
		if ngx[fname] then
			ngx.log(ngx.ERR, 'function to inject already exists: ngx.', fname)
		else
			ngx[fname] = function (...) return logex(lvl, ...) end
			ngx.log(ngx.INFO, 'inject log helper `', fname, '\' into `ngx\' with level ', lvl)
		end
	end
end

init_log_helpers()


--------- Test Cases ----------

function _M.test_logex(chk_called)
	local assert = require 'luassert'
	local spy = require 'luassert.spy'
	local log_tmp
	ngx_log(ngx.ERR, 'chk_called ', chk_called)
	if chk_called then
		log_tmp = spy(logex)
		ngx.log = log_tmp
	end
	ngx.sleep(0.001)

	local tt = {
		hello = 'world',
		index = 12,
		addi = 4,
	}

	ngx.log(ngx.DEBUG, '------------')
	ngx.log(ngx.DEBUG, 'tt ', tt)
	ngx.log(ngx.ERR, 'tt ', tt)

	if chk_called then
		ngx.log = logex
		assert.spy(log_tmp).was_called(3)
	end
end

function _M.test_logex_nil()
	ngx.log(ngx.DEBUG, 'hello ', nil, ' world ', nil)
end

function _M.test_logex_again_timer()
	ngx.timer.at(0.01, _M.test_logex)
	ngx.sleep(0.011)
end

function _M.test_in_spawn_thread()
	local co = ngx.thread.spawn(_M.test_logex)
	ngx.thread.wait(co)
	co = ngx.thread.spawn(_M.test_logex, true)
	ngx.thread.wait(co)
end

function _M.test_log_helpers()
	local tt = {
		hello = 'world',
		index = 12,
		addi = 4,
		aa = true,
		bb = nil,
		cc = ngx.null,
	}
	ngx.debug('tt ', tt, ' xx ', 123)
	ngx.emerg('tt ', tt, ' xx ', 123)
	for fname, lvl in pairs(_M.log_levels) do
		ngx.log(ngx.DEBUG, '>>== log helper [', fname, '] level ', lvl)
		ngx[fname]('tt ', tt, ' xx ', 123)
	end
end


return _M
