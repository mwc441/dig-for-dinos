local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CameraModel = {}
CameraModel.__index = CameraModel

function CameraModel.new(pvInstance : PVInstance, offset : CFrame)
	local self = {}
	setmetatable(self, CameraModel)

	self._Model = pvInstance
	self._Offset = offset

	self:_Setup()

	self._AncestryChangedConnect = pvInstance.AncestryChanged:Connect(function()
		if not pvInstance.Parent then
			self:Destroy()
		end
	end)

	return self
end

function CameraModel:SetOffset(offset : CFrame)
	self._Offset = offset

	self:_PivotModel()
end

function CameraModel:_Setup()
	local function setCollisionGroup(part)
		if not part:IsA("BasePart") then
			return
		end

		part.CollisionGroup = "CameraModel"
	end

	setCollisionGroup(self._Model)
	for _, descendant in pairs(self._Model:GetDescendants()) do
		setCollisionGroup(descendant)
	end

	self._RenderSteppedConnect = RunService.RenderStepped:Connect(function()
		self:_PivotModel()
	end)

	self:_PivotModel()
end

function CameraModel:_PivotModel()
	local currentCamera = Workspace.CurrentCamera

	self._Model:PivotTo(currentCamera.CFrame * self._Offset)
end

function CameraModel:Destroy()
	if self._AncestryChangedConnect then
		self._AncestryChangedConnect:Disconnect()
	end
	self._AncestryChangedConnect = nil

	if self._RenderSteppedConnect then
		self._RenderSteppedConnect:Disconnect()
	end
	self._RenderSteppedConnect = nil
end

return CameraModel