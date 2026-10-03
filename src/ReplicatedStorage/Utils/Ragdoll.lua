local module = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Signal = require(External:WaitForChild("Signal"))

module.Ragdolled = Signal.new()

if RunService:IsServer() then
	local newRE = Instance.new("RemoteEvent")
	newRE.Name = "Ragdolled"
	newRE.Parent = script
else
	script:WaitForChild("Ragdolled").OnClientEvent:Connect(function(ragdolled)
		local character = game.Players.LocalPlayer.Character
		if not character then return end
		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid
		if not humanoid then return end

		module.Ragdolled:Fire(ragdolled)

		if ragdolled then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
			humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)

			for _, animationConstraint : AnimationConstraint in pairs(character:QueryDescendants("AnimationConstraint")) do
				if animationConstraint.Name == "Root" then continue end

				animationConstraint.Enabled = false
			end
		else
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			for _, animationConstraint : AnimationConstraint in pairs(character:QueryDescendants("AnimationConstraint")) do
				animationConstraint.Enabled = true
			end
		end
	end)
end

function module:RagdollCharacter(Player, Character)
	module.Ragdolled:Fire(Player, true)

	script.Ragdolled:FireClient(Player, true)

	Character.Humanoid:UnequipTools()
end

function module:UnragdollCharacter(Player)
	module.Ragdolled:Fire(Player, false)
	script.Ragdolled:FireClient(Player, false)
end

return module