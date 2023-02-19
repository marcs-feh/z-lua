---SHEBANG---

local COMP_ALGORITHMS = {
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

---Help message
local HELP = ('usage: uz [-h] ARCHIVES\n'
            ..'\t-h  Display this help message\n'
            ..'\t--  Stop parsing options after -\n')

---Flags and their actions
local flags = {}
flags = {
	['-h'] = function()
		print(HELP)
		os.exit(0)
	end,
	['--'] = function()
		flags = {}
	end
}

---Get compression algorithm from file extension
local function getCompAlgo(file)
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

---Archives
local archives = {}

---Main
for _, a in ipairs(arg) do
	if flags[a] then
		flags[a]()
	else
		archives[#archives+1] = a
	end
end

if #arg < 1 or #archives == 0 then
	print(HELP)
	os.exit(1)
else
	for _, ar in ipairs(archives) do
		local algo = getCompAlgo(ar)
		local fn = COMP_ALGORITHMS[algo]
		if not fn then
			print('Unrecognized file format: ' .. algo)
			os.exit(1)
		else
			print("[\027[0;34mDecompressing\027[0m]")
			print("  \027[0;36m*\027[0m '".. ar .."' -> \027[0;33m" .. tostring(algo) .. "\027[0m")
			fn(ar)
		end
	end
end

