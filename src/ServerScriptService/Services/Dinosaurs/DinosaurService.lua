local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local DinosaurModels = Assets:WaitForChild("Dinosaurs")
local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local BoostTypesEnum = require(Enums:WaitForChild("BoostTypes"))
local MutationsEnum = require(Enums:WaitForChild("Mutations"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local IapsEnum = require(Enums:WaitForChild("Iaps"))
local SettingsEnum = require(Enums:WaitForChild("Settings"))
local DataKeys = require(ServerScriptService.ServerConfigs.DataKeys)
local DinosaurDef = require(ReplicatedConfigs.DinosaurDef)
local BonePileUtils = require(ReplicatedStorage.Utils.BonePileUtils)
local Dinosaur = require(script.Parent.Dinosaur)
local Knit = require(External:WaitForChild("Knit"))

local DINOSAURS_KEY = DataKeys.Dinosaurs
local DINOSAURS_DEFAULT_DATA = {
	Version = 1,
	Placed = {}
}
local FLOOR_HEIGHT_TOLERANCE = 2

local DinosaurService = {
	Name = "DinosaurService",
	Client = {
		IncomesUpdated = Knit.CreateSignal()
	},
	_DataService = nil,
	_InventoryService = nil,
	_LifecycleService = nil,
	_PlotService = nil,
	_ReplicationService = nil,
	_TimeService = nil,
	_RewardsService = nil,
	_BoostsService = nil,
	_IndexService = nil,
	_IapService = nil,
	_SettingsService = nil,
	_Dinosaurs = {}
}

function DinosaurService:KnitInit()
	for _, animSaves in pairs(DinosaurModels:QueryDescendants("#AnimSaves")) do
		animSaves:Destroy()
	end
end

function DinosaurService:KnitStart()
	self._DataService = require(ServerScriptService.Services.Data.DataService)
	self._InventoryService = require(ServerScriptService.Services.Inventory.InventoryService)
	self._LifecycleService = require(ServerScriptService.Services.LifeCycle.LifecycleService)
	self._PlotService = require(ServerScriptService.Services.Plots.PlotService)
	self._ReplicationService = require(ServerScriptService.Services.Replication.ReplicationService)
	self._TimeService = require(ServerScriptService.Services.Time.TimeService)
	self._RewardsService = require(ServerScriptService.Services.Rewards.RewardsService)
	self._BoostsService = require(ServerScriptService.Services.Boosts.BoostsService)
	self._IndexService = require(ServerScriptService.Services.Index.IndexService)
	self._IapService = require(ServerScriptService.Services.Iaps.IapService)
	self._SettingsService = require(ServerScriptService.Services.Settings.SettingsService)

	self._TimeService.TimeUpdatedSignal:Connect(function()
		for _, player in pairs(self._LifecycleService:GetInitializedPlayers()) do
			self:_AddToDinoIncomes(player)
		end
	end)
end

function DinosaurService:OnPlayerAdded(player)
	local savedData = self._DataService:GetPlayerData(player, DINOSAURS_KEY, DINOSAURS_DEFAULT_DATA)

	self._Dinosaurs[player] = {}
	self:GiveDinosaur(player, "Trex", 1.5, MutationsEnum.Flame)

	local plot = self._PlotService:GetPlotForPlayer(player)
	local floor = plot and plot.Instance:FindFirstChild("_Floor")
	for _, entry in ipairs(savedData.Placed) do
		if floor and floor:IsA("BasePart") and DinosaurDef.GetDinosaurInfo(entry.Id) then
			self:_CreateDinosaur(player, floor, {
				Guid = entry.Guid,
				Id = entry.Id,
				Scale = BonePileUtils.GetScale(entry.Scale),
				Mutation = entry.Mutation or MutationsEnum.Normal,
				ZoneId = entry.ZoneId
			})
		end
	end

	for _, dinosaurs in pairs(self._Dinosaurs) do
		for _, dinosaur in ipairs(dinosaurs) do
			dinosaur:ReplicateTo({ player })
		end
	end
end

function DinosaurService:OnPlayerRemoving(player)
	for _, dinosaur in ipairs(self._Dinosaurs[player] or {}) do
		dinosaur:Destroy()
	end

	self._Dinosaurs[player] = nil
end

function DinosaurService:GiveDinosaur(player, dinosaurId, scale, mutation, zoneId)
	if not DinosaurDef.GetDinosaurInfo(dinosaurId) then return end

	self._IndexService:UnlockForPlayer(player, mutation, dinosaurId)

	return self._InventoryService:AddNonFungibleItemForPlayer(player, dinosaurId, {
		Scale = BonePileUtils.GetScale(scale),
		Mutation = mutation or MutationsEnum.Normal,
		ZoneId = zoneId
	})
end

function DinosaurService:_GetIncomeForPlacedDino(placedDino, cashBoost)
	local info = DinosaurDef.GetDinosaurInfo(placedDino.Id)
	if not info then return end

	local scale : number = placedDino.Scale or 1
	return math.round(DinosaurDef.GetIncome(placedDino.Id, scale, placedDino.Mutation, placedDino.ZoneId) * cashBoost)
end

function DinosaurService:GetIncomePerSecondForPlayer(player)
	local dinosaurData = self._DataService:GetPlayerData(player, DINOSAURS_KEY, DINOSAURS_DEFAULT_DATA)
	local cashBoost = self._BoostsService:GetTotalBoostAmountForType(player, BoostTypesEnum.CashBoost)
	local totalIncome = 0

	for _, placedDino in pairs(dinosaurData.Placed) do
		totalIncome += self:_GetIncomeForPlacedDino(placedDino, cashBoost) or 0
	end

	return totalIncome
end

function DinosaurService:_AddToDinoIncomes(player)
	local dinosaurData = self._DataService:GetPlayerData(player, DINOSAURS_KEY, DINOSAURS_DEFAULT_DATA)

	local cashBoost = self._BoostsService:GetTotalBoostAmountForType(player, BoostTypesEnum.CashBoost)
	local autoCollect = self._IapService:PlayerOwnsProduct(player, IapsEnum.AutoCollect)
		and self._SettingsService:GetSettingForPlayer(player, SettingsEnum.AutoCollect)

	local totalCash = 0
	local incomesPerDino = {}
	for _, placedDino in pairs(dinosaurData.Placed) do
		local income = self:_GetIncomeForPlacedDino(placedDino, cashBoost)
		if not income then continue end

		local guid = placedDino.Guid
		local dinosaur = self:_GetDinosaurByGuid(player, guid)
		if not dinosaur then continue end

		if autoCollect then
			local pendingIncome = dinosaur:GetIncome()
			totalCash += income + pendingIncome
			if pendingIncome > 0 then
				dinosaur:SetIncome(0)
				incomesPerDino[guid] = 0
			end
		else
			totalCash += income
			dinosaur:AddToIncome(income)
			incomesPerDino[guid] = dinosaur:GetIncome()
		end
	end

	if totalCash <= 0 then return end

	if autoCollect then
		self._RewardsService:RewardPlayer(player, PlayerStatsEnum.Cash, totalCash, false, {
			TransactionType = Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			Sku = "Income"
		})
		if next(incomesPerDino) then
			self.Client.IncomesUpdated:Fire(player, incomesPerDino)
		end
	else
		self.Client.IncomesUpdated:Fire(player, incomesPerDino)
	end
end

function DinosaurService:_ClaimIncomeForPlayer(player, guid)
	local dinosaur = self:_GetDinosaurByGuid(player, guid)
	if not dinosaur then return end

	local income = dinosaur:GetIncome() or 0
	if income <= 0 then return end

	dinosaur:SetIncome(0)

	self._RewardsService:RewardPlayer(player, PlayerStatsEnum.Cash, income, false, {
		TransactionType = Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
		Sku = "Income"
	})

	self.Client.IncomesUpdated:Fire(player, {
		[guid] = 0
	})

	return true
end

function DinosaurService:GetMaxDinosaursForPlayer(player)
	return self._PlotService:GetCapacityForPlayer(player)
end

function DinosaurService:_GenerateGuid()
	local guid = HttpService:GenerateGUID(false)
	return guid
end

function DinosaurService:_CreateDinosaur(player, floor, savedData, spawnCFrame)
	local dinosaur = Dinosaur.new(self._ReplicationService, player, floor, savedData, spawnCFrame)
	table.insert(self._Dinosaurs[player], dinosaur)
	dinosaur:ReplicateTo(self._LifecycleService:GetInitializedPlayers())
	return dinosaur
end

function DinosaurService:_GetDinosaurByGuid(player, guid)
	local dinosaurs = self._Dinosaurs[player] or {}
	for _, dinosaur in pairs(dinosaurs) do
		if dinosaur:GetGuid() == guid then
			return dinosaur
		end
	end
end

function DinosaurService:PlaceDinosaur(player, bonePileGuid, groundCFrame)
	local dinosaurs = self._Dinosaurs[player]
	local savedData = self._DataService:GetPlayerData(player, DINOSAURS_KEY, DINOSAURS_DEFAULT_DATA)
	if not dinosaurs or not savedData or #dinosaurs >= self:GetMaxDinosaursForPlayer(player) then
		return false
	end

	if type(bonePileGuid) ~= "string" or typeof(groundCFrame) ~= "CFrame" then
		return false
	end

	local item = self._InventoryService:GetNonFungibleItemForPlayer(player, bonePileGuid)
	if not item or not DinosaurDef.GetDinosaurInfo(item.ItemId) then
		return false
	end

	local plot = self._PlotService:GetPlotForPlayer(player)
	local floor = plot and plot.Instance:FindFirstChild("_Floor")
	if not floor or not floor:IsA("BasePart") then
		return false
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	local localPosition = floor.CFrame:PointToObjectSpace(groundCFrame.Position)
	local floorSize = floor.Size
	if localPosition.X ~= localPosition.X or localPosition.Y ~= localPosition.Y or localPosition.Z ~= localPosition.Z
		or math.abs(localPosition.X) > floorSize.X / 2
		or math.abs(localPosition.Z) > floorSize.Z / 2
		or math.abs(localPosition.Y - floorSize.Y / 2) > FLOOR_HEIGHT_TOLERANCE then
		return false
	end

	local localLookVector = floor.CFrame:VectorToObjectSpace(groundCFrame.LookVector)
	local yaw = math.atan2(-localLookVector.X, -localLookVector.Z)
	if yaw ~= yaw then
		return false
	end

	local savedEntry = {
		Guid = self:_GenerateGuid(),
		Id = item.ItemId,
		Scale = BonePileUtils.GetScale(item.Metadata and item.Metadata.Scale),
		Mutation = item.Metadata and item.Metadata.Mutation or MutationsEnum.Normal,
		ZoneId = item.Metadata and item.Metadata.ZoneId
	}
	local spawnCFrame = floor.CFrame
		* CFrame.new(localPosition.X, floorSize.Y / 2, localPosition.Z)
		* CFrame.Angles(0, yaw, 0)

	if not self._InventoryService:RemoveNonFungibleItemForPlayer(player, bonePileGuid) then
		return false
	end

	table.insert(savedData.Placed, savedEntry)
	self._DataService:SetPlayerData(player, DINOSAURS_KEY, savedData)

	local dinosaur = self:_CreateDinosaur(player, floor, savedEntry, spawnCFrame)
	dinosaur:ReplicateTo({ player })

	return true
end

function DinosaurService:UnequipDinosaur(player, guid)
	if type(guid) ~= "string" then return false end

	local dinosaurs = self._Dinosaurs[player]
	if not dinosaurs then return false end

	local savedData = self._DataService:GetPlayerData(player, DINOSAURS_KEY, DINOSAURS_DEFAULT_DATA)
	if not savedData then return false end

	local placedIndex
	local placedEntry
	for index, entry in ipairs(savedData.Placed) do
		if entry.Guid == guid then
			placedIndex = index
			placedEntry = entry
			break
		end
	end
	if not placedEntry then return false end

	local inventoryGuid = self:GiveDinosaur(player, placedEntry.Id, placedEntry.Scale, placedEntry.Mutation, placedEntry.ZoneId)
	if not inventoryGuid then return false end

	self:_ClaimIncomeForPlayer(player, guid)
	table.remove(savedData.Placed, placedIndex)
	self._DataService:SetPlayerData(player, DINOSAURS_KEY, savedData)

	for index = #dinosaurs, 1, -1 do
		local dinosaur = dinosaurs[index]
		if dinosaur:GetGuid() == guid then
			dinosaur:Destroy()
			table.remove(dinosaurs, index)
			break
		end
	end

	return true
end

function DinosaurService:_SellDinosaurForPlayer(player, guid)
	if type(guid) ~= "string" then return false end

	local item = self._InventoryService:GetNonFungibleItemForPlayer(player, guid)
	if not item then return false end

	local scale = BonePileUtils.GetScale(item.Metadata and item.Metadata.Scale)
	local sellPrice = DinosaurDef.GetSellPrice(item.ItemId, scale, item.Metadata.Mutation, item.Metadata.ZoneId)
	if not sellPrice then return false end

	if not self._InventoryService:RemoveNonFungibleItemForPlayer(player, guid) then
		return false
	end

	self._RewardsService:RewardPlayer(player, PlayerStatsEnum.Cash, sellPrice, false, {
		TransactionType = Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
		Sku = "DinosaurSale"
	})

	return true
end

function DinosaurService:_SellAllDinosaursForPlayer(player)
	local inventoryItems = self._InventoryService:GetNonFungiblesForPlayer(player)
	if not inventoryItems then return false end

	local guids = {}
	local totalSellPrice = 0
	for _, item in ipairs(inventoryItems) do
		local dinosaurInfo = DinosaurDef.GetDinosaurInfo(item.ItemId)
		if not dinosaurInfo then continue end

		local scale = BonePileUtils.GetScale(item.Metadata and item.Metadata.Scale)
		local sellPrice = DinosaurDef.GetSellPrice(item.ItemId, scale, item.Metadata.Mutation, item.Metadata.ZoneId)
		if sellPrice then
			table.insert(guids, item.Guid)
			totalSellPrice += sellPrice
		end
	end

	if #guids == 0 then return false end
	if not self._InventoryService:RemoveNonFungibleItemsForPlayer(player, guids) then
		return false
	end

	self._RewardsService:RewardPlayer(player, PlayerStatsEnum.Cash, totalSellPrice, false, {
		TransactionType = Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
		Sku = "DinosaurSale"
	})

	return true
end

function DinosaurService:EquipBestDinosaurs(player)
	local dinosaurs = self._Dinosaurs[player]
	if not dinosaurs then return false end

	local savedData = self._DataService:GetPlayerData(player, DINOSAURS_KEY, DINOSAURS_DEFAULT_DATA)
	local inventoryItems = self._InventoryService:GetNonFungiblesForPlayer(player)
	if not savedData or not inventoryItems then return false end

	local plot = self._PlotService:GetPlotForPlayer(player)
	local floor = plot and plot.Instance:FindFirstChild("_Floor")
	if not floor or not floor:IsA("BasePart") then return false end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	local candidates = {}
	for _, entry in ipairs(savedData.Placed) do
		local info = DinosaurDef.GetDinosaurInfo(entry.Id)
		if not info then return false end

		local scale = BonePileUtils.GetScale(entry.Scale)
		table.insert(candidates, {
			Guid = entry.Guid,
			Scale = scale,
			Income = DinosaurDef.GetIncome(entry.Id, scale, entry.Mutation, entry.ZoneId),
			Placed = true
		})
	end

	for _, item in ipairs(inventoryItems) do
		local info = DinosaurDef.GetDinosaurInfo(item.ItemId)
		if info then
			local scale = BonePileUtils.GetScale(item.Metadata and item.Metadata.Scale)
			table.insert(candidates, {
				Guid = item.Guid,
				Scale = scale,
				Income = DinosaurDef.GetIncome(item.ItemId, scale, item.Metadata and item.Metadata.Mutation, item.Metadata and item.Metadata.ZoneId),
				Placed = false
			})
		end
	end

	table.sort(candidates, function(a, b)
		if a.Income ~= b.Income then
			return a.Income > b.Income
		end
		if a.Placed ~= b.Placed then
			return a.Placed
		end
		return a.Guid < b.Guid
	end)

	local bestGuids = {}
	local toPlace = {}
	for index = 1, math.min(#candidates, self:GetMaxDinosaursForPlayer(player)) do
		local candidate = candidates[index]
		bestGuids[candidate.Guid] = true
		if not candidate.Placed then
			table.insert(toPlace, candidate)
		end
	end

	local toUnequip = {}
	for _, entry in ipairs(savedData.Placed) do
		if not bestGuids[entry.Guid] then
			table.insert(toUnequip, entry)
		end
	end

	if #toUnequip == 0 and #toPlace == 0 then return true end

	for _, entry in ipairs(toUnequip) do
		if not self:UnequipDinosaur(player, entry.Guid) then
			return false
		end
	end

	local random = Random.new()

	local function getRandomPlacementCFrame(scale)
		local size = floor.Size
		local margin = math.min(4 * scale, size.X / 2, size.Z / 2)
		local halfX = size.X / 2 - margin
		local halfZ = size.Z / 2 - margin
		local x = halfX > 0 and random:NextNumber(-halfX, halfX) or 0
		local z = halfZ > 0 and random:NextNumber(-halfZ, halfZ) or 0
		local yaw = random:NextNumber(-math.pi, math.pi)
		return floor.CFrame * CFrame.new(x, size.Y / 2, z) * CFrame.Angles(0, yaw, 0)
	end

	local allPlaced = true
	for _, candidate in ipairs(toPlace) do
		local cframe = getRandomPlacementCFrame(candidate.Scale)
		if not self:PlaceDinosaur(player, candidate.Guid, cframe) then
			allPlaced = false
		end
	end

	return allPlaced
end

function DinosaurService.Client:PlaceDinosaur(player, bonePileGuid, groundCFrame)
	return self.Server:PlaceDinosaur(player, bonePileGuid, groundCFrame)
end

function DinosaurService.Client:UnequipDinosaur(player, guid)
	return self.Server:UnequipDinosaur(player, guid)
end

function DinosaurService.Client:EquipBestDinosaurs(player)
	return self.Server:EquipBestDinosaurs(player)
end

function DinosaurService.Client:ClaimIncome(player, dinoGuid)
	return self.Server:_ClaimIncomeForPlayer(player, dinoGuid)
end

function DinosaurService.Client:SellDinosaur(player, guid)
	if type(guid) ~= "string" then return end

	return self.Server:_SellDinosaurForPlayer(player, guid)
end

function DinosaurService.Client:SellAllDinosaurs(player)
	return self.Server:_SellAllDinosaursForPlayer(player)
end

return DinosaurService
