local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local ErrorSound = Sounds:WaitForChild("Error")
local PurchaseSound = Sounds:WaitForChild("Purchase")
local EquipSound = Sounds:WaitForChild("EquipSound")
local External = ReplicatedStorage:WaitForChild("External")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Components = ReplicatedStorage:WaitForChild("Components")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local ItemDef = require(ReplicatedConfigs:WaitForChild("ItemDef"))
local GuiButton = require(GuiModules:WaitForChild("Button"))
local GuiObject = require(GuiModules:WaitForChild("Object"))
local Knit = require(External:WaitForChild("Knit"))
local BigNumbers = require(External:WaitForChild("BigNumbers"))

local ShovelUiController = {
	Name = "ShovelUiController",
	_HudController = nil,
	_EquipController = nil,
	_InventoryController = nil,
	_RewardsController = nil,
	_DigService = nil
}

function ShovelUiController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local shovelsFrame = mainGui:WaitForChild("ShovelsFrame")

	self._Gui = {
		MainGui = mainGui,
		Frame = shovelsFrame,
		ShovelTemplate = shovelsFrame:WaitForChild("Templates"):WaitForChild("ShovelTemplate"),
		ShovelList = shovelsFrame:WaitForChild("ShovelList"):WaitForChild("ShovelList"),
		ExitButton = shovelsFrame:WaitForChild("ExitButton")
	}

	local exitButton = GuiButton.new(self._Gui.ExitButton)
	exitButton:SetCallback(function()
		self:SetVisibility(false, true)
	end)
end

function ShovelUiController:KnitStart()
	self._HudController = require(ReplicatedStorage.Controllers.Hud.HudController)
	self._EquipController = require(ReplicatedStorage.Controllers.Equips.EquipController)
	self._InventoryController = require(ReplicatedStorage.Controllers.Inventory.InventoryController)
	self._RewardsController = require(ReplicatedStorage.Controllers.Rewards.RewardsController)
	self._ShovelStoreComponent = require(Components.ShovelStore)
	self._DigService = Knit.GetService("DigService")

	self._EquipController.EquipsUpdatedSignal:Connect(function()
		self:_UpdateUi()
	end)

	self._InventoryController.InventoryUpdatedSignal:Connect(function()
		self:_UpdateUi()
	end)

	self:_SetupUi()

	self:_SetupShovelStores()
end

function ShovelUiController:SetVisibility(visible, toTween)
	local hideTrack = require(self._Gui.Frame.Animator).Hide
	local openTrack = require(self._Gui.Frame.Animator).Open

	if visible then
		self._Gui.Frame.Visible = visible
		self._HudController:SetCurrentlyActiveFrame(self)
		hideTrack:Stop()
		self._Hiding = false
		openTrack:Play()
	else
		local function clear()
			self._Gui.Frame.Visible = visible
			self._HudController:ClearCurrentlyActiveFrame(self)
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

function ShovelUiController:_SetupUi()
	local shovels = ItemDef.GetItemsOfCategory(ItemDef.Categories.Shovel)
	local shovelsSorted = {}
	for shovelId, info in pairs(shovels) do
		table.insert(shovelsSorted, {
			Id = shovelId,
			Info = info
		})
	end

	table.sort(shovelsSorted, function(a, b)
		local aInfo = a.Info
		local bInfo = b.Info

		return (aInfo.Cost or 0) < (bInfo.Cost or 0)
	end)

	for order, shovelTable in pairs(shovelsSorted) do
		local id = shovelTable.Id
		local info = ItemDef.GetItemInfo(id)
		if not info then continue end

		local newShovelTemplate = self._Gui.ShovelTemplate:Clone() :: Frame
		newShovelTemplate.NameText.Text = info.Name or ""
		newShovelTemplate.Icon.Image = info.Icon or ""
		newShovelTemplate.UIGradient.Color = info.GradientColor
		newShovelTemplate.PowerFrame.AmountFrame.AmountText.Text = BigNumbers.GetNumberDisplay(info.DigPower or 0)

		newShovelTemplate.BuyButton.Contents.AmountFrame.AmountText.Text = BigNumbers.GetNumberDisplay(info.Cost or 0)
		local buyButton = GuiButton.new(newShovelTemplate.BuyButton)
		buyButton:SetCallback(function()
			self._DigService:BuyShovel(id):andThen(function(success)
				if not success then
					self._RewardsController:AnnounceMessage("❌ Can't afford!", Color3.fromRGB(255, 0, 0))
					UtilFunctions.PlayCopyOfSound(ErrorSound)
				else
					UtilFunctions.PlayCopyOfSound(PurchaseSound)
					self:_PlayPurchaseAnimation(newShovelTemplate.Icon)
				end
			end)
		end)
		buyButton:SetMakeShineWhenHovered(true)

		local equipButton = GuiButton.new(newShovelTemplate.EquipButton)
		equipButton:SetCallback(function()
			self._DigService:EquipShovel(id):andThen(function(success)
				if success then
					UtilFunctions.PlayCopyOfSound(EquipSound)
				end
			end)
		end)

		local icon = newShovelTemplate.Icon :: ImageLabel
		local iconObject = GuiObject.new(icon)
		local iconZIndex = icon.ZIndex
		newShovelTemplate.MouseEnter:Connect(function()
			icon.ZIndex = 100000
			iconObject:SetRotateLeftRightTime(1)
			iconObject:MakeRotateLeftRight()
			iconObject:TweenScale(1.1, TweenInfo.new(0.2))
		end)

		newShovelTemplate.MouseLeave:Connect(function()
			iconObject:StopRotateLeftRight(true)
			iconObject:TweenScale(1, TweenInfo.new(0.2))
			icon.ZIndex = iconZIndex
		end)

		newShovelTemplate.Name = id
		newShovelTemplate.LayoutOrder = order
		newShovelTemplate.Visible = true
		newShovelTemplate.Parent = self._Gui.ShovelList
	end

	self:_UpdateUi()
end

function ShovelUiController:_PlayPurchaseAnimation(icon)
	local mainGui = self._Gui.MainGui
	local iconPosition = icon.AbsolutePosition - mainGui.AbsolutePosition
	local iconSize = icon.AbsoluteSize
	local centerX = iconPosition.X + iconSize.X / 2
	local centerY = iconPosition.Y + iconSize.Y / 2

	local flyingIcon = icon:Clone() :: ImageLabel
	flyingIcon.Name = "FlyingShovelIcon"
	flyingIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	flyingIcon.Position = UDim2.fromOffset(centerX, centerY)
	flyingIcon.Size = UDim2.fromOffset(iconSize.X, iconSize.Y)
	flyingIcon.Rotation = 0
	flyingIcon.ZIndex = 100000
	flyingIcon.Visible = true
	flyingIcon.Parent = mainGui

	local riseTween = TweenService:Create(flyingIcon, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(centerX, centerY - iconSize.Y * 0.4),
		Size = UDim2.fromOffset(iconSize.X * 1.35, iconSize.Y * 1.35)
	})
	local fallTween = TweenService:Create(flyingIcon, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0, centerX, 1, 0),
		Size = UDim2.fromOffset(0, 0)
	})

	riseTween.Completed:Once(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed then
			fallTween:Play()
		else
			flyingIcon:Destroy()
		end
	end)
	fallTween.Completed:Once(function()
		flyingIcon:Destroy()
	end)
	riseTween:Play()
end

function ShovelUiController:_UpdateUi()
	for _, template in pairs(self._Gui.ShovelList:GetChildren()) do
		if not template:IsA(self._Gui.ShovelTemplate.ClassName) then continue end

		local id = template.Name
		local info = ItemDef.GetItemInfo(id)
		if not info then continue end

		local isEquipped = self._EquipController:IsItemEquipped(id)
		local isOwned = self._InventoryController:HasItems(id, 1)

		template.BuyButton.Visible = not isOwned
		template.EquipButton.Visible = (isOwned) and (not isEquipped)
		template.EquippedText.Visible = isOwned and isEquipped
	end
end

-- SETUP COMPONENT STUFF
function ShovelUiController:_SetupShovelStores()
	for _, shovelStore in pairs(self._ShovelStoreComponent:GetAll()) do
		self:_SetupShovelStore(shovelStore)
	end

	self._ShovelStoreComponent.Started:Connect(function(shovelStore)
		self:_SetupShovelStore(shovelStore)
	end)
end

function ShovelUiController:_SetupShovelStore(shovelStore)
	shovelStore.Interacted:Connect(function()
		if self._Gui.Frame.Visible then return end

		self:SetVisibility(true, true)
	end)
end

return ShovelUiController
