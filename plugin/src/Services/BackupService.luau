--!strict
-- Snapshots specific instances to JSON so we can describe state pre-patch.
-- The actual snapshot is sent to VS Code via HttpBridge for disk storage.

local PathUtils = require(script.Parent.Parent.Utils.PathUtils)
local HttpBridge = require(script.Parent.HttpBridge)

local BackupService = {}

export type Snapshot = {
	path: string,
	className: string,
	name: string,
	source: string?,
	parent: string?,
}

function BackupService.SnapshotPaths(paths: { string }): { Snapshot }
	local snaps: { Snapshot } = {}
	for _, path in paths do
		local inst = PathUtils.Resolve(path)
		if inst then
			local snap: Snapshot = {
				path = path,
				className = inst.ClassName,
				name = inst.Name,
				parent = if inst.Parent then inst.Parent:GetFullName() else nil,
			}
			local ok, src = pcall(function() return (inst :: any).Source end)
			if ok and typeof(src) == "string" then snap.source = src end
			table.insert(snaps, snap)
		else
			table.insert(snaps, { path = path, className = "?", name = PathUtils.Tail(path) })
		end
	end
	return snaps
end

function BackupService.Send(patchId: string, snapshots: { Snapshot }): boolean
	-- Re-use the export endpoint pattern with a 'backup' kind so the extension
	-- writes to .rotree/backups/.
	local ok = HttpBridge.SendExport({
		kind = "backup",
		patchId = patchId,
		exportedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		snapshots = snapshots,
	})
	return ok
end

return BackupService
