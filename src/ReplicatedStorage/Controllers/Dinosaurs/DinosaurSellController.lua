local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local MoneySound = Sounds:WaitForChild("MoneySound")
local External = ReplicatedStorage:WaitForChild("External")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local MutationsEnum = require(ReplicatedStorage:WaitForChild("Enums"):WaitForChild("Mutations"))
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Components = ReplicatedStorage:WaitForChild("Components")
local GuiButton = require(GuiModules:WaitForChild("Button"))
local DinosaurDef = require(ReplicatedConfigs:WaitForChild("DinosaurDef"))
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local BonePileUtils = require(Utils:WaitForChild("BonePileUtils"))
local DinosaurUtils = require(Utils:WaitForChild("DinosaurUtils"))
local RarityColorUtils = require(Utils:WaitForChild("RarityColorUtils"))
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local BigNumbers = require(External:WaitForChild("BigNumbers"))
local Knit = require(External:WaitForChild("Knit"))

local DinosaurSellController = {
	Name = "DinosaurSellController",
	_HudController = nil,
	_InventoryController = nil,
	_DinosaurService = nil,
	_Templates = {},
	_ViewportUpdateQueued = false,
	_OwnedDinosaursByGuid = {}
}

function DinosaurSellController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local sellFrame = mainGui:WaitForChild("SellFrame")

	self._Gui = {
		Frame = sellFrame,
		DinosaurList = sellFrame:WaitForChild("DinosaurList"):WaitForChild("DinosaurList"),
		DinosaurTemplate = sellFrame:WaitForChild("Templates"):WaitForChild("DinosaurTemplate"),
		SellAllButton = sellFrame:WaitForChild("SellAllButton"),
		ExitButton = sellFrame:WaitForChild("ExitButton")
	}

	local sellAllButton = GuiButton.new(self._Gui.SellAllButton)
	sellAllButton:SetCallback(function()
		self._DinosaurService:SellAllDinosaurs():andThen(function(success)
			if success then
				UtilFunctions.PlayCopyOfSound(MoneySound)
			end
		end)
	end)

	local exitButton = GuiButton.new(self._Gui.ExitButton)
	exitButton:SetCallback(function()
		self:SetVisibility(false, true)
	end)
end

function DinosaurSellController:KnitStart()
	self._HudController = require(ReplicatedStorage.Controllers.Hud.HudController)
	self._InventoryController = require(ReplicatedStorage.Controllers.Inventory.InventoryController)
	self._SellStoreComponent = require(Components.SellStore)
	self._DinosaurService = Knit.GetService("DinosaurService")

	self._InventoryController.InventoryUpdatedSignal:Connect(function()
		self:_UpdateUi()
	end)

	self._Gui.Frame:GetPropertyChangedSignal("Visible"):Connect(function()
		self:_QueueViewportUpdate()
	end)
	self._Gui.DinosaurList:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		self:_QueueViewportUpdate()
	end)
	self._Gui.Frame:GetPropertyChangedSignal("Size"):Connect(function()
		self:_QueueViewportUpdate()
	end)

	self:_UpdateUi()

	self:_SetupSellStores()
end

function DinosaurSellController:SetVisibility(visible, toTween)
	local hideTrack = require(self._Gui.Frame.Animator).Hide
	local openTrack = require(self._Gui.Frame.Animator).Open

	if visible then
		self._Gui.Frame.Visible = visible
		self._HudController:SetCurrentlyActiveFrame(self)
		hideTrack:Stop()
		self._Hiding = false
		self:_UpdateUi()
		openTrack:Play()
	else
		local function clear()
			self._Gui.Frame.Visible = visible
			self:_ClearUi()
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

function DinosaurSellController:_UpdateUi()
	if not self._Gui.Frame.Visible then return end

	local dinosaurs = {}
	local owned = {}

	for _, item in ipairs(self._InventoryController:GetNonFungibleItems()) do
		local info = DinosaurDef.GetDinosaurInfo(item.ItemId)
		if info then
			local dinosaur = {
				Id = item.ItemId,
				Guid = item.Guid,
				Scale = BonePileUtils.GetScale(item.Metadata and item.Metadata.Scale),
				Mutation = item.Metadata and item.Metadata.Mutation or MutationsEnum.Normal,
				ZoneId = item.Metadata and item.Metadata.ZoneId
			}
			local entry = {
				Dinosaur = dinosaur,
				Info = info,
				Income = DinosaurDef.GetIncome(item.ItemId, dinosaur.Scale, dinosaur.Mutation, dinosaur.ZoneId),
				Mutation = dinosaur.Mutation
			}
			table.insert(dinosaurs, entry)
			owned[dinosaur.Guid] = entry
		end
	end

	table.sort(dinosaurs, function(a, b)
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

			local sellButton = GuiButton.new(template.SellButton)
			sellButton:SetCallback(function()
				self:_SellDinosaur(guid)
			end)

			template.Parent = self._Gui.DinosaurList
		end

		template.NameText.Text = entry.Info.Name or dinosaur.Id
		template.RarityText.Text = entry.Info.Rarity or ""
		template.RarityText.TextColor3 = self._Gui.DinosaurTemplate.RarityText.TextColor3
		RarityColorUtils.SetColor(template.RarityText, entry.Info.Rarity)
		template.SizeText.Text = string.format("Size: %.1fx", dinosaur.Scale)
		template.IncomeFrame.AmountFrame.AmountText.Text = string.format("%s", BigNumbers.GetNumberDisplay(math.round(entry.Income)))
		local sellPrice = DinosaurDef.GetSellPrice(dinosaur.Id, dinosaur.Scale, dinosaur.Mutation, dinosaur.ZoneId)
		template.SellAmountFrame.AmountFrame.AmountText.Text = string.format("%s", BigNumbers.GetNumberDisplay(sellPrice))
		template.SellButton.Visible = true

		local mutation = dinosaur.Mutation
		template.MutationText.Visible = mutation ~= "Normal"
		template.MutationText.Text = mutation
		template.MutationText.UIGradient.Color = Constants.MutationGradients[mutation] or ColorSequence.new(Color3.fromRGB(255, 255, 255))
		template.LayoutOrder = order
		template.Visible = true
	end

	self:_QueueViewportUpdate()
end

function DinosaurSellController:_ClearUi()
	for _, template in pairs(self._Templates) do
		template:Destroy()
	end
	self._Templates = {}
	self._OwnedDinosaursByGuid = {}
end

function DinosaurSellController:_QueueViewportUpdate()
	if self._ViewportUpdateQueued then return end

	self._ViewportUpdateQueued = true
	task.defer(function()
		self._ViewportUpdateQueued = false
		self:_UpdateViewportModels()
	end)
end

function DinosaurSellController:_IsTemplateInView(template)
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

function DinosaurSellController:_UpdateViewportModels()
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

function DinosaurSellController:_SellDinosaur(guid)
	if not self._OwnedDinosaursByGuid[guid] then return end

	self._DinosaurService:SellDinosaur(guid):andThen(function(success)
		if success then
			UtilFunctions.PlayCopyOfSound(MoneySound)
		end
	end)
end

function DinosaurSellController:_SetupSellStores()
	for _, sellStore in pairs(self._SellStoreComponent:GetAll()) do
		self:_SetupSellStore(sellStore)
	end

	self._SellStoreComponent.Started:Connect(function(sellStore)
		self:_SetupSellStore(sellStore)
	end)
end

function DinosaurSellController:_SetupSellStore(sellStore)
	sellStore.Interacted:Connect(function()
		if self._Gui.Frame.Visible then return end

		self:SetVisibility(true, true)
	end)
end

return DinosaurSellController
