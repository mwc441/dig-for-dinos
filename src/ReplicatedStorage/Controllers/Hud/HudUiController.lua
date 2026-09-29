local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local BigNumbers = require(External:WaitForChild("BigNumbers"))
local GuiButton = require(GuiModules:WaitForChild("Button"))
local CountingText = require(GuiModules:WaitForChild("CountingText"))
local GuiObject = require(GuiModules:WaitForChild("Object"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local Trove = require(External:WaitForChild("Trove"))
local Knit = require(External:WaitForChild("Knit"))

local HudUiController = {
	Name = "HudUiController",
	_PlayerStatsController = nil,
	_Cash = nil,
}

function HudUiController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local hud = mainGui:WaitForChild("Hud")
	local cashFrame = hud:WaitForChild("CashFrame")

	self._Gui = {
		CashFrame = cashFrame,
		CashPlusButton = cashFrame:WaitForChild("PlusButton"),
		CashTemplate = cashFrame:WaitForChild("Templates"):WaitForChild("CashTemplate")
	}
	self._Gui.CashTemplate.Visible = false

	local amountFrame = cashFrame:WaitForChild("AmountFrame")
	self._CashAmountText = CountingText.new(amountFrame:WaitForChild("AmountText"))
	self._CashDarkAmountText = CountingText.new(amountFrame:WaitForChild("DarkAmountText"))
	self._CashGuiObject = GuiObject.new(cashFrame)
	self._CashShadowTrove = Trove.new()

	local cashPlusButton = GuiButton.new(self._Gui.CashPlusButton)
	cashPlusButton:SetCallback(function()
		-- TODO: Cash iaps
	end)
end

function HudUiController:KnitStart()
	self._PlayerStatsController = require(ReplicatedStorage.Controllers.PlayerStats.PlayerStatsController)

	self._PlayerStatsController.StatsUpdatedSignal:Connect(function()
		self:_UpdateUi()
	end)

	self:_UpdateUi()
end

function HudUiController:_UpdateUi()
	self:_UpdateCashFrame()
end

function HudUiController:_UpdateCashFrame()
	local cash = self._PlayerStatsController:GetStatValue(PlayerStatsEnum.Cash) or 0

	if self._Cash == nil then
		self._Cash = cash
		self._CashAmountText:Set(cash)
		self._CashDarkAmountText:Set(cash)
		return
	end

	if cash > self._Cash then
		self:_PulseCashShadows()
		self._CashGuiObject:MakeThrob(1.1, 0.3)
		self:_ShowCashEarned(cash - self._Cash)
	end

	self._CashAmountText:Animate(cash)
	self._CashDarkAmountText:Animate(cash)
	self._Cash = cash
end

function HudUiController:_PulseCashShadows()
	self._CashShadowTrove:Clean()

	local fadeInInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fadeOutInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	for _, shadow in ipairs(self._Gui.CashFrame:QueryDescendants("UIShadow")) do
		shadow.Transparency = 1

		local fadeInTween = TweenService:Create(shadow, fadeInInfo, {
			Transparency = 0.2
		})
		local fadeOutTween = TweenService:Create(shadow, fadeOutInfo, {
			Transparency = 1
		})

		self._CashShadowTrove:Add(fadeInTween)
		self._CashShadowTrove:Add(fadeOutTween)
		self._CashShadowTrove:Connect(fadeInTween.Completed, function(playbackState)
			if playbackState == Enum.PlaybackState.Completed then
				fadeOutTween:Play()
			end
		end)

		fadeInTween:Play()
	end
end

function HudUiController:_ShowCashEarned(amount)
	local cashFrame = self._Gui.CashFrame
	local cashTemplate = self._Gui.CashTemplate:Clone()
	cashTemplate.Text = string.format("+%s", BigNumbers.GetNumberDisplay(amount))
	cashTemplate.Visible = true
	cashTemplate.Parent = cashFrame.Parent

	local parent = cashFrame.Parent :: GuiObject
	local originalSize = cashTemplate.Size
	local guiInset = GuiService:GetGuiInset()
	local cashFramePosition = cashFrame.AbsolutePosition - guiInset
	local parentPosition = parent.AbsolutePosition - guiInset
	local cashFrameCenterX = cashFramePosition.X + (cashFrame.AbsoluteSize.X / 2)
	local cashTemplateCenterY = cashFramePosition.Y
	cashTemplate.Position = UDim2.fromOffset(
		cashFrameCenterX - parentPosition.X,
		cashTemplateCenterY - parentPosition.Y
	)
	cashTemplate.Size = UDim2.fromScale(0, 0)

	local startPosition = cashTemplate.Position
	local growTween = TweenService:Create(cashTemplate, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = originalSize
	})
	local moveTween = TweenService:Create(cashTemplate, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = startPosition + UDim2.fromOffset(0, -35)
	})

	growTween:Play()
	moveTween:Play()
	moveTween.Completed:Once(function(playbackState)
		if playbackState ~= Enum.PlaybackState.Completed then
			cashTemplate:Destroy()
			return
		end

		local shrinkTween = TweenService:Create(cashTemplate, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.fromScale(0, 0)
		})

		shrinkTween:Play()
		shrinkTween.Completed:Once(function()
			cashTemplate:Destroy()
		end)
	end)
end

return HudUiController
