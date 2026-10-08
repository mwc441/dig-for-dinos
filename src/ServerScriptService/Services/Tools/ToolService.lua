local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ToolModules = ReplicatedStorage:WaitForChild("Utils"):WaitForChild("Tools")

local ToolService = {
	Name = "ToolService",
	Client = {},
	_CharacterService = nil,
	_CharacterConnections = {},
	_EquippedTools = {}
}

function ToolService:KnitStart()
	self._CharacterService = require(ServerScriptService.Services.Character.CharacterService)
	self._CharacterService.CharacterAdded:Connect(function(player, character)
		self:_WatchCharacter(player, character)
	end)
	self._CharacterService.CharacterRemoving:Connect(function(player, character)
		local watching = self._CharacterConnections[player]
		if watching and watching.Character == character then
			self:_StopWatchingCharacter(player)
		end
	end)
end

function ToolService:OnPlayerAdded(player)
	local character = player.Character
	if character then
		self:_WatchCharacter(player, character)
	end
end

function ToolService:OnPlayerRemoving(player)
	self:_StopWatchingCharacter(player)
end

function ToolService:GetCharacters()
	return self._CharacterService:GetAllCharacters()
end

function ToolService:_UnequipTool(player)
	local equipped = self._EquippedTools[player]
	self._EquippedTools[player] = nil
	if equipped and equipped.Cleanup then
		equipped.Cleanup()
	end
end

function ToolService:_EquipTool(player, tool)
	local equipped = self._EquippedTools[player]
	if equipped and equipped.Tool == tool then return end

	local moduleScript = ToolModules:FindFirstChild(tool.Name)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then return end

	self:_UnequipTool(player)
	local toolModule = require(moduleScript)
	local record = { Tool = tool, Module = toolModule }
	self._EquippedTools[player] = record
	if toolModule.ServerEquipped then
		record.Cleanup = toolModule:ServerEquipped(player, tool, self)
	end
end

function ToolService:_StopWatchingCharacter(player)
	local watching = self._CharacterConnections[player]
	if watching then
		watching.ChildAdded:Disconnect()
		watching.ChildRemoved:Disconnect()
		self._CharacterConnections[player] = nil
	end
	self:_UnequipTool(player)
end

function ToolService:_WatchCharacter(player, character)
	local watching = self._CharacterConnections[player]
	if watching and watching.Character == character then return end
	self:_StopWatchingCharacter(player)
	self._CharacterConnections[player] = {
		Character = character,
		ChildAdded = character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				self:_EquipTool(player, child)
			end
		end),
		ChildRemoved = character.ChildRemoved:Connect(function(child)
			local equipped = self._EquippedTools[player]
			if equipped and equipped.Tool == child then
				self:_UnequipTool(player)
			end
		end)
	}

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			self:_EquipTool(player, child)
		end
	end
end

function ToolService:ActivateTool(player, tool, ...)
	local watching = self._CharacterConnections[player]
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") or not watching or tool.Parent ~= watching.Character then
		return false
	end
	local equipped = self._EquippedTools[player]
	if not equipped or equipped.Tool ~= tool or not equipped.Module.ServerActivated then
		return false
	end
	return equipped.Module:ServerActivated(player, tool, self, ...)
end

function ToolService.Client:ActivateTool(player, tool, ...)
	return self.Server:ActivateTool(player, tool, ...)
end

return ToolService
