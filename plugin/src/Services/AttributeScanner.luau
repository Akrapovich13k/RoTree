--!strict
local AttributeScanner = {}

local function serializeValue(v: any): any
	local t = typeof(v)
	if t == "string" or t == "number" or t == "boolean" or t == nil then return v end
	if t == "Vector3" then return { x = v.X, y = v.Y, z = v.Z } end
	if t == "Vector2" then return { x = v.X, y = v.Y } end
	if t == "Color3" then return { r = v.R, g = v.G, b = v.B } end
	if t == "UDim2" then return { sx = v.X.Scale, ox = v.X.Offset, sy = v.Y.Scale, oy = v.Y.Offset } end
	if t == "EnumItem" then return v.Name end
	return tostring(v)
end

function AttributeScanner.Scan(roots: { Instance }): { [string]: { [string]: any } }
	local out: { [string]: { [string]: any } } = {}
	for _, root in roots do
		local stack: { Instance } = { root }
		while #stack > 0 do
			local cur = table.remove(stack) :: Instance
			local attrs = cur:GetAttributes()
			local has = false
			local clean: { [string]: any } = {}
			for k, v in attrs do
				has = true
				if k:sub(1, 8) == "_secret_" then continue end
				clean[k] = serializeValue(v)
			end
			if has and next(clean) ~= nil then
				out[cur:GetFullName()] = clean
			end
			for _, child in cur:GetChildren() do
				table.insert(stack, child)
			end
		end
	end
	return out
end

return AttributeScanner
