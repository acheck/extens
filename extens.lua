--[[

Copyright © 2015 Mihail Zuev <z.m.c@list.ru>. 
Author: Mihail Zuev <z.m.c@list.ru>.
 
All rights reserved.
 
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the <organization> nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.
                                                                                
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

--]]



--
-- Return the full path where a Lua module name would be matched
--
package['searchpath'] = package['searchpath'] or function(mod, path)
	mod = mod:gsub('%.',package.config:sub(1,1))

	for p in path:gmatch('[^;]+') do
		local m = p:gsub('?',mod)
		local f = io.open(m,'r')

		if f then f:close() return m, nil end
	end

	return nil, string.format('file %s not found',mod)
end



--
-- Just in case
-- Lua 5.3.4 has a "loadstring", but Lua 5.3.3 is no longer
--
loadstring = loadstring or load



--
-- Formatting a string by the string itself, like python "%" operator with printf formating syntax
-- Example:
--				"${who} is${1%3d} years old" % {who = "Mark", 28} -> Mark is 28 years old
--
getmetatable("").__mod = function(str, tab)
	return (str:gsub('(%${[^}{]+})', function(w)
		local mark = w:sub(3, -2)

		return (mark:gsub('([^%%]+)%%?([-0-9%.]*[cdeEfgGiouxXsq]*)',function(v,fmt)
			v = tonumber(v) or v

			if fmt and #fmt > 0 then
				return tab[v] and ("%" .. fmt):format(tab[v]) or w
			end

			return tab[v] or w
		end))

	end))
end



--
-- Slice of string, ("Simple String"){1,-8} -> Simple
--
getmetatable("").__call = function(str,...)
	local arg = {...}

	if type(arg[1]) == "table" then
		if #(arg[1]) > 2 then
			local t = {}
			for i,v in ipairs(arg[1]) do
				t[i]=string.sub(str,v,v)
			end
			return table.concat(t)
		else
			return string.sub(str,arg[1][1] or 1, arg[1][2] or -1)
		end
	else
		return string.sub(str,arg[1] or 1, arg[2] or -1)
	end
end



--
-- Repeat string few times, like "#" * 10 -> ##########
--
getmetatable("").__mul = function(a,b)
	if type(a) == 'string' and type(b) == 'number' then
		return string.rep(a,b)
	end
	error("attempt to perform arithmetic on a string value")
end



--
-- Standard printf function implementation
--
function printf(...)
	print(string.format(...))
end



--
-- Try-Except-Finally Block Imitation(just for convenience only)
--	USAGE:
--		try(
--			main block code like:- function() code end
--		):except(
--			except block code like:- function(errmsg) code end
--		):finally(
--			finally block code like:- function() code end
--		)
--
function try(todo)
	local stat, err

	if type(todo) == "function" then
		stat, err = pcall(todo)
	end

	return {
		except = function(self,cblock)
			if not stat then
				if type(cblock) == "function" then
					cblock(err or "Internal Try-Except-Finally Error: ...")
				end
			end
			return self
		end,

		finally = function(self,fblock)
			if type(fblock) == "function" then
				fblock()
			end
			return self
		end
	}
end



--
-- Similar Dumper as in Perl Data::Dumper
--
function dumper(o,...)
    local s = {}
		local arg = {...}
		local idx = arg[1] or 0

    if type(o) == 'table' then
			table.insert(s,'{')
			for key,v in pairs(o) do
				table.insert(s,string.format("%s%s => %s,",string.rep(" ",idx+1),key,dumper(o[key],idx+2)))
			end
			table.insert(s,string.format("%s}",string.rep(" ",idx)))
    else
			if type(o) == 'string' then
				table.insert(s,string.format('"%s"',tostring(o)))
			else
				table.insert(s,tostring(o))
			end
    end

    return table.concat(s,"\n")
end



--
-- switch/case statement
--	USAGE:
--		switch(what[,case insensitive]) {
--			['what'] = function()
--			end,
--			['default'] = function()
--			end
--		}
--
function switch (i,c)
	return setmetatable({i},{
		__call = function (t, cases)
			local item = #t == 0 or t[1]

			if c then
				if type(item) == 'string' then item = string.lower(item) end
			end
			return (cases[item] or cases['default'] or function () end)(item)
		end
	})
end



--
-- Define pack() function inside 'table' object
-- For 5.1 and older
--
table.pack = table['pack'] or function(...)
	return { ... }, select("#", ...)
end



--
-- For compatibility with version 5.1 and older
--
do
	local iscoroutine = coroutine.running

	coroutine.running = function()
		local thread, main = iscoroutine()

		if type(main) == 'nil' then
			main = not thread and true
		end
		
		return thread, main
	end
end




--
-- A modified 'require' function, that allows to pass some parameters to the loadable module 
--
do
	local import = require

	require = function(mod, ...)
		if #{...} ~= 0 then
			local mpath = package.searchpath(mod, package.path) return loadfile(mpath)(mod, mpath, ...)
		end

		return import(mod)
	end
end



--
-- Set environment of some function
-- analog from lua 5.1
--
setfenv = setfenv or function(f, e)
	local i = 1

	while true do
		local n = debug.getupvalue(f, i)

		if n == "_ENV" then
			debug.upvaluejoin(f, i, (function()
				return e
			end), 1)
			break
		elseif not n then
			break
		end

		i = i + 1
	end

	return f
end



--
-- Get environment of some function
-- analog from lua 5.1
--
getfenv = getfenv or function(f)
	local i = 1

	while true do
		local n, v = debug.getupvalue(f, i)

		if n == "_ENV" then
			return v
		elseif not n then
			break
		end
		i = i + 1
	end
end



--
-- Clone(not reference) some function and all upvalue's reference
--
function clonefup(f)
  local i = 1 
  local dumped = string.dump(f)
  local cloned = loadstring(dumped)
  local upvaluejoin = debug.upvaluejoin

  while true do
    local name, value = debug.getupvalue(f, i)

    if not name then
      break
    end 

    if upvaluejoin then
      upvaluejoin(cloned, i, f, i)
    else
      debug.setupvalue(cloned,i,value)
    end 

    i = i + 1 
  end 

  return cloned
end



