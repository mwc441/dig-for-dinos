local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local External = ReplicatedStorage:WaitForChild("External")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local LeaderboardGui = Assets:WaitForChild("LeaderboardGui")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local Trove = require(External:WaitForChild("Trove"))
local BigNumbers = require(External:WaitForChild("BigNumbers"))
local Signal = require(External:WaitForChild("Signal"))
local Component = require(External:WaitForChild("Component"))
local EternityNum = require(External:WaitForChild("EternityNum"))

local Leaderboard = Component.new({
	Tag = "Leaderboard",
	Ancestors = { Workspace }
})

function Leaderboard:Construct()
	self.Instance = self.Instance :: Model

	self._LeaderboardKey = self.Instance:GetAttribute("Leaderboard")
	if not self._LeaderboardKey then
		print(self.Instance)
		error("No leaderboard attribute")
	end

	self._TimeId = self.Instance:GetAttribute("TimeId")

	self._UsernamesCache = {}
	self._ImagesCache = {}
	self._CurrentPage = nil

	self._Trove = Trove.new()

	self.Updated = Signal.new()
	self._Trove:Add(self.Updated)

	self:_CreateGui()
end

function Leaderboard:GetLeaderboardKey()
	return self._LeaderboardKey
end

function Leaderboard:GetTimeId()
	return self._TimeId
end

function Leaderboard:_CreateGui()
	local newLeaderboardGui = LeaderboardGui:Clone()
	newLeaderboardGui.Adornee = self.Instance.PrimaryPart
	newLeaderboardGui.Parent = self.Instance

	self._Trove:Add(newLeaderboardGui)

	self._LeaderboardGui = newLeaderboardGui
end

function Leaderboard:GetValueString(value)
	value = EternityNum.lbdecode(value)

	if self._LeaderboardKey == PlayerStatsEnum.RobuxSpent then
		return string.format("%s", EternityNum.short(value, 1))
	elseif self._LeaderboardKey == PlayerStatsEnum.TimePlayed then
		return UtilFunctions.GetTimeStringFromTime(EternityNum.toNumber(value))
	else
		return EternityNum.short(value)
	end
end

function Leaderboard:GetValueColor()
	if self._LeaderboardKey == PlayerStatsEnum.RobuxSpent then
		return ColorSequence.new(Color3.fromRGB(0, 255, 0))
	else
		return ColorSequence.new(Color3.fromRGB(255, 255, 255))
	end
end

function Leaderboard:GetRankForPlayer(player)
	if not self._CurrentPage then
		return
	end

	for rank, data in pairs(self._CurrentPage) do
		local userId = tonumber(data.key)

		if userId == player.UserId then
			return rank
		end
	end
end

function Leaderboard:GetValueForPlayer(player)
	if not self._CurrentPage then
		return
	end

	for _, data in pairs(self._CurrentPage) do
		local userId = tonumber(data.key)

		if userId == player.UserId then
			return data.value
		end
	end
end

function Leaderboard:Update(currentPage)
	self._CurrentPage = currentPage

	local leaderboardList = self._LeaderboardGui:WaitForChild("LeaderboardList"):WaitForChild("LeaderboardList")
	local templates = self._LeaderboardGui.Templates
	for _, template in pairs(leaderboardList:GetChildren()) do
		if template:IsA("Frame") then
			template:Destroy()
		end
	end

	for rank, data in pairs(currentPage) do
		task.spawn(function()
			local playerName = self._UsernamesCache[data.key]
			if not playerName then
				pcall(function()
					playerName = Players:GetNameFromUserIdAsync(data.key)
					self._UsernamesCache[data.key] = playerName
				end)

				if not playerName then
					return
				end
			end

			local playerImage = self._ImagesCache[data.key]
			if not playerImage then
				pcall(function()
					playerImage = Players:GetUserThumbnailAsync(data.key, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size352x352)
					self._ImagesCache[data.key] = playerImage
				end)

				if not playerImage then
					return
				end
			end

			local template = (rank < 4) and templates:FindFirstChild(tostring(rank)) or templates["4"]
			local newTemplate = template:Clone()
			newTemplate.LayoutOrder = rank
			newTemplate.PlayerImage.Image = playerImage or ""
			newTemplate.PlayerNameText.Text = playerName or ""
			newTemplate.PlaceText.Text = string.format("#%d", rank)

			newTemplate.ValueText.Text = self:GetValueString(data.value)
			newTemplate.ValueText.UIGradient.Color = self:GetValueColor()
			newTemplate.Visible = true
			newTemplate.Parent = leaderboardList
		end)
	end

	self.Updated:Fire()
end

function Leaderboard:Stop()
	self._Trove:Clean()
end

return Leaderboard