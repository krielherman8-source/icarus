--!strict

local Players = game:GetService("Players")

local Remotes = require(script.Remotes)
local DataService = require(script.DataService)
local Leaderstats = require(script.Leaderstats)
local WorldBuilder = require(script.WorldBuilder)
local WingsService = require(script.WingsService)
local RunManager = require(script.RunManager)
local CatapultService = require(script.CatapultService)
local ShopService = require(script.ShopService)
local CharacterUtil = require(script.CharacterUtil)

Remotes.setup()

local world = WorldBuilder.build()
DataService.start()
Leaderstats.start()
WingsService.start()
RunManager.start(world.spawnPad)
CatapultService.start(world)
ShopService.start()

local function hookPlayer(player: Player)
	player.RespawnLocation = world.spawnPad
	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			if player:GetAttribute("InRun") == true or player:GetAttribute("InCatapult") == true then
				return
			end
			local rig = CharacterUtil.get(player)
			if not rig or rig.character ~= character then
				return
			end
			-- The default spawn can beat the new SpawnLocation on the first frame.
			if rig.root.Position.Y < 20 then
				CharacterUtil.placeOnPad(rig, world.spawnPad)
			end
		end)
	end)
end

for _, player in Players:GetPlayers() do
	hookPlayer(player)
end
Players.PlayerAdded:Connect(hookPlayer)
