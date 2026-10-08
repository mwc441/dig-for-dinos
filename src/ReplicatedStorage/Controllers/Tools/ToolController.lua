local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Knit = require(ReplicatedStorage.External.Knit)
local ToolModules = ReplicatedStorage:WaitForChild("Utils"):WaitForChild("Tools")

local ToolController = {
	Name = "ToolController",
	_ToolService = nil,
	_Character = nil,
	_CharacterConnections = {},
	_EquippedTool = nil,
	_ToolCleanup = nil
}

function ToolController:KnitStart()
	self._ToolService = Knit.GetService("ToolService")

	Player.CharacterAdded:Connect(function(character)
		self:_WatchCharacter(character)
	end)
	Player.CharacterRemoving:Connect(function(character)
		if self._Character == character then
			self:_WatchCharacter(nil)
		end
	end)

	if Player.Character then
		self:_WatchCharacter(Player.Character)
	end
end

function ToolController:_UnequipTool()
	local cleanup = self._ToolCleanup
	self._EquippedTool = nil
	self._ToolCleanup = nil
	if cleanup then
		cleanup()
	end
end

function ToolController:_EquipTool(tool)
	if self._EquippedTool == tool then return end

	local moduleScript = ToolModules:FindFirstChild(tool.Name)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then return end

	self:_UnequipTool()
	local toolModule = require(moduleScript)
	self._EquippedTool = tool
	if toolModule.ClientEquipped then
		self._ToolCleanup = toolModule:ClientEquipped(tool, self)
	end
end

function ToolController:_WatchCharacter(character)
	for _, connection in ipairs(self._CharacterConnections) do
		connection:Disconnect()
	end
	self._CharacterConnections = {}
	self:_UnequipTool()
	self._Character = character
	if not character then return end

	table.insert(self._CharacterConnections, character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			self:_EquipTool(child)
		end
	end))
	table.insert(self._CharacterConnections, character.ChildRemoved:Connect(function(child)
		if child == self._EquippedTool then
			self:_UnequipTool()
		end
	end))

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			self:_EquipTool(child)
		end
	end
end

function ToolController:ActivateTool(tool, ...)
	if tool ~= self._EquippedTool or tool.Parent ~= Player.Character then return end
	return self._ToolService:ActivateTool(tool, ...)
end

return ToolController
