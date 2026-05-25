--!strict
local Theme = require(script.Parent.Theme)

local Components = {}

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Theme.Radius.M)
	c.Parent = parent
	return c
end

local function padding(parent: Instance, all: number?)
	local p = Instance.new("UIPadding")
	local v = UDim.new(0, all or Theme.Spacing.M)
	p.PaddingTop, p.PaddingBottom, p.PaddingLeft, p.PaddingRight = v, v, v, v
	p.Parent = parent
	return p
end

local function stroke(parent: GuiObject)
	local s = Instance.new("UIStroke")
	s.Color = Theme.Colors().Border
	s.Thickness = 1
	s.Transparency = 0.2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	Theme.OnChange(function()
		s.Color = Theme.Colors().Border
	end)
	return s
end

function Components.Container(parent: Instance?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Theme.Colors().Background
	f.BackgroundTransparency = 0
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.Parent = parent
	Theme.OnChange(function()
		f.BackgroundColor3 = Theme.Colors().Background
	end)
	return f
end

function Components.Card(parent: Instance, title: string?, subtitle: string?): Frame
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Theme.Colors().Surface
	card.BorderSizePixel = 0
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.Size = UDim2.new(1, 0, 0, 0)
	card.Parent = parent

	corner(card, Theme.Radius.L)
	stroke(card)
	padding(card, Theme.Spacing.L)

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, Theme.Spacing.M)
	layout.Parent = card

	if title then
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, Theme.TextSize.SectionHeader + 4)
		t.Font = Theme.Font.BodyBold
		t.TextSize = Theme.TextSize.SectionHeader
		t.TextColor3 = Theme.Colors().TextPrimary
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Text = title
		t.LayoutOrder = -2
		t.Parent = card
		Theme.OnChange(function()
			t.TextColor3 = Theme.Colors().TextPrimary
		end)
	end

	if subtitle then
		local s = Instance.new("TextLabel")
		s.BackgroundTransparency = 1
		s.Size = UDim2.new(1, 0, 0, Theme.TextSize.Caption + 4)
		s.Font = Theme.Font.Body
		s.TextSize = Theme.TextSize.Caption
		s.TextColor3 = Theme.Colors().TextSecondary
		s.TextXAlignment = Enum.TextXAlignment.Left
		s.Text = subtitle
		s.LayoutOrder = -1
		s.Parent = card
		Theme.OnChange(function()
			s.TextColor3 = Theme.Colors().TextSecondary
		end)
	end

	Theme.OnChange(function()
		card.BackgroundColor3 = Theme.Colors().Surface
	end)

	return card
end

function Components.Button(parent: Instance, text: string, kind: string?, onClick: (() -> ())?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Size = UDim2.new(1, 0, 0, 32)
	b.Font = Theme.Font.BodyBold
	b.TextSize = Theme.TextSize.Body
	b.Text = text
	b.Parent = parent

	corner(b, Theme.Radius.M)

	local function paint()
		local c = Theme.Colors()
		if kind == "ghost" then
			b.BackgroundColor3 = c.GhostBg
			b.TextColor3 = c.GhostFg
		elseif kind == "danger" then
			b.BackgroundColor3 = c.Danger
			b.TextColor3 = Color3.new(1, 1, 1)
		else
			b.BackgroundColor3 = c.ButtonBg
			b.TextColor3 = c.ButtonFg
		end
	end
	paint()
	Theme.OnChange(paint)

	b.MouseEnter:Connect(function()
		local c = Theme.Colors()
		if kind == "ghost" then
			b.BackgroundColor3 = c.GhostBgHover
		else
			b.BackgroundColor3 = c.ButtonBgHover
		end
	end)
	b.MouseLeave:Connect(paint)

	if onClick then
		b.Activated:Connect(onClick)
	end

	return b
end

function Components.StatLine(parent: Instance, label: string, value: string): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 22)
	row.Parent = parent

	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(0.6, 1)
	l.Position = UDim2.fromScale(0, 0)
	l.Font = Theme.Font.Body
	l.TextSize = Theme.TextSize.Body
	l.TextColor3 = Theme.Colors().TextSecondary
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = label
	l.Parent = row

	local v = Instance.new("TextLabel")
	v.BackgroundTransparency = 1
	v.Size = UDim2.fromScale(0.4, 1)
	v.Position = UDim2.fromScale(0.6, 0)
	v.Font = Theme.Font.BodyBold
	v.TextSize = Theme.TextSize.Body
	v.TextColor3 = Theme.Colors().TextPrimary
	v.TextXAlignment = Enum.TextXAlignment.Right
	v.Text = value
	v.Parent = row

	Theme.OnChange(function()
		l.TextColor3 = Theme.Colors().TextSecondary
		v.TextColor3 = Theme.Colors().TextPrimary
	end)

	row:SetAttribute("RoTreeStatKey", label)
	return row
end

function Components.Heading(parent: Instance, title: string, subtitle: string?): Frame
	local h = Instance.new("Frame")
	h.BackgroundTransparency = 1
	h.AutomaticSize = Enum.AutomaticSize.Y
	h.Size = UDim2.new(1, 0, 0, 0)
	h.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = h

	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, Theme.TextSize.Title + 4)
	t.Font = Theme.Font.Title
	t.TextSize = Theme.TextSize.Title
	t.TextColor3 = Theme.Colors().TextPrimary
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = title
	t.Parent = h

	if subtitle then
		local s = Instance.new("TextLabel")
		s.BackgroundTransparency = 1
		s.Size = UDim2.new(1, 0, 0, Theme.TextSize.Subtitle + 4)
		s.Font = Theme.Font.Subtitle
		s.TextSize = Theme.TextSize.Subtitle
		s.TextColor3 = Theme.Colors().TextSecondary
		s.TextXAlignment = Enum.TextXAlignment.Left
		s.Text = subtitle
		s.Parent = h
		Theme.OnChange(function()
			s.TextColor3 = Theme.Colors().TextSecondary
		end)
	end

	Theme.OnChange(function()
		t.TextColor3 = Theme.Colors().TextPrimary
	end)
	return h
end

function Components.StatusDot(parent: Instance, color: Color3): Frame
	local d = Instance.new("Frame")
	d.Size = UDim2.fromOffset(8, 8)
	d.BackgroundColor3 = color
	d.BorderSizePixel = 0
	d.Parent = parent
	corner(d, 4)
	return d
end

function Components.Spacer(parent: Instance, h: number): Frame
	local s = Instance.new("Frame")
	s.BackgroundTransparency = 1
	s.Size = UDim2.new(1, 0, 0, h)
	s.Parent = parent
	return s
end

function Components.Toggle(parent: Instance, label: string, initial: boolean, onChange: (boolean) -> ()): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 28)
	row.Parent = parent

	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -56, 1, 0)
	l.Font = Theme.Font.Body
	l.TextSize = Theme.TextSize.Body
	l.TextColor3 = Theme.Colors().TextPrimary
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = label
	l.Parent = row

	local sw = Instance.new("TextButton")
	sw.Size = UDim2.fromOffset(44, 24)
	sw.Position = UDim2.new(1, -44, 0.5, -12)
	sw.AutoButtonColor = false
	sw.Text = ""
	sw.BorderSizePixel = 0
	sw.Parent = row
	corner(sw, 12)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(20, 20)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Parent = sw
	corner(knob, 10)

	local state = initial
	local function paint()
		local c = Theme.Colors()
		sw.BackgroundColor3 = if state then c.Accent else c.GhostBg
		knob.Position = if state then UDim2.new(1, -22, 0.5, -10) else UDim2.new(0, 2, 0.5, -10)
		l.TextColor3 = c.TextPrimary
	end
	paint()
	Theme.OnChange(paint)

	sw.Activated:Connect(function()
		state = not state
		paint()
		onChange(state)
	end)

	return row
end

return Components
