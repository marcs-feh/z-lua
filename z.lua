---SHEBANG---

---Global settings
local settings = {
	algo  = 'zstd',
	override_name = nil, -- Set this to a string and it becomes the forced name
	force = false,
	use_module = false,
	verbose = false
}

---Log function for verbose mode
local function log(msg)
	if settings.verbose then
		io.stderr:write(tostring(msg) .. '\n')
	end
end

---Get number of keys in table.
local function keyCount(tbl)
	local n = 0
	for k, _ in pairs(tbl) do
		if type(k) ~= 'number' then
			n = n + 1
		end
	end
	return n
end

---Check if file is readble(exists)
local function fileExists(path)
	local f = io.open(path, 'r')
	if f then
		f:close()
		return true
	end
	return false
end

---Utility function to expand table to string
local function expandKeys(tbl)
	local s = ''
	for k, _ in pairs(tbl) do
		if type(k) == 'string' then
			s = s .. "'" .. tostring(k) .. "' "
		end
	end
	return s
end

---Metatable for archives
local ar_mt = {
	__tostring = function (self)
		local s = '[\27[0;34m'.. self.name .. '\27[0m : \27[0;33m' .. self.comp_algo ..'\27[0m]\n'
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
		comp_algo = t.comp_algo or 'zstd',
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

---Command to use for tape archiver
local TAR_CMD = 'tar'

---Ask OS to execute cmd, checks if fname exists
local function compress(fname, cmd)
	if fileExists(fname) then
		if settings.force then
			os.remove(fname)
			os.execute(cmd)
		else
			print(fname .. " already exists, delete it or use -f to overwrite it.")
		end
	else
		os.execute(cmd)
	end
end

---Compression algos and their functions.
local COMP_ALGORITHMS = {
	['xz'] = function(out, files)
		local fname = out ..".tar.xz"
		local cmd = TAR_CMD .. " cJf '" .. fname .. "' " .. expandKeys(files)
		compress(fname, cmd)
		log('Compressing with: ' .. cmd)
	end,
	['gzip'] = function(out, files)
		local fname = out ..".tar.gz"
		local cmd = TAR_CMD .. " czf '" .. fname .. "' " .. expandKeys(files)
		compress(fname, cmd)
		log('Compressing with: ' .. cmd)
	end,
	['bzip'] = function(out, files)
		local fname = out ..".tar.bz"
		local cmd = TAR_CMD .. " cjf '" .. fname .. "' " .. expandKeys(files)
		compress(fname, cmd)
		log('Compressing with: ' .. cmd)
	end,
	['zstd'] = function(out, files)
		local fname = out ..".tar.zst"
		local cmd = TAR_CMD .. ' cf - '.. expandKeys(files) .. ' | zstd -T0 -19 -o ' .. "'".. fname .."'"
		compress(fname, cmd)
		log('Compressing with: ' .. cmd)
	end,
	['lz4'] = function(out, files)
		local fname = out ..".tar.lz4"
		local cmd = TAR_CMD .. ' cf - '.. expandKeys(files) .. ' | lz4 - ' .. "'".. fname .."'"
		compress(fname, cmd)
		log('Compressing with: ' .. cmd)
	end,
	['7z'] = function(out, files)
		local fname = out ..".7z"
		local cmd = '7z a '.. "'" .. fname .. "' ".. expandKeys(files)
		compress(fname, cmd)
		log('Compressing with: ' .. cmd)
	end
}

--- Help message
local HELP = ('usage: z [-l MOD] [-c ALGO] [-o NAME] [-fh] TARGETS\n'
            ..'\t-f       Override existing archives\n'
            ..'\t-v       Be verbose\n'
            ..'\t-c ALGO  Use ALGO as compression algorithm\n'
            ..'\t-o NAME  Use NAME as archive output\n'
            ..'\t-l MOD   Load lua module MOD and use its Archives field to run the\n'
            ..'\t         program, this will cause the program to ignore any targets\n'
            ..'\t         provided through the command line, supresses: -o,-c\n'
            ..'\t-h       Display this help message\n'
            ..'\t--       Stop parsing options after -\n')

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

	['-v'] = function()
		settings.verbose = true
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
		log('Loading module: ' .. mod)
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

log('Current settings')
for k, v in pairs(settings) do
	log(' ' .. k .. ': ' .. tostring(v))
end

if settings.use_module then
	for _, ar in ipairs(archives) do
		print(ar)
		if keyCount(ar.entries) == 0 then
			print('Archive ' .. ar.name .. ' contains no entries, skipping...')
		else
			COMP_ALGORITHMS[ar.comp_algo](ar.name, ar.entries)
		end
	end
elseif #targets > 0 then
	local ar = Archive{name = settings.override_name or targets[1], comp_algo = settings.algo}
	for _, v in ipairs(targets) do
		ar:addEntry(v)
	end
	print(ar)
	if keyCount(ar.entries) == 0 then
		print('Archive ' .. ar.name .. ' contains no entries, skipping...')
	else
		COMP_ALGORITHMS[ar.comp_algo](ar.name, ar.entries)
	end
else
	--print help and exit
	print(HELP)
	os.exit(1)
end

