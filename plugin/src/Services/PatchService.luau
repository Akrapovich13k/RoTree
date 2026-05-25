--!strict
-- The SOLE module that mutates the DataModel.
-- Every entry point requires (a) a fresh user confirmation upstream and
-- (b) a successful backup. Critical patches require the caller to pass
-- `criticalConfirmed = true`.

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Config = require(script.Parent.Parent.Config)
local PathUtils = require(script.Parent.Parent.Utils.PathUtils)
local BackupService = require(script.Parent.BackupService)
local PropertyDeserializer = require(script.Parent.PropertyDeserializer)

local PatchService = {}

export type PatchOp = {
	op: string, -- "setSource" | "setProperties" | "createFolder" | "createScript" | "rename" | "delete"
	path: string?,
	parentPath: string?,
	name: string?,
	className: string?,
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

function PatchService.IsCritical(patch: Patch): boolean
	if patch.critical then return true end
	for _, op in patch.ops do
		local p = op.path or op.parentPath or ""
		for _, pat in Config.CRITICAL_PATTERNS do
			if string.find(p, pat, 1, true) then return true end
		end
	end
	local deletes = 0
	for _, op in patch.ops do
		if op.op == "delete" then deletes += 1 end
	end
	if deletes > Config.MAX_PATCH_DELETES then return true end
	return false
end

local function collectAffectedPaths(patch: Patch): { string }
	local set: { [string]: true } = {}
	for _, op in patch.ops do
		if op.path then set[op.path] = true end
		if op.parentPath then set[op.parentPath] = true end
	end
	local out: { string } = {}
	for k in set do table.insert(out, k) end
	return out
end

local function applyOp(op: PatchOp): (boolean, string?)
	if op.op == "setSource" then
		if not op.path or not op.source then return false, "setSource requires path + source" end
		local inst = PathUtils.Resolve(op.path)
		if not inst then return false, "Instance not found: " .. op.path end
		local ok, err = pcall(function() (inst :: any).Source = op.source end)
		if not ok then return false, tostring(err) end
		return true, nil

	elseif op.op == "setProperties" then
		if not op.path or not op.props then return false, "setProperties requires path + props" end
		local inst = PathUtils.Resolve(op.path)
		if not inst then return false, "Instance not found: " .. op.path end
		local props = PropertyDeserializer.ConvertProps(op.props)
		for k, v in props do
			local ok, err = pcall(function() (inst :: any)[k] = v end)
			if not ok then return false, string.format("Failed to set %s: %s", k, tostring(err)) end
		end
		return true, nil

	elseif op.op == "createFolder" then
		if not op.parentPath or not op.name then return false, "createFolder requires parentPath + name" end
		local parent = PathUtils.Resolve(op.parentPath)
		if not parent then return false, "Parent not found: " .. op.parentPath end
		local f = Instance.new("Folder")
		f.Name = op.name
		f.Parent = parent
		return true, nil

	elseif op.op == "createScript" then
		if not op.parentPath or not op.name or not op.className then
			return false, "createScript requires parentPath + name + className"
		end
		if op.className ~= "Script" and op.className ~= "LocalScript" and op.className ~= "ModuleScript" then
			return false, "Invalid script className: " .. tostring(op.className)
		end
		local parent = PathUtils.Resolve(op.parentPath)
		if not parent then return false, "Parent not found: " .. op.parentPath end
		local s = Instance.new(op.className)
		s.Name = op.name
		if op.source then (s :: any).Source = op.source end
		s.Parent = parent
		return true, nil

	elseif op.op == "createInstance" then
		if not op.parentPath or not op.className then
			return false, "createInstance requires parentPath + className"
		end
		local parent = PathUtils.Resolve(op.parentPath)
		if not parent then return false, "Parent not found: " .. op.parentPath end
		local newOk, inst = pcall(function() return Instance.new(op.className :: string) end)
		if not newOk or not inst then
			return false, "Cannot create " .. tostring(op.className) .. ": " .. tostring(inst)
		end
		if op.name then (inst :: any).Name = op.name end
		if op.props then
			local props = PropertyDeserializer.ConvertProps(op.props)
			for k, v in props do
				local sOk, sErr = pcall(function() (inst :: any)[k] = v end)
				if not sOk then
					inst:Destroy()
					return false, string.format("createInstance: failed to set %s on new %s: %s",
						k, op.className, tostring(sErr))
				end
			end
		end
		if op.source then
			pcall(function() (inst :: any).Source = op.source end)
		end
		inst.Parent = parent
		return true, nil

	elseif op.op == "rename" then
		if not op.path or not op.name then return false, "rename requires path + name" end
		local inst = PathUtils.Resolve(op.path)
		if not inst then return false, "Instance not found: " .. op.path end
		inst.Name = op.name
		return true, nil

	elseif op.op == "move" then
		if not op.path or not op.parentPath then return false, "move requires path + parentPath" end
		local inst = PathUtils.Resolve(op.path)
		if not inst then return false, "Instance not found: " .. op.path end
		local parent = PathUtils.Resolve(op.parentPath)
		if not parent then return false, "Parent not found: " .. op.parentPath end
		-- Refuse self-parenting / circular moves
		if inst == parent then return false, "Cannot move an instance into itself" end
		local cur = parent
		while cur do
			if cur == inst then
				return false, string.format("Cannot move %s into one of its own descendants (%s)", op.path, op.parentPath)
			end
			cur = cur.Parent
		end
		local ok, err = pcall(function() inst.Parent = parent end)
		if not ok then return false, "Failed to move: " .. tostring(err) end
		-- Optional concurrent rename in the same op so the AI doesn't need two passes
		if op.name then inst.Name = op.name end
		return true, nil

	elseif op.op == "delete" then
		if not op.path then return false, "delete requires path" end
		local inst = PathUtils.Resolve(op.path)
		if not inst then return false, "Instance not found: " .. op.path end
		inst:Destroy()
		return true, nil
	end
	return false, "Unknown op: " .. tostring(op.op)
end

export type ApplyResult = {
	success: boolean,
	error: string?,
	applied: number,
	failed: number,
}

function PatchService.Apply(patch: Patch, criticalConfirmed: boolean): ApplyResult
	if PatchService.IsCritical(patch) and not criticalConfirmed then
		return { success = false, error = "Critical patch refused (no double confirmation)", applied = 0, failed = #patch.ops }
	end

	local affected = collectAffectedPaths(patch)
	local snaps = BackupService.SnapshotPaths(affected)
	local ok = BackupService.Send(patch.id, snaps)
	if not ok then
		return { success = false, error = "Backup failed; refusing to apply.", applied = 0, failed = #patch.ops }
	end

	local recording = ChangeHistoryService:TryBeginRecording(("RoTree patch: %s"):format(patch.title or patch.id))
	local applied, failed = 0, 0
	local firstError: string? = nil

	for _, op in patch.ops do
		local opOk, err = applyOp(op)
		if opOk then applied += 1
		else
			failed += 1
			if not firstError then firstError = err end
		end
	end

	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end

	return {
		success = failed == 0,
		error = firstError,
		applied = applied,
		failed = failed,
	}
end

return PatchService
