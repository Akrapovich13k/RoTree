--!strict
-- RoTree — Roblox Game Tree Bridge
-- Plugin entry point. Wires UI to services. No logic lives in this file.

local Config = require(script.Config)
local Theme = require(script.UI.Theme)
local MainWindow = require(script.UI.MainWindow)
local PatchPreview = require(script.UI.PatchPreview)
local ExportService = require(script.Services.ExportService)
local HttpBridge = require(script.Services.HttpBridge)
local PatchService = require(script.Services.PatchService)
local WatchService = require(script.Services.WatchService)

local toolbar = plugin:CreateToolbar(Config.PLUGIN_NAME)
local button = toolbar:CreateButton(
	Config.PLUGIN_NAME,
	Config.PLUGIN_SUBTITLE,
	"rbxasset://textures/Settings/Singleton/UpgradeStudio@2x.png"
)
button.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	false, -- initial enabled
	false, -- override previous state
	360, 600, -- initial w/h
	300, 480  -- min w/h
)
local widget = plugin:CreateDockWidgetPluginGui("RoTreeMain", widgetInfo)
widget.Title = Config.PLUGIN_NAME .. " — " .. Config.PLUGIN_SUBTITLE
widget.Name = "RoTreeMain"

local safeMode = false
local watchOn = false
local autoApplyOn = false
local autoApplyLoopRunning = false

local function notify(title: string, text: string)
	local ok = pcall(function()
		(plugin :: any):Notification({ Title = title, Text = text })
	end)
	if not ok then
		print(string.format("[%s] %s — %s", Config.PLUGIN_NAME, title, text))
	end
end

local window: any
local function rebuildWindow()
	for _, c in widget:GetChildren() do c:Destroy() end
	window = MainWindow.Build(widget, {
		OnExportFull = function()
			notify("RoTree", "Scanning game tree…")
			local ok, err, stats = ExportService.Run("full", safeMode)
			if ok then
				notify("RoTree", "Export sent to VS Code.")
				window.SetBridgeStatus(true)
				if stats then window.SetStats(stats) end
				window.SetLastExport(os.date("!%Y-%m-%d %H:%M UTC"))
			else
				notify("RoTree export failed", tostring(err))
				window.SetBridgeStatus(false)
			end
		end,
		OnExportSelected = function()
			notify("RoTree", "Exporting selection…")
			local ok, err, stats = ExportService.Run("selected", safeMode)
			if ok then
				notify("RoTree", "Selection export sent.")
				if stats then window.SetStats(stats) end
				window.SetLastExport(os.date("!%Y-%m-%d %H:%M UTC"))
				window.SetBridgeStatus(true)
			else
				notify("RoTree", tostring(err))
			end
		end,
		OnExportScripts = function()
			local ok, err = ExportService.Run("scripts", safeMode)
			notify("RoTree", if ok then "Scripts sent." else tostring(err))
		end,
		OnExportRemotes = function()
			local ok, err = ExportService.Run("remotes", safeMode)
			notify("RoTree", if ok then "Remotes sent." else tostring(err))
		end,
		OnExportGui = function()
			local ok, err = ExportService.Run("gui", safeMode)
			notify("RoTree", if ok then "GUI sent." else tostring(err))
		end,
		OnGenerateContext = function()
			-- Re-running a full export regenerates context server-side.
			local ok, err = ExportService.Run("full", safeMode)
			notify("RoTree", if ok then "CLAUDE_CONTEXT.md refreshed." else tostring(err))
		end,
		OnOpenFolder = function()
			-- Plugin can't open OS folders. Ask the extension to.
			HttpBridge.SendExport({ kind = "openFolder" })
			notify("RoTree", "Asked VS Code to reveal .rotree/")
		end,
		OnApplyPatch = function()
			local list = HttpBridge.ListPatches()
			if #list == 0 then
				notify("RoTree", "No pending patches in .rotree/patches/")
				return
			end
			local first = list[1]
			local patch = HttpBridge.GetPatch(first.id)
			if not patch then
				notify("RoTree", "Failed to read patch " .. first.id)
				return
			end
			patch.critical = PatchService.IsCritical(patch)
			PatchPreview.Show(widget, patch, function()
				local result = PatchService.Apply(patch, patch.critical or false)
				if result.success then
					notify("RoTree", string.format("Applied %d ops.", result.applied))
				else
					notify("RoTree", string.format("Applied %d / failed %d. %s", result.applied, result.failed, tostring(result.error or "")))
				end
			end, function()
				notify("RoTree", "Patch cancelled.")
			end)
		end,
		OnPingBridge = function(): boolean
			local ok = HttpBridge.Ping()
			return ok
		end,
		OnSafeModeChanged = function(on: boolean)
			safeMode = on
		end,
		OnWatchModeChanged = function(on: boolean)
			watchOn = on
			if on then
				WatchService.Configure({
					debounceSeconds = 3,
					minIntervalSeconds = 5,
					onTrigger = function()
						local ok, _err, stats = ExportService.Run("full", safeMode)
						if ok and window then
							if stats then window.SetStats(stats) end
							window.SetLastExport(os.date("!%Y-%m-%d %H:%M UTC") .. " (auto)")
							window.SetBridgeStatus(true)
						end
					end,
				})
				WatchService.Enable()
				notify("RoTree", "Watch mode on — re-exports on changes.")
			else
				WatchService.Disable()
				notify("RoTree", "Watch mode off.")
			end
		end,
		OnAutoApplyChanged = function(on: boolean)
			autoApplyOn = on
			if on then
				notify("RoTree", "AI auto-apply ON. Critical patches still need manual confirmation.")
				if not autoApplyLoopRunning then
					autoApplyLoopRunning = true
					task.spawn(function()
						while autoApplyOn do
							local patch = HttpBridge.PollAutoApply()
							if patch then
								if PatchService.IsCritical(patch) then
									-- Refuse here, the user can apply via Apply Patch.
									HttpBridge.ReportApplyResult({
										id = patch.id,
										success = false,
										applied = 0,
										failed = #patch.ops,
										error = "Critical patch — refused by auto-apply. Open Studio → RoTree → Apply Patch to review.",
									})
									notify("RoTree", "Critical patch refused — queued for manual apply: " .. patch.title)
								else
									local result = PatchService.Apply(patch, false)
									HttpBridge.ReportApplyResult({
										id = patch.id,
										success = result.success,
										applied = result.applied,
										failed = result.failed,
										error = result.error,
									})
									if result.success then
										notify("RoTree", "Auto-applied: " .. patch.title)
									else
										notify("RoTree", "Auto-apply failed: " .. (result.error or "?"))
									end
								end
							end
							task.wait(2)
						end
						autoApplyLoopRunning = false
					end)
				end
			else
				notify("RoTree", "AI auto-apply OFF.")
			end
		end,
		OnThemeToggle = function(_dark: boolean)
			rebuildWindow()
		end,
	})
end

button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	if widget.Enabled and #widget:GetChildren() == 0 then
		rebuildWindow()
		task.spawn(function()
			local ok = HttpBridge.Ping()
			if window then window.SetBridgeStatus(ok) end
		end)
	end
end)

plugin.Unloading:Connect(function()
	WatchService.Disable()
	autoApplyOn = false
end)
