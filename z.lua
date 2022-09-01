#!/usr/bin/env lua

---Metatable for archives
local ar_mt = {
	__tostring = function (self)
		local s = '[\27[0;34m'.. self.name .. '\27[0m | \27[0;33m' .. self.comp_algo ..'\27[0m]\n'
		local old_s = s
			for f, _ in pairs(self.entries) do
				s = s .. "  \27[0;36m*\27[0m '" .. f .. "'\n"
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
		entries   = {},
		name      = t.name or 'untitled-archive',
		addEntry  = function (self, file)
			file = file:gsub('~', os.getenv('HOME'), 1) -- expand ~ to user's home dir
			self.entries[file] = true
		end,
		delEntry  = function (self, file)
			self.entries[file] = nil
		end
	}

	t.entries = t.entries or {}
	for _, v in ipairs(t.entries) do
		ar:addEntry(v)
	end

	setmetatable(ar, ar_mt)
	return ar
end

--- Utility function to expand table to string
local function expandKeys(tbl)
	local s = ''
	for k, _ in pairs(tbl) do
		if type(k) == 'string' then
			s = s .. "'" .. tostring(k) .. "' "
		end
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
	['gzip'] = function(out, files)
		local cmd = TAR_CMD .. " czf '".. out ..".tar.gz' " .. expandKeys(files)
		print(cmd)
		os.execute(cmd)
	end,
	['bzip'] = function(out, files)
		local cmd = TAR_CMD .. " cjf '".. out ..".tar.bz' " .. expandKeys(files)
		print(cmd)
		os.execute(cmd)
	end,
	['zstd'] = function(out, files)
		local cmd = TAR_CMD .. ' cf - '.. expandKeys(files) .. ' | zstd -o ' .. "'".. out ..".tar.zst'"
		print(cmd)
		os.execute(cmd)
	end,
	['lz4'] = function(out, files)
		local cmd = TAR_CMD .. ' cf - '.. expandKeys(files) .. ' | lz4 - ' .. "'".. out ..".tar.lz4'"
		print(cmd)
		os.execute(cmd)
	end,
}

--- Help message
local HELP = ('usage: z [-l MOD] [-c ALGO] [-o NAME] [-fh] TARGETS\n'
            ..'\t-f       Override existing archives\n'
            ..'\t-c ALGO  Use ALGO as compression algorithm\n'
            ..'\t-b       Bundle all targets into a single archive\n'
            ..'\t-o NAME  Use NAME as archive output, assumes -b\n'
            ..'\t-l MOD   Load lua module MOD and use its Archives field to run the\n'
            ..'\t         program, this will cause the program to ignore any targets\n'
            ..'\t         provided through the command line, supresses: -b,-o,-c\n'
            ..'\t-h       Display this help message\n'
            ..'\t--       Stop parsing options after -\n')

---Global settings
local settings = {
	algo  = 'gzip',
	bundle = false,
	override_name = nil, -- Set this to a string and it becomes the forced name
	force = false,
	use_module = false
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
		print(HELP)
		os.exit(0)
		return 0
	end,

	['-l'] = function(mod)
		if not mod then
			error('No module provided')
		end
		mod = mod:gsub('%.lua$', '') -- remove .lua extension for convenience
		local s = require(mod)
		if not s or type(Archives) ~= 'table' then
			error('No archive schema found in Lua module: ' .. mod)
		end

		for _, a in ipairs(Archives) do
			--for k,v in pairs(a.entries) do print('[a] ',k,v) end
			archives[#archives+1] = Archive{name = a.name, comp_algo = a.comp_algo}
			for _, e in ipairs(a.entries) do
				archives[#archives]:addEntry(e)
			end
		end

		settings.use_module = true

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

if settings.use_module then
	for _, ar in ipairs(archives) do
		print(ar)
		COMP_ALGORITHMS[ar.comp_algo](ar.name, ar.entries)
	end
elseif #targets > 0 then
	local out = Archive{name = settings.override_name or targets[1], comp_algo = settings.algo}
	for _, v in ipairs(targets) do
		out:addEntry(v)
	end
	COMP_ALGORITHMS[out.comp_algo](out.name, out.entries)
else
	--print help and exit
	print(HELP)
	os.exit(1)
end

