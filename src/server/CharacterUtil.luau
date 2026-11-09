--!strict

local CharacterUtil = {}

export type Rig = {
	character: Model,
	root: BasePart,
	humanoid: Humanoid,
}

function CharacterUtil.get(player: Player): Rig?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid then
		return {
			character = character,
			root = root,
			humanoid = humanoid,
		}
	end
	return nil
end

function CharacterUtil.torso(character: Model): BasePart?
	local inst = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if inst and inst:IsA("BasePart") then
		return inst
	end
	return nil
end

function CharacterUtil.prepareForFlight(humanoid: Humanoid)
	humanoid.PlatformStand = true
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
end

function CharacterUtil.release(humanoid: Humanoid)
	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end

-- Stand the rig on a pad, facing +X (toward the sun).
function CharacterUtil.placeOnPad(rig: Rig, pad: BasePart)
	local top = pad.Position.Y + pad.Size.Y * 0.5
	local hip = rig.humanoid.HipHeight + rig.root.Size.Y * 0.5
	local standAt = Vector3.new(pad.Position.X, top + hip + 0.15, pad.Position.Z)
	rig.root.AssemblyLinearVelocity = Vector3.zero
	rig.root.AssemblyAngularVelocity = Vector3.zero
	rig.root.Anchored = false
	rig.root.CFrame = CFrame.lookAt(standAt, standAt + Vector3.xAxis)
	CharacterUtil.release(rig.humanoid)
	rig.humanoid.Health = rig.humanoid.MaxHealth
end

return CharacterUtil
