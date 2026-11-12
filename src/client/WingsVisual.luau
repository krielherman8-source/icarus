--!strict
-- Recolors the replicated wing panels on this character. The server owns the
-- moment they detach; this just makes the wax look hot before that replicates.

local Players = game:GetService("Players")

local WingsVisual = {}

local CREAM = Color3.fromRGB(236, 226, 206)
local EMBER = Color3.fromRGB(255, 118, 36)
local ASH = Color3.fromRGB(48, 22, 18)

local function waxColor(alpha: number): Color3
	if alpha < 0.55 then
		return CREAM:Lerp(EMBER, alpha / 0.55)
	end
	return EMBER:Lerp(ASH, (alpha - 0.55) / 0.45)
end

local function eachWing(callback: (Model) -> ())
	local character = Players.LocalPlayer.Character
	if not character or character:GetAttribute("WingsMelted") == true then
		return
	end
	for _, child in character:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, -4) == "Wing" then
			callback(child)
		end
	end
end

function WingsVisual.apply(alpha: number)
	local color = waxColor(math.clamp(alpha, 0, 1))
	local dripRate = if alpha < 0.35 then 0 else (alpha - 0.35) * 78
	eachWing(function(wing)
		for _, desc in wing:GetDescendants() do
			if desc:IsA("BasePart") and string.sub(desc.Name, 1, 7) == "Feather" then
				desc.Color = color
			elseif desc:IsA("ParticleEmitter") and desc.Name == "Drip" then
				desc.Rate = dripRate
			end
		end
	end)
end

function WingsVisual.melt()
	eachWing(function(wing)
		for _, desc in wing:GetDescendants() do
			if desc:IsA("BasePart") and string.sub(desc.Name, 1, 7) == "Feather" then
				desc.Color = ASH
			elseif desc:IsA("ParticleEmitter") and desc.Name == "Drip" then
				desc.Rate = 90
			end
		end
	end)
end

return WingsVisual
