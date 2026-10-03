local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local BonePileUtils = require(Utils:WaitForChild("BonePileUtils"))
local DinosaurDef = require(ReplicatedConfigs:WaitForChild("DinosaurDef"))
local Knit = require(External:WaitForChild("Knit"))
local PartUtil = require(Utils:WaitForChild("Part"))
local RarityUtils = require(Utils:WaitForChild("RarityUtils"))
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local Ragdoll = require(Utils:WaitForChild("Ragdoll"))

local PICKUP_DISTANCE = 10
local PICKUP_HOLD_DURATION = 2.5
local DROP_LIFETIME = 2 * 60

local BonePileService = {
	Name = "BonePileService",
	Client = {
		CarriedDinosaurId = Knit.CreateProperty(nil),
		BonesRewarded = Knit.CreateSignal()
	},
	_InventoryService = nil,
	_Carried = {},
	_Dropped = {},
	_InventoryTools = {},
	_EquippedInventoryDisplays = {},
	_PlayerConnections = {},
	_DeathConnections = {},
	_HumanoidAddedConnections = {},
	_EquippedToolConnections = {}
}

function BonePileService:KnitInit()
	self._InventoryService = require(ServerScriptService.Services.Inventory.InventoryService)

	local folder = Workspace:FindFirstChild("_BonePiles")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "_BonePiles"
		folder.Parent = Workspace
	end
	self._Folder = folder
end

function BonePileService:KnitStart()
	self._InventoryService.PlayerInventoryUpdated:Connect(function(player)
		self:_SyncInventoryTools(player)
	end)

	RunService.Heartbeat:Connect(function(dt)
		self:_CheckSafeZones()
	end)

	Ragdoll.Ragdolled:Connect(function(player)
		self:DropForPlayer(player)
	end)
end

function BonePileService:OnPlayerAdded(player)
	if self._PlayerConnections[player] then
		return
	end

	self._InventoryService:AddNonFungibleItemForPlayer(player, "Trex", {
		Scale = 1.5
	})

	local connections = {}
	self._PlayerConnections[player] = connections
	self._InventoryTools[player] = {}

	table.insert(connections, player.CharacterAdded:Connect(function(character)
		self:_WatchCharacter(player, character)
		self:_SyncInventoryTools(player)
	end))

	table.insert(connections, player.CharacterRemoving:Connect(function()
		self:_RemoveEquippedInventoryDisplay(player)
		self:DropForPlayer(player)
		self:_StopWatchingCharacter(player)
	end))

	if player.Character then
		self:_WatchCharacter(player, player.Character)
		self:_SyncInventoryTools(player)
	end
end

function BonePileService:OnPlayerRemoving(player)
	self:DropForPlayer(player)
	self:_RemoveEquippedInventoryDisplay(player)
	self:_StopWatchingCharacter(player)

	local inventoryTools = self._InventoryTools[player]
	if inventoryTools then
		for guid in pairs(table.clone(inventoryTools)) do
			self:_DestroyInventoryTool(player, guid)
		end
		self._InventoryTools[player] = nil
	end

	local connections = self._PlayerConnections[player]
	if connections then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		self._PlayerConnections[player] = nil
	end
end

function BonePileService:_StopWatchingCharacter(player)
	local deathConnection = self._DeathConnections[player]
	if deathConnection then
		deathConnection:Disconnect()
		self._DeathConnections[player] = nil
	end

	local humanoidAddedConnection = self._HumanoidAddedConnections[player]
	if humanoidAddedConnection then
		humanoidAddedConnection:Disconnect()
		self._HumanoidAddedConnections[player] = nil
	end

	local equippedToolConnection = self._EquippedToolConnections[player]
	if equippedToolConnection then
		equippedToolConnection:Disconnect()
		self._EquippedToolConnections[player] = nil
	end
end

function BonePileService:_WatchCharacter(player, character)
	self:_StopWatchingCharacter(player)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		self:_WatchHumanoid(player, character, humanoid)
	else
		self._HumanoidAddedConnections[player] = character.ChildAdded:Connect(function(child)
			if child:IsA("Humanoid") then
				self:_WatchHumanoid(player, character, child)
			end
		end)
	end
end

function BonePileService:_WatchHumanoid(player, character, humanoid)
	if not self._PlayerConnections[player] or player.Character ~= character then
		return
	end

	self:_StopWatchingCharacter(player)
	self._DeathConnections[player] = humanoid.Died:Connect(function()
		self:DropForPlayer(player)
	end)
	self._EquippedToolConnections[player] = character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and self._Carried[player] then
			task.defer(function()
				if self._Carried[player] and humanoid.Parent == character then
					humanoid:UnequipTools()
				end
			end)
		end
	end)
	if humanoid.Health <= 0 then
		self:DropForPlayer(player)
	end
end

function BonePileService:_RemoveEquippedInventoryDisplay(player, tool)
	local display = self._EquippedInventoryDisplays[player]
	if display and (not tool or display.Tool == tool) then
		self._EquippedInventoryDisplays[player] = nil
		display.Model:Destroy()
	end
end

function BonePileService:_EquipInventoryTool(player, tool, guid, dinosaurId)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid or humanoid.Health <= 0 or tool.Parent ~= character then
		return
	end

	if self._Carried[player] then
		humanoid:UnequipTools()
		return
	end

	local item = self._InventoryService:GetNonFungibleItemForPlayer(player, guid)
	if not item or item.ItemId ~= dinosaurId then
		return
	end

	self:_RemoveEquippedInventoryDisplay(player)
	local scale = BonePileUtils.GetScale(item.Metadata and item.Metadata.Scale)
	local model = BonePileUtils.CreateModel(dinosaurId, scale)
	if not model then
		return
	end

	model.Name = "EquippedBonePile"
	BonePileUtils.CarryPileModel(model, character)
	model.Parent = character
	self._EquippedInventoryDisplays[player] = { Tool = tool, Model = model }
end

function BonePileService:_CreateInventoryTool(player, guid, dinosaurId, scale, backpack)
	local dinosaurInfo = DinosaurDef.GetDinosaurInfo(dinosaurId)
	local tool = Instance.new("Tool")
	tool.Name = dinosaurInfo.Name .. " " .. string.format("(%0.1fx)", scale)
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool:SetAttribute("BonePileGuid", guid)
	tool:SetAttribute("DinosaurId", dinosaurId)
	tool:SetAttribute("Scale", scale)

	tool.Equipped:Connect(function()
		if self._InventoryTools[player] and self._InventoryTools[player][guid] == tool then
			self:_EquipInventoryTool(player, tool, guid, dinosaurId)
		end
	end)

	tool.Unequipped:Connect(function()
		self:_RemoveEquippedInventoryDisplay(player, tool)
	end)
	tool.Destroying:Connect(function()
		self:_RemoveEquippedInventoryDisplay(player, tool)
		if self._InventoryTools[player] and self._InventoryTools[player][guid] == tool then
			self._InventoryTools[player][guid] = nil
			task.defer(function()
				self:_SyncInventoryTools(player)
			end)
		end
	end)

	self._InventoryTools[player][guid] = tool
	tool.Parent = backpack
end

function BonePileService:_DestroyInventoryTool(player, guid)
	local inventoryTools = self._InventoryTools[player]
	local tool = inventoryTools and inventoryTools[guid]
	if not tool then
		return
	end

	self:_RemoveEquippedInventoryDisplay(player, tool)
	inventoryTools[guid] = nil
	tool:Destroy()
end

function BonePileService:_SyncInventoryTools(player)
	local inventoryTools = self._InventoryTools[player]
	local backpack = player:FindFirstChild("Backpack")
	if not inventoryTools or not backpack then
		return
	end

	local owned = {}
	for _, item in ipairs(self._InventoryService:GetNonFungiblesForPlayer(player) or {}) do
		if DinosaurDef.GetDinosaurInfo(item.ItemId) then
			owned[item.Guid] = {
				DinosaurId = item.ItemId,
				Scale = BonePileUtils.GetScale(item.Metadata and item.Metadata.Scale)
			}
		end
	end

	for guid, tool in pairs(table.clone(inventoryTools)) do
		local item = owned[guid]
		if not item
			or tool:GetAttribute("DinosaurId") ~= item.DinosaurId
			or tool:GetAttribute("Scale") ~= item.Scale
			or (tool.Parent ~= backpack and tool.Parent ~= player.Character) then
			self:_DestroyInventoryTool(player, guid)
		end
	end

	for guid, item in pairs(owned) do
		if not inventoryTools[guid] then
			self:_CreateInventoryTool(player, guid, item.DinosaurId, item.Scale, backpack)
		end
	end
end

function BonePileService:_CreatePile(dinosaurId, scale)
	local model = BonePileUtils.CreateModel(dinosaurId, scale)
	if not model then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.HoldDuration = PICKUP_HOLD_DURATION
	prompt.MaxActivationDistance = PICKUP_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Enabled = false
	prompt.Parent = model.PrimaryPart

	local pile = {
		DinosaurId = dinosaurId,
		Scale = model:GetAttribute("Scale"),
		Model = model,
		Prompt = prompt
	}

	prompt.Triggered:Connect(function(player)
		self:_PickUp(pile, player)
	end)

	return pile
end

function BonePileService:_CancelDropExpiry(pile)
	if pile.DropExpiryThread then
		task.cancel(pile.DropExpiryThread)
		pile.DropExpiryThread = nil
	end
end

function BonePileService:_Carry(pile, player)
	if self._Carried[player] or not self._PlayerConnections[player] or not player:IsDescendantOf(Players) then
		return false
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local pileModel = pile.Model

	CollectionService:RemoveTag(pileModel, "Hover")
	CollectionService:RemoveTag(pileModel, "Spin")

	humanoid:UnequipTools()
	self:_RemoveEquippedInventoryDisplay(player)
	self:_CancelDropExpiry(pile)
	pile.Prompt.Enabled = false
	self._Dropped[pileModel] = nil
	local weld = BonePileUtils.CarryPileModel(pileModel, character)

	pile.Carrier = player
	pile.CarrierWeld = weld
	pileModel.Parent = self._Folder
	self._Carried[player] = pile
	self.Client.CarriedDinosaurId:SetFor(player, pile.DinosaurId)

	return true
end

function BonePileService:_PlaceDropped(pile, position, lookVector)
	local excluded = { pile.Model }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excluded
	params.RespectCanCollide = true

	local hit = Workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -512, 0), params)
	local groundPosition = hit and hit.Position or position
	local facing = Vector3.new(lookVector.X, 0, lookVector.Z)
	if facing.Magnitude < 0.001 then
		facing = Vector3.new(0, 0, -1)
	end

	local pileModel = pile.Model

	local groundCFrame = CFrame.lookAt(groundPosition, groundPosition + facing.Unit)
	local _, boundsSize = pileModel:GetBoundingBox()
	local cframe = groundCFrame + Vector3.new(0, boundsSize.Y / 2, 0) + Vector3.new(0, 1.5, 0)

	pileModel:SetAttribute("HoverDistance", 0.5)
	pileModel:SetAttribute("HoverTime", 2)
	pileModel:SetAttribute("SpinSpeed", 20)
	CollectionService:AddTag(pileModel, "Hover")
	CollectionService:AddTag(pileModel, "Spin")

	pileModel:PivotTo(cframe)
	pileModel.Parent = self._Folder

	self._Dropped[pileModel] = pile
	pile.Prompt.Enabled = true
	self:_CancelDropExpiry(pile)
	pile.DropExpiryThread = task.delay(DROP_LIFETIME, function()
		pile.DropExpiryThread = nil
		if self._Dropped[pileModel] ~= pile then
			return
		end

		self._Dropped[pileModel] = nil
		pileModel:Destroy()
	end)
end

function BonePileService:DropForPlayer(player)
	local pile = self._Carried[player]
	if not pile or pile.Banking then
		return false
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local lookVector = rootPart and rootPart.CFrame.LookVector or pile.Model:GetPivot().LookVector
	local position = pile.Model:GetPivot().Position

	self._Carried[player] = nil
	pile.Carrier = nil
	if pile.CarrierWeld then
		pile.CarrierWeld:Destroy()
		pile.CarrierWeld = nil
	end
	UtilFunctions.AnchorAllDescendants(pile.Model, true)
	self.Client.CarriedDinosaurId:SetFor(player, nil)
	self:_PlaceDropped(pile, position, lookVector)

	return true
end

function BonePileService:_PickUp(pile, player)
	if self._Dropped[pile.Model] ~= pile or self._Carried[player] then
		return
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or (rootPart.Position - pile.Model.PrimaryPart.Position).Magnitude > PICKUP_DISTANCE + 2 then
		return
	end

	self:_Carry(pile, player)
end

function BonePileService:AwardForDirt(player, dirtRarity, dirtCFrame, dirtScale)
	local lootTable = DinosaurDef.GetLootTableForRarity(dirtRarity)
	if #lootTable == 0 then
		return false
	end

	local dinosaurId = RarityUtils.GetLootTableResults(lootTable).Id
	local pile = self:_CreatePile(dinosaurId, dirtScale)
	if not pile then
		return false
	end

	if self._Carried[player] then
		self:DropForPlayer(player)
	end

	if not self:_Carry(pile, player) then
		UtilFunctions.AnchorAllDescendants(pile.Model, true)
		self:_PlaceDropped(pile, dirtCFrame.Position, dirtCFrame.LookVector)
	end

	return true
end

function BonePileService:_BankPile(player, pile)
	if pile.Banking then
		return
	end
	pile.Banking = true

	local guid = self._InventoryService:AddNonFungibleItemForPlayer(player, pile.DinosaurId, {
		Scale = pile.Scale
	})
	if not guid then
		pile.Banking = false
		return
	end

	self._Carried[player] = nil
	pile.Carrier = nil
	self.Client.CarriedDinosaurId:SetFor(player, nil)
	self.Client.BonesRewarded:Fire(player)
	pile.Model:Destroy()

	self:_SyncInventoryTools(player)
	local tool = self._InventoryTools[player] and self._InventoryTools[player][guid]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if tool and tool.Parent == player:FindFirstChild("Backpack") and humanoid and humanoid.Health > 0 then
		humanoid:EquipTool(tool)
	end
end

function BonePileService:_CheckSafeZones()
	if not next(self._Carried) then
		return
	end

	local zones = {}
	for _, instance in ipairs(CollectionService:GetTagged("Zone2d")) do
		if instance.Name == "SafeZone" and instance:IsA("BasePart") and instance:IsDescendantOf(Workspace) then
			table.insert(zones, PartUtil.new(instance))
		end
	end
	if #zones == 0 then
		return
	end

	for player, pile in pairs(self._Carried) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			for _, zone in ipairs(zones) do
				if zone:PlayerIsInsidePartArea(player, 15) then
					self:_BankPile(player, pile)
					break
				end
			end
		end
	end
end

function BonePileService.Client:Drop(player)
	return self.Server:DropForPlayer(player)
end

return BonePileService
