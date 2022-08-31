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
	force = false,
}

---Archive list
local archives = {}

---Flags and their actions
local flags = {
	['-c'] = function(arg)
		if not COMP_ALGORITHMS[arg] then
			error('Invalid compression algorithm: ' .. tostring(arg), 2)
		end
	end,
	['-f'] = function()
		settings.force = true
	end,
}

--- Main

