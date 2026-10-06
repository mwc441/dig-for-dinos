local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local ServerConfigs = ServerScriptService:WaitForChild("ServerConfigs")
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local DataKeys = require(ServerConfigs:WaitForChild("DataKeys"))
local Signal = require(External:WaitForChild("Signal"))
local Knit = require(External:WaitForChild("Knit"))

local STATS_KEY = DataKeys.PlayerStats
local STATS_DEFAULT_DATA = {
	Version = 1,
	Stats = {
		[PlayerStatsEnum.Cash] = 0,
		[PlayerStatsEnum.OfflineEarnings] = 0,
		[PlayerStatsEnum.Rebirths] = 0,
		[PlayerStatsEnum.PlotLevel] = 1
	}
}

local PlayerStatsService = {
	Name = "PlayerStatsService",
	Client = {},
	_DataService = nil,
	_BoostsService = nil,
	PlayerStatsUpdated = Signal.new()
}

function PlayerStatsService:KnitStart()
	self._DataService = require(ServerScriptService.Services.Data.DataService)
	self._BoostsService = require(ServerScriptService.Services.Boosts.BoostsService)
end

function PlayerStatsService:OnPlayerAdded(player)
	-- Initialize when player added
	self:Reconcile(player)
end

function PlayerStatsService:Reconcile(player)
	local playerStatData = self._DataService:GetPlayerData(player, STATS_KEY, STATS_DEFAULT_DATA)
	local reconciled = false

	if type(playerStatData) ~= "table" then
		playerStatData = {
			Version = STATS_DEFAULT_DATA.Version,
			Stats = {}
		}
		reconciled = true
	end

	if playerStatData.Version == nil then
		playerStatData.Version = STATS_DEFAULT_DATA.Version
		reconciled = true
	end

	if type(playerStatData.Stats) ~= "table" then
		playerStatData.Stats = {}
		reconciled = true
	end

	for statEnum, defaultValue in pairs(STATS_DEFAULT_DATA.Stats) do
		if playerStatData.Stats[statEnum] ~= nil then
			continue
		end

		playerStatData.Stats[statEnum] = defaultValue
		reconciled = true
	end

	if reconciled then
		self._DataService:SetPlayerData(player, STATS_KEY, playerStatData, true)
	end

	return playerStatData
end

function PlayerStatsService:GetStatValueForPlayer(player, statEnum)
	local playerStatData = self:Reconcile(player)

	return playerStatData.Stats[statEnum]
end

function PlayerStatsService:AddToStatForPlayer(player, statEnum, amount)
	local currentValue = self:GetStatValueForPlayer(player, statEnum) or 0

	local newValue = currentValue + amount

	self:SetStatValueForPlayer(player, statEnum, newValue)

	return newValue
end

function PlayerStatsService:SetStatValueForPlayer(player, statEnum, statValue)
	local playerStatData = self:Reconcile(player)

	playerStatData.Stats[statEnum] = statValue

	self._DataService:SetPlayerData(player, STATS_KEY, playerStatData, true)

	self.PlayerStatsUpdated:Fire(player, statEnum)
end

return PlayerStatsService
