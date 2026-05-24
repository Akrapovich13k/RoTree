--!strict
-- Apple-inspired color & spacing tokens. Light theme default, dark optional.

local Theme = {}

Theme.Mode = "Light" :: "Light" | "Dark"

local LIGHT = {
	Background = Color3.fromRGB(245, 246, 248),
	Surface = Color3.fromRGB(255, 255, 255),
	SurfaceAlt = Color3.fromRGB(250, 250, 252),
	Border = Color3.fromRGB(228, 229, 232),
	Divider = Color3.fromRGB(235, 236, 239),

	TextPrimary = Color3.fromRGB(28, 28, 30),
	TextSecondary = Color3.fromRGB(99, 99, 102),
	TextTertiary = Color3.fromRGB(142, 142, 147),

	Accent = Color3.fromRGB(10, 132, 255),
	AccentSoft = Color3.fromRGB(225, 237, 254),
	Success = Color3.fromRGB(48, 209, 88),
	Warning = Color3.fromRGB(255, 159, 10),
	Danger = Color3.fromRGB(255, 69, 58),

	ButtonBg = Color3.fromRGB(10, 132, 255),
	ButtonFg = Color3.fromRGB(255, 255, 255),
	ButtonBgHover = Color3.fromRGB(0, 122, 245),

	GhostBg = Color3.fromRGB(242, 243, 245),
	GhostFg = Color3.fromRGB(28, 28, 30),
	GhostBgHover = Color3.fromRGB(232, 233, 236),
}

local DARK = {
	Background = Color3.fromRGB(28, 28, 30),
	Surface = Color3.fromRGB(44, 44, 46),
	SurfaceAlt = Color3.fromRGB(58, 58, 60),
	Border = Color3.fromRGB(72, 72, 74),
	Divider = Color3.fromRGB(58, 58, 60),

	TextPrimary = Color3.fromRGB(245, 245, 247),
	TextSecondary = Color3.fromRGB(174, 174, 178),
	TextTertiary = Color3.fromRGB(124, 124, 128),

	Accent = Color3.fromRGB(10, 132, 255),
	AccentSoft = Color3.fromRGB(28, 50, 86),
	Success = Color3.fromRGB(48, 209, 88),
	Warning = Color3.fromRGB(255, 159, 10),
	Danger = Color3.fromRGB(255, 69, 58),

	ButtonBg = Color3.fromRGB(10, 132, 255),
	ButtonFg = Color3.fromRGB(255, 255, 255),
	ButtonBgHover = Color3.fromRGB(64, 156, 255),

	GhostBg = Color3.fromRGB(58, 58, 60),
	GhostFg = Color3.fromRGB(245, 245, 247),
	GhostBgHover = Color3.fromRGB(72, 72, 74),
}

Theme.Spacing = {
	XS = 4,
	S = 8,
	M = 12,
	L = 16,
	XL = 24,
	XXL = 32,
}

Theme.Radius = {
	S = 6,
	M = 10,
	L = 14,
	XL = 20,
}

Theme.Font = {
	Title = Enum.Font.GothamBold,
	Subtitle = Enum.Font.Gotham,
	Body = Enum.Font.Gotham,
	BodyBold = Enum.Font.GothamMedium,
	Mono = Enum.Font.RobotoMono,
}

Theme.TextSize = {
	Title = 20,
	Subtitle = 13,
	SectionHeader = 14,
	Body = 13,
	Caption = 11,
	Stat = 22,
}

function Theme.Colors()
	return if Theme.Mode == "Dark" then DARK else LIGHT
end

local listeners: { (string) -> () } = {}

function Theme.OnChange(fn: (string) -> ())
	table.insert(listeners, fn)
end

function Theme.SetMode(mode: "Light" | "Dark")
	if mode == Theme.Mode then return end
	Theme.Mode = mode
	for _, fn in listeners do
		task.spawn(fn, mode)
	end
end

return Theme
