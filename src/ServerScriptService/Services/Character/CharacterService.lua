local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local BoostTypesEnum = require(Enums:WaitForChild("BoostTypes"))
local Knit = require(External:WaitForChild("Knit"))
local Signal = require(External:WaitForChild("Signal"))

local CharacterService = {
	Name = "CharacterService",
	Client = {},
	_PlayerConnections = {},
	CharacterAdded = Signal.new(),
	CharacterRemoving = Signal.new()
}

function CharacterService:OnPlayerAdded(player)
	self._PlayerConnections[player] = {}

	local connectionsTable = self._PlayerConnections[player]

	table.insert(connectionsTable, player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")

		self:_SetupCharacter(player)
	end))

	table.insert(connectionsTable, player.CharacterRemoving:Connect(function(character)
		character:Destroy() -- weird roblox memory leak fix
		self.CharacterRemoving:Fire(player, character)
	end))

	if player.Character then
		self:_SetupCharacter(player)
	end
end

function CharacterService:OnPlayerRemoving(player)
	local connectionsTable = self._PlayerConnections[player] or {}
	for _, connection in pairs(connectionsTable) do
		connection:Disconnect()
	end
	self._PlayerConnections[player] = nil
end

function CharacterService:_SetupCharacter(player)
	local character = player.Character
	if not character then return end

	self:_SetupCollisionGroups(character)
	self.CharacterAdded:Fire(player, character)
end

function CharacterService:GetAllCharacters()
	local characters = {}
	for _, player in pairs(Players:GetPlayers()) do
		if not player.Character then
			continue
		end

		characters[player] = player.Character
	end

	return characters
end

function CharacterService:_SetupCollisionGroups(character)
	local function setCollisionGroup(part)
		part.CollisionGroup = "Players"
	end

	for _, child in pairs(character:GetDescendants()) do
		if child:IsA("BasePart") then
			setCollisionGroup(child)
		end
	end

	character.DescendantAdded:Connect(function(child)
		if child:IsA("BasePart") then
			setCollisionGroup(child)
		end
	end)
end

return CharacterService