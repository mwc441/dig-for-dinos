local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ShovelModels : Folder = Assets:WaitForChild("Shovels")
local External = ReplicatedStorage:WaitForChild("External")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local ItemDef = require(ReplicatedConfigs:WaitForChild("ItemDef"))
local DirtDef = require(ReplicatedConfigs:WaitForChild("DirtDef"))
local DirtSpawnerDef = require(ReplicatedConfigs:WaitForChild("DirtSpawnerDef"))
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local Knit = require(External:WaitForChild("Knit"))
local DirtSpawner = require(script.Parent:WaitForChild("DirtSpawner"))

local SHOVEL_SLOT = ItemDef.Categories.Shovel
local DEFAULT_SHOVEL_ID = "WoodenShovel"
local EQUIPPED_SHOVEL_NAME = "EquippedShovel"
local SHOVEL_MOTOR_NAME = "ShovelMotor6D"
local DIG_RANGE = 8

local DigService = {
	Name = "DigService",
	Client = {
		InitialDirtGuids = Knit.CreateProperty(nil)
	},
	_EquipService = nil,
	_InventoryService = nil,
	_CommerceService = nil,
	_CharacterService = nil,
	_ReplicationService = nil,
	_LifecycleService = nil,
	_BonePileService = nil,
	_DirtSpawners = {},
	_ShovelTools = {},
	_LastDig = {}
}

function DigService:KnitStart()
	self._EquipService = require(ServerScriptService.Services.Equips.EquipService)
	self._InventoryService = require(ServerScriptService.Services.Inventory.InventoryService)
	self._CommerceService = require(ServerScriptService.Services.Commerce.CommerceService)
	self._CharacterService = require(ServerScriptService.Services.Character.CharacterService)
	self._ReplicationService = require(ServerScriptService.Services.Replication.ReplicationService)
	self._LifecycleService = require(ServerScriptService.Services.LifeCycle.LifecycleService)
	self._BonePileService = require(script.Parent:WaitForChild("BonePileService"))

	CollectionService:GetInstanceAddedSignal("DirtSpawner"):Connect(function(instance)
		self:_AddDirtSpawner(instance)
	end)
	CollectionService:GetInstanceRemovedSignal("DirtSpawner"):Connect(function(instance)
		self:_RemoveDirtSpawner(instance)
	end)

	for _, instance in ipairs(CollectionService:GetTagged("DirtSpawner")) do
		self:_AddDirtSpawner(instance)
	end

	self._EquipService.PlayerEquipUpdated:Connect(function(player, slotId)
		if slotId ~= SHOVEL_SLOT then
			return
		end

		self:_UpdateShovelToolForPlayer(player)
	end)

	self._CharacterService.CharacterAdded:Connect(function(player, character)
		self:_UpdateShovelToolForPlayer(player, character)
	end)
end

function DigService:OnPlayerAdded(player)
	self:_UpdateShovelToolForPlayer(player)

	self.Client.InitialDirtGuids:SetFor(player, self:_ReplicateDirtToPlayer(player))
end

function DigService:_ReplicateDirtToPlayer(player)
	local initialGuids = {}
	for _, spawner in pairs(self._DirtSpawners) do
		spawner:ReplicateToPlayer(player, initialGuids)
	end
	return initialGuids
end

function DigService:OnPlayerRemoving(player)
	self:_DestroyShovelTool(player)
	self._LastDig[player] = nil
end

function DigService:_AddDirtSpawner(instance)
	if not instance:IsA("BasePart") or not instance:IsDescendantOf(Workspace) or self._DirtSpawners[instance] then
		return
	end

	local config = DirtSpawnerDef.GetSpawnerInfo(instance.Name)
	if not config then
		warn("No DirtSpawner config for ID " .. instance.Name)
		return
	end

	self._DirtSpawners[instance] = DirtSpawner.new(instance, self._ReplicationService, config, self._LifecycleService)
end

function DigService:_RemoveDirtSpawner(instance)
	local spawner = self._DirtSpawners[instance]
	if not spawner then
		return
	end

	self._DirtSpawners[instance] = nil
	spawner:Destroy()
end

function DigService:GetDirt(guid)
	for _, spawner in pairs(self._DirtSpawners) do
		local dirt = spawner:GetDirt(guid)
		if dirt then
			return dirt
		end
	end
end

function DigService:_GetDigCooldown(player)
	return 1 -- TODO: Upgrades for this?
end

function DigService:_IsShovel(itemId)
	if type(itemId) ~= "string" then
		return false
	end

	local itemInfo = ItemDef.GetItemInfo(itemId)
	return itemInfo ~= nil and itemInfo.Category == ItemDef.Categories.Shovel
end

function DigService:EquipShovelForPlayer(player, shovelId)
	if not self:_IsShovel(shovelId)
		or self._InventoryService:GetQuantityOfItemForPlayer(player, shovelId) <= 0 then
		return false
	end

	return self._EquipService:EquipItemForPlayer(player, SHOVEL_SLOT, shovelId)
end

function DigService:BuyShovelForPlayer(player, shovelId)
	if not self:_IsShovel(shovelId) then
		return false
	end

	local hasShovel = self._InventoryService:CheckPlayerInventoryForItems(player, shovelId, 1)
	if hasShovel then return end

	local shovelInfo = ItemDef.GetItemInfo(shovelId)
	if not self._CommerceService:Spend(player, PlayerStatsEnum.Cash, shovelInfo.Cost, {
		Sku = shovelId
	}) then
		return false
	end

	self._InventoryService:AddItemsToPlayersInventory(player, {
		[shovelId] = 1
	})
	if self:EquipShovelForPlayer(player, shovelId) then
		self:_EquipShovelToolForPlayer(player)
	end

	return true
end

function DigService:_EnsureShovelForPlayer(player)
	local equippedShovelId = self._EquipService:GetEquippedItemForPlayer(player, SHOVEL_SLOT)
	local hasEquippedOwnedShovel = self:_IsShovel(equippedShovelId)
		and self._InventoryService:GetQuantityOfItemForPlayer(player, equippedShovelId) > 0

	if hasEquippedOwnedShovel then
		return equippedShovelId
	end

	if self._InventoryService:GetQuantityOfItemForPlayer(player, DEFAULT_SHOVEL_ID) <= 0 then
		self._InventoryService:AddItemsToPlayersInventory(player, {
			[DEFAULT_SHOVEL_ID] = 1
		})
	end

	if self:EquipShovelForPlayer(player, DEFAULT_SHOVEL_ID) then
		return DEFAULT_SHOVEL_ID
	end
end

function DigService:_GetShovelHandle(shovelModel)
	local primaryPart = shovelModel.PrimaryPart
	if primaryPart then
		return primaryPart
	end

	local handle = shovelModel:FindFirstChild("Handle", true)
	if handle and handle:IsA("BasePart") then
		return handle
	end

	return shovelModel:FindFirstChildWhichIsA("BasePart", true)
end

function DigService:_RemoveShovelFromCharacter(character)
	local equippedShovel = character:FindFirstChild(EQUIPPED_SHOVEL_NAME)
	if equippedShovel then
		equippedShovel:Destroy()
	end
end

function DigService:_ApplyShovelToCharacter(character, itemId)
	self:_RemoveShovelFromCharacter(character)

	if not self:_IsShovel(itemId) then
		return
	end

	local shovelTemplate = ShovelModels:FindFirstChild(itemId)
	if not shovelTemplate or not shovelTemplate:IsA("Model") then
		return
	end

	local rightHand = character:FindFirstChild("RightHand")
	if not rightHand or not rightHand:IsA("BasePart") then
		return
	end

	local shovelModel = shovelTemplate:Clone()
	local handle = self:_GetShovelHandle(shovelModel)
	if not handle or not handle:IsA("BasePart") then
		shovelModel:Destroy()
		return
	end

	UtilFunctions.AnchorAllDescendants(shovelModel, false)
	UtilFunctions.CanCollideAllDescendants(shovelModel, false)

	shovelModel.Name = EQUIPPED_SHOVEL_NAME
	shovelModel.Parent = character
	shovelModel:PivotTo(rightHand:GetPivot())

	local motor = Instance.new("Motor6D")
	motor.Name = SHOVEL_MOTOR_NAME
	motor.C0 = CFrame.identity
	motor.C1 = CFrame.identity
	motor.Part0 = rightHand
	motor.Part1 = handle
	motor.Parent = handle

	shovelModel:SetAttribute("ItemId", itemId)
end

function DigService:_CreateShovelTool(player, itemId)
	local itemInfo = ItemDef.GetItemInfo(itemId)
	if not itemInfo then
		return
	end

	local shovelTool = Instance.new("Tool")
	shovelTool.Name = itemInfo.Name
	shovelTool.ToolTip = itemInfo.Name or ""
	shovelTool.RequiresHandle = false
	shovelTool.TextureId = itemInfo.Icon
	shovelTool.CanBeDropped = false
	shovelTool:SetAttribute("ItemId", itemId)

	shovelTool.Equipped:Connect(function()
		if self._ShovelTools[player] ~= shovelTool then
			return
		end

		local character = player.Character
		if character then
			self:_ApplyShovelToCharacter(character, itemId)
		end
	end)

	shovelTool.Unequipped:Connect(function()
		if self._ShovelTools[player] ~= shovelTool then
			return
		end

		local character = player.Character
		if character then
			self:_RemoveShovelFromCharacter(character)
		end
	end)

	self._ShovelTools[player] = shovelTool
	shovelTool.Parent = player:WaitForChild("Backpack")

	return shovelTool
end

function DigService:_DestroyShovelTool(player)
	local character = player.Character
	if character then
		self:_RemoveShovelFromCharacter(character)
	end

	local shovelTool = self._ShovelTools[player]
	self._ShovelTools[player] = nil

	if shovelTool and shovelTool.Parent then
		shovelTool:Destroy()
	end
end

function DigService:_UpdateShovelToolForPlayer(player, character)
	local equippedShovelId = self:_EnsureShovelForPlayer(player)
	local itemInfo = ItemDef.GetItemInfo(equippedShovelId)
	if not itemInfo then
		self:_DestroyShovelTool(player)
		return
	end

	local shovelTool = self._ShovelTools[player]
	if not shovelTool
		or not shovelTool.Parent
		or shovelTool:GetAttribute("ItemId") ~= equippedShovelId
		or shovelTool.Name ~= itemInfo.Name then
		self:_DestroyShovelTool(player)
		shovelTool = self:_CreateShovelTool(player, equippedShovelId)
	end

	if not shovelTool then
		return
	end

	character = character or player.Character
	if not character then
		return
	end

	local backpack = player:FindFirstChild("Backpack")
	if shovelTool.Parent ~= character and shovelTool.Parent ~= backpack and backpack then
		shovelTool.Parent = backpack
	end

	local currentShovel = character:FindFirstChild(EQUIPPED_SHOVEL_NAME)
	if shovelTool.Parent == character then
		if currentShovel and currentShovel:GetAttribute("ItemId") == equippedShovelId then
			return
		end

		self:_ApplyShovelToCharacter(character, equippedShovelId)
	else
		if currentShovel then
			self:_RemoveShovelFromCharacter(character)
		end
	end
end

function DigService:_EquipShovelToolForPlayer(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	self:_UpdateShovelToolForPlayer(player, character)

	local shovelTool = self._ShovelTools[player]
	if not shovelTool or shovelTool.Parent ~= player:FindFirstChild("Backpack") then
		return false
	end

	humanoid:EquipTool(shovelTool)
	return true
end

function DigService:_DigForPlayer(player, dirtGuid, predictionId)
	if typeof(dirtGuid) ~= "number" then
		return false
	end
	if typeof(predictionId) ~= "number" or predictionId < 1 or predictionId % 1 ~= 0 then
		predictionId = nil
	end

	local currentTime = os.clock()
	local digCooldown = self:_GetDigCooldown(player)
	local lastDig = self._LastDig[player] or 0

	if currentTime < (lastDig + (digCooldown * 0.8)) then
		return false
	end

	local dirt = self:GetDirt(dirtGuid)
	if not dirt or dirt:GetHealth() <= 0 then
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local shovelTool = self._ShovelTools[player]
	if not shovelTool or shovelTool.Parent ~= character then
		return false
	end

	local shovelId = shovelTool:GetAttribute("ItemId")
	if shovelId ~= self._EquipService:GetEquippedItemForPlayer(player, SHOVEL_SLOT) then
		return false
	end

	local shovelInfo = ItemDef.GetItemInfo(shovelId)
	if not shovelInfo or shovelInfo.Category ~= SHOVEL_SLOT or typeof(shovelInfo.DigPower) ~= "number" or shovelInfo.DigPower <= 0 then
		return false
	end

	local dirtPosition = dirt:GetCFrame().Position
	local position = rootPart.Position
	local x = dirtPosition.X - position.X
	local z = dirtPosition.Z - position.Z
	local distanceSquared = x * x + z * z
	if distanceSquared > ((DIG_RANGE * dirt:GetScale()) ^ 2 + 8 ^ 2) then
		return false
	end

	self._LastDig[player] = currentTime
	local remainingHealth = dirt:Damage(shovelInfo.DigPower, player.UserId, predictionId)
	if remainingHealth == 0 then
		local dirtRarity = DirtDef.GetDirtInfo(dirt:GetDirtId()).Rarity
		self._BonePileService:AwardForDirt(player, dirtRarity, dirt:GetCFrame(), dirt:GetScale())
	end

	return remainingHealth ~= nil
end

function DigService.Client:Dig(player, dirtGuid, predictionId)
	return self.Server:_DigForPlayer(player, dirtGuid, predictionId)
end

function DigService.Client:EquipShovel(player, shovelId)
	return self.Server:EquipShovelForPlayer(player, shovelId)
end

function DigService.Client:BuyShovel(player, shovelId)
	return self.Server:BuyShovelForPlayer(player, shovelId)
end

return DigService
