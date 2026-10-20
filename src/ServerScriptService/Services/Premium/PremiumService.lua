local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local BoostsEnum = require(Enums:WaitForChild("Boosts"))
local IapsEnum = require(Enums:WaitForChild("Iaps"))
local Knit = require(External:WaitForChild("Knit"))

local GAMEPASS_BOOSTS = {
	[IapsEnum.VIP] = {
		{
			BoostId = BoostsEnum.VIPCashBoost,
			Level = 1
		},

		{
			BoostId = BoostsEnum.VIPDigPowerBoost,
			Level = 1
		}
	},

	[IapsEnum.Cash2x] = {
		{
			BoostId = BoostsEnum.Cash2xBoost,
			Level = 1
		}
	},

	[IapsEnum.Cash4x] = {
		{
			BoostId = BoostsEnum.Cash2xBoost,
			Level = 2
		}
	},

	[IapsEnum.Cash8x] = {
		{
			BoostId = BoostsEnum.Cash2xBoost,
			Level = 3
		}
	},

	[IapsEnum.Cash16x] = {
		{
			BoostId = BoostsEnum.Cash2xBoost,
			Level = 4
		}
	},

	[IapsEnum.Cash32x] = {
		{
			BoostId = BoostsEnum.Cash2xBoost,
			Level = 5
		}
	},

	[IapsEnum.DigPower2x] = {
		{
			BoostId = BoostsEnum.DigPower2xBoost,
			Level = 1
		}
	}
}

local PremiumService = {
	Name = "PremiumService",
	Client = {},
	_BoostsService = nil,
	_ServerBoostsService = nil,
	_TimeService = nil,
	_IapService = nil,
	_RobloxPlusDetails = {}
}

function PremiumService:KnitStart()
	self._BoostsService = require(ServerScriptService.Services.Boosts.BoostsService)
	self._TimeService = require(ServerScriptService.Services.Time.TimeService)
	self._ServerBoostsService = require(ServerScriptService.Services.Boosts.ServerBoostsService)
	self._IapService = require(ServerScriptService.Services.Iaps.IapService)

	self._IapService.PlayerIapsUpdated:Connect(function(player)
		self:_UpdateGamepassesForPlayer(player)
	end)

	self._TimeService.TimeUpdatedSignal:Connect(function()
		for _, player in pairs(Players:GetPlayers()) do
			task.spawn(function()
				self:_UpdateRobloxPlus(player)
			end)
		end
	end)
end

function PremiumService:OnPlayerAdded(player: Player)
	task.spawn(function()
		self:_CheckForRobloxPlus(player)

		player:GetPropertyChangedSignal("HasRobloxSubscription"):Connect(function()
			self:_CheckForRobloxPlus(player)
		end)
	end)

	self:_UpdateGamepassesForPlayer(player)
end

function PremiumService:OnPlayerRemoving(player)
	self._BoostsService:RemoveBoostForPlayer(player, BoostsEnum.RobloxPlusBoost)
	self:_RemoveGamepassBoostsForPlayer(player)
	self._RobloxPlusDetails[player] = nil
end

function PremiumService:_CheckForRobloxPlus(player)
	local success
	local details
	local maxRetries = 5
	local retries = 0
	while not success do
		success, details = pcall(function()
			return MarketplaceService:GetRobloxSubscriptionDetailsAsync(player)
		end)

		if not Players:IsAncestorOf(player) then
			break
		end

		if not success then
			if retries >= maxRetries then
				break
			end

			retries += 1
			task.wait(1)
		end
	end
	if not success then return end
	if not Players:IsAncestorOf(player) then return end

	self._RobloxPlusDetails[player] = details

	self:_UpdateRobloxPlus(player)
end

function PremiumService:_UpdateRobloxPlus(player)
	local details = self._RobloxPlusDetails[player]
	if not details then return end

	if not details.IsSubscribed then
		self._BoostsService:RemoveBoostForPlayer(player, BoostsEnum.RobloxPlusBoost)
		return
	end

	local function giveBoost(level)
		local boost = self._BoostsService:GetBoostOfIdForPlayer(player, BoostsEnum.RobloxPlusBoost)
		if boost then
			self._BoostsService:UpdateBoostOfId(player, BoostsEnum.RobloxPlusBoost, {
				Level = level
			})
		else
			self._BoostsService:AddBoostForPlayer(player, {
				Id = BoostsEnum.RobloxPlusBoost,
				Level = level
			})
		end
	end

	if not details.IsOriginExperience then
		giveBoost(1)
	else
		local monthTime = 30 * 24 * 60 * 60
		local monthsSubscribed = math.floor((os.time() - details.StartTime.UnixTimestamp) / monthTime) + 1
		local maxLevel = 4

		-- Give players an extra level for every month they are subscribed (up until a max level of 4)
		-- All roblox plus players get level 1, and then roblox plus subscribers that subscribed in our game
		-- get further levels for subscribing in our game. The first month level 2, second month level 3,
		-- and third month level 4
		giveBoost(math.min(1 + monthsSubscribed, maxLevel))
	end
end

-- GAMEPASS CODE
function PremiumService:_GiveBoostToPlayer(player, boostId, level)
	level = level or 1

	local boost = self._BoostsService:GetBoostOfIdForPlayer(player, boostId)
	if not boost then
		self._BoostsService:AddBoostForPlayer(player, {
			Id = boostId,
			Level = level
		})
	elseif boost.Level ~= level then
		self._BoostsService:UpdateBoostOfId(player, boostId, {
			Level = level
		})
	end
end

function PremiumService:_UpdateGamepassesForPlayer(player)
	local levelsByBoostId = {}
	for iapId, boosts in pairs(GAMEPASS_BOOSTS) do
		local ownsIap = self._IapService:PlayerOwnsProduct(player, iapId)
		for _, boostInfo in ipairs(boosts) do
			local boostId = boostInfo.BoostId
			local level = ownsIap and (boostInfo.Level or 1) or 0
			levelsByBoostId[boostId] = math.max(levelsByBoostId[boostId] or 0, level)
		end
	end

	for boostId, level in pairs(levelsByBoostId) do
		if level > 0 then
			self:_GiveBoostToPlayer(player, boostId, level)
		else
			self._BoostsService:RemoveBoostForPlayer(player, boostId)
		end
	end

	if self._IapService:PlayerOwnsProduct(player, IapsEnum.VIP) then
		player:SetAttribute("Vip", true)
	end
end

function PremiumService:_RemoveGamepassBoostsForPlayer(player)
	for _, boosts in pairs(GAMEPASS_BOOSTS) do
		for _, boostInfo in ipairs(boosts) do
			self._BoostsService:RemoveBoostForPlayer(player, boostInfo.BoostId)
		end
	end
end

return PremiumService
