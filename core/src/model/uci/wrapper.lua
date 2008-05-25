--[[
LuCI - UCI wrapper library

Description:
Wrapper for the /sbin/uci application, syntax of implemented functions
is comparable to the syntax of the uci application

Any return value of false or nil can be interpreted as an error

FileId:
$Id$

License:
Copyright 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at 

	http://www.apache.org/licenses/LICENSE-2.0 

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

]]--

module("luci.model.uci.wrapper", package.seeall)

require("luci.util")
require("luci.sys")

-- Session class
Session = luci.util.class()

-- Session constructor
function Session.__init__(self, savedir)
	self.ucicmd = savedir and "uci -P " .. savedir or "uci"
end

function Session.add(self, config, section_type)
	return self:_uci("add " .. _path(config) .. " " .. _path(section_type))
end

function Session.changes(self, config)
	return self:_uci("changes " .. _path(config))
end

function Session.commit(self, config)
	return self:_uci2("commit " .. _path(config))
end

function Session.del(self, config, section, option)
	return self:_uci2("del " .. _path(config, section, option))
end

function Session.get(self, config, section, option)
	return self:_uci("get " .. _path(config, section, option))
end

function Session.revert(self, config)
	return self:_uci2("revert " .. _path(config))
end

function Session.sections(self, config)	
	if not config then
		return nil
	end
	
	local r1, r2 = self:_uci3("show " .. _path(config))
	if type(r1) == "table" then
		return r1, r2
	else
		return nil, r2
	end
end

function Session.set(self, config, section, option, value)
	return self:_uci2("set " .. _path(config, section, option, value))
end

function Session.synchronize(self) end

-- Dummy transaction functions

function Session.t_load(self) end
function Session.t_save(self) end

Session.t_add = Session.add
Session.t_commit = Session.commit
Session.t_del = Session.del
Session.t_get = Session.get
Session.t_revert = Session.revert
Session.t_sections = Session.sections
Session.t_set = Session.set





-- Internal functions --


function Session._uci(self, cmd)
	local res = luci.sys.exec(self.ucicmd .. " 2>/dev/null " .. cmd)
	
	if res:len() == 0 then
		return nil
	else
		return res:sub(1, res:len()-1)
	end	
end

function Session._uci2(self, cmd)
	local res = luci.sys.exec(self.ucicmd .. " 2>&1 " .. cmd)
	
	if res:len() > 0 then
		return false, res
	else
		return true
	end	
end

function Session._uci3(self, cmd)
	local res = luci.sys.execl(self.ucicmd .. " 2>&1 " .. cmd)
	if res[1] and res[1]:sub(1, self.ucicmd:len()+1) == self.ucicmd..":" then
		return nil, res[1]
	end

	local tbl = {}
	local ord = {}

	for k,line in pairs(res) do
		c, s, t = line:match("^([^.]-)%.([^.]-)=(.-)$")
		if c then
			tbl[s] = {}
			table.insert(ord, s)
			tbl[s][".type"] = t
		end
	
		c, s, o, v = line:match("^([^.]-)%.([^.]-)%.([^.]-)=(.-)$")
		if c then
			tbl[s][o] = v
		end
	end
	
	return tbl, ord
end

-- Build path (config.section.option=value) and prevent command injection
function _path(...)
	local result = ""
	
	-- Not using ipairs because it is not reliable in case of nil arguments
	arg.n = nil
	for k,v in pairs(arg) do
		if v then
			v = tostring(v)
			if k == 1 then
				result = "'" .. v:gsub("['.]", "") .. "'"
			elseif k < 4 then
				result = result .. ".'" .. v:gsub("['.]", "") .. "'"
			elseif k == 4 then
				result = result .. "='" .. v:gsub("'", "") .. "'"
			end
		end
	end
	return result
end