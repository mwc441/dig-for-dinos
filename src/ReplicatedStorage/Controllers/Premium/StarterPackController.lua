local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local IapsEnum = require(Enums:WaitForChild("Iaps"))
local GuiButton = require(GuiModules:WaitForChild("Button"))
local GuiObject = require(GuiModules:WaitForChild("Object"))
local Knit = require(External:WaitForChild("Knit"))

local StarterPackController = {
	Name = "StarterPackController",
	_HudController = nil,
	_IapController = nil,
}

function StarterPackController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local hud = mainGui:WaitForChild("Hud")
	local starterPackFrame = mainGui:WaitForChild("StarterPackFrame")

	self._Gui = {
		Frame = starterPackFrame,
		RobuxButton = starterPackFrame:WaitForChild("BuyButtons"):WaitForChild("Robux"),
		GiftButton = starterPackFrame:WaitForChild("BuyButtons"):WaitForChild("Gift"),
		StarterPackButton = hud:WaitForChild("StarterPackButton"),
		ExitButton = starterPackFrame:WaitForChild("ExitButton")
	}
	self:_SetFlipbooksEnabled(self._Gui.Frame.Visible)

	local starterPackButton = GuiButton.new(self._Gui.StarterPackButton)
	starterPackButton:SetCallback(function()
		self:SetVisibility(not self._Gui.Frame.Visible, true)
	end)

	local exitButton = GuiButton.new(self._Gui.ExitButton)
	exitButton:SetCallback(function()
		self:SetVisibility(false, true)
	end)

	local robuxButton = GuiButton.new(self._Gui.RobuxButton)
	robuxButton:SetCallback(function()
		self._IapController:PurchaseIap(IapsEnum.StarterPack)
	end)
	robuxButton:SetMakeShineWhenHovered(true)

	local giftButton = GuiButton.new(self._Gui.GiftButton)
	giftButton:SetCallback(function()
		self._IapController:GiftIap(IapsEnum.StarterPack)
	end)
	giftButton:SetMakeShineWhenHovered(true)

	self._GamepassTextObject = GuiObject.new(self._Gui.Frame.Items.Gamepass.Gamepass)
	self._TitleTextObject = GuiObject.new(self._Gui.StarterPackButton.TitleText)
end

function StarterPackController:KnitStart()
	self._HudController = require(ReplicatedStorage.Controllers.Hud.HudController)
	self._IapController = require(ReplicatedStorage.Controllers.Iaps.IapController)

	self._IapController.IapCacheChanged:Connect(function()
		self:_UpdateUi()
	end)

	self._IapController.IapsUpdatedSignal:Connect(function()
		self:_UpdateUi()
	end)

	self:_UpdateUi()
end

function StarterPackController:SetVisibility(visible, toTween)
	local hideTrack = require(self._Gui.Frame.Animator).Hide
	local openTrack = require(self._Gui.Frame.Animator).Open

	if visible then
		self._Gui.Frame.Visible = visible
		self._GamepassTextObject:MakeRainbow()
		self:_SetFlipbooksEnabled(true)
		self._HudController:SetCurrentlyActiveFrame(self)

		hideTrack:Stop()
		self._Hiding = false
		openTrack:Play()
	else
		self:_SetFlipbooksEnabled(false)

		local function clear()
			self._Gui.Frame.Visible = visible
			self._HudController:ClearCurrentlyActiveFrame(self)
			self._GamepassTextObject:StopRainbow()
		end

		if toTween then
			if self._Hiding then return end

			self._Hiding = true
			hideTrack:Play()
			hideTrack.Completed:Once(function()
				self._Hiding = false
				clear()
			end)
		else
			clear()
		end
	end
end

function StarterPackController:_SetFlipbooksEnabled(enabled)
	for _, descendant in pairs(self._Gui.Frame:QueryDescendants(".2dFlipbook")) do
		descendant:SetAttribute("FlipbookEnabled", enabled)
	end
end

function StarterPackController:_SetStarterPackButtonVisible(visible)
	self._Gui.StarterPackButton.Visible = visible
	if self._StarterPackButtonVisible == visible then
		return
	end

	self._StarterPackButtonVisible = visible

	if visible then
		self._TitleTextObject:MakeRainbow()
	else
		self._TitleTextObject:StopRainbow()
	end
end

function StarterPackController:_UpdateUi()
	local price = self._IapController:GetPriceOfIap(IapsEnum.StarterPack) or 0
	self._Gui.RobuxButton.PriceText.Text = tonumber(price)

	local ownsStarterPack = self._IapController:OwnsIap(IapsEnum.StarterPack)
	self:_SetStarterPackButtonVisible(not ownsStarterPack)

	if self._Gui.Frame.Visible and ownsStarterPack then
		self:SetVisibility(false, true)
	end
end

return StarterPackController
