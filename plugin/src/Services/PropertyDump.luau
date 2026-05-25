--!strict
-- Per-class property lists with inheritance. Used by PropertyScanner to read
-- "all" common properties of every instance.
--
-- Each entry's array part lists property names to try via pcall. `_inherits`
-- points at a parent ClassName whose props are also included. The walk
-- dedupes so each property is read at most once per instance.

local PropertyDump = {}

local PROPS: { [string]: { _inherits: string?, [number]: string } } = {
	Instance = { "Name", "Archivable" },

	-- ── Parts ────────────────────────────────────────────────────────────
	BasePart = {
		_inherits = "Instance",
		"Anchored", "CanCollide", "CanQuery", "CanTouch", "CastShadow",
		"CollisionGroup", "Color", "Material", "MaterialVariant", "Massless",
		"Reflectance", "RootPriority", "Size", "Transparency", "Locked",
		"Position", "Orientation", "CFrame",
		"Velocity", "AssemblyAngularVelocity", "AssemblyLinearVelocity",
		"TopSurface", "BottomSurface", "FrontSurface", "BackSurface",
		"LeftSurface", "RightSurface", "Massless", "PivotOffset",
	},
	Part = { _inherits = "BasePart", "Shape" },
	WedgePart = { _inherits = "BasePart" },
	CornerWedgePart = { _inherits = "BasePart" },
	TrussPart = { _inherits = "BasePart", "Style" },
	MeshPart = { _inherits = "BasePart", "MeshId", "TextureID", "DoubleSided", "RenderFidelity", "CollisionFidelity" },
	UnionOperation = { _inherits = "BasePart", "UsePartColor", "CollisionFidelity", "RenderFidelity" },
	SpawnLocation = { _inherits = "Part", "Duration", "TeamColor", "Neutral", "Enabled", "AllowTeamChangeOnTouch" },
	Seat = { _inherits = "Part", "Disabled" },
	VehicleSeat = { _inherits = "Part", "Disabled", "MaxSpeed", "Torque", "TurnSpeed", "HeadsUpDisplay" },

	-- ── Containers / hierarchy ───────────────────────────────────────────
	Model = { _inherits = "Instance", "PrimaryPart", "WorldPivot", "ScaleType" },
	Folder = { _inherits = "Instance" },
	Configuration = { _inherits = "Instance" },
	Actor = { _inherits = "Model" },
	Tool = { _inherits = "Instance",
		"CanBeDropped", "Enabled", "Grip", "GripForward", "GripPos",
		"GripRight", "GripUp", "ManualActivationOnly", "RequiresHandle",
		"TextureId", "ToolTip",
	},
	Backpack = { _inherits = "Instance" },

	-- ── Scripts ──────────────────────────────────────────────────────────
	LuaSourceContainer = { _inherits = "Instance", "Source" },
	Script = { _inherits = "LuaSourceContainer", "Enabled", "RunContext" },
	LocalScript = { _inherits = "LuaSourceContainer", "Enabled" },
	ModuleScript = { _inherits = "LuaSourceContainer" },

	-- ── GUI ──────────────────────────────────────────────────────────────
	GuiBase2d = { _inherits = "Instance" },
	GuiObject = { _inherits = "GuiBase2d",
		"Active", "AnchorPoint", "AutomaticSize", "BackgroundColor3",
		"BackgroundTransparency", "BorderColor3", "BorderMode", "BorderSizePixel",
		"ClipsDescendants", "Interactable", "LayoutOrder",
		"NextSelectionDown", "NextSelectionLeft", "NextSelectionRight", "NextSelectionUp",
		"Position", "Rotation", "Selectable", "SelectionOrder",
		"Size", "SizeConstraint", "Visible", "ZIndex",
	},
	Frame = { _inherits = "GuiObject", "Style" },
	CanvasGroup = { _inherits = "GuiObject", "GroupColor3", "GroupTransparency" },
	ScrollingFrame = { _inherits = "Frame",
		"AutomaticCanvasSize", "BottomImage", "CanvasPosition", "CanvasSize",
		"ElasticBehavior", "HorizontalScrollBarInset", "MidImage",
		"ScrollBarImageColor3", "ScrollBarImageTransparency", "ScrollBarThickness",
		"ScrollingDirection", "ScrollingEnabled", "TopImage",
		"VerticalScrollBarInset", "VerticalScrollBarPosition",
	},
	ViewportFrame = { _inherits = "GuiObject",
		"Ambient", "CurrentCamera", "ImageColor3", "ImageTransparency",
		"LightColor", "LightDirection",
	},
	TextLabel = { _inherits = "GuiObject",
		"Font", "FontFace", "LineHeight", "MaxVisibleGraphemes", "RichText",
		"Text", "TextColor3", "TextScaled", "TextSize",
		"TextStrokeColor3", "TextStrokeTransparency", "TextTransparency",
		"TextTruncate", "TextWrapped", "TextXAlignment", "TextYAlignment",
	},
	TextButton = { _inherits = "TextLabel", "AutoButtonColor", "Modal", "Selected", "Style" },
	TextBox = { _inherits = "TextLabel",
		"ClearTextOnFocus", "CursorPosition", "MultiLine",
		"PlaceholderColor3", "PlaceholderText",
		"SelectionStart", "ShowNativeInput", "TextEditable",
	},
	ImageLabel = { _inherits = "GuiObject",
		"Image", "ImageColor3", "ImageRectOffset", "ImageRectSize",
		"ImageTransparency", "ResampleMode", "ScaleType",
		"SliceCenter", "SliceScale", "TileSize",
	},
	ImageButton = { _inherits = "ImageLabel",
		"AutoButtonColor", "HoverImage", "Modal", "PressedImage", "Selected", "Style",
	},
	LayerCollector = { _inherits = "GuiBase2d",
		"Enabled", "ResetOnSpawn", "ZIndexBehavior",
	},
	ScreenGui = { _inherits = "LayerCollector",
		"AutoLocalize", "ClipToDeviceSafeArea", "DisplayOrder",
		"IgnoreGuiInset", "OnTopOfCoreBlur",
		"SafeAreaCompatibility", "ScreenInsets",
	},
	GuiBase3d = { _inherits = "Instance", "Color3", "Transparency", "Visible" },
	SurfaceGui = { _inherits = "LayerCollector",
		"Adornee", "AlwaysOnTop", "Brightness", "CanvasSize",
		"ClipsDescendants", "Face", "LightInfluence", "PixelsPerStud",
		"SizingMode", "ToolPunchThroughDistance", "ZOffset",
	},
	BillboardGui = { _inherits = "LayerCollector",
		"Active", "Adornee", "AlwaysOnTop", "Brightness",
		"ClipsDescendants", "DistanceLowerLimit", "DistanceStep",
		"DistanceUpperLimit", "ExtentsOffset", "ExtentsOffsetWorldSpace",
		"LightInfluence", "MaxDistance", "PlayerToHideFrom",
		"Size", "SizeOffset", "StudsOffset", "StudsOffsetWorldSpace",
	},

	-- ── UI helpers ───────────────────────────────────────────────────────
	UIComponent = { _inherits = "Instance" },
	UIPadding = { _inherits = "UIComponent", "PaddingBottom", "PaddingLeft", "PaddingRight", "PaddingTop" },
	UICorner = { _inherits = "UIComponent", "CornerRadius" },
	UIStroke = { _inherits = "UIComponent", "ApplyStrokeMode", "Color", "LineJoinMode", "Thickness", "Transparency", "Enabled" },
	UIGradient = { _inherits = "UIComponent", "Color", "Enabled", "Offset", "Rotation", "Transparency" },
	UIScale = { _inherits = "UIComponent", "Scale" },
	UISizeConstraint = { _inherits = "UIComponent", "MaxSize", "MinSize" },
	UIAspectRatioConstraint = { _inherits = "UIComponent", "AspectRatio", "AspectType", "DominantAxis" },
	UIListLayout = { _inherits = "UIComponent",
		"FillDirection", "HorizontalAlignment", "Padding", "SortOrder", "VerticalAlignment", "Wraps",
	},
	UIGridLayout = { _inherits = "UIComponent",
		"CellPadding", "CellSize", "FillDirection", "FillDirectionMaxCells",
		"HorizontalAlignment", "SortOrder", "StartCorner", "VerticalAlignment",
	},
	UIPageLayout = { _inherits = "UIComponent",
		"Animated", "Circular", "EasingDirection", "EasingStyle",
		"FillDirection", "GamepadInputEnabled", "HorizontalAlignment",
		"Padding", "ScrollWheelInputEnabled", "SortOrder", "TouchInputEnabled",
		"TweenTime", "VerticalAlignment",
	},

	-- ── Sound ────────────────────────────────────────────────────────────
	SoundService = { _inherits = "Instance",
		"AmbientReverb", "DistanceFactor", "DopplerScale",
		"RespectFilteringEnabled", "RolloffScale", "VolumetricAudio",
	},
	Sound = { _inherits = "Instance",
		"EmitterSize", "Looped", "MaxDistance", "MinDistance",
		"PlayOnRemove", "Playing", "PlaybackRegionsEnabled", "PlaybackSpeed",
		"RollOffMaxDistance", "RollOffMinDistance", "RollOffMode",
		"SoundGroup", "SoundId", "TimeLength", "TimePosition", "Volume",
	},
	SoundGroup = { _inherits = "Instance", "Volume" },

	-- ── Lighting ─────────────────────────────────────────────────────────
	Lighting = { _inherits = "Instance",
		"Ambient", "Brightness", "ColorShift_Bottom", "ColorShift_Top",
		"ClockTime", "EnvironmentDiffuseScale", "EnvironmentSpecularScale",
		"ExposureCompensation", "GeographicLatitude", "GlobalShadows",
		"OutdoorAmbient", "ShadowSoftness", "Technology", "TimeOfDay", "FogColor",
		"FogEnd", "FogStart", "Outlines",
	},
	Light = { _inherits = "Instance", "Brightness", "Color", "Enabled", "Shadows" },
	PointLight = { _inherits = "Light", "Range" },
	SpotLight = { _inherits = "Light", "Angle", "Face", "Range" },
	SurfaceLight = { _inherits = "Light", "Angle", "Face", "Range" },
	Atmosphere = { _inherits = "Instance", "Color", "Decay", "Density", "Glare", "Haze", "Offset" },
	Sky = { _inherits = "Instance",
		"CelestialBodiesShown", "MoonAngularSize", "MoonTextureId",
		"SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp",
		"StarCount", "SunAngularSize", "SunTextureId",
	},
	BlurEffect = { _inherits = "Instance", "Enabled", "Size" },
	BloomEffect = { _inherits = "Instance", "Enabled", "Intensity", "Size", "Threshold" },
	ColorCorrectionEffect = { _inherits = "Instance", "Enabled", "Brightness", "Contrast", "Saturation", "TintColor" },
	SunRaysEffect = { _inherits = "Instance", "Enabled", "Intensity", "Spread" },
	DepthOfFieldEffect = { _inherits = "Instance", "Enabled", "FarIntensity", "FocusDistance", "InFocusRadius", "NearIntensity" },

	-- ── Camera ──────────────────────────────────────────────────────────
	Camera = { _inherits = "Instance",
		"CFrame", "CameraSubject", "CameraType", "DiagonalFieldOfView",
		"FieldOfView", "FieldOfViewMode", "Focus", "HeadLocked",
		"HeadScale", "MaxAxisFieldOfView", "VRTiltAndRollEnabled",
	},

	-- ── Effects ──────────────────────────────────────────────────────────
	ParticleEmitter = { _inherits = "Instance",
		"Acceleration", "Brightness", "Color", "Drag",
		"EmissionDirection", "Enabled", "FlipbookFramerate",
		"FlipbookLayout", "FlipbookMode", "FlipbookStartRandom",
		"Lifetime", "LightEmission", "LightInfluence",
		"LockedToPart", "Orientation", "Rate", "RotSpeed", "Rotation",
		"ShapeInOut", "ShapePartial", "ShapeStyle", "Size", "Speed",
		"SpreadAngle", "Squash", "Texture", "TimeScale", "Transparency",
		"VelocityInheritance", "ZOffset",
	},
	Trail = { _inherits = "Instance",
		"Attachment0", "Attachment1", "Brightness", "Color", "Enabled",
		"FaceCamera", "Lifetime", "LightEmission", "LightInfluence",
		"MaxLength", "MinLength", "TextureLength", "TextureMode",
		"Transparency", "WidthScale",
	},
	Beam = { _inherits = "Instance",
		"Attachment0", "Attachment1", "Brightness", "Color", "CurveSize0",
		"CurveSize1", "Enabled", "FaceCamera", "LightEmission",
		"LightInfluence", "Segments", "Texture", "TextureLength",
		"TextureMode", "TextureSpeed", "Transparency", "Width0", "Width1",
		"ZOffset",
	},
	Attachment = { _inherits = "Instance",
		"Axis", "CFrame", "Orientation", "Position", "SecondaryAxis",
		"Visible", "WorldAxis", "WorldCFrame", "WorldOrientation",
		"WorldPosition", "WorldSecondaryAxis",
	},
	Decal = { _inherits = "Instance",
		"Color3", "Face", "LocalTransparencyModifier", "Shiny",
		"Specular", "Texture", "Transparency", "ZIndex",
	},
	Texture = { _inherits = "Decal", "OffsetStudsU", "OffsetStudsV", "StudsPerTileU", "StudsPerTileV" },

	-- ── Value objects ───────────────────────────────────────────────────
	StringValue = { _inherits = "Instance", "Value" },
	IntValue = { _inherits = "Instance", "Value" },
	NumberValue = { _inherits = "Instance", "Value" },
	BoolValue = { _inherits = "Instance", "Value" },
	Vector3Value = { _inherits = "Instance", "Value" },
	Color3Value = { _inherits = "Instance", "Value" },
	CFrameValue = { _inherits = "Instance", "Value" },
	ObjectValue = { _inherits = "Instance", "Value" },
	BrickColorValue = { _inherits = "Instance", "Value" },
	RayValue = { _inherits = "Instance", "Value" },

	-- ── Remotes ──────────────────────────────────────────────────────────
	RemoteEvent = { _inherits = "Instance" },
	UnreliableRemoteEvent = { _inherits = "Instance" },
	RemoteFunction = { _inherits = "Instance" },
	BindableEvent = { _inherits = "Instance" },
	BindableFunction = { _inherits = "Instance" },

	-- ── Constraints ──────────────────────────────────────────────────────
	Constraint = { _inherits = "Instance",
		"Active", "Attachment0", "Attachment1", "Color", "Enabled", "Visible",
	},
	AlignOrientation = { _inherits = "Constraint",
		"AlignType", "MaxAngularVelocity", "MaxTorque", "Mode",
		"PrimaryAxis", "PrimaryAxisOnly", "ReactionTorqueEnabled",
		"Responsiveness", "RigidityEnabled", "SecondaryAxis",
	},
	AlignPosition = { _inherits = "Constraint",
		"ApplyAtCenterOfMass", "MaxForce", "MaxVelocity", "Mode", "Position",
		"ReactionForceEnabled", "Responsiveness", "RigidityEnabled",
	},
	HingeConstraint = { _inherits = "Constraint",
		"ActuatorType", "AngularResponsiveness", "AngularSpeed",
		"AngularVelocity", "CurrentAngle", "LimitsEnabled", "LowerAngle",
		"MotorMaxAcceleration", "MotorMaxTorque", "Restitution",
		"ServoMaxTorque", "TargetAngle", "UpperAngle",
	},
	SpringConstraint = { _inherits = "Constraint",
		"Coils", "Damping", "FreeLength", "LimitsEnabled", "MaxForce",
		"MaxLength", "MinLength", "Radius", "Stiffness", "Thickness",
	},
	Weld = { _inherits = "Constraint", "C0", "C1", "Part0", "Part1" },
	WeldConstraint = { _inherits = "Instance", "Enabled", "Part0", "Part1" },
	Motor6D = { _inherits = "Constraint",
		"C0", "C1", "CurrentAngle", "DesiredAngle", "MaxVelocity", "Part0", "Part1",
	},

	-- ── Animation ────────────────────────────────────────────────────────
	Animation = { _inherits = "Instance", "AnimationId" },
	AnimationController = { _inherits = "Instance" },
	Animator = { _inherits = "Instance", "EvaluationThrottled", "PreferLodEnabled" },
	KeyframeSequence = { _inherits = "Instance", "AuthoredHipHeight", "Loop", "Priority" },

	-- ── Humanoid / characters ────────────────────────────────────────────
	Humanoid = { _inherits = "Instance",
		"AutoJumpEnabled", "AutoRotate", "AutomaticScalingEnabled",
		"BreakJointsOnDeath", "CameraOffset", "DisplayDistanceType",
		"DisplayName", "EvaluateStateMachine", "FloorMaterial",
		"Health", "HealthDisplayDistance", "HealthDisplayType",
		"HipHeight", "Jump", "JumpHeight", "JumpPower",
		"MaxHealth", "MaxSlopeAngle", "MoveDirection",
		"NameDisplayDistance", "NameOcclusion", "PlatformStand",
		"RequiresNeck", "RigType", "RootPart", "SeatPart", "Sit",
		"TargetPoint", "UseJumpPower", "WalkSpeed", "WalkToPart", "WalkToPoint",
	},
	HumanoidDescription = { _inherits = "Instance",
		"Face", "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
		"HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor",
		"LeftLegColor", "RightLegColor",
		"HatAccessory", "HairAccessory", "FaceAccessory", "FrontAccessory",
		"BackAccessory", "ShouldersAccessory", "WaistAccessory", "NeckAccessory",
		"Shirt", "Pants", "GraphicTShirt", "Skin",
		"HeightScale", "WidthScale", "DepthScale", "HeadScale", "BodyTypeScale", "ProportionScale",
	},
	Accessory = { _inherits = "Instance", "AccessoryType" },
	ClothingBase = { _inherits = "Instance", "Color3" },
	Shirt = { _inherits = "ClothingBase", "ShirtTemplate" },
	Pants = { _inherits = "ClothingBase", "PantsTemplate" },
	ShirtGraphic = { _inherits = "Instance", "Color3", "Graphic" },

	-- ── Workspace ────────────────────────────────────────────────────────
	Workspace = { _inherits = "Instance",
		"Gravity", "FallenPartsDestroyHeight", "AllowThirdPartySales",
		"StreamingEnabled", "StreamingTargetRadius", "StreamingMinRadius",
		"FilteringEnabled", "FluidForces", "Retargeting",
		"PhysicsSimulationRate", "PhysicsSteppingMethod",
	},

	-- ── Teams ────────────────────────────────────────────────────────────
	Team = { _inherits = "Instance", "AutoAssignable", "TeamColor", "Score" },

	-- ── Services usually queried ─────────────────────────────────────────
	StarterPlayer = { _inherits = "Instance",
		"AutoJumpEnabled", "CameraMaxZoomDistance", "CameraMinZoomDistance",
		"CameraMode", "CharacterJumpHeight", "CharacterJumpPower",
		"CharacterMaxSlopeAngle", "CharacterUseJumpPower", "CharacterWalkSpeed",
		"DevCameraOcclusionMode", "DevComputerCameraMovementMode",
		"DevComputerMovementMode", "DevTouchCameraMovementMode",
		"DevTouchMovementMode", "EnableMouseLockOption", "HealthDisplayDistance",
		"LoadCharacterAppearance", "NameDisplayDistance",
	},
}

function PropertyDump.GetPropertiesFor(className: string): { string }
	local out: { string } = {}
	local seen: { [string]: boolean } = {}
	local current: string? = className
	local guard = 0
	while current and guard < 50 do
		guard += 1
		local entry = PROPS[current]
		if not entry then break end
		for _, prop in ipairs(entry) do
			if not seen[prop] then
				seen[prop] = true
				table.insert(out, prop)
			end
		end
		current = entry._inherits
	end
	-- Universal fallback in case className isn't in our dump.
	if not seen.Name then table.insert(out, "Name") end
	if not seen.Archivable then table.insert(out, "Archivable") end
	return out
end

return PropertyDump
