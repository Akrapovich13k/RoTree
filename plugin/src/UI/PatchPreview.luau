--!strict
-- A modal-like preview shown inside the plugin widget before any patch is applied.

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local PatchPreview = {}

export type PatchOp = {
	op: string,
	path: string?,
	source: string?,
	props: { [string]: any }?,
}

export type Patch = {
	id: string,
	title: string,
	description: string?,
	critical: boolean?,
	ops: { PatchOp },
}

function PatchPreview.Show(parent: PluginGui, patch: Patch, onConfirm: () -> (), onCancel: () -> ())
	local existing = parent:FindFirstChild("RoTreePatchModal")
	if existing then existing:Destroy() end

	local overlay = Instance.new("Frame")
	overlay.Name = "RoTreePatchModal"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.4
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 50
	overlay.Parent = parent

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.new(0.9, 0, 0.9, 0)
	card.BackgroundColor3 = Theme.Colors().Surface
	card.BorderSizePixel = 0
	card.ZIndex = 51
	card.Parent = overlay

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.Radius.L)
	corner.Parent = card

	local padding = Instance.new("UIPadding")
	local pv = UDim.new(0, Theme.Spacing.L)
	padding.PaddingTop, padding.PaddingBottom, padding.PaddingLeft, padding.PaddingRight = pv, pv, pv, pv
	padding.Parent = card

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, Theme.Spacing.M)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = card

	-- Title
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, Theme.TextSize.Title + 4)
	title.Font = Theme.Font.Title
	title.TextSize = Theme.TextSize.Title
	title.TextColor3 = Theme.Colors().TextPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Review patch: " .. patch.title
	title.ZIndex = 51
	title.Parent = card

	if patch.critical then
		local warn = Instance.new("TextLabel")
		warn.BackgroundColor3 = Theme.Colors().Warning
		warn.BackgroundTransparency = 0.85
		warn.Size = UDim2.new(1, 0, 0, 36)
		warn.Font = Theme.Font.BodyBold
		warn.TextSize = Theme.TextSize.Body
		warn.TextColor3 = Theme.Colors().Warning
		warn.Text = "  ⚠ Critical patch — affects DataStore / leaderstats / purchases."
		warn.TextXAlignment = Enum.TextXAlignment.Left
		warn.ZIndex = 51
		warn.Parent = card
		local wc = Instance.new("UICorner")
		wc.CornerRadius = UDim.new(0, Theme.Radius.S)
		wc.Parent = warn
	end

	if patch.description then
		local d = Instance.new("TextLabel")
		d.BackgroundTransparency = 1
		d.Size = UDim2.new(1, 0, 0, 40)
		d.Font = Theme.Font.Body
		d.TextSize = Theme.TextSize.Body
		d.TextColor3 = Theme.Colors().TextSecondary
		d.TextXAlignment = Enum.TextXAlignment.Left
		d.TextYAlignment = Enum.TextYAlignment.Top
		d.TextWrapped = true
		d.Text = patch.description
		d.ZIndex = 51
		d.Parent = card
	end

	-- Op list
	local opsScroll = Instance.new("ScrollingFrame")
	opsScroll.Size = UDim2.new(1, 0, 1, -160)
	opsScroll.BackgroundColor3 = Theme.Colors().SurfaceAlt
	opsScroll.BorderSizePixel = 0
	opsScroll.ScrollBarThickness = 6
	opsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	opsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	opsScroll.ZIndex = 51
	opsScroll.Parent = card

	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, Theme.Radius.M)
	sc.Parent = opsScroll

	local sp = Instance.new("UIPadding")
	sp.PaddingTop = UDim.new(0, 8)
	sp.PaddingBottom = UDim.new(0, 8)
	sp.PaddingLeft = UDim.new(0, 8)
	sp.PaddingRight = UDim.new(0, 8)
	sp.Parent = opsScroll

	local sl = Instance.new("UIListLayout")
	sl.Padding = UDim.new(0, 4)
	sl.SortOrder = Enum.SortOrder.LayoutOrder
	sl.Parent = opsScroll

	for i, op in patch.ops do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 18)
		row.Font = Theme.Font.Mono
		row.TextSize = Theme.TextSize.Caption
		row.TextColor3 = Theme.Colors().TextPrimary
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = string.format("%d. %s  %s", i, op.op, op.path or "")
		row.ZIndex = 51
		row.LayoutOrder = i
		row.Parent = opsScroll
	end

	-- Buttons
	local btnRow = Instance.new("Frame")
	btnRow.BackgroundTransparency = 1
	btnRow.Size = UDim2.new(1, 0, 0, 36)
	btnRow.ZIndex = 51
	btnRow.LayoutOrder = 99
	btnRow.Parent = card

	local btnLayout = Instance.new("UIListLayout")
	btnLayout.FillDirection = Enum.FillDirection.Horizontal
	btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	btnLayout.Padding = UDim.new(0, Theme.Spacing.S)
	btnLayout.Parent = btnRow

	local cancel = Instance.new("TextButton")
	cancel.AutoButtonColor = false
	cancel.Size = UDim2.fromOffset(110, 32)
	cancel.BackgroundColor3 = Theme.Colors().GhostBg
	cancel.TextColor3 = Theme.Colors().GhostFg
	cancel.Font = Theme.Font.BodyBold
	cancel.TextSize = Theme.TextSize.Body
	cancel.Text = "Cancel"
	cancel.ZIndex = 51
	cancel.Parent = btnRow
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, Theme.Radius.M)
	cc.Parent = cancel

	local apply = Instance.new("TextButton")
	apply.AutoButtonColor = false
	apply.Size = UDim2.fromOffset(140, 32)
	apply.BackgroundColor3 = if patch.critical then Theme.Colors().Danger else Theme.Colors().Accent
	apply.TextColor3 = Color3.new(1, 1, 1)
	apply.Font = Theme.Font.BodyBold
	apply.TextSize = Theme.TextSize.Body
	apply.Text = if patch.critical then "Apply (Critical)" else "Apply patch"
	apply.ZIndex = 51
	apply.Parent = btnRow
	local ac = Instance.new("UICorner")
	ac.CornerRadius = UDim.new(0, Theme.Radius.M)
	ac.Parent = apply

	cancel.Activated:Connect(function()
		overlay:Destroy()
		onCancel()
	end)

	apply.Activated:Connect(function()
		if patch.critical then
			-- Second confirmation step: rename button, require a click again
			if apply.Text == "Confirm critical apply" then
				overlay:Destroy()
				onConfirm()
			else
				apply.Text = "Confirm critical apply"
				apply.BackgroundColor3 = Theme.Colors().Danger
			end
		else
			overlay:Destroy()
			onConfirm()
		end
	end)
end

return PatchPreview
