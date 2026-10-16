local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Knit = require(External:WaitForChild("Knit"))

local TAG_FORMATS = {
	RobuxSpent = "<font color=\"#07fc03\"></font>#%d", -- TODO: Update these
	Cash = "💸#%d",
	Rebirths = "🔁#%d",
	DigPower = "💪#%d"
}

local LeaderboardController = {
	Name = "LeaderboardController",
	_LeaderboardService = nil,
	_LeaderboardRanks = {}
}

function LeaderboardController:KnitStart()
	self._LeaderboardService = Knit.GetService("LeaderboardService")

	self._LeaderboardService.PlayerLeaderboardRanks:Observe(function(ranks)
		self._LeaderboardRanks = ranks or {}
	end)
end

function LeaderboardController:GetChatTagsForPlayer(player)
	local ranks = self._LeaderboardRanks[tostring(player.UserId)] or {}

	local chatTagString = ""
	for leaderboardId, format in pairs(TAG_FORMATS) do
		local leaderboardIdTable = ranks[leaderboardId]
		if not leaderboardIdTable then continue end

		local rank = leaderboardIdTable.All
		if not rank then continue end

		local chatColor = "#5a5a5a"
		if rank == 1 then
			chatColor = "#ffd322"
		elseif rank == 2 then
			chatColor = "#c2c2c2"
		elseif rank == 3 then
			chatColor = "#93661e"
		end

		chatTagString ..= string.format("<font color=\"%s\">[%s]</font>", chatColor, string.format(format, rank))
	end

	return chatTagString
end

return LeaderboardController