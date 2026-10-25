local GamepadService = game:GetService("GamepadService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local random = Random.new()

local External = ReplicatedStorage:WaitForChild("External")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local GuiButton = require(GuiModules:WaitForChild("Button"))
local DinosaurDef = require(ReplicatedConfigs:WaitForChild("DinosaurDef"))
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local DinosaurUtils = require(Utils:WaitForChild("DinosaurUtils"))
local RarityColorUtils = require(Utils:WaitForChild("RarityColorUtils"))
local BigNumbers = require(External:WaitForChild("BigNumbers"))
local Device = require(External:WaitForChild("Device"))
local Knit = require(External:WaitForChild("Knit"))

local DinosaurUiController = {
	Name = "DinosaurUiController",
	_HudController = nil,
	_HudUiController = nil,
	_DinosaurController = nil,
	_InventoryController = nil,
	_PlotController = nil,
	_DinosaurService = nil,
	_Templates = {},
	_ViewportUpdateQueued = false,
	_OwnedDinosaursByGuid = {},
	_Placing = false,
}

function DinosaurUiController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local hud = mainGui:WaitForChild("Hud")
	local rightSideButtons = hud:WaitForChild("RightSideButtons")
	local dinosaursFrame = mainGui:WaitForChild("DinosaursFrame")

	self._Gui = {
		Frame = dinosaursFrame,
		DinosaursButton = rightSideButtons:WaitForChild("DinosaursButton"),
		DinosaurList = dinosaursFrame:WaitForChild("DinosaurList"):WaitForChild("DinosaurList"),
		DinosaurTemplate = dinosaursFrame:WaitForChild("Templates"):WaitForChild("DinosaurTemplate"),
		EquipBestButton = dinosaursFrame:WaitForChild("EquipBestButton"),
		ExitButton = dinosaursFrame:WaitForChild("ExitButton")
	}

	local dinosaursButton = GuiButton.new(self._Gui.DinosaursButton)
	dinosaursButton:SetMakeIconScaleWhenHovered(true)
	dinosaursButton:SetMakeIconRotateLeftRightWhenHovered(true)
	dinosaursButton:SetCallback(function()
		self:SetVisibility(not self._Gui.Frame.Visible, true)
	end)

	local exitButton = GuiButton.new(self._Gui.ExitButton)
	exitButton:SetCallback(function()
		self:SetVisibility(false, true)
	end)

	local equipBestButton = GuiButton.new(self._Gui.EquipBestButton)
	equipBestButton:SetCallback(function()
		self:_EquipBest()
	end)
end

function DinosaurUiController:KnitStart()
	self._HudController = require(ReplicatedStorage.Controllers.Hud.HudController)
	self._HudUiController = require(ReplicatedStorage.Controllers.Hud.HudUiController)
	self._DinosaurController = require(ReplicatedStorage.Controllers.Dinosaurs.DinosaurController)
	self._InventoryController = require(ReplicatedStorage.Controllers.Inventory.InventoryController)
	self._PlotController = require(ReplicatedStorage.Controllers.Plots.PlotController)
	self._DinosaurService = Knit.GetService("DinosaurService")

	local function updateUi()
		self:_UpdateUi()
	end

	self._DinosaurController.DinosaurDataUpdatedSignal:Connect(function()
		updateUi()
	end)
	self._InventoryController.InventoryUpdatedSignal:Connect(function()
		updateUi()
	end)

	self._Gui.Frame:GetPropertyChangedSignal("Visible"):Connect(function()
		self:_QueueViewportUpdate()
	end)
	self._Gui.DinosaurList:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		self:_QueueViewportUpdate()
	end)

	updateUi()
end

function DinosaurUiController:SetVisibility(visible, toTween)
	local hideTrack = require(self._Gui.Frame.Animator).Hide
	local openTrack = require(self._Gui.Frame.Animator).Open

	if visible then
		self._Gui.Frame.Visible = visible
		self._HudController:SetCurrentlyActiveFrame(self)
		if Device.GetUserDevice() == "Controller" and not GamepadService.GamepadCursorEnabled then
			GamepadService:EnableGamepadCursor(nil)
		end
		hideTrack:Stop()
		self._Hiding = false
		self:_UpdateUi()
		openTrack:Play()
		self._HudUiController:HideRightSideButtons()
	else
		local function clear()
			self._Gui.Frame.Visible = visible
			self:_ClearUi()
			self._HudController:ClearCurrentlyActiveFrame(self)
		end

		self._HudUiController:ShowRightSideButtons()

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

function DinosaurUiController:_UpdateUi()
	if not self._Gui.Frame.Visible then return end

	local dinosaurs = {}
	local owned = {}

	for _, dinosaur in ipairs(self._DinosaurController:GetOwnedDinosaurs()) do
		local info = DinosaurDef.GetDinosaurInfo(dinosaur.Id)
		local entry = {
			Dinosaur = dinosaur,
			Info = info,
			Income = DinosaurDef.GetIncome(dinosaur.Id, dinosaur.Scale, dinosaur.Mutation, dinosaur.ZoneId),
			Placed = self._DinosaurController:IsDinosaurPlaced(dinosaur.Guid)
		}
		table.insert(dinosaurs, entry)
		owned[dinosaur.Guid] = entry
	end

	table.sort(dinosaurs, function(a, b)
		if a.Placed ~= b.Placed then
			return a.Placed
		end
		if a.Income ~= b.Income then
			return a.Income > b.Income
		end
		return a.Dinosaur.Guid < b.Dinosaur.Guid
	end)

	for guid, template in pairs(self._Templates) do
		if not owned[guid] then
			template:Destroy()
			self._Templates[guid] = nil
		end
	end

	self._OwnedDinosaursByGuid = owned

	for order, entry in ipairs(dinosaurs) do
		local dinosaur = entry.Dinosaur
		local guid = dinosaur.Guid
		local template = self._Templates[guid]
		if not template then
			template = self._Gui.DinosaurTemplate:Clone()
			template.Name = guid
			self._Templates[guid] = template

			local equipButton = GuiButton.new(template.EquipButton)
			equipButton:SetCallback(function()
				self:_EquipDinosaur(guid)
			end)

			local unequipButton = GuiButton.new(template.UnequipButton)
			unequipButton:SetCallback(function()
				self._DinosaurService:UnequipDinosaur(guid)
			end)

			template.Parent = self._Gui.DinosaurList
		end

		template.NameText.Text = entry.Info and entry.Info.Name or dinosaur.Id
		template.RarityText.Text = entry.Info and entry.Info.Rarity or ""
		template.RarityText.TextColor3 = self._Gui.DinosaurTemplate.RarityText.TextColor3
		RarityColorUtils.SetColor(template.RarityText, entry.Info and entry.Info.Rarity)
		template.SizeText.Text = string.format("Size: %.1fx", dinosaur.Scale)
		template.IncomeFrame.AmountFrame.AmountText.Text = string.format("%s", BigNumbers.GetNumberDisplay(math.round(entry.Income)))
		template.EquipButton.Visible = not entry.Placed
		template.UnequipButton.Visible = entry.Placed

		local mutation = dinosaur.Mutation
		template.MutationText.Text = mutation
		template.MutationText.Visible = mutation ~= "Normal"
		template.MutationText.UIGradient.Color = Constants.MutationGradients[mutation] or ColorSequence.new(Color3.fromRGB(255, 255, 255))

		template.LayoutOrder = order
		template.Visible = true
	end

	self:_QueueViewportUpdate()
end

function DinosaurUiController:_ClearUi()
	for _, template in pairs(self._Templates) do
		template:Destroy()
	end
	self._Templates = {}

	self._OwnedDinosaursByGuid = {}
end

function DinosaurUiController:_QueueViewportUpdate()
	if self._ViewportUpdateQueued then return end

	self._ViewportUpdateQueued = true
	task.defer(function()
		self._ViewportUpdateQueued = false
		self:_UpdateViewportModels()
	end)
end

function DinosaurUiController:_IsTemplateInView(template)
	local scrollFrame = self._Gui.DinosaurList
	local scrollPosition = scrollFrame.AbsolutePosition
	local scrollSize = scrollFrame.AbsoluteSize
	local templatePosition = template.AbsolutePosition
	local templateSize = template.AbsoluteSize
	return templateSize.X > 0 and templateSize.Y > 0
		and templatePosition.X < scrollPosition.X + scrollSize.X
		and templatePosition.X + templateSize.X > scrollPosition.X
		and templatePosition.Y < scrollPosition.Y + scrollSize.Y
		and templatePosition.Y + templateSize.Y > scrollPosition.Y
end

function DinosaurUiController:_UpdateViewportModels()
	local uiOpen = self._Gui.Frame.Visible and self._Gui.DinosaurList.Visible

	for guid, template in pairs(self._Templates) do
		local entry = self._OwnedDinosaursByGuid[guid]
		local dinosaur = entry and entry.Dinosaur
		local viewportFrame = template.ViewportFrame :: ViewportFrame
		local inView = uiOpen and template.Visible and viewportFrame.Visible and self:_IsTemplateInView(template)
		if not inView then
			local worldModel = viewportFrame:FindFirstChildWhichIsA("WorldModel")
			if worldModel then
				worldModel:Destroy()
			end

			local camera = viewportFrame:FindFirstChildWhichIsA("Camera")
			if camera then
				camera:Destroy()
			end
		end

		if inView and dinosaur and entry.Info and (not viewportFrame:FindFirstChildWhichIsA("WorldModel")) then
			DinosaurUtils.CreateViewportModel(viewportFrame, dinosaur.Id, dinosaur.Scale, dinosaur.Mutation)
		end
	end
end

function DinosaurUiController:_GetRandomPlacementCFrame(scale)
	local plot = self._PlotController:GetPlot()
	local floor = plot and plot.Instance:FindFirstChild("_Floor")
	if not floor or not floor:IsA("BasePart") then
		return
	end

	local size = floor.Size
	local margin = math.min(4 * scale, size.X / 2, size.Z / 2)
	local x = random:NextNumber(-size.X / 2 + margin, size.X / 2 - margin)
	local z = random:NextNumber(-size.Z / 2 + margin, size.Z / 2 - margin)
	local yaw = random:NextNumber(-math.pi, math.pi)
	return floor.CFrame * CFrame.new(x, size.Y / 2, z) * CFrame.Angles(0, yaw, 0)
end

function DinosaurUiController:_EquipDinosaur(guid)
	if self._Placing or self._DinosaurController:IsDinosaurPlaced(guid) or self._DinosaurController:IsAtMaxCapacity() then
		return
	end

	local entry = self._OwnedDinosaursByGuid[guid]
	if not entry then return end

	local character = Player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local cframe = self:_GetRandomPlacementCFrame(entry.Dinosaur.Scale)
	if not cframe then return end

	self._Placing = true
	self._DinosaurService:PlaceDinosaur(guid, cframe):andThen(function()
		self._Placing = false
	end, function()
		self._Placing = false
	end)
end

function DinosaurUiController:_EquipBest()
	if self._Placing then return end

	self._Placing = true
	self._DinosaurService:EquipBestDinosaurs():andThen(function()
		self._Placing = false
	end, function()
		self._Placing = false
	end)
end

return DinosaurUiController
