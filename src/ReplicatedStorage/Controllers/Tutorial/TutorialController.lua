local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local TutorialBeam = ClientAssets:WaitForChild("TutorialBeam")
local External = ReplicatedStorage:WaitForChild("External")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local TutorialBox = require(GuiModules:WaitForChild("TutorialBox"))
local WorldTutorialBox = require(GuiModules:WaitForChild("WorldTutorialBox"))
local Confetti = require(Utils:WaitForChild("Confetti"))
local Fireworks = require(Utils:WaitForChild("Fireworks"))
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local DirtDef = require(ReplicatedConfigs:WaitForChild("DirtDef"))
local DinosaurDef = require(ReplicatedConfigs:WaitForChild("DinosaurDef"))
local ItemDef = require(ReplicatedConfigs:WaitForChild("ItemDef"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local IapsEnum = require(Enums:WaitForChild("Iaps"))
local SettingsEnum = require(Enums:WaitForChild("Settings"))
local Derpbar = require(External:WaitForChild("Derpbar"))
local Knit = require(External:WaitForChild("Knit"))
local Trove = require(External:WaitForChild("Trove"))

local DIG_POWER_TO_GAIN = 10
local STEPS = {
	{ Start = "_StartDigFirstDirt", Stop = "_StopDigFirstDirt" },
	{ Start = "_StartBringBackFirstDino", Stop = "_StopBringBackFirstDino" },
	{ Start = "_StartPlaceDinoOnBase", Stop = "_StopPlaceDinoOnBase" },
	{ Start = "_StartCollectMoneyFromDino", Stop = "_StopCollectMoneyFromDino" },
	{ Start = "_StartDigInExcavationSite", Stop = "_StopDigInExcavationSite" },
	{ Start = "_StartBuyFirstShovel", Stop = "_StopBuyFirstShovel" },
	{ Start = "_StartBuyFirstUpgrade", Stop = "_StopBuyFirstUpgrade" }
}

local TutorialController = {
	Name = "TutorialController",
	_PlotController = nil,
	_TutorialService = nil,
	_DigService = nil,
	_BonePileService = nil,
	_BonePileController = nil,
	_DinosaurController = nil,
	_IapController = nil,
	_InventoryController = nil,
	_PlayerStatsController = nil,
	_ReplicationController = nil,
	_SettingsController = nil,
	_TeleportController = nil,
	_ShovelUiController = nil,
	_UpgradesUiController = nil,
	_UpgradeController = nil,
	_RewardsController = nil,
	_PendingLogSteps = {},
	_LoggingStep = false,
	_BeamTrove = Trove.new()
}

function TutorialController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local teleportButtons = mainGui:WaitForChild("Hud"):WaitForChild("TeleportButtons")
	local shovelsFrame = mainGui:WaitForChild("ShovelsFrame")
	local upgradesFrame = mainGui:WaitForChild("UpgradesFrame")

	self._Gui = {
		MainGui = mainGui,
		TutorialText = mainGui:WaitForChild("TutorialText"),
		ConfettiTopFrame = mainGui:WaitForChild("ConfettiTopFrame"),
		TeleportButtons = teleportButtons,
		ShovelsTeleportButton = teleportButtons:WaitForChild("ShovelsButton"),
		UpgradesTeleportButton = teleportButtons:WaitForChild("UpgradesButton"),
		ShovelsFrame = shovelsFrame,
		ShovelList = shovelsFrame:WaitForChild("ShovelList"):WaitForChild("ShovelList"),
		UpgradesFrame = upgradesFrame,
		UpgradesList = upgradesFrame:WaitForChild("UpgradesList")
	}
	self._Gui.TutorialText.Visible = false
end

function TutorialController:KnitStart()
	self._PlotController = require(ReplicatedStorage.Controllers.Plots.PlotController)
	self._BonePileController = require(ReplicatedStorage.Controllers.Digging.BonePileController)
	self._DinosaurController = require(ReplicatedStorage.Controllers.Dinosaurs.DinosaurController)
	self._IapController = require(ReplicatedStorage.Controllers.Iaps.IapController)
	self._InventoryController = require(ReplicatedStorage.Controllers.Inventory.InventoryController)
	self._PlayerStatsController = require(ReplicatedStorage.Controllers.PlayerStats.PlayerStatsController)
	self._ReplicationController = require(ReplicatedStorage.Controllers.Replication.ReplicationController)
	self._SettingsController = require(ReplicatedStorage.Controllers.Settings.SettingsController)
	self._TeleportController = require(ReplicatedStorage.Controllers.Teleport.TeleportController)
	self._ShovelUiController = require(ReplicatedStorage.Controllers.Digging.ShovelUiController)
	self._UpgradesUiController = require(ReplicatedStorage.Controllers.Upgrades.UpgradesUiController)
	self._UpgradeController = require(ReplicatedStorage.Controllers.Upgrades.UpgradeController)
	self._RewardsController = require(ReplicatedStorage.Controllers.Rewards.RewardsController)
	self._TutorialService = Knit.GetService("TutorialService")
	self._DigService = Knit.GetService("DigService")
	self._BonePileService = Knit.GetService("BonePileService")

	while not self._PlotController:GetPlot() do
		task.wait()
	end

	self._TutorialService:GetNextStep():andThen(function(step)
		self:_StartStep(step)
	end)
end

-- TUTORIAL FUNCTIONS
function TutorialController:_SetTutorialText(message: string)
	self._Gui.TutorialText.Text = message
	self._Gui.TutorialText.Visible = true
end

function TutorialController:_StartStep(step: number)
	if step > #STEPS then
		self._Gui.TutorialText.Visible = false
		return
	end

	self._CurrentStep = step
	self._StepTrove = Trove.new()
	self[STEPS[step].Start](self)
end

function TutorialController:_CleanStep()
	self._StepTrove:Clean()
	self._StepTrove = nil
	self:_HideTutorialBeam()
end

function TutorialController:_SendNextCompletedStep()
	if self._LoggingStep or #self._PendingLogSteps == 0 then return end
	self._LoggingStep = true
	local step = self._PendingLogSteps[1]

	local function retry()
		task.delay(2, function()
			self._LoggingStep = false
			self:_SendNextCompletedStep()
		end)
	end

	self._TutorialService:LogOnboardingStep(step):andThen(function(accepted)
		if not accepted then
			retry()
			return
		end

		table.remove(self._PendingLogSteps, 1)
		self._LoggingStep = false
		self:_SendNextCompletedStep()
	end, retry)
end

function TutorialController:_CompleteStep(step: number)
	if self._CurrentStep ~= step then return end
	self._CurrentStep = nil
	self[STEPS[step].Stop](self)
	table.insert(self._PendingLogSteps, step + 1)
	self:_SendNextCompletedStep()
	self:_StartStep(step + 1)
end

function TutorialController:_StartDigFirstDirt()
	self:_SetTutorialText("Equip your shovel and dig a dirt pile!")
	local box = TutorialBox.new()
	box:GetObject().Active = false
	self._StepTrove:Add(box)
	local backpack = Player:WaitForChild("Backpack")
	local currentTemplate
	local visibilityConnection
	local wasShovelEquipped

	self._StepTrove:Add(function()
		if visibilityConnection then visibilityConnection:Disconnect() end
	end)

	local function findShovelTool()
		local character = Player.Character
		local containers = if character then { character, backpack } else { backpack }
		for _, container in ipairs(containers) do
			for _, child in ipairs(container:GetChildren()) do
				if not child:IsA("Tool") then continue end
				local itemId = child:GetAttribute("ItemId")
				local info = typeof(itemId) == "string" and ItemDef.GetItemInfo(itemId)
				if info and info.Category == ItemDef.Categories.Shovel then
					return child
				end
			end
		end
	end

	local function isTemplateVisible(template)
		if not template:IsDescendantOf(Player.PlayerGui) then return false end
		local ancestor = template
		while ancestor and ancestor ~= Player.PlayerGui do
			if ancestor:IsA("GuiObject") and not ancestor.Visible then return false end
			if ancestor:IsA("ScreenGui") and not ancestor.Enabled then return false end
			ancestor = ancestor.Parent
		end
		return true
	end

	local function updateShovelBox()
		if self._CurrentStep ~= 1 then return end
		local shovel = findShovelTool()
		local shovelEquipped = shovel ~= nil and shovel.Parent == Player.Character
		if shovelEquipped ~= wasShovelEquipped then
			wasShovelEquipped = shovelEquipped
			self:_SetTutorialText(if shovelEquipped then "Dig a dirt pile!" else "Equip your shovel and dig a dirt pile!")
		end
		local template = shovel and Derpbar.GetToolTemplate(shovel)
		if template ~= currentTemplate then
			if visibilityConnection then visibilityConnection:Disconnect() end
			currentTemplate = template
			box:StopTrackingFrame()
			if template then
				box:MoveAndResizeToFrame(template)
				visibilityConnection = template:GetPropertyChangedSignal("Visible"):Connect(updateShovelBox)
			else
				visibilityConnection = nil
			end
		end
		if template and not shovelEquipped and isTemplateVisible(template) then
			box:Show()
		else
			box:Hide()
		end
	end

	local watchedTools = {}
	local function watchTool(child)
		if not child:IsA("Tool") or watchedTools[child] then return end
		watchedTools[child] = true
		self._StepTrove:Add(child:GetAttributeChangedSignal("ItemId"):Connect(updateShovelBox))
		self._StepTrove:Add(child.Equipped:Connect(updateShovelBox))
		self._StepTrove:Add(child.Unequipped:Connect(updateShovelBox))
	end

	local function watchTools(container)
		for _, child in ipairs(container:GetChildren()) do watchTool(child) end
		self._StepTrove:Add(container.ChildAdded:Connect(function(child)
			watchTool(child)
			updateShovelBox()
		end))
		self._StepTrove:Add(container.ChildRemoved:Connect(updateShovelBox))
	end

	watchTools(backpack)
	if Player.Character then watchTools(Player.Character) end
	self._StepTrove:Add(Player.CharacterAdded:Connect(function(character)
		watchTools(character)
		updateShovelBox()
	end))
	self._StepTrove:Add(Derpbar.ToolTemplateChanged:Connect(updateShovelBox))
	self._StepTrove:Add(Derpbar.InventoryOpened:Connect(updateShovelBox))
	updateShovelBox()

	local function updateTarget()
		if self._CurrentStep ~= 1 then return end
		local character = Player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local origin = rootPart and rootPart.Position or self._PlotController:GetPlot().Instance:GetPivot().Position
		local bestDirt
		local bestRarity = math.huge
		local bestDistance = math.huge

		for _, dirt in ipairs(self._ReplicationController:GetReplicatorsOfType("Dirt")) do
			if dirt.ZoneId ~= "Zone1" or dirt.Health <= 0 then continue end
			local info = DirtDef.GetDirtInfo(dirt.DirtId)
			if not info then continue end

			local rarity = table.find(Constants.RarityOrder, info.Rarity) or math.huge
			local distance = (dirt.CFrame.Position - origin).Magnitude
			if rarity < bestRarity or (rarity == bestRarity and distance < bestDistance) then
				bestDirt = dirt
				bestRarity = rarity
				bestDistance = distance
			end
		end

		if bestDirt and bestDirt.Guid ~= self._TargetDirtGuid then
			self._TargetDirtGuid = bestDirt.Guid
			self:_ShowBeamToPosition(bestDirt.CFrame.Position)
		elseif not bestDirt then
			self._TargetDirtGuid = nil
			self:_HideTutorialBeam()
		end
	end

	self._StepTrove:Add(self._DigService.DirtCompleted:Connect(function(_, zoneId)
		if zoneId == "Zone1" then
			self:_CompleteStep(1)
		end
	end))
	self._StepTrove:Add(self._ReplicationController.ReplicatorReplicatedSignal:Connect(function(data)
		if data.Type == "Dirt" then updateTarget() end
	end))
	self._StepTrove:Add(self._ReplicationController.ReplicatorDereplicatedSignal:Connect(function(guid)
		if guid == self._TargetDirtGuid then updateTarget() end
	end))
	self._StepTrove:Add(RunService.Heartbeat:Connect(function()
		updateTarget()
	end))
	self._StepTrove:Add(Player.CharacterAdded:Connect(function()
		task.defer(updateTarget)
	end))
	updateTarget()
end

function TutorialController:_StopDigFirstDirt()
	self._TargetDirtGuid = nil
	self:_CleanStep()
end

function TutorialController:_StartBringBackFirstDino()
	local bonePiles = Workspace:WaitForChild("_BonePiles")
	local beamTarget
	local bonePileBox
	local wasCarrying
	local lookForOwnPileUntil = os.clock() + 5

	local function getRootPart()
		local character = Player.Character
		return character and character:FindFirstChild("HumanoidRootPart")
	end

	local function findBonePile()
		local rootPart = getRootPart()
		local ownPile, otherPile
		local ownDistance, otherDistance = math.huge, math.huge

		for _, model in ipairs(bonePiles:GetChildren()) do
			if not model:IsA("Model") or model:GetAttribute("ZoneId") ~= "Zone1" then continue end
			local part = model.PrimaryPart
			local prompt = part and part:FindFirstChildOfClass("ProximityPrompt")
			if not prompt or not prompt.Enabled then continue end

			local distance = rootPart and (part.Position - rootPart.Position).Magnitude or 0
			if model:GetAttribute("DugByUserId") == Player.UserId then
				if distance < ownDistance then
					ownPile, ownDistance = model, distance
				end
			elseif distance < otherDistance then
				otherPile, otherDistance = model, distance
			end
		end

		return ownPile or (os.clock() >= lookForOwnPileUntil and otherPile or nil)
	end

	local function findSafeZone()
		local rootPart = getRootPart()
		local closestZone
		local closestDistance = math.huge

		for _, part in ipairs(CollectionService:GetTagged("Zone2d")) do
			if part.Name ~= "SafeZone" or not part:IsA("BasePart") or not part:IsDescendantOf(Workspace) then continue end
			local distance = rootPart and (part.Position - rootPart.Position).Magnitude or 0
			if distance < closestDistance then
				closestZone, closestDistance = part, distance
			end
		end

		return closestZone
	end

	local function updateBeam()
		if self._CurrentStep ~= 2 then return end
		local carrying = self._BonePileService.CarriedDinosaurId:Get() ~= nil
		if carrying ~= wasCarrying then
			wasCarrying = carrying
			self:_SetTutorialText(if carrying then "Bring the dinosaur bones back to the safe zone." else "Pick up the dinosaur bones.")
		end

		local target = if carrying then findSafeZone() else findBonePile()
		if target == beamTarget then return end
		beamTarget = target
		if target and target:IsA("Model") then
			if bonePileBox then
				bonePileBox:SetTarget(target)
				bonePileBox:Show()
			else
				bonePileBox = WorldTutorialBox.new(target)
				bonePileBox:GetObject().Active = false
				self._StepTrove:Add(bonePileBox)
			end
			self:_ShowBeamToPart(target.PrimaryPart)
		elseif target then
			if bonePileBox then bonePileBox:Hide() end
			self:_ShowBeamToPart(target)
		else
			if bonePileBox then bonePileBox:Hide() end
			self:_HideTutorialBeam()
		end
	end

	local function checkBanked()
		if self._DinosaurController:GetDinosaurCount() > 0 then
			self:_CompleteStep(2)
			return
		end
		for _, item in ipairs(self._InventoryController:GetNonFungibleItems()) do
			if DinosaurDef.GetDinosaurInfo(item.ItemId) then
				self:_CompleteStep(2)
				return
			end
		end
	end

	self._StepTrove:Add(self._BonePileService.BonesRewarded:Connect(function()
		self:_CompleteStep(2)
	end))
	self._StepTrove:Add(self._InventoryController.InventoryUpdatedSignal:Connect(checkBanked))
	self._StepTrove:Add(self._DinosaurController.DinosaurDataUpdatedSignal:Connect(checkBanked))
	self._StepTrove:Add(self._BonePileService.CarriedDinosaurId:Observe(updateBeam))
	local updateElapsed = 0
	self._StepTrove:Add(RunService.Heartbeat:Connect(function(dt)
		updateElapsed += dt
		if updateElapsed < 0.2 then return end
		updateElapsed = 0
		updateBeam()
	end))
	updateBeam()
	checkBanked()
end

function TutorialController:_StopBringBackFirstDino()
	self:_CleanStep()
end

function TutorialController:_StartPlaceDinoOnBase()
	self:_SetTutorialText("Place your dinosaur on your base.")
	self._Gui.TutorialText.Visible = not self._BonePileController:IsAssembling()
	local plot = self._PlotController:GetPlot()
	local floor = plot.Instance:FindFirstChild("_Floor")
	self:_ShowBeamToPosition(floor and floor.Position or plot.Instance:GetPivot().Position)

	local function checkPlaced()
		for _, dinosaur in ipairs(self._DinosaurController:GetOwnedDinosaurs()) do
			if self._DinosaurController:IsDinosaurPlaced(dinosaur.Guid) then
				self._TutorialDinoGuid = dinosaur.Guid
				if not self._BonePileController:IsAssembling() then
					self:_CompleteStep(3)
				end
				return
			end
		end
	end

	local function equipBonePile()
		if self._CurrentStep ~= 3 then return end
		local character = Player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local backpack = Player:FindFirstChild("Backpack")
		if not humanoid or not backpack then return end

		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("BonePileGuid") then
				humanoid:EquipTool(tool)
				return
			end
		end
	end

	self._StepTrove:Add(self._DinosaurController.DinosaurDataUpdatedSignal:Connect(checkPlaced))
	self._StepTrove:Add(self._BonePileController.AssemblyStateChangedSignal:Connect(function(isAssembling)
		self._Gui.TutorialText.Visible = not isAssembling
		if not isAssembling then checkPlaced() end
		if isAssembling then self:_HideTutorialBeam() end
	end))
	self._StepTrove:Add(Player.CharacterAdded:Connect(function(character)
		self._StepTrove:Add(task.spawn(function()
			character:WaitForChild("Humanoid", 5)
			equipBonePile()
		end))
	end))

	equipBonePile()

	checkPlaced()
end

function TutorialController:_StopPlaceDinoOnBase()
	self:_CleanStep()
end

function TutorialController:_StartCollectMoneyFromDino()
	self:_SetTutorialText("Collect cash")
	local function checkAutoCollect()
		if self._IapController:OwnsIap(IapsEnum.AutoCollect)
			and self._SettingsController:GetSetting(SettingsEnum.AutoCollect)
			and self._DinosaurController:GetDinosaurCount() > 0 then
			self:_CompleteStep(4)
		end
	end

	local function updateBeam()
		if self._CurrentStep ~= 4 then return end
		local guid = self._TutorialDinoGuid
		if not guid or not self._DinosaurController:IsDinosaurPlaced(guid) then
			guid = nil
			for _, dinosaur in ipairs(self._DinosaurController:GetOwnedDinosaurs()) do
				if self._DinosaurController:IsDinosaurPlaced(dinosaur.Guid) then
					guid = dinosaur.Guid
					break
				end
			end
			self._TutorialDinoGuid = guid
		end

		local dinosaur = guid and self._DinosaurController:GetDinosaur(guid)
		local model = dinosaur and dinosaur:GetModel()
		local part = model and model.PrimaryPart
		if part == self._IncomeBeamTarget then return end

		self._IncomeBeamTarget = part
		if part then
			self:_ShowBeamToPart(part)
		else
			self:_HideTutorialBeam()
		end
	end

	self._StepTrove:Add(self._DinosaurController.IncomeCollectedSignal:Connect(function()
		self:_CompleteStep(4)
	end))
	self._StepTrove:Add(self._IapController.IapsUpdatedSignal:Connect(checkAutoCollect))
	self._StepTrove:Add(self._SettingsController.SettingUpdated:Connect(function(settingId)
		if settingId == SettingsEnum.AutoCollect then checkAutoCollect() end
	end))
	self._StepTrove:Add(self._ReplicationController.ReplicatorReplicatedSignal:Connect(function(data)
		if data.Type == "Dinosaur" then updateBeam() end
	end))
	self._StepTrove:Add(self._ReplicationController.ReplicatorDereplicatedSignal:Connect(updateBeam))
	self._StepTrove:Add(self._DinosaurController.DinosaurDataUpdatedSignal:Connect(updateBeam))
	self._StepTrove:Add(self._PlotController.PlotsChanged:Connect(updateBeam))
	updateBeam()
	checkAutoCollect()
end

function TutorialController:_StopCollectMoneyFromDino()
	self._IncomeBeamTarget = nil
	self._TutorialDinoGuid = nil
	self:_CleanStep()
end

function TutorialController:_StartDigInExcavationSite()
	self:_SetTutorialText(`Dig to gain Dig Power (0 / {DIG_POWER_TO_GAIN})`)
	local plot = self._PlotController:GetPlot()
	local excavation = plot.Instance:FindFirstChild("_Excavation")
	local part = excavation and (excavation:IsA("Model") and excavation.PrimaryPart or excavation)
	if part and part:IsA("BasePart") then
		self:_ShowBeamToPart(part)
	end

	local startingPower = self._PlayerStatsController:GetStatValue(PlayerStatsEnum.DigPower)
	local function checkPower()
		local power = self._PlayerStatsController:GetStatValue(PlayerStatsEnum.DigPower)
		if not power then return end
		if startingPower == nil then startingPower = power end
		local gained = math.clamp(math.floor(power - startingPower), 0, DIG_POWER_TO_GAIN)
		self:_SetTutorialText(`Dig to gain Dig Power ({gained} / {DIG_POWER_TO_GAIN})`)
		if gained >= DIG_POWER_TO_GAIN then
			self:_CompleteStep(5)
		end
	end

	self._StepTrove:Add(self._PlayerStatsController.StatsUpdatedSignal:Connect(checkPower))
	checkPower()
end

function TutorialController:_StopDigInExcavationSite()
	self:_CleanStep()
end

function TutorialController:_StartBuyFirstShovel()
	self:_SetTutorialText("Teleport to the shovel shop and buy the Stone Shovel.")
	local box = TutorialBox.new()
	box:GetObject().Active = false
	self._StepTrove:Add(box)
	local button = self._Gui.ShovelsTeleportButton
	local frame = self._Gui.ShovelsFrame

	local function showTeleportButton()
		self:_SetTutorialText("Teleport to the shovel shop and buy the Stone Shovel.")
		if self._Gui.TeleportButtons.Visible then
			self:_HideTutorialBeam()
			box:MoveAndResizeToFrame(button)
			box:Show()
		else
			box:Hide()
			local plot = self._PlotController:GetPlot()
			local spawn = plot.Instance:FindFirstChild("_Spawn")
			self:_ShowBeamToPosition(spawn and spawn.Position or plot.Instance:GetPivot().Position)
		end
	end

	local function openShop()
		self._ShovelUiController:SetVisibility(true, true)
		local stoneTemplate = self._Gui.ShovelList:WaitForChild("StoneShovel")
		if self._CurrentStep ~= 6 then return end
		self:_HideTutorialBeam()
		self:_SetTutorialText("Buy the Stone Shovel.")
		box:MoveAndResizeToFrame(stoneTemplate)
		box:Show()
	end

	self._StepTrove:Add(self._TeleportController.ShovelsTeleportClicked:Connect(openShop))
	self._StepTrove:Add(frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not frame.Visible then
			showTeleportButton()
		end
	end))
	self._StepTrove:Add(self._Gui.TeleportButtons:GetPropertyChangedSignal("Visible"):Connect(function()
		if not frame.Visible then showTeleportButton() end
	end))
	self._StepTrove:Add(self._InventoryController.InventoryUpdatedSignal:Connect(function()
		if self._InventoryController:HasItems("StoneShovel", 1) then
			self:_CompleteStep(6)
		end
	end))

	if self._InventoryController:HasItems("StoneShovel", 1) then
		self:_CompleteStep(6)
	elseif frame.Visible then
		openShop()
	else
		showTeleportButton()
	end
end

function TutorialController:_StopBuyFirstShovel()
	self:_CleanStep()
	self._ShovelUiController:SetVisibility(false)
end

function TutorialController:_StartBuyFirstUpgrade()
	self:_SetTutorialText("Teleport to the upgrade shop and buy the Speed upgrade.")
	local box = TutorialBox.new()
	box:GetObject().Active = false
	self._StepTrove:Add(box)
	local button = self._Gui.UpgradesTeleportButton
	local frame = self._Gui.UpgradesFrame

	local function showTeleportButton()
		self:_SetTutorialText("Teleport to the upgrade shop and buy the Speed upgrade.")
		if self._Gui.TeleportButtons.Visible then
			self:_HideTutorialBeam()
			box:MoveAndResizeToFrame(button)
			box:Show()
		else
			box:Hide()
			local plot = self._PlotController:GetPlot()
			local spawn = plot.Instance:FindFirstChild("_Spawn")
			self:_ShowBeamToPosition(spawn and spawn.Position or plot.Instance:GetPivot().Position)
		end
	end

	local function openShop()
		self._UpgradesUiController:SetVisibility(true, true)
		local speedTemplate = self._Gui.UpgradesList:WaitForChild("SpeedUpgrade")
		if self._CurrentStep ~= 7 then return end
		self:_HideTutorialBeam()
		self:_SetTutorialText("Buy the Speed upgrade.")
		box:MoveAndResizeToFrame(speedTemplate)
		box:Show()
	end

	self._StepTrove:Add(self._TeleportController.UpgradesTeleportClicked:Connect(openShop))
	self._StepTrove:Add(frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not frame.Visible then
			showTeleportButton()
		end
	end))
	self._StepTrove:Add(self._Gui.TeleportButtons:GetPropertyChangedSignal("Visible"):Connect(function()
		if not frame.Visible then showTeleportButton() end
	end))
	self._StepTrove:Add(self._UpgradeController.UpgradesUpdated:Connect(function()
		if self._UpgradeController:GetUpgradeLevel("SpeedUpgrade") > 0 then
			self:_CompleteStep(7)
		end
	end))

	if self._UpgradeController:GetUpgradeLevel("SpeedUpgrade") > 0 then
		self:_CompleteStep(7)
	elseif frame.Visible then
		openShop()
	else
		showTeleportButton()
	end
end

function TutorialController:_StopBuyFirstUpgrade()
	self:_CleanStep()
	self._UpgradesUiController:SetVisibility(false)
	local character = Player.Character
	local origin = character and character:GetPivot() or self._PlotController:GetPlot().Instance:GetPivot()
	Fireworks.LaunchFireworks(origin)
	Confetti.Burst(nil, self._Gui.ConfettiTopFrame, 100, 180, 360, nil, 3, 4)
	self._RewardsController:AnnounceMessage("🎉 You completed the tutorial! 🎉", Color3.fromRGB(255, 219, 60))
end

-- TUTORIAL BEAM STUFF
function TutorialController:_ShowBeamToPosition(position: Vector3)
	self:_ShowBeamsToPositions({ position })
end

function TutorialController:_ShowBeamToPart(part: BasePart)
	self:_ShowBeamsToPositions({ part })
end

function TutorialController:_ShowBeamsToPositions(positions: { Vector3 | BasePart })
	self:_HideTutorialBeam()
	local generation = self._BeamGeneration

	self._BeamTrove:Add(Player.CharacterAdded:Connect(function(character)
		self:_AttachTutorialBeamsToCharacter(character, positions, generation)
	end))

	if Player.Character then
		self:_AttachTutorialBeamsToCharacter(Player.Character, positions, generation)
	end
end

function TutorialController:_HideTutorialBeam()
	self._BeamGeneration = (self._BeamGeneration or 0) + 1
	self._BeamTrove:Clean()
end

function TutorialController:_ClearTutorialBeamInstances()
	if self._BeamInstanceTrove then
		self._BeamTrove:Remove(self._BeamInstanceTrove)
		self._BeamInstanceTrove = nil
	end
end

function TutorialController:_AttachTutorialBeamToCharacter(character: Model, position: Vector3)
	self:_AttachTutorialBeamsToCharacter(character, { position })
end

function TutorialController:_AttachTutorialBeamsToCharacter(character: Model, positions: { Vector3 | BasePart }, generation: number?)
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if not rootPart or (generation and generation ~= self._BeamGeneration) then return end

	self:_ClearTutorialBeamInstances()

	self._BeamInstanceTrove = Trove.new()
	self._BeamTrove:Add(self._BeamInstanceTrove)

	local characterAttachment = Instance.new("Attachment")
	characterAttachment.Name = "TutorialBeamAttachment"
	characterAttachment.Parent = rootPart
	self._BeamInstanceTrove:Add(characterAttachment)

	for _, position in ipairs(positions) do
		local targetPart
		if typeof(position) == "Instance" then
			if not position:IsDescendantOf(Workspace) then continue end
			targetPart = position
		else
			targetPart = Instance.new("Part")
			targetPart.Name = "TutorialBeamTarget"
			targetPart.Anchored = true
			targetPart.CanCollide = false
			targetPart.CanQuery = false
			targetPart.CanTouch = false
			targetPart.Transparency = 1
			targetPart.Size = Vector3.one
			targetPart.CFrame = CFrame.new(position)
			targetPart.Parent = Workspace
			self._BeamInstanceTrove:Add(targetPart)
		end

		local targetAttachment = Instance.new("Attachment")
		targetAttachment.Name = "TutorialBeamAttachment"
		targetAttachment.Parent = targetPart
		self._BeamInstanceTrove:Add(targetAttachment)

		local beam = TutorialBeam:Clone()
		beam.Parent = rootPart
		self._BeamInstanceTrove:Add(beam)

		if beam:IsA("Beam") then
			beam.Attachment0 = characterAttachment
			beam.Attachment1 = targetAttachment
		else
			for _, descendant in ipairs(beam:GetDescendants()) do
				if not descendant:IsA("Beam") then continue end

				descendant.Attachment0 = descendant.Attachment0 or characterAttachment
				descendant.Attachment1 = descendant.Attachment1 or targetAttachment
			end
		end
	end
end

return TutorialController
