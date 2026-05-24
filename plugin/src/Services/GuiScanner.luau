--!strict
local Config = require(script.Parent.Parent.Config)

local GuiScanner = {}

export type GuiEntry = {
	name: string,
	className: string,
	fullPath: string,
	size: { number }?,
	position: { number }?,
	anchorPoint: { number }?,
	backgroundColor: { number }?,
	backgroundTransparency: number?,
	text: string?,
	image: string?,
	visible: boolean?,
	zIndex: number?,
	children: { string },
}

local function color3ToTable(c: Color3?): { number }?
	if not c then return nil end
	return { c.R, c.G, c.B }
end

local function udim2ToTable(u: UDim2?): { number }?
	if not u then return nil end
	return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset }
end

local function vector2ToTable(v: Vector2?): { number }?
	if not v then return nil end
	return { v.X, v.Y }
end

function GuiScanner.IsGui(inst: Instance): boolean
	return Config.GUI_CLASSES[inst.ClassName] == true
end

function GuiScanner.Scan(roots: { Instance }): { GuiEntry }
	local out: { GuiEntry } = {}
	for _, root in roots do
		local stack: { Instance } = { root }
		while #stack > 0 do
			local cur = table.remove(stack) :: Instance
			if GuiScanner.IsGui(cur) then
				local entry: GuiEntry = {
					name = cur.Name,
					className = cur.ClassName,
					fullPath = cur:GetFullName(),
					children = {},
				}
				local g: any = cur
				if pcall(function() return g.Size end) then entry.size = udim2ToTable(g.Size) end
				if pcall(function() return g.Position end) then entry.position = udim2ToTable(g.Position) end
				if pcall(function() return g.AnchorPoint end) then entry.anchorPoint = vector2ToTable(g.AnchorPoint) end
				if pcall(function() return g.BackgroundColor3 end) then entry.backgroundColor = color3ToTable(g.BackgroundColor3) end
				if pcall(function() return g.BackgroundTransparency end) then entry.backgroundTransparency = g.BackgroundTransparency end
				if pcall(function() return g.Text end) then entry.text = tostring(g.Text) end
				if pcall(function() return g.Image end) then entry.image = tostring(g.Image) end
				if pcall(function() return g.Visible end) then entry.visible = g.Visible end
				if pcall(function() return g.ZIndex end) then entry.zIndex = g.ZIndex end

				for _, child in cur:GetChildren() do
					if GuiScanner.IsGui(child) then
						table.insert(entry.children, child.Name)
					end
				end
				table.insert(out, entry)
			end
			for _, child in cur:GetChildren() do
				table.insert(stack, child)
			end
		end
	end
	return out
end

return GuiScanner
