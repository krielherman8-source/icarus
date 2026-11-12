--!strict

local GuiUtil = {}

GuiUtil.Palette = {
	ink = Color3.fromRGB(18, 16, 28),
	panel = Color3.fromRGB(28, 24, 40),
	cream = Color3.fromRGB(236, 224, 198),
	gold = Color3.fromRGB(232, 188, 96),
	sea = Color3.fromRGB(126, 198, 214),
	heat = Color3.fromRGB(255, 96, 52),
	good = Color3.fromRGB(132, 196, 126),
	dim = Color3.fromRGB(170, 162, 150),
}

function GuiUtil.corner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

function GuiUtil.stroke(parent: Instance, color: Color3, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function GuiUtil.formatInt(value: number): string
	local digits = tostring(math.max(0, math.floor(value + 0.5)))
	local reversed = digits:reverse():gsub("(%d%d%d)", "%1,")
	local formatted = reversed:reverse()
	if string.sub(formatted, 1, 1) == "," then
		formatted = string.sub(formatted, 2)
	end
	return formatted
end

return GuiUtil
