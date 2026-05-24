--!strict
local Config = require(script.Parent.Parent.Config)
local Ignore = require(script.Parent.Parent.Utils.Ignore)

local ScriptScanner = {}

export type ScriptEntry = {
	name: string,
	className: string,
	fullPath: string,
	source: string?,
	lines: number,
	bytes: number,
	requires: { string },
	remotes: { string },
	services: { string },
	empty: boolean,
	redacted: boolean,
}

local function detectRequires(source: string): { string }
	local hits = {}
	for path in source:gmatch("require%s*%(([^%)]+)%)") do
		table.insert(hits, (path:gsub("^%s+", ""):gsub("%s+$", "")))
	end
	return hits
end

local function detectRemoteUsage(source: string): { string }
	local hits = {}
	local seen = {}
	for name in source:gmatch("([%a_][%w_]*)%s*:FireServer") do
		if not seen[name] then seen[name] = true; table.insert(hits, name) end
	end
	for name in source:gmatch("([%a_][%w_]*)%s*:FireClient") do
		if not seen[name] then seen[name] = true; table.insert(hits, name) end
	end
	for name in source:gmatch("([%a_][%w_]*)%s*:InvokeServer") do
		if not seen[name] then seen[name] = true; table.insert(hits, name) end
	end
	for name in source:gmatch("([%a_][%w_]*)%s*:InvokeClient") do
		if not seen[name] then seen[name] = true; table.insert(hits, name) end
	end
	return hits
end

local function detectServices(source: string): { string }
	local hits = {}
	local seen = {}
	for svc in source:gmatch("game:GetService%(%s*[\"']([%a]+)[\"']") do
		if not seen[svc] then seen[svc] = true; table.insert(hits, svc) end
	end
	return hits
end

function ScriptScanner.IsScript(inst: Instance): boolean
	return Config.SCRIPT_CLASSES[inst.ClassName] == true
end

function ScriptScanner.Scan(roots: { Instance }, opts: { ignore: Ignore.Rules, safeMode: boolean }): { ScriptEntry }
	local out: { ScriptEntry } = {}
	for _, root in roots do
		local stack: { Instance } = { root }
		while #stack > 0 do
			local cur = table.remove(stack) :: Instance
			if ScriptScanner.IsScript(cur) then
				local path = cur:GetFullName()
				local ignored = Ignore.IsIgnored(opts.ignore, path)
				if not ignored or not opts.safeMode then
					local src: string? = nil
					local ok, value = pcall(function()
						return (cur :: any).Source
					end)
					if ok and typeof(value) == "string" then
						src = value
					end
					local redacted = opts.safeMode and ignored
					if redacted then src = nil end

					local lines = 0
					local bytes = 0
					if src then
						bytes = #src
						if bytes > Config.MAX_SOURCE_BYTES_PER_SCRIPT then
							src = src:sub(1, Config.MAX_SOURCE_BYTES_PER_SCRIPT) .. "\n-- [RoTree] truncated"
						end
						for _ in src:gmatch("\n") do lines = lines + 1 end
						lines = lines + 1
					end

					table.insert(out, {
						name = cur.Name,
						className = cur.ClassName,
						fullPath = path,
						source = src,
						lines = lines,
						bytes = bytes,
						requires = if src then detectRequires(src) else {},
						remotes = if src then detectRemoteUsage(src) else {},
						services = if src then detectServices(src) else {},
						empty = (src == nil) or (#(src or "") < 10),
						redacted = redacted,
					})
				end
			end
			for _, child in cur:GetChildren() do
				table.insert(stack, child)
			end
		end
	end
	return out
end

return ScriptScanner
