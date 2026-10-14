local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Signal = require(ReplicatedStorage.External.Signal)
local Knit = require(ReplicatedStorage.External.Knit)
local ToolModules = ReplicatedStorage:WaitForChild("Utils"):WaitForChild("Tools")

local ToolController = {
	Name = "ToolController",
	_ToolService = nil,
	_PlayerConnections = {},
	_CharacterConnections = {},
	_EquippedTools = {},
	_EquippedTool = nil,
	_ToolCleanup = nil,
	ToolEquipped = Signal.new(),
	ToolUnequipped = Signal.new()
}

function ToolController:KnitStart()
	self._ToolService = Knit.GetService("ToolService")

	Players.PlayerAdded:Connect(function(player)
		self:_WatchPlayer(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_StopWatchingPlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_WatchPlayer(player)
	end
end

function ToolController:_WatchPlayer(player)
	if self._PlayerConnections[player] then return end

	self._PlayerConnections[player] = {
		player.CharacterAdded:Connect(function(character)
			self:_WatchCharacter(player, character)
		end),
		player.CharacterRemoving:Connect(function(character)
			local watching = self._CharacterConnections[player]
			if watching and watching.Character == character then
				self:_StopWatchingCharacter(player)
			end
		end)
	}

	if player.Character then
		self:_WatchCharacter(player, player.Character)
	end
end

function ToolController:_StopWatchingPlayer(player)
	local connections = self._PlayerConnections[player]
	if connections then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		self._PlayerConnections[player] = nil
	end

	self:_StopWatchingCharacter(player)
end

function ToolController:_UnequipTool(player, character)
	local tool = self._EquippedTools[player]
	if not tool then return end

	self._EquippedTools[player] = nil
	if player == Player then
		local cleanup = self._ToolCleanup
		self._EquippedTool = nil
		self._ToolCleanup = nil
		if cleanup then
			cleanup()
		end
	end

	self.ToolUnequipped:Fire(player, character, tool)
end

function ToolController:_EquipTool(player, character, tool)
	if tool.Parent ~= character then return end
	if self._EquippedTools[player] == tool then return end

	self:_UnequipTool(player, character)
	self._EquippedTools[player] = tool
	self.ToolEquipped:Fire(player, character, tool)

	if player ~= Player then return end

	local moduleScript = ToolModules:FindFirstChild(tool.Name)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then return end

	local toolModule = require(moduleScript)
	if self._EquippedTools[player] ~= tool then return end

	self._EquippedTool = tool
	if toolModule.ClientEquipped then
		self._ToolCleanup = toolModule:ClientEquipped(tool, self)
	end
end

function ToolController:_StopWatchingCharacter(player)
	local watching = self._CharacterConnections[player]
	if not watching then return end

	watching.ChildAdded:Disconnect()
	watching.ChildRemoved:Disconnect()
	self._CharacterConnections[player] = nil
	self:_UnequipTool(player, watching.Character)
end

function ToolController:_WatchCharacter(player, character)
	local watching = self._CharacterConnections[player]
	if watching and watching.Character == character then return end

	self:_StopWatchingCharacter(player)
	self._CharacterConnections[player] = {
		Character = character,
		ChildAdded = character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				self:_EquipTool(player, character, child)
			end
		end),
		ChildRemoved = character.ChildRemoved:Connect(function(child)
			if child == self._EquippedTools[player] then
				self:_UnequipTool(player, character)
			end
		end)
	}

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			self:_EquipTool(player, character, child)
		end
	end
end

function ToolController:GetEquippedToolForPlayer(player)
	return self._EquippedTools[player]
end

function ToolController:ActivateTool(tool, ...)
	if tool ~= self._EquippedTool or tool.Parent ~= Player.Character then return end
	return self._ToolService:ActivateTool(tool, ...)
end

return ToolController
