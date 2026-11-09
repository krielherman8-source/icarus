--!strict
-- Creates the remote folder the client waits for. Call setup() before any other service.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local EVENT_NAMES = {
	"ChargeHeld",
	"LaunchBegan",
	"RunEndNotice",
	"RunResult",
	"ReturnToPad",
	"StatePush",
	"ExitCatapult",
	"Melted",
}

local FUNCTION_NAMES = { "Purchase", "GetState" }

local folder: Folder? = nil

function Remotes.setup()
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing and existing:IsA("Folder") then
		folder = existing
		return
	end

	local created = Instance.new("Folder")
	created.Name = "Remotes"
	created.Parent = ReplicatedStorage
	folder = created

	for _, name in EVENT_NAMES do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = created
	end
	for _, name in FUNCTION_NAMES do
		local func = Instance.new("RemoteFunction")
		func.Name = name
		func.Parent = created
	end
end

function Remotes.event(name: string): RemoteEvent
	local root = folder or (ReplicatedStorage:WaitForChild("Remotes") :: Folder)
	folder = root
	local inst = root:WaitForChild(name)
	assert(inst:IsA("RemoteEvent"), name .. " is not a RemoteEvent")
	return inst
end

function Remotes.func(name: string): RemoteFunction
	local root = folder or (ReplicatedStorage:WaitForChild("Remotes") :: Folder)
	folder = root
	local inst = root:WaitForChild(name)
	assert(inst:IsA("RemoteFunction"), name .. " is not a RemoteFunction")
	return inst
end

return Remotes
