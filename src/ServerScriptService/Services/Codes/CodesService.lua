local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local ServerConfigs = ServerScriptService:WaitForChild("ServerConfigs")
local CodesDef = require(ServerConfigs:WaitForChild("CodesDef"))
local DataKeys = require(ServerConfigs:WaitForChild("DataKeys"))
local Knit = require(External:WaitForChild("Knit"))

local CODE_EXPIRED_MESSAGE = "❌ Code expired!"
local CODE_EXPIRED_COLOR = Color3.fromRGB(255, 255, 255)
local CODE_ALREADY_REDEEMED_MESSAGE = "❌ Code already redeemed!"
local CODE_ALREADY_REDEEMED_COLOR = Color3.fromRGB(255, 255, 255)
local CODE_DOESNT_EXIST_MESSAGE = "❌ Code doesn't exist"
local CODE_DOESNT_EXIST_COLOR = Color3.fromRGB(255, 255, 255)
local CODE_REDEEMED_MESSAGE = "🎉 Code redeemed!"
local CODE_REDEEMED_COLOR = Color3.fromRGB(255, 255, 255)
local CODES_KEY = DataKeys.Codes
local CODES_DEFAULT_DATA = {
	Version = 1,
	CodesRedeemed = {}
}

local CodesService = {
	Name = "CodesService",
	Client = {},
	_DataService = nil,
	_RewardsService = nil,
	_AnalyticsService = nil
}

function CodesService:KnitStart()
	self._DataService = require(ServerScriptService.Services.Data.DataService)
	self._RewardsService = require(ServerScriptService.Services.Rewards.RewardsService)
	self._AnalyticsService = require(ServerScriptService.Services.Analytics.AnalyticsService)
end

function CodesService:_SubmitCodeForPlayer(player, code)
	local codeInfo = CodesDef.GetCodeInfoFromCode(code)
	if not codeInfo then
		self._RewardsService:AnnounceMessageToPlayer(player, CODE_DOESNT_EXIST_MESSAGE, CODE_DOESNT_EXIST_COLOR)
		return
	end

	if codeInfo.StartTime then
		if os.time() < codeInfo.StartTime then
			self._RewardsService:AnnounceMessageToPlayer(player, CODE_DOESNT_EXIST_MESSAGE, CODE_DOESNT_EXIST_COLOR)
			return
		end
	end

	if codeInfo.ExpiryTime then
		if os.time() >= codeInfo.ExpiryTime then
			self._RewardsService:AnnounceMessageToPlayer(player, CODE_EXPIRED_MESSAGE, CODE_EXPIRED_COLOR)
			return
		end
	end

	code = codeInfo.Code

	local playerCodeData = self._DataService:GetPlayerData(player, CODES_KEY, CODES_DEFAULT_DATA)
	if table.find(playerCodeData.CodesRedeemed, code) then
		self._RewardsService:AnnounceMessageToPlayer(player, CODE_ALREADY_REDEEMED_MESSAGE, CODE_ALREADY_REDEEMED_COLOR)
		return
	end

	table.insert(playerCodeData.CodesRedeemed, code)

	self._DataService:SetPlayerData(player, CODES_KEY, playerCodeData)

	self._RewardsService:AnnounceMessageToPlayer(player, CODE_REDEEMED_MESSAGE, CODE_REDEEMED_COLOR)

	for rewardType, reward in pairs(codeInfo.Rewards or {}) do
		self._RewardsService:RewardPlayer(player, rewardType, reward, true, {
			TransactionType = Enum.AnalyticsEconomyTransactionType.TimedReward.Name
		})
	end

	self._AnalyticsService:LogCustomEvent(player, "CodeRedeemed", 1, {
		[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = "Code - " .. code
	})

	return true
end

function CodesService.Client:SubmitCode(player, code)
	if type(code) ~= "string" then return end

	return self.Server:_SubmitCodeForPlayer(player, code)
end

return CodesService