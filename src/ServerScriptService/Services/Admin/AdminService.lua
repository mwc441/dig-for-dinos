local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local Cmdr = require(External:WaitForChild("Cmdr"))
local Knit = require(External:WaitForChild("Knit"))

local AdminService = {
	Name = "AdminService",
	Client = {},
	_DebugService = nil,
}

function AdminService:KnitInit()
	script.Parent.AdminClient.Enabled = false

	local commandsToRemove = { "announce" }
	Cmdr:RegisterDefaultCommands(function(cmd)
		if table.find(commandsToRemove, cmd.Name) then
			return false
		else
			return true
		end
	end)

	Cmdr:RegisterCommandsIn(script.Parent.Commands)

	Cmdr:RegisterTypesIn(script.Parent.Types)

	Cmdr:RegisterHook("BeforeRun", function(context)
		local player = context.Executor

		if not self:IsPlayerAdmin(player) then
			return "Not admin sorry!"
		end
	end)
end

function AdminService:KnitStart()
	self._DebugService = require(ServerScriptService.Services.Debug.DebugService)
end

function AdminService:OnPlayerAdded(player: Player)
	if self:IsPlayerAdmin(player) then
		local newClientScript = script.Parent.AdminClient:Clone()
		newClientScript.Parent = player.PlayerGui
		newClientScript.Enabled = true
	end
end

function AdminService:IsPlayerAdmin(player)
	local highestRank = UtilFunctions.GetHighestGroupRankForPlayer(player, Constants.GroupId)

	if highestRank then
		local rankInfo = Constants.GroupRanks[highestRank]
		if rankInfo then
			return rankInfo.IsAdmin
		end
	end
end

return AdminService