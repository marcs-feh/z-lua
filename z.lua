#!/usr/bin/env lua

---Compression algos and their extensions.
local COMP_ALGORITHMS = {
	['xz'] = 'xz',
	['zstd'] = 'zst',
	['gzip'] = 'gz',
	['bzip'] = 'bz'
}

local settings = {
	algo  = 'gzip',
	force = false,
}

local flags = {
	['-c'] = function(arg)
		if not COMP_ALGORITHMS[arg] then
			error('Invalid Compression algorithm: ' .. tostring(arg), 2)
		end
	end,
	['-f'] = function()
		settings.force = true
	end
}

