local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local BoostTypesEnum = require(Enums:WaitForChild("BoostTypes"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
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
	_Dinosaurs = {}
}

function DinosaurService:KnitStart()
	self._DataService = require(ServerScriptService.Services.Data.DataService)
	self._InventoryService = require(ServerScriptService.Services.Inventory.InventoryService)
	self._LifecycleService = require(ServerScriptService.Services.LifeCycle.LifecycleService)
	self._PlotService = require(ServerScriptService.Services.Plots.PlotService)
	self._ReplicationService = require(ServerScriptService.Services.Replication.ReplicationService)
	self._TimeService = require(ServerScriptService.Services.Time.TimeService)
	self._RewardsService = require(ServerScriptService.Services.Rewards.RewardsService)
	self._BoostsService = require(ServerScriptService.Services.Boosts.BoostsService)

	self._TimeService.TimeUpdatedSignal:Connect(function()
		for _, player in pairs(self._LifecycleService:GetInitializedPlayers()) do
			self:_AddToDinoIncomes(player)
		end
	end)
end

function DinosaurService:OnPlayerAdded(player)
	local savedData = self._DataService:GetPlayerData(player, DINOSAURS_KEY, DINOSAURS_DEFAULT_DATA)

	self._Dinosaurs[player] = {}

	local plot = self._PlotService:GetPlotForPlayer(player)
	local floor = plot and plot.Instance:FindFirstChild("_Floor")
	for _, entry in ipairs(savedData.Placed) do
		if floor and floor:IsA("BasePart") and DinosaurDef.GetDinosaurInfo(entry.Id) then
			self:_CreateDinosaur(player, floor, {
				Guid = entry.Guid,
				Id = entry.Id,
				Scale = BonePileUtils.GetScale(entry.Scale)
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

function DinosaurService:_GetIncomeForPlacedDino(placedDino, cashBoost)
	local info = DinosaurDef.GetDinosaurInfo(placedDino.Id)
	if not info then return end

	local scale : number = placedDino.Scale or 1
	return math.round(info.Income * scale * cashBoost)
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

	local totalCash = 0
	local incomesPerDino = {}
	for _, placedDino in pairs(dinosaurData.Placed) do
		local income = self:_GetIncomeForPlacedDino(placedDino, cashBoost)
		if not income then continue end

		local guid = placedDino.Guid
		local dinosaur = self:_GetDinosaurByGuid(player, guid)
		if not dinosaur then continue end

		totalCash += income
		dinosaur:AddToIncome(income)

		incomesPerDino[guid] = dinosaur:GetIncome()
	end

	if totalCash <= 0 then return end

	self.Client.IncomesUpdated:Fire(player, incomesPerDino)
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
		Scale = BonePileUtils.GetScale(item.Metadata and item.Metadata.Scale)
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

function DinosaurService.Client:PlaceDinosaur(player, bonePileGuid, groundCFrame)
	return self.Server:PlaceDinosaur(player, bonePileGuid, groundCFrame)
end

function DinosaurService.Client:ClaimIncome(player, dinoGuid)
	return self.Server:_ClaimIncomeForPlayer(player, dinoGuid)
end

return DinosaurService
