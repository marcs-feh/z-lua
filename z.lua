---SHEBANG---

---Global settings
local settings = {
	comp_algo  = '7z',
	outfile = nil, -- Set this to a string and it becomes the forced name
	force = false,
	verbose = false,
	tar_cmd = 'tar', -- Command to use for tape archiver
}

---Log function for verbose mode
local function log(msg)
	if settings.verbose then
		io.stderr:write(tostring(msg) .. '\n')
	end
end

---Check if file is readble(exists)
local function file_exists(path)
	local f = io.open(path, 'r')
	if f then
		f:close()
		return true
	end
	return false
end

---Utility function to expand table to string
local function expand_keys(tbl)
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
		comp_algo = t.comp_algo or settings.comp_algo,
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

---Ask OS to execute cmd, checks if fname exists
local function compress(fname, cmd)
	if file_exists(fname) then
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

---Get compression algorithm from file extension
local function getCompAlgoFromExt(file)
	local ext = file:reverse():match('^%w+%.')
	if not ext then
		print('Unrecognized file format: ' .. tostring(ext))
		os.exit(1)
	else
		ext = ext:reverse()
	end
	local algoExtensions = {
		['.gz']  = 'gzip',
		['.xz']  = 'xz',
		['.bz']  = 'bzip',
		['.zst'] = 'zstd',
		['.lz4'] = 'lz4',
		['.zip'] = 'zip',
		['.7z']  = '7z',
	}
	return algoExtensions[ext]
end


--- Compression algos and their functions.
local COMP_ALGORITHMS = {
	['xz'] = function(out, files)
		local fname = out ..".tar.xz"
		local cmd = settings.tar_cmd .. " cJf '" .. fname .. "' " .. expand_keys(files)
		compress(fname, cmd)
		log('Compressing with: ' .. cmd)
	end,
	['gzip'] = function(out, files)
		local fname = out ..".tar.gz"
		local cmd = settings.tar_cmd .. " czf '" .. fname .. "' " .. expand_keys(files)
		compress(fname, cmd)
		log('Compressing with: ' .. cmd)
	end,
	['bzip'] = function(out, files)
		local fname = out ..".tar.bz"
		local cmd = settings.tar_cmd .. " cjf '" .. fname .. "' " .. expand_keys(files)
		compress(fname, cmd)
		log('Compressing with: ' .. cmd)
	end,
	['zstd'] = function(out, files)
		local fname = out ..".tar.zst"
		local cmd = settings.tar_cmd .. ' cf - '.. expand_keys(files) .. ' | zstd -T0 -19 -o ' .. "'".. fname .."'"
		compress(fname, cmd)
		log('Compressing with: ' .. cmd)
	end,
	['zip'] = function(out, files)
		local fname = out ..".zip"
		local cmd = 'zip '.. "'" .. fname .. "' -r ".. expand_keys(files)
		compress(fname, cmd)
		log('Compressing with: ' .. cmd)
	end,
	['lz4'] = function(out, files)
		local fname = out ..".tar.lz4"
		local cmd = settings.tar_cmd .. ' cf - '.. expand_keys(files) .. ' | lz4 - ' .. "'".. fname .."'"
		compress(fname, cmd)
		log('Compressing with: ' .. cmd)
	end,
	['7z'] = function(out, files)
		local fname = out ..".7z"
		local cmd = '7z a '.. "'" .. fname .. "' ".. expand_keys(files)
		compress(fname, cmd)
		log('Compressing with: ' .. cmd)
	end
}

local DECOMP_ALGORITHMS = {
	['xz'] = function(ar)
		local cmd = "tar xJf '".. ar .."'"
		os.execute(cmd)
	end,
	['gzip'] = function(ar)
		local cmd = "tar xzf '".. ar .."'"
		os.execute(cmd)
	end,
	['bzip'] = function(ar)
		local cmd = "tar xjf '".. ar .."'"
		os.execute(cmd)
	end,
	['zstd'] = function(ar)
		local cmd = "zstd -d '" .. ar .. "' --stdout | tar xf -"
		os.execute(cmd)
	end,
	['lz4'] = function(ar)
		local cmd = "lz4 -c -d '" .. ar .. "' | tar xf -"
		os.execute(cmd)
	end,
	['zip'] = function (ar)
		local cmd = "unzip '" .. ar .. "'"
		os.execute(cmd)
	end,
	['7z'] = function(ar)
		local cmd = "7z x '" .. ar .. "'"
		os.execute(cmd)
	end
}




--- Help message
local HELP = ('usage: z [c|d] [-c:ALGO] [-o:NAME] [OPTS] TARGETS\n'
..'    -c:ALGO  Use ALGO as compression algorithm\n'
..'    -o:NAME  Use NAME as archive output\n'
..'    -h       Display this help message\n'
..'    -f       Override existing archives\n'
..'    -v       Be verbose\n'
..'    --       Stop parsing options after -\n')

---Archive list
local cli_parse = function (arg_list)
	local flags = {}
	local regular = {}

	local is_flag = function(s)
		if #s < 2 then return false end
		return s:sub(1,1) == '-'
	end

	local make_flag = function(s)
		local p = s:find(':')
		local flag = nil
		if not p then
			flag = {s:sub(2, p), true}
		else
			flag = {s:sub(2, p-1), s:sub(p+1, #s)}
		end
		return flag
	end

	for _, arg in ipairs(arg_list) do
		if is_flag(arg) then
			flags[#flags+1] = make_flag(arg)
		else
			regular[#regular+1] = arg
		end
	end

	return flags, regular
end

--- Main
local cli_args = _G.arg
if #cli_args < 2 then
	print(HELP)
	os.exit(1)
end

local mode = cli_args[1]
print('MODE:', mode)

table.remove(cli_args, 1)

if mode == 'c' then
	local flags, targets = cli_parse(cli_args)

	for _, flag in pairs(flags) do
		local key = flag[1]
		local val = flag[2]
		if key == 'h' then
			print(HELP)
			os.exit(1)
		elseif key == 'c' then
			settings.comp_algo = val
		elseif key == 'o' then
			settings.outfile = val
		elseif key == 'v' then
			settings.verbose = true
		elseif key == 'f' then
			settings.force = true
		end
	end

	for k, v in pairs(settings) do
		print(('%s: %s'):format(k, v))
	end

	local out = Archive{
		name = settings.outfile or targets[1],
		comp_algo = settings.comp_algo,
	}

	for _, t in ipairs(targets) do
		out:addEntry(t)
	end

	COMP_ALGORITHMS[out.comp_algo](out.name, out.entries)

elseif mode == 'd' then
	local archives = {}
	for _, a in ipairs(cli_args) do
		archives[#archives+1] = a
	end

	for _, ar in ipairs(archives) do
		local algo = getCompAlgoFromExt(ar)
		local fn = DECOMP_ALGORITHMS[algo]
		if not fn then
			print('Unrecognized file format: ' .. algo)
			os.exit(1)
		else
			print("[\027[0;34mDecompressing\027[0m]")
			print("  \027[0;36m*\027[0m '".. ar .."' -> \027[0;33m" .. tostring(algo) .. "\027[0m")
			fn(ar)
		end
	end
else
	print(HELP)
	os.exit(1)
end



