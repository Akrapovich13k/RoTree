--!strict
local AttributeScanner = {}

-- Serialize an attribute value into the SAME JSON shapes PropertyScanner emits,
-- so the AI sees one consistent representation everywhere (and patch-apply can
-- round-trip it). Roblox attributes can be any of these data types — covering
-- them all keeps Model/Folder metadata (e.g. an "OwnerId" or "SpawnCFrame" on a
-- base) from collapsing into a lossy tostring().
local function serializeValue(v: any): any
	local t = typeof(v)
	if t == "string" or t == "number" or t == "boolean" then return v end
	if t == "Vector3" then return { x = v.X, y = v.Y, z = v.Z } end
	if t == "Vector2" then return { x = v.X, y = v.Y } end
	if t == "Color3" then return { r = v.R, g = v.G, b = v.B } end
	if t == "BrickColor" then return { name = v.Name, number = v.Number } end
	if t == "UDim" then return { scale = v.Scale, offset = v.Offset } end
	if t == "UDim2" then
		return {
			x = { scale = v.X.Scale, offset = v.X.Offset },
			y = { scale = v.Y.Scale, offset = v.Y.Offset },
		}
	end
	if t == "CFrame" then return { components = { v:GetComponents() } } end
	if t == "NumberRange" then return { min = v.Min, max = v.Max } end
	if t == "Rect" then
		return {
			min = { x = v.Min.X, y = v.Min.Y },
			max = { x = v.Max.X, y = v.Max.Y },
		}
	end
	if t == "Font" then return { family = v.Family, weight = v.Weight.Name, style = v.Style.Name } end
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
