--!strict
-- The full RoTree window. Builds the layout, exposes setters for live data.
-- Receives an `api` table of callbacks for each action (no logic here).

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Config = require(script.Parent.Parent.Config)

export type Api = {
	OnExportFull: () -> (),
	OnExportSelected: () -> (),
	OnExportScripts: () -> (),
	OnExportRemotes: () -> (),
	OnExportGui: () -> (),
	OnGenerateContext: () -> (),
	OnOpenFolder: () -> (),
	OnApplyPatch: () -> (),
	OnPingBridge: () -> boolean,
	OnSafeModeChanged: (boolean) -> (),
	OnThemeToggle: (boolean) -> (),
}

local MainWindow = {}

function MainWindow.Build(parent: PluginGui, api: Api)
	local stats = {
		instances = 0,
		scripts = 0,
		remotes = 0,
		gui = 0,
		parts = 0,
		modules = 0,
	}
	local lastExport = "never"
	local bridgeOnline = false

	-- root container
	local root = Components.Container(parent)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = root

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, Theme.Spacing.XL)
	pad.PaddingBottom = UDim.new(0, Theme.Spacing.XL)
	pad.PaddingLeft = UDim.new(0, Theme.Spacing.XL)
	pad.PaddingRight = UDim.new(0, Theme.Spacing.XL)
	pad.Parent = scroll

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, Theme.Spacing.L)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	-- Header
	local headerWrap = Instance.new("Frame")
	headerWrap.BackgroundTransparency = 1
	headerWrap.AutomaticSize = Enum.AutomaticSize.Y
	headerWrap.Size = UDim2.new(1, 0, 0, 0)
	headerWrap.LayoutOrder = 1
	headerWrap.Parent = scroll
	Components.Heading(headerWrap, Config.PLUGIN_NAME, Config.PLUGIN_SUBTITLE)

	-- Bridge status card
	local bridgeCard = Components.Card(scroll, "Bridge", "Connection to VS Code")
	bridgeCard.LayoutOrder = 2

	local bridgeRow = Instance.new("Frame")
	bridgeRow.BackgroundTransparency = 1
	bridgeRow.Size = UDim2.new(1, 0, 0, 22)
	bridgeRow.Parent = bridgeCard

	local dot = Components.StatusDot(bridgeRow, Theme.Colors().Danger)
	dot.Position = UDim2.new(0, 0, 0.5, -4)

	local bridgeLabel = Instance.new("TextLabel")
	bridgeLabel.BackgroundTransparency = 1
	bridgeLabel.Size = UDim2.new(1, -16, 1, 0)
	bridgeLabel.Position = UDim2.new(0, 16, 0, 0)
	bridgeLabel.Font = Theme.Font.Body
	bridgeLabel.TextSize = Theme.TextSize.Body
	bridgeLabel.TextColor3 = Theme.Colors().TextPrimary
	bridgeLabel.TextXAlignment = Enum.TextXAlignment.Left
	bridgeLabel.Text = "Offline · localhost:" .. Config.BRIDGE_PORT
	bridgeLabel.Parent = bridgeRow

	Components.Button(bridgeCard, "Test connection", "ghost", function()
		local ok = api.OnPingBridge()
		MainWindow.SetBridgeStatus(ok)
	end)

	-- Exports card
	local exports = Components.Card(scroll, "Exports", "Send your game tree to VS Code")
	exports.LayoutOrder = 3

	Components.Button(exports, "Export Game Tree", nil, api.OnExportFull)
	Components.Button(exports, "Export Selected", "ghost", api.OnExportSelected)
	Components.Button(exports, "Export Scripts", "ghost", api.OnExportScripts)
	Components.Button(exports, "Export Remotes", "ghost", api.OnExportRemotes)
	Components.Button(exports, "Export GUI", "ghost", api.OnExportGui)

	Components.Toggle(exports, "Safe Mode (redact sensitive sources)", false, api.OnSafeModeChanged)

	-- Stats card
	local statsCard = Components.Card(scroll, "Last export", "Snapshot of what was sent")
	statsCard.LayoutOrder = 4

	local lastRow = Components.StatLine(statsCard, "When", lastExport)
	local s1 = Components.StatLine(statsCard, "Instances", "0")
	local s2 = Components.StatLine(statsCard, "Scripts", "0")
	local s3 = Components.StatLine(statsCard, "Remotes", "0")
	local s4 = Components.StatLine(statsCard, "GUI elements", "0")
	local s5 = Components.StatLine(statsCard, "Parts", "0")
	local s6 = Components.StatLine(statsCard, "ModuleScripts", "0")

	-- Claude Context card
	local ctx = Components.Card(scroll, "Claude Context", "Generate the file Claude reads")
	ctx.LayoutOrder = 5
	Components.Button(ctx, "Generate Claude Context", "ghost", api.OnGenerateContext)
	Components.Button(ctx, "Open Export Folder", "ghost", api.OnOpenFolder)

	-- Rojo card
	local rojo = Components.Card(scroll, "Rojo", "Detected from VS Code workspace")
	rojo.LayoutOrder = 6
	local rojoStatus = Components.StatLine(rojo, "Status", "Unknown")

	-- Patch Safety card
	local patch = Components.Card(scroll, "Patch Safety", "Apply only after preview + confirmation")
	patch.LayoutOrder = 7
	Components.StatLine(patch, "Backups", "Auto, per patch")
	Components.StatLine(patch, "Critical confirm", "Required for DataStore, leaderstats, etc.")
	Components.Button(patch, "Apply Patch…", "ghost", api.OnApplyPatch)

	-- Theme toggle card
	local themeCard = Components.Card(scroll, "Appearance", nil)
	themeCard.LayoutOrder = 8
	Components.Toggle(themeCard, "Dark mode", Theme.Mode == "Dark", function(on)
		Theme.SetMode(if on then "Dark" else "Light")
		api.OnThemeToggle(on)
	end)

	-- Footer
	local footer = Instance.new("TextLabel")
	footer.BackgroundTransparency = 1
	footer.Size = UDim2.new(1, 0, 0, 18)
	footer.Font = Theme.Font.Body
	footer.TextSize = Theme.TextSize.Caption
	footer.TextColor3 = Theme.Colors().TextTertiary
	footer.TextXAlignment = Enum.TextXAlignment.Center
	footer.Text = string.format("RoTree v%s · local-only", Config.PLUGIN_VERSION)
	footer.LayoutOrder = 100
	footer.Parent = scroll
	Theme.OnChange(function()
		footer.TextColor3 = Theme.Colors().TextTertiary
	end)

	-- Public setters
	function MainWindow.SetBridgeStatus(online: boolean)
		bridgeOnline = online
		dot.BackgroundColor3 = if online then Theme.Colors().Success else Theme.Colors().Danger
		bridgeLabel.Text = (if online then "Online" else "Offline") .. " · localhost:" .. Config.BRIDGE_PORT
	end

	function MainWindow.SetStats(s: { [string]: number })
		stats = s
		local pairs_ = { { s1, "instances" }, { s2, "scripts" }, { s3, "remotes" }, { s4, "gui" }, { s5, "parts" }, { s6, "modules" } }
		for _, statRow in pairs_ do
			local row, key = statRow[1], statRow[2]
			for _, child in row:GetChildren() do
				if child:IsA("TextLabel") and child.TextXAlignment == Enum.TextXAlignment.Right then
					child.Text = tostring(s[key] or 0)
				end
			end
		end
	end

	function MainWindow.SetLastExport(when: string)
		lastExport = when
		local labels = lastRow:GetChildren()
		for _, child in labels do
			if child:IsA("TextLabel") and child.TextXAlignment == Enum.TextXAlignment.Right then
				child.Text = when
			end
		end
	end

	function MainWindow.SetRojoStatus(text: string)
		local labels = rojoStatus:GetChildren()
		for _, child in labels do
			if child:IsA("TextLabel") and child.TextXAlignment == Enum.TextXAlignment.Right then
				child.Text = text
			end
		end
	end

	return MainWindow
end

return MainWindow
