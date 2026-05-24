--!strict
local PathUtils = {}

function PathUtils.FullPath(inst: Instance): string
	return inst:GetFullName()
end

function PathUtils.Parent(path: string): string?
	local last = path:find("%.[^%.]*$")
	if not last then return nil end
	return path:sub(1, last - 1)
end

function PathUtils.Tail(path: string): string
	local last = path:find("%.[^%.]*$")
	if not last then return path end
	return path:sub(last + 1)
end

function PathUtils.Resolve(rootPath: string): Instance?
	local parts = string.split(rootPath, ".")
	local first = parts[1]
	local svc: Instance? = game:FindFirstChild(first)
	if not svc then
		local ok, s = pcall(function() return game:GetService(first) end)
		if ok then svc = s end
	end
	if not svc then return nil end
	local current: Instance = svc
	for i = 2, #parts do
		local nxt = current:FindFirstChild(parts[i])
		if not nxt then return nil end
		current = nxt
	end
	return current
end

return PathUtils
