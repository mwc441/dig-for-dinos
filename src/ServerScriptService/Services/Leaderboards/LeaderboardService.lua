local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local Components = ServerScriptService:WaitForChild("Components")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local TableUtils = require(External:WaitForChild("TableUtils"))
local EternityNum = require(External:WaitForChild("EternityNum"))
local Knit = require(External:WaitForChild("Knit"))
local BigNumbers = require(External:WaitForChild("BigNumbers"))

local CURRENT_DATASTORE_NAME_ENDING = "_Leaderboard"
local TIME_TO_UPDATE_LEADERBOARDS = 1 * 60 -- 1 minute

local LeaderboardService = {
	Name = "LeaderboardService",
	Client = {
		PlayerLeaderboardRanks = Knit.CreateProperty({})
	},
	_PlayerStatsService = nil,
	_TimeService = nil,
	_LifecycleService = nil,
	_PlayerToAdds = {},
	_LastUpdated = nil
}

function LeaderboardService:KnitStart()
	self._PlayerStatsService = require(ServerScriptService.Services.PlayerStats.PlayerStatsService)
	self._TimeService = require(ServerScriptService.Services.Time.TimeService)
	self._LifecycleService = require(ServerScriptService.Services.LifeCycle.LifecycleService)
	self._LeaderboardComponent = require(Components.Leaderboard)

	self._TimeService.TimeUpdatedSignal:Connect(function(currentTime)
		if currentTime >= ((self._LastUpdated or 0) + TIME_TO_UPDATE_LEADERBOARDS) then
			self._LastUpdated = currentTime
			self:_UpdateLeaderboards()
		end
	end)

	self._PlayerStatsService.PlayerStatsUpdated:Connect(function(player)
		self:_UpdateLeaderstatsForPlayer(player)
	end)

	self:_SetupLeaderboards()
end

function LeaderboardService:OnPlayerAdded(player)
	local ranks = self.Client.PlayerLeaderboardRanks:Get()
	ranks[player.UserId] = {}
	self.Client.PlayerLeaderboardRanks:Set(ranks)

	self:_UpdatePlayerRanks(player)

	self:_UpdateLeaderstatsForPlayer(player)
end

function LeaderboardService:OnPlayerRemoving(player)
	local ranks = self.Client.PlayerLeaderboardRanks:Get()
	ranks[player.UserId] = nil
	self.Client.PlayerLeaderboardRanks:Set(ranks)
end

function LeaderboardService:_GetAllNonTimedLeaderboardKeys()
	local leaderboardKeys = {}

	for _, leaderboardComponent in pairs(self._LeaderboardComponent:GetAll()) do
		if leaderboardComponent:GetTimeId() then
			continue
		end

		local leaderboardKey = leaderboardComponent:GetLeaderboardKey()
		if not table.find(leaderboardKeys, leaderboardKey) then
			table.insert(leaderboardKeys, leaderboardKey)
		end
	end

	return leaderboardKeys
end

function LeaderboardService:_GetAllNonTimedLeaderboards(key)
	local leaderboards = {}
	for _, leaderboardComponent in pairs(self._LeaderboardComponent:GetAll()) do
		if leaderboardComponent:GetTimeId() then
			continue
		end

		if leaderboardComponent:GetLeaderboardKey() == key then
			table.insert(leaderboards, leaderboardComponent)
		end
	end

	return leaderboards
end

function LeaderboardService:_SetupLeaderboards()
	for _, leaderboardComponent in pairs(self._LeaderboardComponent:GetAll()) do
		self:_SetupLeaderboard(leaderboardComponent)
	end

	self._LeaderboardComponent.Started:Connect(function(leaderboardComponent)
		self:_SetupLeaderboard(leaderboardComponent)
	end)
end

function LeaderboardService:_SetupLeaderboard(leaderboardComponent)
	leaderboardComponent.Updated:Connect(function()
		self:_UpdateAllPlayerRanks()
	end)
end

function LeaderboardService:_UpdateLeaderboards()
	self:_UpdateNonTimedLeaderboards()
	self:_UpdateTimedLeaderboards()
end

function LeaderboardService:_UpdateAllPlayerRanks()
	for _, player in pairs(self._LifecycleService:GetInitializedPlayers()) do
		self:_UpdatePlayerRanks(player)
	end
end

function LeaderboardService:_UpdatePlayerRanks(player)
	local ranks = self.Client.PlayerLeaderboardRanks:Get()
	local playerRanks = ranks[player.UserId]

	for _, leaderboardComponent in pairs(self._LeaderboardComponent:GetAll()) do
		local rank = leaderboardComponent:GetRankForPlayer(player)

		local leaderboardKey = leaderboardComponent:GetLeaderboardKey()
		local timeId = leaderboardComponent:GetTimeId() or "All"

		local leaderboardKeyTable = playerRanks[leaderboardKey]
		if not leaderboardKeyTable then
			playerRanks[leaderboardKey] = {}
			leaderboardKeyTable = playerRanks[leaderboardKey]
		end

		leaderboardKeyTable[timeId] = rank
	end

	self.Client.PlayerLeaderboardRanks:Set(ranks)

	local bestRank = self:_GetPlayerBestRank(player)
	if not bestRank then
		return
	end

	player:SetAttribute("Rank", bestRank)
end

function LeaderboardService:_GetPlayerBestRank(player)
	local ranks = self.Client.PlayerLeaderboardRanks:Get()
	local playerRanks = ranks[player.UserId]

	local bestRank
	for _, leaderboardKeyTable in pairs(playerRanks or {}) do
		for _, rank in pairs(leaderboardKeyTable) do
			if rank < (bestRank or math.huge) then
				bestRank = rank
			end
		end
	end

	return bestRank
end

function LeaderboardService:_UpdateNonTimedLeaderboards()
	local leaaderboardKeys = self:_GetAllNonTimedLeaderboardKeys()
	for _, leaderboardKey in pairs(leaaderboardKeys) do
		task.spawn(function()
			self:_UpdateEntriesInNonTimedLeaderboard(leaderboardKey)
			self:_GetEntriesInNonTimedLeaderboard(leaderboardKey)
		end)
	end
end

function LeaderboardService:_UpdateEntriesInNonTimedLeaderboard(leaderboardId)
	local dataStore = DataStoreService:GetOrderedDataStore(leaderboardId .. CURRENT_DATASTORE_NAME_ENDING)
	for _, player in pairs(self._LifecycleService:GetInitializedPlayers()) do
		if player.UserId <= 0 then
			continue
		end

		local playerValue = self._PlayerStatsService:GetStatValueForPlayer(player, leaderboardId)
		if not playerValue then
			continue
		end

		local success, error = pcall(function()
			dataStore:SetAsync(tostring(player.UserId), EternityNum.lbencode(playerValue))
		end)

		if not success then
			warn(error)
		end
	end
end

function LeaderboardService:_GetEntriesInNonTimedLeaderboard(leaderboardId)
	local success, dataStorePages = pcall(function()
		local dataStore = DataStoreService:GetOrderedDataStore(leaderboardId .. CURRENT_DATASTORE_NAME_ENDING)
		return dataStore:GetSortedAsync(false, 100)
	end)

	if not success then
		return
	end

	local currentPage = dataStorePages:GetCurrentPage()

	local leaderboards = self:_GetAllNonTimedLeaderboards(leaderboardId)
	for _, leaderboardComponent in pairs(leaderboards) do
		leaderboardComponent:Update(currentPage)
	end
end

-- TIMED LEADERBOARD STUFF
function LeaderboardService:AddToValueForPlayer(player, value, toAdd)
	local leaderboards = self:_GetTimedLeaderboardsWithKey(value)
	if #leaderboards <= 0 then
		return
	end

	if type(toAdd) ~= "number" then
		return
	end

	if toAdd <= 0 then
		return
	end

	local playerToAddTable = self._PlayerToAdds[player]
	if not playerToAddTable then
		self._PlayerToAdds[player] = {}
		playerToAddTable = self._PlayerToAdds[player]
	end

	local oldValue = (playerToAddTable[value] or 0)

	playerToAddTable[value] = oldValue + toAdd
end

function LeaderboardService:_CheckToAddTable(player)
	local playerToAddTable = self._PlayerToAdds[player]
	if not playerToAddTable then
		return
	end

	local total = 0
	for _ in pairs(playerToAddTable) do
		total += 1
	end

	if total <= 0 then
		self._PlayerToAdds[player] = nil
	end
end

function LeaderboardService:_UpdateTimedLeaderboards()
	local leaderboardTables = {}
	for _, leaderboardComponent in pairs(self._LeaderboardComponent:GetAll()) do
		local timeId = leaderboardComponent:GetTimeId()
		if not timeId then
			continue
		end

		local leaderboardKey = leaderboardComponent:GetLeaderboardKey()
		if not leaderboardKey then
			continue
		end

		local leaderboardTable = leaderboardTables[leaderboardKey]
		if not leaderboardTable then
			leaderboardTables[leaderboardKey] = {}

			leaderboardTable = leaderboardTables[leaderboardKey]
		end

		if not table.find(leaderboardTable, timeId) then
			table.insert(leaderboardTable, timeId)
		end
	end

	for leaderboardId, leaderboardTable in pairs(leaderboardTables) do
		for _, timeId in pairs(leaderboardTable) do
			task.spawn(function()
				self:_UpdateEntriesInTimedLeaderboard(leaderboardId, timeId)
				self:_GetEntiresInTimedLeaderboard(leaderboardId, timeId)
			end)
		end
	end
end

function LeaderboardService:GetTimeStringFromTimeId(timeId)
	local timeString
	if timeId == "Monthly" then
		local dateTime = DateTime.now()
		local universalTime = dateTime:ToUniversalTime()

		timeString = string.format("_%d_%d", universalTime.Month, universalTime.Year)
	end

	return timeString
end

function LeaderboardService:_UpdateEntriesInTimedLeaderboard(leaderboardId, timeId)
	local timeString = self:GetTimeStringFromTimeId(timeId)
	if not timeString then
		return
	end

	local dataStore = DataStoreService:GetOrderedDataStore(leaderboardId .. CURRENT_DATASTORE_NAME_ENDING .. timeString)

	local players = TableUtils.Keys(self._PlayerToAdds)
	for _, player in pairs(players) do
		local playerToAddTable = self._PlayerToAdds[player]
		if not playerToAddTable then
			continue
		end

		local toAddForValue = playerToAddTable[leaderboardId] or 0
		self._PlayerToAdds[player][leaderboardId] = nil
		self:_CheckToAddTable(player)

		if toAddForValue <= 0 then
			continue
		end

		if player.UserId <= 0 then
			continue
		end

		local success, error = pcall(function()
			dataStore:UpdateAsync(tostring(player.UserId), function(oldValue)
				return EternityNum.lbencode(EternityNum.add(EternityNum.lbdecode(oldValue), toAddForValue))
			end)
		end)

		if not success then
			warn(error)
		end
	end
end

function LeaderboardService:_GetAllTimedLeaderboards(leaderboardKey, timeId)
	local leaderboards = {}
	for _, leaderboardComponent in pairs(self._LeaderboardComponent:GetAll()) do
		if (leaderboardComponent:GetTimeId() == timeId) and (leaderboardComponent:GetLeaderboardKey() == leaderboardKey) then
			table.insert(leaderboards, leaderboardComponent)
		end
	end

	return leaderboards
end

function LeaderboardService:_GetTimedLeaderboardsWithKey(leaderboardKey)
	local leaderboards = {}
	for _, leaderboardComponent in pairs(self._LeaderboardComponent:GetAll()) do
		if (leaderboardComponent:GetLeaderboardKey() == leaderboardKey) and (leaderboardComponent:GetTimeId()) then
			table.insert(leaderboards, leaderboardComponent)
		end
	end

	return leaderboards
end

function LeaderboardService:_GetEntiresInTimedLeaderboard(leaderboardId, timeId)
	local timeString = self:GetTimeStringFromTimeId(timeId)
	if not timeString then
		return
	end

	local success, dataStorePages = pcall(function()
		local dataStore = DataStoreService:GetOrderedDataStore(leaderboardId .. CURRENT_DATASTORE_NAME_ENDING .. timeString)
		return dataStore:GetSortedAsync(false, 100)
	end)

	if not success then
		return
	end

	local currentPage = dataStorePages:GetCurrentPage()

	local leaderboards = self:_GetAllTimedLeaderboards(leaderboardId, timeId)
	for _, leaderboardComponent in pairs(leaderboards) do
		leaderboardComponent:Update(currentPage)
	end
end

-- leaderstats
function LeaderboardService:_UpdateLeaderstatsForPlayer(player)
	local leaderstatsFolder = player:FindFirstChild("leaderstats")
	if not leaderstatsFolder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "leaderstats"
		newFolder.Parent = player
		leaderstatsFolder = newFolder
	end

	local cashString = "💰 Cash"
	local cashValue = leaderstatsFolder:FindFirstChild(cashString)
	if not cashValue then
		local newStringValue = Instance.new("StringValue")
		newStringValue.Name = cashString
		newStringValue.Parent = leaderstatsFolder

		cashValue = newStringValue
	end

	local rebirthString = "🔁 Rebirths"
	local rebirthValue = leaderstatsFolder:FindFirstChild(rebirthString)
	if not rebirthValue then
		local newNumberValue = Instance.new("NumberValue")
		newNumberValue.Name = rebirthString
		newNumberValue.Parent = leaderstatsFolder

		rebirthValue = newNumberValue
	end

	local cash = self._PlayerStatsService:GetStatValueForPlayer(player, PlayerStatsEnum.Cash) or 0
	cashValue.Value = BigNumbers.GetNumberDisplay(cash)

	local rebirths = self._PlayerStatsService:GetStatValueForPlayer(player, PlayerStatsEnum.Rebirths) or 0
	rebirthValue.Value = rebirths
end

return LeaderboardService