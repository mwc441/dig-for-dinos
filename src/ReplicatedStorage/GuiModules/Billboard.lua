local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local External = ReplicatedStorage:WaitForChild("External")
local Signal = require(External:WaitForChild("Signal"))

local Billboard = {}
Billboard.__index = Billboard

function Billboard.new(billboard, distance)
	local self = {}
	setmetatable(self, Billboard)

	self._Object = billboard

	self._TweenWhenNear = true
	self._Tween = nil
	self._Heartbeat = nil
	self._TweenTime = 0.15
	self._TweenDistance = distance or 5
	self._OriginalSize = billboard.Size
	self._PlayerIsNear = false

	self.OnShowingChanged = Signal.new()

	self.OnShowingChanged:Connect(function() end) -- To avoid queue build-up

	billboard.Size = UDim2.new(0, 0, 0, 0)
	billboard.Enabled = false

	self._Open = false

	self:EnableDistance()

	local connection
	connection = billboard.AncestryChanged:Connect(function()
		if not billboard.Parent then
			self:Destroy()
			connection:Disconnect()
		end
	end)

	return self
end

function Billboard:EnableDistance()
	self:_SetupHeartbeat()
end

function Billboard:DisableDistance()
	self._PlayerIsNear = false
	self:_DisconnectHeartbeat()
end

function Billboard:_SetupHeartbeat()
	self:_DisconnectHeartbeat()

	self._Heartbeat = RunService.Heartbeat:Connect(function()
		if not self._TweenWhenNear then
			return
		end

		if not self._Object.Adornee then
			return
		end

		local character = Player.Character
		if not character then
			return
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			return
		end

		local distance = (rootPart.Position - self._Object.Adornee:GetPivot().Position).Magnitude
		if (distance <= self._TweenDistance) then
			if not self._PlayerIsNear then
				self._PlayerIsNear = true
				self:TweenGuiOpen()
			end
		else
			if self._PlayerIsNear then
				self._PlayerIsNear = false
				self:TweenGuiClose()
			end
		end
	end)
end

function Billboard:_DisconnectHeartbeat()
	if self._Heartbeat then
		self._Heartbeat:Disconnect()
	end
	self._Heartbeat = nil
end

function Billboard:EnableMouseDetection(raycastParams)
	if not self._Object.Adornee then
		return
	end

	self:_ShootRaycast(raycastParams)

	self._MouseConnect = Mouse.Move:Connect(function()
		self:_ShootRaycast(raycastParams)
	end)
end

function Billboard:_ShootRaycast(raycastParams)
	local camera = game.Workspace.CurrentCamera

	local unitRay = camera:ScreenPointToRay(Mouse.X, Mouse.Y)

	local raycastResult = game.Workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
	if raycastResult and (not self._PlayerIsNear) then
		self:MouseHovered(true)
	elseif (not raycastResult) and (not self._PlayerIsNear) then
		self:MouseHovered(false)
	end
end

function Billboard:MouseHovered(hovered)
	if hovered and (not self._PlayerIsNear) then
		self:TweenGuiOpen()
	elseif (not hovered) and (not self._PlayerIsNear) then
		self:TweenGuiClose()
	end
end

function Billboard:DisableMouseDetection()
	if self._MouseConnect then
		self._MouseConnect:Disconnect()
	end
	self._MouseConnect = nil
end

function Billboard:TweenGuiOpen()
	if self._Open then
		return
	end

	self._Open = true

	if self._Tween then
		self._Tween:Cancel()
	end
	self._Tween = nil

	self._Object.Enabled = true

	self._Object.Size = UDim2.new(0, 0, 0, 0)

	local tweenInfo = TweenInfo.new(self._TweenTime)
	local tween = TweenService:Create(self._Object, tweenInfo, {
		Size = self._OriginalSize
	})

	self._Tween = tween

	self.OnShowingChanged:Fire(true)

	tween:Play()
end

function Billboard:TweenGuiClose()
	if not self._Open then
		return
	end

	self._Open = false

	if self._Tween then
		self._Tween:Cancel()
	end
	self._Tween = nil

	local tweenInfo = TweenInfo.new(self._TweenTime)
	local tween = TweenService:Create(self._Object, tweenInfo, {
		Size = UDim2.new(0, 0, 0, 0)
	})

	self._Tween = tween

	tween:Play()

	self.OnShowingChanged:Fire(false)

	tween.Completed:Connect(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed then
			self._Object.Enabled = false
		end
	end)
end

function Billboard:Destroy()
	if self._Tween then
		self._Tween:Cancel()
	end
	self._Tween = nil

	self:_DisconnectHeartbeat()

	if self.OnShowingChanged then
		self.OnShowingChanged:Destroy()
	end
	self.OnShowingChanged = nil

	self:DisableMouseDetection()

	self._Object.Size = self._OriginalSize
end

return Billboard