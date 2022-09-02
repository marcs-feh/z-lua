#!/usr/bin/env lua

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
		local cmd = "lz4 -d '" .. ar .. "' --stdout | tar xf -"
		os.execute(cmd)
	end,
}

---Get compression algorithm from file extension
local function getCompAlgo(file)
	local ext = file:reverse():match('^%w+%.'):reverse()
	local algoExtensions = {
		['.gz'] = 'gzip',
		['.xz'] = 'xz',
		['.bz'] = 'bzip',
		['.zst'] = 'zstd',
		['.lz4'] = 'lz4',
	}
	return algoExtensions[ext]
end

---Main
if #arg < 1 then
	print('help')
else
	print("[\027[0;34mDecompressing\027[0m]")
	for _, a in ipairs(arg) do
		local algo = getCompAlgo(a)
		print("  \027[0;36m*\027[0m '".. a .."' -> \027[0;33m" .. algo .. "\027[0m")
		COMP_ALGORITHMS[algo](a)
	end
end

