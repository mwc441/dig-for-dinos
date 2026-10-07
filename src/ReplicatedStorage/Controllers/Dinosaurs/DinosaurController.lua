local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local random = Random.new()

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local MoneySound = Sounds:WaitForChild("MoneySound")
local External = ReplicatedStorage:WaitForChild("External")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local BonePileUtils = require(Utils:WaitForChild("BonePileUtils"))
local DinosaurDef = require(ReplicatedStorage:WaitForChild("ReplicatedConfigs"):WaitForChild("DinosaurDef"))
local Signal = require(External:WaitForChild("Signal"))
local TableUtils = require(External:WaitForChild("TableUtils"))
local Dinosaur = require(script.Parent.Dinosaur)
local Knit = require(External:WaitForChild("Knit"))

local DinosaurController = {
	Name = "DinosaurController",
	_PlotController = nil,
	_DataController = nil,
	_InventoryController = nil,
	_ReplicationController = nil,
	_DinosaurService = nil,
	_DinosaurData = {},
	_Dinosaurs = {},
	_LocalDinosaursHidden = false,
	DinosaurDataUpdatedSignal = Signal.new()
}

function DinosaurController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local incomeParticlesFrame = mainGui:WaitForChild("IncomeParticleFrame")

	self._Gui = {
		IncomeParticleFrame = incomeParticlesFrame,
		CashTemplate = incomeParticlesFrame:WaitForChild("Templates"):WaitForChild("CashTemplate")
	}
end

function DinosaurController:KnitStart()
	self._DataController = require(ReplicatedStorage.Controllers.Data.DataController)
	self._InventoryController = require(ReplicatedStorage.Controllers.Inventory.InventoryController)
	self._PlotController = require(ReplicatedStorage.Controllers.Plots.PlotController)
	self._ReplicationController = require(ReplicatedStorage.Controllers.Replication.ReplicationController)
	self._DinosaurService = Knit.GetService("DinosaurService")

	local folder = Instance.new("Folder")
	folder.Name = "_Dinosaurs"
	folder.Parent = Workspace
	self._Folder = folder

	self._DinosaurService.IncomesUpdated:Connect(function(incomesPerDino)
		for guid, totalIncome in pairs(incomesPerDino) do
			local dinosaur = self._Dinosaurs[guid]
			if dinosaur then
				dinosaur:SetIncome(totalIncome)
			end
		end
	end)

	self._ReplicationController.ReplicatorReplicatedSignal:Connect(function(replicationData)
		if replicationData.Type == "Dinosaur" then
			self:_CreateDinosaur(replicationData)
		end
	end)
	self._ReplicationController.ReplicatorUpdatedSignal:Connect(function(replicationData)
		if replicationData.Type ~= "Dinosaur" then
			return
		end

		local dinosaur = self._Dinosaurs[replicationData.Guid]
		if dinosaur then
			dinosaur:Update(replicationData)
		end
	end)
	self._ReplicationController.ReplicatorEventSignal:Connect(function(guid, eventName, ...)
		local dinosaur = self._Dinosaurs[guid]
		if dinosaur then
			dinosaur:FireEvent(eventName, ...)
		end
	end)
	self._ReplicationController.ReplicatorDereplicatedSignal:Connect(function(guid)
		self:_DestroyDinosaur(guid)
	end)

	for _, replicationData in ipairs(self._ReplicationController:GetReplicatorsOfType("Dinosaur")) do
		self:_CreateDinosaur(replicationData)
	end

	self._PlotController.PlotsChanged:Connect(function()
		self:_ReconcileDinosaurs()
	end)

	local dinosaursData = self._DataController:GetProfileData("Dinosaurs")
	if dinosaursData then
		self:_UpdateDinosaurs(dinosaursData)
	end

	self._DataController.ProfileUpdatedSignal:Connect(function(profileData)
		if profileData.Dinosaurs then
			self:_UpdateDinosaurs(profileData.Dinosaurs)
		end
	end)
end

-- DATA STUFF
function DinosaurController:_UpdateDinosaurs(dinosaurData)
	if not TableUtils.Equals(self._DinosaurData, dinosaurData) then
		self._DinosaurData = dinosaurData
		self.DinosaurDataUpdatedSignal:Fire()
	end
end

function DinosaurController:GetMaxDinosaurs()
	return self._PlotController:GetCapacity()
end

function DinosaurController:GetDinosaurCount()
	return #(self._DinosaurData.Placed or {})
end

function DinosaurController:GetOwnedDinosaurs()
	local dinosaurs = {}

	for _, placedDinosaur in ipairs(self._DinosaurData.Placed or {}) do
		table.insert(dinosaurs, {
			Id = placedDinosaur.Id,
			Guid = placedDinosaur.Guid,
			Scale = BonePileUtils.GetScale(placedDinosaur.Scale)
		})
	end

	for _, item in ipairs(self._InventoryController:GetNonFungibleItems()) do
		if DinosaurDef.GetDinosaurInfo(item.ItemId) then
			table.insert(dinosaurs, {
				Id = item.ItemId,
				Guid = item.Guid,
				Scale = BonePileUtils.GetScale(item.Metadata and item.Metadata.Scale)
			})
		end
	end

	return dinosaurs
end

function DinosaurController:IsDinosaurPlaced(guid)
	for _, placedDinosaur in ipairs(self._DinosaurData.Placed or {}) do
		if placedDinosaur.Guid == guid then
			return true
		end
	end

	return false
end

function DinosaurController:IsDinosaurOwned(guid)
	if self:IsDinosaurPlaced(guid) then
		return true
	end

	local item = self._InventoryController:GetNonFungibleItem(guid)
	return item ~= nil and DinosaurDef.GetDinosaurInfo(item.ItemId) ~= nil
end

function DinosaurController:IsAtMaxCapacity()
	return self:GetDinosaurCount() >= self:GetMaxDinosaurs()
end

-- REPLICATOR STUFF
function DinosaurController:_CreateDinosaur(replicationData)
	local guid = replicationData.Guid
	if self._Dinosaurs[guid] then
		return self._Dinosaurs[guid]
	end

	local dinosaur = Dinosaur.new(replicationData)

	dinosaur.Touched:Connect(function()
		if not self._PlotController:IsInsidePlot() then return end

		local income = dinosaur:GetIncome()
		if income <= 0 then return end

		dinosaur:SetIncome(0)

		UtilFunctions.PlayCopyOfSound(MoneySound)

		self:_DoIncomeGuiParticles()

		self._DinosaurService:ClaimIncome(guid)
	end)

	self._Dinosaurs[guid] = dinosaur
	self:_ReconcileDinosaur(guid)
	return dinosaur
end

function DinosaurController:_ReconcileDinosaurs()
	for guid in pairs(self._Dinosaurs) do
		self:_ReconcileDinosaur(guid)
	end
end

function DinosaurController:HideDinosaurs()
	self._LocalDinosaursHidden = true
	for _, dinosaur in pairs(self._Dinosaurs) do
		if dinosaur:GetOwnerUserId() == Player.UserId then
			dinosaur:Hide()
		end
	end
end

function DinosaurController:ShowDinosaurs()
	self._LocalDinosaursHidden = false
	for guid, dinosaur in pairs(self._Dinosaurs) do
		if dinosaur:GetOwnerUserId() == Player.UserId then
			self:_ReconcileDinosaur(guid)
		end
	end
end

function DinosaurController:_ReconcileDinosaur(guid)
	local dinosaur = self._Dinosaurs[guid]
	if self._LocalDinosaursHidden and dinosaur:GetOwnerUserId() == Player.UserId then
		dinosaur:Hide()
		return
	end

	local owner = Players:GetPlayerByUserId(dinosaur:GetOwnerUserId())
	local plot = self._PlotController:GetPlotForPlayer(owner)
	local floor = plot and plot.Instance:FindFirstChild("_Floor")

	if not floor or not floor:IsA("BasePart") then
		dinosaur:Hide()
		return
	end

	dinosaur:Show(plot, self._Folder)
end

function DinosaurController:_DestroyDinosaur(guid)
	local dinosaur = self._Dinosaurs[guid]
	if dinosaur then
		dinosaur:Destroy()
	end
	self._Dinosaurs[guid] = nil
end

-- GUI STUFF
function DinosaurController:_DoIncomeGuiParticles()
	local frame = self._Gui.IncomeParticleFrame
	local template = self._Gui.CashTemplate
	local frameSize = frame.AbsoluteSize

	for _ = 1, random:NextInteger(6, 8) do
		local cash = template:Clone()
		local sizeMultiplier = random:NextNumber(0.9, 1.2)
		local fullSize = UDim2.new(
			template.Size.X.Scale * sizeMultiplier,
			template.Size.X.Offset * sizeMultiplier,
			template.Size.Y.Scale * sizeMultiplier,
			template.Size.Y.Offset * sizeMultiplier
		)
		local width = frameSize.X * fullSize.X.Scale + fullSize.X.Offset
		local height = frameSize.Y * fullSize.Y.Scale + fullSize.Y.Offset
		local rotation = template.Rotation + random:NextNumber(-20, 20)
		local rotationRadians = math.rad(rotation)
		local rotatedWidth = math.abs(width * math.cos(rotationRadians)) + math.abs(height * math.sin(rotationRadians))
		local rotatedHeight = math.abs(width * math.sin(rotationRadians)) + math.abs(height * math.cos(rotationRadians))
		local xMargin = frameSize.X > 0 and math.clamp(rotatedWidth / (2 * frameSize.X), 0, 0.5) or 0.5
		local yMargin = frameSize.Y > 0 and math.clamp(rotatedHeight / (2 * frameSize.Y), 0, 0.5) or 0.5

		cash.AnchorPoint = Vector2.new(0.5, 0.5)
		cash.Position = UDim2.fromScale(
			random:NextNumber(xMargin, 1 - xMargin),
			random:NextNumber(yMargin, 1 - yMargin)
		)
		cash.Rotation = rotation + random:NextNumber(-90, 90)
		cash.Size = UDim2.fromScale(0, 0)
		cash.Visible = true
		cash.Parent = frame

		local growTween = TweenService:Create(cash, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = fullSize,
			Rotation = rotation
		})
		local shrinkTween = TweenService:Create(cash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.fromScale(0, 0),
			Rotation = cash.Rotation + random:NextNumber(-90, 90)
		})
		local holdTime = random:NextNumber(0.5, 0.75)

		growTween.Completed:Once(function(playbackState)
			if playbackState ~= Enum.PlaybackState.Completed then return end
			task.delay(holdTime, function()
				if cash.Parent then
					shrinkTween:Play()
				end
			end)
		end)
		shrinkTween.Completed:Once(function()
			cash:Destroy()
		end)

		growTween:Play()
	end
end

return DinosaurController
