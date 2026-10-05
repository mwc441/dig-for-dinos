local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local Signal = require(External:WaitForChild("Signal"))
local Knit = require(External:WaitForChild("Knit"))

local LifecycleService = {
	Name = "LifecycleService",
	Client = {},
	_DataService = nil,
	_PlayerStatsService = nil,
	_IapService = nil,
	_PolicyService = nil,
	_FriendsService = nil,
	_BoostsService = nil,
	_ServerBoostsService = nil,
	_CharacterService = nil,
	_InventoryService = nil,
	_EquipService = nil,
	_DigService = nil,
	_BonePileService = nil,
	_TimerService = nil,
	_LeaderboardService = nil,
	_AdminService = nil,
	_PremiumService = nil,
	_RewardsService = nil,
	_OrbService = nil,
	_TutorialService = nil,
	_PlotService = nil,
	_DinosaurService = nil,
	_RebirthService = nil,
	_InitializedPlayers = {},
	PlayerHasFullyInitialized = Signal.new()
}

function LifecycleService:KnitStart()
	self._DataService = require(ServerScriptService.Services.Data.DataService)
	self._PlayerStatsService = require(ServerScriptService.Services.PlayerStats.PlayerStatsService)
	self._IapService = require(ServerScriptService.Services.Iaps.IapService)
	self._PolicyService = require(ServerScriptService.Services.Policy.PolicyService)
	self._FriendsService = require(ServerScriptService.Services.Friends.FriendsService)
	self._BoostsService = require(ServerScriptService.Services.Boosts.BoostsService)
	self._ServerBoostsService = require(ServerScriptService.Services.Boosts.ServerBoostsService)
	self._CharacterService = require(ServerScriptService.Services.Character.CharacterService)
	self._InventoryService = require(ServerScriptService.Services.Inventory.InventoryService)
	self._EquipService = require(ServerScriptService.Services.Equips.EquipService)
	self._DigService = require(ServerScriptService.Services.Digging.DigService)
	self._BonePileService = require(ServerScriptService.Services.Digging.BonePileService)
	self._TimerService = require(ServerScriptService.Services.Timers.TimerService)
	self._LeaderboardService = require(ServerScriptService.Services.Leaderboards.LeaderboardService)
	self._AdminService = require(ServerScriptService.Services.Admin.AdminService)
	self._PremiumService = require(ServerScriptService.Services.Premium.PremiumService)
	self._RewardsService = require(ServerScriptService.Services.Rewards.RewardsService)
	self._OrbService = require(ServerScriptService.Services.Orbs.OrbService)
	self._TutorialService = require(ServerScriptService.Services.Tutorial.TutorialService)
	self._PlotService = require(ServerScriptService.Services.Plots.PlotService)
	self._DinosaurService = require(ServerScriptService.Services.Dinosaurs.DinosaurService)
	self._RebirthService = require(ServerScriptService.Services.Rebirths.RebirthService)

	task.defer(function()
		Players.PlayerAdded:Connect(function(player)
			self:_PlayerAdded(player)
		end)

		Players.PlayerRemoving:Connect(function(player)
			self:_PlayerRemoving(player)
		end)

		for _, player in pairs(Players:GetPlayers()) do
			task.spawn(function()
				self:_PlayerAdded(player)
			end)
		end
	end)
end

function LifecycleService:IsPlayerInitialized(player)
	return self._InitializedPlayers[player]
end

function LifecycleService:GetInitializedPlayers()
	local players = {}
	for player in pairs(self._InitializedPlayers) do
		table.insert(players, player)
	end

	return players
end

function LifecycleService:_PlayerAdded(player)
	self._DataService:OnPlayerAdded(player) -- Keep on top!

	if not player:IsDescendantOf(Players) or (not self._DataService:GetPlayerProfile(player)) then
		-- Player left before data could load or player profile couldn't be loaded
		return
	end

	self._InventoryService:OnPlayerAdded(player) -- Keep on top of others
	self._RebirthService:OnPlayerAdded(player)
	self._BonePileService:OnPlayerAdded(player)
	self._EquipService:OnPlayerAdded(player)
	self._DigService:OnPlayerAdded(player)
	self._PlayerStatsService:OnPlayerAdded(player)
	self._PolicyService:OnPlayerAdded(player)
	self._IapService:OnPlayerAdded(player)
	self._FriendsService:OnPlayerAdded(player)
	self._BoostsService:OnPlayerAdded(player)
	self._ServerBoostsService:OnPlayerAdded(player)
	self._CharacterService:OnPlayerAdded(player)
	self._LeaderboardService:OnPlayerAdded(player)
	self._AdminService:OnPlayerAdded(player)
	self._PremiumService:OnPlayerAdded(player)
	self._RewardsService:OnPlayerAdded(player)
	self._OrbService:OnPlayerAdded(player)
	self._TutorialService:OnPlayerAdded(player)
	self._TimerService:OnPlayerAdded(player)
	self._PlotService:OnPlayerAdded(player)
	self._DinosaurService:OnPlayerAdded(player)

	if Players:IsAncestorOf(player) then
		self._InitializedPlayers[player] = true

		self.PlayerHasFullyInitialized:Fire(player)
	end
end

function LifecycleService:_PlayerRemoving(player)
	self._InitializedPlayers[player] = nil

	self._IapService:OnPlayerRemoving(player)
	self._PolicyService:OnPlayerRemoving(player)
	self._FriendsService:OnPlayerRemoving(player)
	self._ServerBoostsService:OnPlayerRemoving(player)
	self._BonePileService:OnPlayerRemoving(player)
	self._CharacterService:OnPlayerRemoving(player)
	self._DigService:OnPlayerRemoving(player)
	self._TimerService:OnPlayerRemoving(player)
	self._LeaderboardService:OnPlayerRemoving(player)
	self._PremiumService:OnPlayerRemoving(player)
	self._OrbService:OnPlayerRemoving(player)
	self._TutorialService:OnPlayerRemoving(player)
	self._DinosaurService:OnPlayerRemoving(player)
	self._PlotService:OnPlayerRemoving(player)
	self._InventoryService:OnPlayerRemoving(player) -- Keep below others

	self._DataService:OnPlayerRemoving(player) -- Keep at bottom
end

return LifecycleService
