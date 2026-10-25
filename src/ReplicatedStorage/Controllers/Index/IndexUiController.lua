local GamepadService = game:GetService("GamepadService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local IndexClaimSound = Sounds:WaitForChild("IndexClaim")
local External = ReplicatedStorage:WaitForChild("External")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local RarityColorUtils = require(Utils:WaitForChild("RarityColorUtils"))
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local DinosaurUtils = require(Utils:WaitForChild("DinosaurUtils"))
local Flipbook2d = require(Utils:WaitForChild("2dFlipbook"))
local MutationsEnum = require(Enums:WaitForChild("Mutations"))
local NumberTypesEnum = require(Enums:WaitForChild("NumberTypes"))
local IndexDef = require(ReplicatedConfigs:WaitForChild("IndexDef"))
local DinosaurDef = require(ReplicatedConfigs:WaitForChild("DinosaurDef"))
local DirtSpawnerDef = require(ReplicatedConfigs:WaitForChild("DirtSpawnerDef"))
local ZoneDef = require(ReplicatedConfigs:WaitForChild("ZoneDef"))
local BoostsDef = require(ReplicatedConfigs:WaitForChild("BoostsDef"))
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local GuiButton = require(GuiModules:WaitForChild("Button"))
local GuiObject = require(GuiModules:WaitForChild("Object"))
local Device = require(External:WaitForChild("Device"))
local Knit = require(External:WaitForChild("Knit"))
local BigNumbers = require(External:WaitForChild("BigNumbers"))

local INDEX_VIEWPORT_FRAME_GAP = 5

local IndexUiController = {
	Name = "IndexUiController",
	_HudController = nil,
	_IndexController = nil,
	_IndexService = nil,
	_ActiveIndexTemplates = {},
	_IndexTemplateVisualUpdateQueued = false,
	_IndexViewportQueue = {},
	_PendingIndexViewports = {},
	_IndexViewportFrame = 0,
	_LastIndexViewportFrame = -INDEX_VIEWPORT_FRAME_GAP
}

function IndexUiController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local indexFrame = mainGui:WaitForChild("IndexFrame")
	local hud = mainGui:WaitForChild("Hud")
	local mainButtons = hud:WaitForChild("MainButtons")

	self._Gui = {
		Frame = indexFrame,
		IndexButton = mainButtons:WaitForChild("IndexButton"):WaitForChild("IndexButton"),
		ExitButton = indexFrame:WaitForChild("ExitButton"),
		CategoryButton = indexFrame:WaitForChild("Templates"):WaitForChild("CategoryButton"),
		CategoryButtons = indexFrame:WaitForChild("CategoryButtons"),
		IndexTemplate = indexFrame:WaitForChild("Templates"):WaitForChild("IndexTemplate"),
		IndexList = indexFrame:WaitForChild("IndexList"):WaitForChild("IndexList"),
		RewardTemplate = indexFrame:WaitForChild("Templates"):WaitForChild("RewardTemplate"),
		RewardsList = indexFrame:WaitForChild("InfoFrames"):WaitForChild("RewardsFrame"):WaitForChild("RewardsList"),
		ProgressBar = indexFrame:WaitForChild("ProgressBar"),
		InfoFrame = indexFrame:WaitForChild("InfoFrames"):WaitForChild("InfoFrame"),
		ZoneTemplate = indexFrame:WaitForChild("Templates"):WaitForChild("ZoneTemplate"),
		ClaimButton = indexFrame:WaitForChild("InfoFrames"):WaitForChild("RewardsFrame"):WaitForChild("ClaimButton")
	}
	self._Gui.InfoFrame.ZonesFrame.Visible = false

	local indexButton = GuiButton.new(self._Gui.IndexButton)
	indexButton:SetMakeIconRotateLeftRightWhenHovered(true)
	indexButton:SetMakeIconScaleWhenHovered(true)
	local iconObject = indexButton:GetIconObject()
	indexButton:SetCallback(function()
		self:SetVisibility(not self._Gui.Frame.Visible, true)
		iconObject:GrowAndFade(1.75, TweenInfo.new(0.35), 10000)
	end)

	local exitButton = GuiButton.new(self._Gui.ExitButton)
	exitButton:SetCallback(function()
		self:SetVisibility(false, true)
	end)

	local claimButton = GuiButton.new(self._Gui.ClaimButton)
	claimButton:SetCallback(function()
		if not self._SelectCategory then return end

		self._IndexService:Claim(self._SelectedCategory):andThen(function(success)
			if success then
				UtilFunctions.PlayCopyOfSound(IndexClaimSound)
			end
		end)
	end)

	self:_SetupCategoryButtons()
end

function IndexUiController:KnitStart()
	self._HudController = require(ReplicatedStorage.Controllers.Hud.HudController)
	self._IndexController = require(ReplicatedStorage.Controllers.Index.IndexController)
	self._IndexService = Knit.GetService("IndexService")

	self._IndexController.IndexUpdated:Connect(function()
		self:_UpdateUi()
	end)

	self._Gui.Frame:GetPropertyChangedSignal("Visible"):Connect(function()
		self:_QueueIndexTemplateVisualUpdate()
	end)
	for _, property in ipairs({"CanvasPosition", "AbsolutePosition", "AbsoluteSize", "Visible"}) do
		self._Gui.IndexList:GetPropertyChangedSignal(property):Connect(function()
			self:_QueueIndexTemplateVisualUpdate()
		end)
	end
	RunService.RenderStepped:Connect(function()
		self:_ProcessIndexViewportQueue()
	end)

	self:_UpdateUi()
end

function IndexUiController:SetVisibility(visible, toTween)
	local hideTrack = require(self._Gui.Frame.Animator).Hide
	local openTrack = require(self._Gui.Frame.Animator).Open

	if visible then
		self._Gui.Frame.Visible = visible
		self._HudController:SetCurrentlyActiveFrame(self)
		if Device.GetUserDevice() == "Controller" and not GamepadService.GamepadCursorEnabled then
			GamepadService:EnableGamepadCursor(nil)
		end

		self:_SetupUi()

		hideTrack:Stop()
		self._Hiding = false
		openTrack:Play()
	else
		local function clear()
			self._Gui.Frame.Visible = visible
			self._HudController:ClearCurrentlyActiveFrame(self)
			self:_ClearUi()
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

function IndexUiController:_SetupUi()
	self:_ClearUi()

	self:_SelectCategory(MutationsEnum.Normal)

	self:_UpdateUi()
end

function IndexUiController:_SetupCategoryButtons()
	for category, info in pairs(IndexDef.GetAllIndexes()) do
		local newCategoryButton = self._Gui.CategoryButton:Clone()

		newCategoryButton.NameText.Text = info.Name or ""
		newCategoryButton.OuterNameText.Text = info.Name or ""
		newCategoryButton.Icon.Image = info.Icon or ""

		local flipbookInfo = Constants.MutationFlipbooks[category]
		if flipbookInfo then
			newCategoryButton.Flipbook.Image = flipbookInfo.Id
			newCategoryButton.Flipbook.UIGradient.Color = flipbookInfo.Color or ColorSequence.new(Color3.fromRGB(255, 255, 255))
			local flipbook = Flipbook2d.new(newCategoryButton.Flipbook, flipbookInfo.Size, flipbookInfo.Row, flipbookInfo.Tiles, flipbookInfo.FPS)
			flipbook:Play()
		end

		local categoryButton = GuiButton.new(newCategoryButton)
		categoryButton:SetCallback(function()
			self:_SelectCategory(category)
		end)

		newCategoryButton.Name = category
		newCategoryButton.LayoutOrder = info.Order or 10000
		newCategoryButton.Visible = true
		newCategoryButton.Parent = self._Gui.CategoryButtons
	end
end

function IndexUiController:_SelectCategory(category)
	if category == self._SelectedCategory then return end

	self._SelectedCategory = category

	if not self._SelectedCategory then
		self:_ClearIndex()
		self:_SelectItem(nil)
		return
	end

	self:_SelectItem(nil)
	self:_SetupIndex()
	self:_UpdateRewardsFrame()
	self:_UpdateProgressBar()
end

function IndexUiController:_SetupIndex()
	self:_ClearIndex()

	if not self._SelectedCategory then return end

	local dinosaurs = {}
	for dinosaurId, info in pairs(DinosaurDef.GetAllDinosaurs()) do
		table.insert(dinosaurs, {
			Id = dinosaurId,
			Info = info
		})
	end

	table.sort(dinosaurs, function(a, b)
		local aInfo = a.Info
		local bInfo = b.Info

		local aRarityOrder = table.find(Constants.RarityOrder, aInfo.Rarity)
		local bRarityOrder = table.find(Constants.RarityOrder, bInfo.Rarity)

		if aRarityOrder ~= bRarityOrder then
			return aRarityOrder < bRarityOrder
		end

		return a.Id < b.Id
	end)

	for order, dinosaurTable in pairs(dinosaurs) do
		local dinosaurId = dinosaurTable.Id
		local info = DinosaurDef.GetDinosaurInfo(dinosaurId)
		if not info then continue end

		local newIndexTemplate = self._Gui.IndexTemplate:Clone()

		local button = newIndexTemplate.Button
		local guiButton = GuiButton.new(button)
		guiButton:SetCallback(function()
			self:_SelectItem(dinosaurId)
		end)

		button.RarityText.Text = info.Rarity or ""
		button.BG.UIGradient.Color = ColorSequence.new(RarityColorUtils.GetColor(info.Rarity))
		button.Flipbook.Image = ""

		newIndexTemplate.Name = dinosaurId
		newIndexTemplate.Visible = true
		newIndexTemplate.LayoutOrder = order
		newIndexTemplate.Parent = self._Gui.IndexList
	end

	self:_UpdateIndex()
	self:_UpdateIndexTemplateVisuals()
end

function IndexUiController:_QueueIndexTemplateVisualUpdate()
	if self._IndexTemplateVisualUpdateQueued then return end

	self._IndexTemplateVisualUpdateQueued = true
	task.defer(function()
		self._IndexTemplateVisualUpdateQueued = false
		self:_UpdateIndexTemplateVisuals()
	end)
end

function IndexUiController:_ProcessIndexViewportQueue()
	self._IndexViewportFrame += 1
	if self._IndexViewportFrame - self._LastIndexViewportFrame < INDEX_VIEWPORT_FRAME_GAP then return end

	while #self._IndexViewportQueue > 0 do
		local template = table.remove(self._IndexViewportQueue, 1)
		if not self._PendingIndexViewports[template] then continue end
		self._PendingIndexViewports[template] = nil
		if template.Parent ~= self._Gui.IndexList or not self._ActiveIndexTemplates[template] then continue end

		local button = template.Button
		local inView = self._Gui.Frame.Visible
			and not self._Hiding
			and self._Gui.IndexList.Visible
			and template.Visible
			and button.Visible
			and self:_IsTemplateInView(template)
		if not inView then
			self:_ClearIndexTemplateVisuals(template)
			continue
		end
		if not button.ViewportFrame.Visible then continue end

		self._LastIndexViewportFrame = self._IndexViewportFrame
		DinosaurUtils.CreateViewportModel(button.ViewportFrame, template.Name, 1, self._SelectedCategory)
		break
	end
end

function IndexUiController:_IsTemplateInView(template)
	local scrollFrame = self._Gui.IndexList
	local scrollPosition = scrollFrame.AbsolutePosition
	local scrollSize = scrollFrame.AbsoluteSize
	local templatePosition = template.AbsolutePosition
	local templateSize = template.AbsoluteSize
	return scrollSize.X > 0 and scrollSize.Y > 0
		and templateSize.X > 0 and templateSize.Y > 0
		and templatePosition.X < scrollPosition.X + scrollSize.X
		and templatePosition.X + templateSize.X > scrollPosition.X
		and templatePosition.Y < scrollPosition.Y + scrollSize.Y
		and templatePosition.Y + templateSize.Y > scrollPosition.Y
end

function IndexUiController:_UpdateIndexTemplateVisuals()
	local uiOpen = self._Gui.Frame.Visible and self._Gui.IndexList.Visible
	local flipbookInfo = Constants.MutationFlipbooks[self._SelectedCategory]

	for _, template in pairs(self._Gui.IndexList:GetChildren()) do
		if not template:IsA(self._Gui.IndexTemplate.ClassName) then continue end

		local button = template.Button
		local inView = uiOpen and template.Visible and button.Visible and self:_IsTemplateInView(template)
		if not inView then
			self:_ClearIndexTemplateVisuals(template)
			continue
		end

		if self._ActiveIndexTemplates[template] then continue end

		local info = DinosaurDef.GetDinosaurInfo(template.Name)
		if not info then continue end

		local visuals = {
			RarityText = RarityColorUtils.SetColor(button.RarityText, info.Rarity)
		}
		if flipbookInfo then
			button.Flipbook.Image = flipbookInfo.Id
			button.Flipbook.UIGradient.Color = flipbookInfo.Color or ColorSequence.new(Color3.fromRGB(255, 255, 255))
			visuals.Flipbook = Flipbook2d.new(button.Flipbook, flipbookInfo.Size, flipbookInfo.Row, flipbookInfo.Tiles, flipbookInfo.FPS)
			visuals.Flipbook:Play()
		end

		self._ActiveIndexTemplates[template] = visuals
		if button.ViewportFrame.Visible and not self._PendingIndexViewports[template] then
			self._PendingIndexViewports[template] = true
			table.insert(self._IndexViewportQueue, template)
		end
	end
end

function IndexUiController:_ClearIndexTemplateVisuals(template)
	if self._PendingIndexViewports[template] then
		self._PendingIndexViewports[template] = nil
		local queueIndex = table.find(self._IndexViewportQueue, template)
		if queueIndex then
			table.remove(self._IndexViewportQueue, queueIndex)
		end
	end
	local visuals = self._ActiveIndexTemplates[template]
	if not visuals then return end
	self._ActiveIndexTemplates[template] = nil

	if visuals.Flipbook then
		visuals.Flipbook:Destroy()
	end
	if visuals.RarityText then
		visuals.RarityText:Destroy()
	end

	local button = template.Button
	button.Flipbook.Image = ""
	button.RarityText.TextColor3 = self._Gui.IndexTemplate.Button.RarityText.TextColor3

	local viewportFrame = button.ViewportFrame
	local worldModel = viewportFrame:FindFirstChildWhichIsA("WorldModel")
	if worldModel then
		worldModel:Destroy()
	end
	local camera = viewportFrame:FindFirstChildWhichIsA("Camera")
	if camera then
		camera:Destroy()
	end
end

function IndexUiController:_SelectItem(itemId)
	if self._SelectedItem == itemId then return end

	self._SelectedItem = itemId

	if not self._SelectedItem then
		self:_ClearInfoFrame()
		return
	end

	self:_SetupInfoFrame()
end

function IndexUiController:_SetupInfoFrame()
	self:_ClearInfoFrame()

	local category = self._SelectedCategory
	if not category then return end

	local itemId = self._SelectedItem
	if not itemId then return end

	local info = DinosaurDef.GetDinosaurInfo(itemId)
	if not info then return end

	local infoFrame = self._Gui.InfoFrame
	infoFrame.ZonesFrame.Visible = true

	local income = DinosaurDef.GetIncome(itemId, 1, self._SelectedCategory)
	local incomeFrame = infoFrame.IncomeFrame
	incomeFrame.AmountFrame.AmountText.Text = string.format("%s", BigNumbers.GetNumberDisplay(income))
	incomeFrame.Visible = true

	infoFrame.MutationText.Text = category
	infoFrame.MutationText.UIGradient.Color = Constants.MutationGradients[category] or ColorSequence.new(Color3.fromRGB(255, 255, 255))

	infoFrame.RarityText.Text = info.Rarity or ""

	local zonesList = infoFrame.ZonesFrame.ZonesList :: Frame
	local zoneIds = {}
	for zoneId, spawnerInfo in pairs(DirtSpawnerDef.Table) do
		if table.find(spawnerInfo.DinosaurIds, itemId) then
			table.insert(zoneIds, zoneId)
		end
	end
	table.sort(zoneIds, function(first, second)
		local firstInfo = ZoneDef.GetZoneInfo(first)
		local secondInfo = ZoneDef.GetZoneInfo(second)
		local firstOrder = firstInfo and firstInfo.Order or math.huge
		local secondOrder = secondInfo and secondInfo.Order or math.huge
		if firstOrder == secondOrder then
			return first < second
		end
		return firstOrder < secondOrder
	end)

	for _, zoneId in ipairs(zoneIds) do
		local zoneInfo = ZoneDef.GetZoneInfo(zoneId)
		if zoneInfo then
			local zoneTemplate = self._Gui.ZoneTemplate:Clone()
			zoneTemplate.Name = zoneId
			zoneTemplate.LayoutOrder = zoneInfo.Order or 1000
			zoneTemplate.NameText.Text = zoneInfo.Name
			zoneTemplate.NameText.UIGradient.Color = zoneInfo.Color
			zoneTemplate.Visible = true
			zoneTemplate.Parent = zonesList
		end
	end

	self._InfoFrameRarityText = RarityColorUtils.SetColor(infoFrame.RarityText, info.Rarity)

	infoFrame.Flipbook.Image = ""

	local flipbookInfo = Constants.MutationFlipbooks[category]
	if flipbookInfo then
		infoFrame.Flipbook.Image = flipbookInfo.Id
		infoFrame.Flipbook.UIGradient.Color = flipbookInfo.Color or ColorSequence.new(Color3.fromRGB(255, 255, 255))
		self._InfoFrameFlipbook = Flipbook2d.new(infoFrame.Flipbook, flipbookInfo.Size, flipbookInfo.Row, flipbookInfo.Tiles, flipbookInfo.FPS)
		self._InfoFrameFlipbook:Play()
	end

	DinosaurUtils.CreateViewportModel(infoFrame.ViewportFrame, itemId, 1, category)

	self:_UpdateInfoFrame()
end

function IndexUiController:_UpdateUi()
	self:_UpdateIndexButton()

	if not self._Gui.Frame.Visible then return end

	self:_UpdateIndex()
	self:_UpdateCategoryButtons()
	self:_UpdateProgressBar()
	self:_UpdateRewardsFrame()
	self:_UpdateInfoFrame()
end

function IndexUiController:_UpdateProgressBar()
	local category = self._SelectedCategory
	if not category then return end

	local level = self._IndexController:GetLevelClaimed(category)
	local nextLevelInfo = IndexDef.GetLevelInfoForIndex(category, level + 1)
	local unlockedItems = self._IndexController:GetUnlocked(category)

	local progress
	local progressText
	if not nextLevelInfo then
		progress = 1
		progressText = "MAX"
	else
		progress = math.clamp(#unlockedItems / nextLevelInfo.Required, 0, 1)
		progressText = string.format("%d / %d", #unlockedItems, nextLevelInfo.Required)
	end

	local barContainer = self._Gui.ProgressBar.BarContainer
	local amountText = self._Gui.ProgressBar.AmountText

	amountText.Text = progressText

	local oldSize = barContainer.Bar.Size
	barContainer.Bar.Size = UDim2.new(progress, 0, oldSize.Y.Scale, oldSize.Y.Offset)
end

function IndexUiController:_UpdateRewardsFrame()
	local category = self._SelectedCategory
	if not category then return end

	local level = self._IndexController:GetLevelClaimed(category)
	local levelInfo = IndexDef.GetLevelInfoForIndex(category, level + 1)
	local unlocks = self._IndexController:GetUnlocked(category)
	local indexInfo = IndexDef.GetIndexInfo(category)
	local boostId = indexInfo and indexInfo.Boost
	local boostInfo = boostId and BoostsDef.GetBoostInfo(boostId)
	local rewards = levelInfo and levelInfo.Rewards or {}

	self._Gui.ClaimButton.Visible = levelInfo ~= nil and #unlocks >= levelInfo.Required

	for _, template in pairs(self._Gui.RewardsList:GetChildren()) do
		if not template:IsA(self._Gui.RewardTemplate.ClassName) then continue end

		if not rewards[template.Name] and (not boostInfo or template.Name ~= boostId) then
			template:Destroy()
		end
	end

	for rewardType, reward in pairs(rewards) do
		local rewardTemplate = self._Gui.RewardsList:FindFirstChild(rewardType)
		if not rewardTemplate then
			local newRewardTemplate = self._Gui.RewardTemplate:Clone()

			newRewardTemplate.Button.NameText.Text = rewardType
			newRewardTemplate.Button.Icon.Image = Constants.Icons[rewardType] or ""

			newRewardTemplate.Name = rewardType
			newRewardTemplate.Visible = true
			newRewardTemplate.Parent = self._Gui.RewardsList
			rewardTemplate = newRewardTemplate
		end

		rewardTemplate.Button.QuantityText.Text = string.format("x%s", BigNumbers.GetNumberDisplay(reward))
	end

	if boostInfo then
		local boostTemplate = self._Gui.RewardsList:FindFirstChild(boostId)
		if not boostTemplate then
			boostTemplate = self._Gui.RewardTemplate:Clone()
			boostTemplate.Name = boostId
			boostTemplate.Visible = true
			boostTemplate.Parent = self._Gui.RewardsList
		end

		local boostLevel = levelInfo and level + 1 or level
		local amount = BoostsDef.GetTotalAmountForBoostForLevel(boostId, boostLevel)
		if boostInfo.NumberType == NumberTypesEnum.Multiplying then
			boostTemplate.Button.NameText.Text = string.format("x%.2f", amount)
		else
			boostTemplate.Button.NameText.Text = string.format("+%g%%", amount * 100)
		end
		boostTemplate.Button.Icon.Image = boostInfo.Icon or ""
		boostTemplate.Button.QuantityText.Text = ""
	end
end

function IndexUiController:_UpdateIndex()
	local category = self._SelectedCategory
	if not category then return end

	for _, template in pairs(self._Gui.IndexList:GetChildren()) do
		if not template:IsA(self._Gui.IndexTemplate.ClassName) then continue end

		local dinosaurId = template.Name
		local dinosaurInfo = DinosaurDef.GetDinosaurInfo(dinosaurId)
		if not dinosaurInfo then continue end

		local isUnlocked = self._IndexController:IsUnlocked(category, dinosaurId)
		template.Button.NameText.Text = isUnlocked and dinosaurInfo.Name or "???"
		template.Button.ViewportFrame.Ambient = isUnlocked and self._Gui.IndexTemplate.Button.ViewportFrame.Ambient or Color3.fromRGB(0, 0, 0)
		template.Button.ViewportFrame.LightColor = isUnlocked and self._Gui.IndexTemplate.Button.ViewportFrame.LightColor or Color3.fromRGB(0, 0, 0)
	end
end

function IndexUiController:_UpdateIndexButton()
	local anyClaimable = false
	for category in pairs(IndexDef.GetAllIndexes()) do
		local level = self._IndexController:GetLevelClaimed(category)
		local nextLevelInfo = IndexDef.GetLevelInfoForIndex(category, level + 1)
		if not nextLevelInfo then continue end

		local unlocks = self._IndexController:GetUnlocked(category)

		local isClaimable = #unlocks >= nextLevelInfo.Required
		if isClaimable then
			anyClaimable = true
		end
	end

	if not self._NotificationBubbleObject then
		self._NotificationBubbleObject = GuiObject.new(self._Gui.IndexButton.NotificationBubble)
	end

	if anyClaimable and (not self._NotificationActive) then
		self._NotificationActive = true
		self._Gui.IndexButton.NotificationBubble.Visible = true
		self._NotificationBubbleObject:StartPulse(function()
			self._NotificationBubbleObject:GrowFrameOutlineAndFade(2.5, nil, nil)
		end, 1.4, 0.2, 0.1, 1)
	elseif (not anyClaimable) and (self._NotificationActive) then
		self._Gui.IndexButton.NotificationBubble.Visible = false
		self._NotificationBubbleObject:StopPulse()
		self._NotificationActive = false
	end
end

function IndexUiController:_UpdateCategoryButtons()
	for _, template in pairs(self._Gui.CategoryButtons:GetChildren()) do
		if not template:IsA(self._Gui.CategoryButton.ClassName) then continue end

		local category = template.Name
		local level = self._IndexController:GetLevelClaimed(category)
		local nextLevelInfo = IndexDef.GetLevelInfoForIndex(category, level + 1)
		local unlocked = self._IndexController:GetUnlocked(category)

		local notificationBubbleVisible = false
		if not nextLevelInfo then
			notificationBubbleVisible = false
		else
			notificationBubbleVisible = #unlocked >= nextLevelInfo.Required
		end

		template.NotificationBubble.Visible = notificationBubbleVisible
	end
end

function IndexUiController:_UpdateInfoFrame()
	local category = self._SelectedCategory
	if not category then return end

	local itemId = self._SelectedItem
	if not itemId then return end

	local info = DinosaurDef.GetDinosaurInfo(itemId)
	if not info then return end

	local isUnlocked = self._IndexController:IsUnlocked(category, itemId)

	local infoFrame = self._Gui.InfoFrame

	infoFrame.NameText.Text = isUnlocked and info.Name or "???"
	infoFrame.ViewportFrame.Ambient = isUnlocked and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)
	infoFrame.ViewportFrame.LightColor = isUnlocked and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)
end

function IndexUiController:_ClearIndex()
	table.clear(self._IndexViewportQueue)
	table.clear(self._PendingIndexViewports)
	for _, template in pairs(self._Gui.IndexList:GetChildren()) do
		if template:IsA(self._Gui.IndexTemplate.ClassName) then
			self:_ClearIndexTemplateVisuals(template)
			template:Destroy()
		end
	end
end

function IndexUiController:_ClearInfoFrame()
	local infoFrame = self._Gui.InfoFrame
	infoFrame.ZonesFrame.Visible = false

	for _, template in pairs(infoFrame.ZonesFrame.ZonesList:GetChildren()) do
		if template:IsA(self._Gui.ZoneTemplate.ClassName) then
			template:Destroy()
		end
	end

	if self._InfoFrameFlipbook then
		self._InfoFrameFlipbook:Destroy()
		self._InfoFrameFlipbook = nil
	end
	infoFrame.Flipbook.Image = ""

	if self._InfoFrameRarityText then
		self._InfoFrameRarityText:Destroy()
		self._InfoFrameRarityText = nil
	end

	infoFrame.ViewportFrame:ClearAllChildren()
	infoFrame.IncomeFrame.Visible = false
	infoFrame.MutationText.Text = ""
	infoFrame.NameText.Text = ""
	infoFrame.RarityText.Text = ""
end

function IndexUiController:_ClearRewardsFrame()
	for _, template in pairs(self._Gui.RewardsList:GetChildren()) do
		if template:IsA(self._Gui.RewardTemplate.ClassName) then
			template:Destroy()
		end
	end
end

function IndexUiController:_ClearUi()
	self:_SelectCategory(nil)
	self:_SelectItem(nil)
	self:_ClearIndex()
	self:_ClearInfoFrame()
	self:_ClearRewardsFrame()
end

return IndexUiController
