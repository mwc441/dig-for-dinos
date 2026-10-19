local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local External = ReplicatedStorage:WaitForChild("External")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local BoostTypesEnum = require(Enums:WaitForChild("BoostTypes"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local Rarities = require(Enums:WaitForChild("Rarities"))
local ItemDef = require(ReplicatedConfigs:WaitForChild("ItemDef"))
local DirtDef = require(ReplicatedConfigs:WaitForChild("DirtDef"))
local DirtSpawnerDef = require(ReplicatedConfigs:WaitForChild("DirtSpawnerDef"))
local ZoneDef = require(ReplicatedConfigs:WaitForChild("ZoneDef"))
local RarityColorUtils = require(Utils:WaitForChild("RarityColorUtils"))
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local Knit = require(External:WaitForChild("Knit"))
local DirtSpawner = require(script.Parent:WaitForChild("DirtSpawner"))

local SHOVEL_SLOT = ItemDef.Categories.Shovel
local DEFAULT_SHOVEL_ID = "WoodenShovel"
local DIG_RANGE = 8
local BASE_TRAINING_POWER = 1

local DigService = {
	Name = "DigService",
	Client = {
		InitialDirtGuids = Knit.CreateProperty(nil),
		UpcomingGuaranteedSpawns = Knit.CreateProperty({})
	},
	_EquipService = nil,
	_InventoryService = nil,
	_CommerceService = nil,
	_CharacterService = nil,
	_PlotService = nil,
	_PlayerStatsService = nil,
	_BoostsService = nil,
	_ReplicationService = nil,
	_LifecycleService = nil,
	_BonePileService = nil,
	_RewardsService = nil,
	_TimeService = nil,
	_DirtSpawners = {},
	_GuaranteedNextSpawns = {},
	_GuaranteedRandom = Random.new(),
	_ShovelTools = {},
	_LastDig = {},
	_LastTrainingDig = {}
}

function DigService:KnitStart()
	self._EquipService = require(ServerScriptService.Services.Equips.EquipService)
	self._InventoryService = require(ServerScriptService.Services.Inventory.InventoryService)
	self._CommerceService = require(ServerScriptService.Services.Commerce.CommerceService)
	self._CharacterService = require(ServerScriptService.Services.Character.CharacterService)
	self._PlotService = require(ServerScriptService.Services.Plots.PlotService)
	self._PlayerStatsService = require(ServerScriptService.Services.PlayerStats.PlayerStatsService)
	self._BoostsService = require(ServerScriptService.Services.Boosts.BoostsService)
	self._ReplicationService = require(ServerScriptService.Services.Replication.ReplicationService)
	self._LifecycleService = require(ServerScriptService.Services.LifeCycle.LifecycleService)
	self._RewardsService = require(ServerScriptService.Services.Rewards.RewardsService)
	self._TimeService = require(ServerScriptService.Services.Time.TimeService)
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

	local now = os.time()
	for _, guarantee in ipairs(DirtSpawnerDef.GuaranteedSpawns) do
		self._GuaranteedNextSpawns[guarantee.Rarity] = now + guarantee.IntervalSeconds
	end
	self:_PublishGuaranteedSpawns()

	self._TimeService.TimeUpdatedSignal:Connect(function()
		self:_UpdateGuaranteedSpawns()
	end)

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
	self._LastTrainingDig[player] = nil
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

	self._DirtSpawners[instance] = DirtSpawner.new(
		instance,
		self._ReplicationService,
		config,
		self._LifecycleService,
		function(dirt)
			self:_AnnounceRareDirt(dirt)
		end
	)
end

function DigService:_RemoveDirtSpawner(instance)
	local spawner = self._DirtSpawners[instance]
	if not spawner then
		return
	end

	self._DirtSpawners[instance] = nil
	spawner:Destroy()
end

function DigService:_AnnounceRareDirt(dirt)
	local dirtInfo = DirtDef.GetDirtInfo(dirt:GetDirtId())
	local rarity = dirtInfo.Rarity
	if rarity ~= Rarities.Mythical and rarity ~= Rarities.Secret then
		return
	end

	local zoneInfo = ZoneDef.GetZoneInfo(dirt:GetZoneId())
	local zoneName = zoneInfo and zoneInfo.Name or dirt:GetZoneId()
	local rarityColor = RarityColorUtils.GetColor(rarity):ToHex()
	local zoneColor = zoneInfo and UtilFunctions.GetColorFromColorSequence(zoneInfo.Color):ToHex() or "FFFFFF"
	local message = `A <font color="#{rarityColor}">{rarity}</font> dirt pile has spawned in <font color="#{zoneColor}">{zoneName}</font>!`
	self._RewardsService:MakeAnnouncement(message, Color3.new(1, 1, 1))
	self._RewardsService:MakeSystemMessage(message, Color3.new(1, 1, 1))
end

function DigService:_PublishGuaranteedSpawns()
	local upcoming = {}
	for _, guarantee in ipairs(DirtSpawnerDef.GuaranteedSpawns) do
		table.insert(upcoming, {
			Rarity = guarantee.Rarity,
			SpawnsAt = self._GuaranteedNextSpawns[guarantee.Rarity]
		})
	end
	self.Client.UpcomingGuaranteedSpawns:Set(upcoming)
end

function DigService:_SpawnGuaranteedDirt(dirtId)
	local spawnersByZone = {}
	for _, spawner in pairs(self._DirtSpawners) do
		local zoneId = spawner:GetZoneId()
		spawnersByZone[zoneId] = spawnersByZone[zoneId] or {}
		table.insert(spawnersByZone[zoneId], spawner)
	end

	local zoneIds = {}
	for zoneId in pairs(spawnersByZone) do
		table.insert(zoneIds, zoneId)
	end

	while #zoneIds > 0 do
		local zoneId = table.remove(zoneIds, self._GuaranteedRandom:NextInteger(1, #zoneIds))
		local spawners = spawnersByZone[zoneId]
		while #spawners > 0 do
			local spawner = table.remove(spawners, self._GuaranteedRandom:NextInteger(1, #spawners))
			local dirt = spawner:SpawnDirt(dirtId)
			if dirt then
				return dirt
			end
		end
	end
end

function DigService:_UpdateGuaranteedSpawns()
	local now = os.time()
	local changed = false
	for _, guarantee in ipairs(DirtSpawnerDef.GuaranteedSpawns) do
		if now >= self._GuaranteedNextSpawns[guarantee.Rarity]
			and self:_SpawnGuaranteedDirt(guarantee.DirtId) then
			self._GuaranteedNextSpawns[guarantee.Rarity] = now + guarantee.IntervalSeconds
			changed = true
		end
	end

	if changed then
		self:_PublishGuaranteedSpawns()
	end
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

function DigService:_GetDigTrainingSpeed(player)
	return 1 -- Digs per second. Apply training speed upgrades here later.
end

function DigService:_GetDigTrainingCooldown(player)
	return 1 / self:_GetDigTrainingSpeed(player)
end

function DigService:_IsPlayerOnExcavation(player)
	local plot = self._PlotService:GetPlotForPlayer(player)
	local excavation = plot and plot.Instance:FindFirstChild("_Excavation")
	local part = excavation and excavation:IsA("Model") and excavation.PrimaryPart
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not part or not rootPart or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local offset = part.CFrame:PointToObjectSpace(rootPart.Position)
	return math.abs(offset.X) <= (part.Size.X / 2) * 2 and math.abs(offset.Z) <= (part.Size.Z / 2) * 2
end

function DigService:_TrainDigPowerForPlayer(player)
	local currentTime = os.clock()
	local lastTrainingDig = self._LastTrainingDig[player]
	if lastTrainingDig and currentTime < lastTrainingDig + self:_GetDigTrainingCooldown(player) * 0.9 then
		return false
	end

	if not self:_IsPlayerOnExcavation(player) then
		return false
	end

	local shovelId = self._EquipService:GetEquippedItemForPlayer(player, SHOVEL_SLOT)
	local shovelInfo = ItemDef.GetItemInfo(shovelId)
	if not shovelInfo or shovelInfo.Category ~= SHOVEL_SLOT
		or typeof(shovelInfo.DigMultiplier) ~= "number" or shovelInfo.DigMultiplier <= 0
		or self._InventoryService:GetQuantityOfItemForPlayer(player, shovelId) <= 0 then
		return false
	end

	self._LastTrainingDig[player] = currentTime
	local trainingBoost = self._BoostsService:GetTotalBoostAmountForType(player, BoostTypesEnum.DigPowerTrainingBoost)
	local powerGained = BASE_TRAINING_POWER * shovelInfo.DigMultiplier * trainingBoost
	self._PlayerStatsService:AddToStatForPlayer(player, PlayerStatsEnum.DigPower, powerGained)
	return powerGained
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

	self._ShovelTools[player] = shovelTool
	shovelTool.Parent = player:WaitForChild("Backpack")

	return shovelTool
end

function DigService:_DestroyShovelTool(player)
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
	if not shovelInfo or shovelInfo.Category ~= SHOVEL_SLOT then
		return false
	end

	local digPower = self._PlayerStatsService:GetStatValueForPlayer(player, PlayerStatsEnum.DigPower)
	if typeof(digPower) ~= "number" or digPower <= 0 or digPower ~= digPower then
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
	local remainingHealth = dirt:Damage(digPower, player.UserId, predictionId)
	if remainingHealth == 0 then
		local dirtRarity = DirtDef.GetDirtInfo(dirt:GetDirtId()).Rarity
		self._BonePileService:AwardForDirt(player, dirt:GetZoneId(), dirtRarity, dirt:GetCFrame(), dirt:GetScale())
	end

	return remainingHealth ~= nil
end

function DigService.Client:Dig(player, dirtGuid, predictionId)
	return self.Server:_DigForPlayer(player, dirtGuid, predictionId)
end

function DigService.Client:TrainDigPower(player)
	return self.Server:_TrainDigPowerForPlayer(player)
end

function DigService.Client:EquipShovel(player, shovelId)
	return self.Server:EquipShovelForPlayer(player, shovelId)
end

function DigService.Client:BuyShovel(player, shovelId)
	return self.Server:BuyShovelForPlayer(player, shovelId)
end

return DigService
