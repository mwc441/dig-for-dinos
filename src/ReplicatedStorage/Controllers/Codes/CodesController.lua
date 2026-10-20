local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local CodeSuccessSound = Sounds:WaitForChild("CodeSuccess")
local ErrorSound = Sounds:WaitForChild("Error")
local External = ReplicatedStorage:WaitForChild("External")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local GuiButton = require(GuiModules:WaitForChild("Button"))
local Knit = require(External:WaitForChild("Knit"))

local CodesController = {
	Name = "CodesController",
	_CodesService = nil
}

function CodesController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local premiumShopFrame = mainGui:WaitForChild("PremiumShopFrame")
	local codesFrame = premiumShopFrame:WaitForChild("IapList"):WaitForChild("IapList"):WaitForChild("CodesFrame")

	self._Gui = {
		Frame = codesFrame,
		CodeBox = codesFrame:WaitForChild("CodeBox") :: TextBox,
		EnterButton = codesFrame:WaitForChild("EnterButton")
	}

	local enterButton = GuiButton.new(self._Gui.EnterButton)
	enterButton:SetCallback(function()
		self:_SubmitCode()
	end)

	self._Gui.CodeBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			self:_SubmitCode()
		end
	end)
end

function CodesController:KnitStart()
	self._CodesService = Knit.GetService("CodesService")
end

function CodesController:_SubmitCode()
	local code = self._Gui.CodeBox.Text
	if code == "" then return end

	self._Gui.CodeBox.Text = ""

	self._CodesService:SubmitCode(code):andThen(function(success)
		if success then
			CodeSuccessSound:Play()
		else
			ErrorSound:Play()
		end
	end)
end

return CodesController