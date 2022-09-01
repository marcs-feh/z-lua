#!/usr/bin/env lua

---Metatable for archives
local ar_mt = {
	__tostring = function (self)
		local s = '['.. self.name .. ' : ' .. self.comp_algo ..']\n'
		local old_s = s
			for f, _ in pairs(self.entries) do
				s = s .. '\t\'' .. f .. '\'\n'
			end
		if s == old_s then
			s = s .. '\t(empty)\n'
		end
		return s
	end,
	__metatable = false
}

---Creates an Archive.
---@param t table
---@return table
local function Archive(t)
	local ar = {
		comp_algo = t.comp_algo or 'gzip',
		entries   = t.entries or {},
		name      = t.name or 'untitled-archive',
		addEntry  = function (self, file)
			self.entries[file] = true
		end,
		delEntry  = function (self, file)
			self.entries[file] = nil
		end
	}

	t.entries = t.entries or {}
	for _, v in ipairs(t.entries) do
		ar.entries[v] = true
	end

	setmetatable(ar, ar_mt)
	return ar
end


---Compression algos and their extensions.
local COMP_ALGORITHMS = {
	['xz'] = 'xz',
	['zstd'] = 'zst',
	['gzip'] = 'gz',
	['bzip'] = 'bz'
}

---Global settings
local settings = {
	algo  = 'gzip',
	bundle = false,
	override_name = nil, -- Set this to a string and it becomes the forced name
	force = false,
}

---Archive list
local archives = {}

---Flags and their actions
local flags = {}
flags = {
	['-c'] = function(arg)
		if not COMP_ALGORITHMS[arg] then
			error('Invalid compression algorithm: ' .. tostring(arg))
		end
	end,

	['-f'] = function()
		settings.force = true
	end,

	['-b'] = function()
		settings.bundle = true
	end,

	['-o'] = function(name)
		if not name or flags[name] then
			error('No provided output for -o')
		end
		settings.bundle = true
		settings.override_name = tostring(name)
	end,

	['-h'] = function()
		print('usage: z [-l MOD] [-c ALGO] [-o NAME] [-fh] TARGETS\n'
			  ..'\t-f       Override existing archives\n'
			  ..'\t-c ALGO  Use ALGO as compression algorithm\n'
			  ..'\t-b       Bundle all targets into a single archive\n'
			  ..'\t-o NAME  Use NAME as archive output, assumes -b\n'
				..'\t-l MOD   Load lua module MOD and use its Archives field to run the\n'
				..'\t         program, this will cause the program to ignore any targets\n'
				..'\t         provided through the command line, supresses: -b,-o,-c\n'
			  ..'\t-h       Display this help message\n'
			  ..'\t--       Stop parsing options after -\n'
		)
		os.exit(0)
	end,

	['-l'] = function(mod)
		if not mod then
			error('No module provided')
		end
		local s = require(mod)
		if not s.Archives then
			error('No archive schema found in Lua module: ' .. mod)
		end
	end,

	['--'] = function()
		flags = {}
	end
}

--- Main

local targets = {}
for i, a in ipairs(arg) do
	if flags[a] then
		flags[a](arg[i+1])
	else
		targets[#targets+1] = a
		print('Target :', a)
	end
end

