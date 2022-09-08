# z-lua

z-lua is a small archiving utility that serves as a front-end to other
archiving and file compression software such as `tar`, `gzip`, `xz`, `bzip`,
`zstd`, `lz4`, `7z`.

## Defining archives using Lua

You can use lua code to define a list of archives like so

```lua
--- example.lua
Archives = {
	{
		-- Name of the archive (extension is decided automatically based on comp_algo
		name = 'media',
		-- Folders/Files to compress
		entries = {'~/Music', '~/Videos', '~/Pictures'},
		-- Compression algorithm
		comp_algo = 'zstd'
	},
	{
		name = 'bigfile',
	  -- Compressing a single file is fine, just dont forget the {}
		entries = {'~/Projects/mybigfile'},
		comp_algo = '7z'
	},
}
```
The valid `comp_algo` are:
- gzip
- xz
- bzip
- zstd
- lz4
- 7z

