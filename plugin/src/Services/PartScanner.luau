--!strict
local Config = require(script.Parent.Parent.Config)

local PartScanner = {}

export type PartEntry = {
	name: string,
	className: string,
	fullPath: string,
	position: { number }?,
	size: { number }?,
	orientation: { number }?,
	color: { number }?,
	material: string?,
	anchored: boolean?,
	canCollide: boolean?,
	transparency: number?,
	shape: string?,
}

function PartScanner.IsPart(inst: Instance): boolean
	return Config.PART_CLASSES[inst.ClassName] == true
end

function PartScanner.Scan(roots: { Instance }, opts: { maxParts: number? }?): { PartEntry }
	local out: { PartEntry } = {}
	local cap = (opts and opts.maxParts) or 2000
	for _, root in roots do
		local stack: { Instance } = { root }
		while #stack > 0 do
			if #out >= cap then return out end
			local cur = table.remove(stack) :: Instance
			if PartScanner.IsPart(cur) then
				local p: any = cur
				local entry: PartEntry = {
					name = cur.Name,
					className = cur.ClassName,
					fullPath = cur:GetFullName(),
				}
				pcall(function() entry.position = { p.Position.X, p.Position.Y, p.Position.Z } end)
				pcall(function() entry.size = { p.Size.X, p.Size.Y, p.Size.Z } end)
				pcall(function()
					local o = p.Orientation
					entry.orientation = { o.X, o.Y, o.Z }
				end)
				pcall(function() entry.color = { p.Color.R, p.Color.G, p.Color.B } end)
				pcall(function() entry.material = p.Material.Name end)
				pcall(function() entry.anchored = p.Anchored end)
				pcall(function() entry.canCollide = p.CanCollide end)
				pcall(function() entry.transparency = p.Transparency end)
				pcall(function() entry.shape = p.Shape.Name end)
				table.insert(out, entry)
			end
			for _, child in cur:GetChildren() do
				table.insert(stack, child)
			end
		end
	end
	return out
end

return PartScanner
