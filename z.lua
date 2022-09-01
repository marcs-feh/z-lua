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

--- Utility function to expand table to string
local function expandKeys(tbl)
	local s = ''
	for k, _ in pairs(tbl) do
		s = s .. "'" .. tostring(k) .. "' "
	end
	return s
end

---Command to use for tape archiver
local TAR_CMD = 'tar'

---Compression algos and their functions.
local COMP_ALGORITHMS = {
	['xz'] = function(out, files)
		local cmd = TAR_CMD .. " cJf '".. out ..".tar.xz' " .. expandKeys(files)
		print(cmd)
		os.execute(cmd)
	end,
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

---Non-flag CLI arguments
local targets = {}

---Flags and their actions
--Each action returns how many CLI arguments they consumed
local flags = {}
flags = {
	['-c'] = function(alg)
		if not COMP_ALGORITHMS[alg] then
			error('Invalid compression algorithm: ' .. tostring(alg))
		end

		settings.algo = alg
		return 1
	end,

	['-f'] = function()
		settings.force = true
		return 0
	end,

	['-b'] = function()
		settings.bundle = true
		return 0
	end,

	['-o'] = function(name)
		if not name or flags[name] then
			error('No provided output for -o')
		end
		settings.bundle = true
		settings.override_name = tostring(name)
		return 1
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
		return 0
	end,

	['-l'] = function(mod)
		if not mod then
			error('No module provided')
		end
		local s = require(mod)
		if not s or type(Archives) ~= 'table' then
			error('No archive schema found in Lua module: ' .. mod)
		end

		for _, a in ipairs(Archives) do
			archives[#archives+1] = Archive(a)
		end

		targets = {}
		return 1
	end,

	['--'] = function()
		flags = {}
		return 0
	end
}

--- Main
local i = 1
local a = nil
while i <= #arg do
	a = arg[i]
	if flags[a] then
		i = i + flags[a](arg[i+1])
	else
		targets[#targets+1] = a
	end
	i = i + 1
end

if #targets > 0 then
	local out = Archive{name = settings.override_name, comp_algo = settings.algo}
	for _, v in pairs(targets) do
		out:addEntry(v)
	end
	--print(out)
	COMP_ALGORITHMS[out.comp_algo](out.name, out.entries)
end

