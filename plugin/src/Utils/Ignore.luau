--!strict
-- Matches paths against .rotreeignore-style globs. The actual file is read by the
-- VS Code extension and sent back to the plugin on connect.

local Ignore = {}

export type Rules = {
	patterns: { string },
	critical: { string },
}

function Ignore.Empty(): Rules
	return { patterns = {}, critical = {} }
end

local function escapeMagic(s: string): string
	return (s:gsub("[%(%)%.%+%-%?%[%]%^%$%%]", "%%%1"))
end

local function globToLuaPattern(g: string): string
	-- Convert a gitignore-like glob into a Lua pattern.
	-- ** -> .*  (matches any path segments)
	-- *  -> [^.]*  (matches within one segment)
	-- ?  -> .
	local out = {}
	local i = 1
	while i <= #g do
		local c = g:sub(i, i)
		if c == "*" and g:sub(i + 1, i + 1) == "*" then
			table.insert(out, ".*")
			i = i + 2
		elseif c == "*" then
			table.insert(out, "[^.]*")
			i = i + 1
		elseif c == "?" then
			table.insert(out, ".")
			i = i + 1
		elseif c == "/" then
			table.insert(out, "%.")
			i = i + 1
		else
			table.insert(out, escapeMagic(c))
			i = i + 1
		end
	end
	return "^" .. table.concat(out) .. "$"
end

function Ignore.Parse(text: string): Rules
	local rules = Ignore.Empty()
	for line in (text or ""):gmatch("[^\r\n]+") do
		local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
		if trimmed == "" or trimmed:sub(1, 1) == "#" then
			continue
		end
		local isCritical = trimmed:sub(1, 9) == "critical:"
		if isCritical then trimmed = trimmed:sub(10):gsub("^%s+", "") end
		table.insert(if isCritical then rules.critical else rules.patterns, globToLuaPattern(trimmed))
	end
	return rules
end

function Ignore.IsIgnored(rules: Rules, path: string): boolean
	for _, pat in rules.patterns do
		if path:match(pat) then return true end
	end
	return false
end

function Ignore.IsCritical(rules: Rules, path: string): boolean
	for _, pat in rules.critical do
		if path:match(pat) then return true end
	end
	return false
end

return Ignore
