local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local NameGui = ClientAssets:WaitForChild("NameGui")
local External = ReplicatedStorage:WaitForChild("External")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local BoostTypesEnum = require(Enums:WaitForChild("BoostTypes"))
local Transparency = require(Utils:WaitForChild("Transparency"))
local Knit = require(External:WaitForChild("Knit"))
local Signal = require(External:WaitForChild("Signal"))

local CharacterSoundGroup = Instance.new("SoundGroup")
CharacterSoundGroup.Name = "CharacterSoundGroup"
CharacterSoundGroup.Volume = 0.25
CharacterSoundGroup.Parent = SoundService

local CharacterController = {
	Name = "CharacterController",
	_BoostController = nil,
	_WalkSpeedOverride = nil,
	_AllCharactersVisibleConnection = nil,
	_CharacterTransparencies = {},
	_PlayerConnections = {},
	CharacterAdded = Signal.new(),
	CharacterRemoving = Signal.new()
}

function CharacterController:KnitStart()
	self._BoostController = require(ReplicatedStorage.Controllers.Boosts.BoostController)

	Players.PlayerAdded:Connect(function(player)
		self:_SetupPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local connectionsTable = self._PlayerConnections[player] or {}
		for _, connection in pairs(connectionsTable) do
			connection:Disconnect()
		end
		self._PlayerConnections[player] = nil

		if player.Character then
			self:_RestoreCharacterTransparency(player.Character)
		end
	end)

	for _, player in pairs(Players:GetPlayers()) do
		task.spawn(function()
			self:_SetupPlayer(player)
		end)
	end

	self._BoostController.BoostsUpdatedSignal:Connect(function()
		self:_UpdateWalkSpeed()
	end)
end

function CharacterController:_SetupPlayer(player : Player)
	self._PlayerConnections[player] = {}

	local connectionsTable = self._PlayerConnections[player]

	table.insert(connectionsTable, player.CharacterAdded:Connect(function(character)
		self:_SetupCharacter(player, character)
	end))

	table.insert(connectionsTable, player.CharacterRemoving:Connect(function(character)
		self:_RestoreCharacterTransparency(character)
		self.CharacterRemoving:Fire(player, character)
	end))

	local character = player.Character
	if character then
		self:_SetupCharacter(player, character)
	end
end

function CharacterController:GetAllCharacters()
	local characters = {}
	for _, player in pairs(Players:GetPlayers()) do
		if not player.Character then
			continue
		end

		characters[player] = player.Character
	end

	return characters
end

function CharacterController:_SetupCharacter(player, character)
	self:_LowerCharacterSounds(character)
	self:_HideHumanoidNameDisplay(character)
	self:_SetupNameGui(player, character)

	self.CharacterAdded:Fire(player, character)

	if player == Player then
		self:_UpdateWalkSpeed()
	end
end

function CharacterController:_HideHumanoidNameDisplay(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
end

function CharacterController:_SetupNameGui(player, character)
	local head = character:WaitForChild("Head", 5)
	if not head then return end

	local existingNameGui = head:FindFirstChild(NameGui.Name)
	if existingNameGui then
		existingNameGui:Destroy()
	end

	local newNameGui = NameGui:Clone()
	newNameGui.NameText.Text = self:_GetPlayerDisplayName(player)
	newNameGui.Parent = head
end

function CharacterController:_GetPlayerDisplayName(player)
	local displayName = player.DisplayName or player.Name

	if player.HasVerifiedBadge then
		return displayName .. " "
	end

	return displayName
end

function CharacterController:_LowerCharacterSounds(character)
	local rootPart = character:WaitForChild("HumanoidRootPart")

	for _, child in pairs(rootPart:GetChildren()) do
		if child:IsA("Sound") then
			child.SoundGroup = CharacterSoundGroup
		end
	end

	rootPart.ChildAdded:Connect(function(child)
		if child:IsA("Sound") then
			child.SoundGroup = CharacterSoundGroup
		end
	end)
end

function CharacterController:AnchorCharacter(anchor)
	local character = Player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	rootPart.Anchored = anchor
end

function CharacterController:SetWalkspeed(walkSpeed: number?)
	self._WalkSpeedOverride = walkSpeed
	self:_UpdateWalkSpeed()
end

function CharacterController:SetWalkSpeed(walkSpeed: number?)
	self:SetWalkspeed(walkSpeed)
end

function CharacterController:MakeAllCharactersVisible(visible)
	if self._AllCharactersVisibleConnection then
		self._AllCharactersVisibleConnection:Disconnect()
		self._AllCharactersVisibleConnection = nil
	end

	if not visible then
		self._AllCharactersVisibleConnection = self.CharacterAdded:Connect(function(player)
			self:MakeCharacterVisible(player, false)
		end)
	end

	for _, player in pairs(Players:GetPlayers()) do
		if not player.Character then
			continue
		end

		self:MakeCharacterVisible(player, visible)
	end
end

function CharacterController:MakeCharacterVisible(player, visible)
	local character = player.Character
	if not character then
		return
	end

	if visible then
		self:_RestoreCharacterTransparency(character)
	else
		self:_HideCharacter(character)
	end
end

function CharacterController:_HideCharacter(character)
	if self._CharacterTransparencies[character] then
		return
	end

	local transparency = Transparency.new(character)
	transparency:Hide()
	self._CharacterTransparencies[character] = transparency
end

function CharacterController:_RestoreCharacterTransparency(character)
	local transparency = self._CharacterTransparencies[character]
	if not transparency then
		return
	end

	transparency:Destroy()
	self._CharacterTransparencies[character] = nil
end

function CharacterController:_UpdateWalkSpeed()
	local character = Player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	if self._WalkSpeedOverride then
		humanoid.WalkSpeed = self._WalkSpeedOverride
		return
	end

	local walkSpeedAdditive = self._BoostController:GetAddingBoostAmountOfType(BoostTypesEnum.WalkSpeedBoost) or 0
	local walkSpeedMultiplying = self._BoostController:GetMultiplyingBoostAmountOfType(BoostTypesEnum.WalkSpeedBoost) or 1

	humanoid.WalkSpeed = (StarterPlayer.CharacterWalkSpeed + walkSpeedAdditive) * walkSpeedMultiplying
end

return CharacterController
