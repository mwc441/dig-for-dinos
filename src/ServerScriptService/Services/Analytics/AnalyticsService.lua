local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxAnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local TableUtils = require(External:WaitForChild("TableUtils"))
local Knit = require(External:WaitForChild("Knit"))

local QUEUE_PROCESS_TIME = 60 / 20 -- analytics service limit
local PLAYER_ANALYTICS_QUEUE_TABLE = {
	LastSent = 0,
	Queue = {}
}

local AnalyticsService = {
	Name = "AnalyticsService",
	Client = {},
	_PlayerQueueTables = {}
}

function AnalyticsService:KnitStart()
	self:_SetupQueueHeartbeat()

	game:BindToClose(function()
		for player, playerQueueTable in pairs(self._PlayerQueueTables) do
			for _, queueItem in pairs(playerQueueTable.Queue) do
				self:_ProcessQueueItemForPlayer(player, queueItem)
			end
		end
		self._PlayerQueueTables = {}
	end)
end

function AnalyticsService:GetPlayerQueueTable(player)
	local playerQueueTable = self._PlayerQueueTables[player]
	if not playerQueueTable and Players:IsAncestorOf(player) then
		self._PlayerQueueTables[player] = TableUtils.Copy(PLAYER_ANALYTICS_QUEUE_TABLE)

		playerQueueTable = self._PlayerQueueTables[player]
	end

	return playerQueueTable
end

function AnalyticsService:_SetupQueueHeartbeat()
	RunService.Heartbeat:Connect(function()
		local queueTables = {}
		for player, queueTable in pairs(self._PlayerQueueTables) do
			queueTables[player] = queueTable
		end

		for player in pairs(queueTables) do
			task.spawn(function()
				self:_ProcessPlayerQueue(player)
			end)
		end
	end)
end

function AnalyticsService:_ProcessPlayerQueue(player)
	local playerQueue = self:GetPlayerQueueTable(player)
	if not playerQueue then
		return
	end

	local queue = playerQueue.Queue
	if #queue <= 0 then
		if not Players:IsAncestorOf(player) then
			self._PlayerQueueTables[player] = nil
		end

		return
	end

	if not (os.clock() >= (playerQueue.LastSent + QUEUE_PROCESS_TIME)) then
		return
	end

	playerQueue.LastSent = os.clock()

	local queueItem = table.remove(queue, 1)

	self:_ProcessQueueItemForPlayer(player, queueItem)
end

function AnalyticsService:_AddToPlayerQueue(player, queueItem)
	local playerQueue = self:GetPlayerQueueTable(player)
	if not playerQueue then
		return
	end

	if not Players:IsAncestorOf(player) then
		return
	end

	table.insert(playerQueue.Queue, queueItem)

	if Constants.LogAnalyticsIncomingEvents and RunService:IsStudio() then
		local playerQueueTable = self:GetPlayerQueueTable(player)
		print("[INCOMING] " .. (queueItem.EventName or queueItem.Type) .. " Adding Analytic Event (" .. tostring(#playerQueueTable.Queue) .. " items in queue)", queueItem)
	end
end

function AnalyticsService:_ProcessQueueItemForPlayer(player, queueItem)
	if queueItem.CustomFields then
		for customFieldKey, customFieldValue in pairs(queueItem.CustomFields) do
			if type(customFieldValue) ~= "string" then
				continue
			end

			local s = customFieldValue
			s = string.gsub(s, ",", "")
			s = string.gsub(s, "\'", "")
			s = string.gsub(s, "\"", "")
			queueItem.CustomFields[customFieldKey] = s
		end
	end

	if Constants.LogAnalyticsOutgoingEvents and RunService:IsStudio() then
		local playerQueueTable = self:GetPlayerQueueTable(player)
		print("[OUTGOING] " .. (queueItem.EventName or queueItem.Type) .. " Analytic Event Sending (" .. tostring(#playerQueueTable.Queue) .. " items left in queue)", queueItem)
	end

	-- Send to analytics service
	local success, errorMessage
	if queueItem.Type == "EconomyEvent" then
		success, errorMessage = pcall(function()
			RobloxAnalyticsService:LogEconomyEvent(player,
				queueItem.FlowType,
				queueItem.CurrencyType,
				queueItem.Amount,
				queueItem.EndingBalance,
				queueItem.TransactionType,
				queueItem.ItemSku,
				queueItem.CustomFields
			)
		end)
	elseif queueItem.Type == "CustomEvent" then
		success, errorMessage = pcall(function()
			RobloxAnalyticsService:LogCustomEvent(player,
				queueItem.EventName,
				queueItem.Value,
				queueItem.CustomFields
			)
		end)
	elseif queueItem.Type == "FunnelEvent" then
		success, errorMessage = pcall(function()
			RobloxAnalyticsService:LogFunnelStepEvent(player,
				queueItem.FunnelName,
				queueItem.FunnelSessionId,
				queueItem.Step,
				queueItem.StepName,
				queueItem.CustomFields
			)
		end)
	elseif queueItem.Type == "OnboardingFunnelEvent" then
		success, errorMessage = pcall(function()
			RobloxAnalyticsService:LogOnboardingFunnelStepEvent(player,
				queueItem.Step,
				queueItem.StepName,
				queueItem.CustomFields
			)
		end)
	end

	if not success then
		warn(errorMessage)
	end
end

function AnalyticsService:LogEconomyEvent(player, flowType, currencyType, amount, endingBalance, transactionType, itemSku, customFields)
	local playerQueue = self:GetPlayerQueueTable(player)
	if not playerQueue then
		return
	end

	local queue = playerQueue.Queue
	local similarItem
	for _, queueItem in pairs(queue) do
		if queueItem.Type == "EconomyEvent" then
			if queueItem.FlowType == flowType and queueItem.CurrencyType == currencyType and queueItem.TransactionType == transactionType and queueItem.ItemSku == itemSku and TableUtils.Equals(customFields, queueItem.CustomFields) then
				similarItem = queueItem
				break
			end
		end
	end

	if similarItem then
		similarItem.Amount = similarItem.Amount + amount
		similarItem.EndingBalance = endingBalance
	else
		self:_AddToPlayerQueue(player, {
			Type = "EconomyEvent",
			FlowType = flowType,
			CurrencyType = currencyType,
			Amount = amount,
			EndingBalance = endingBalance,
			TransactionType = transactionType,
			ItemSku = itemSku,
			CustomFields = customFields
		})
	end
end

function AnalyticsService:LogCustomEvent(player, eventName, value, customFields)
	local playerQueue = self:GetPlayerQueueTable(player)
	if not playerQueue then
		return
	end

	local queue = playerQueue.Queue
	local similarItem
	for _, queueItem in pairs(queue) do
		if queueItem.Type ~= "CustomEvent" then
			continue
		end

		if queueItem.EventName ~= eventName then
			continue
		end

		local itemCustomFields = queueItem.CustomFields
		if TableUtils.Equals(itemCustomFields, customFields) then
			similarItem = queueItem
			break
		end
	end

	if similarItem then
		similarItem.Value = similarItem.Value + value
	else
		self:_AddToPlayerQueue(player, {
			Type = "CustomEvent",
			EventName = eventName,
			Value = value,
			CustomFields = customFields
		})
	end
end

function AnalyticsService:LogFunnelStepEvent(player, funnelName, funnelSessionId, step, stepName, customFields)
	self:_AddToPlayerQueue(player, {
		Type = "FunnelEvent",
		FunnelName = funnelName,
		FunnelSessionId = funnelSessionId,
		Step = step,
		StepName = stepName,
		CustomFields = customFields
	})
end

function AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName, customFields)
	self:_AddToPlayerQueue(player, {
		Type = "OnboardingFunnelEvent",
		Step = step,
		StepName = stepName,
		CustomFields = customFields
	})
end

return AnalyticsService