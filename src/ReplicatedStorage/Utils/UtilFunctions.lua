local Debris = game:GetService("Debris")
local GroupService = game:GetService("GroupService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UtilFunctions = {}

function UtilFunctions.GetHighestGroupRankForPlayer(player: Player, groupId: number): number?
	local success, result = pcall(function()
		return GroupService:GetRolesInGroupAsync(player.UserId, groupId)
	end)

	if not success then
		return nil
	end

	if not result.IsMember then
		return nil
	end

	local highestRank = -math.huge

	for _, role in ipairs(result.Roles or {}) do
		local rank = role.Rank or 0
		if rank > highestRank then
			highestRank = rank
		end
	end

	return highestRank
end

function UtilFunctions.GetNonInvisibleRaycastResult(origin, direction, params : RaycastParams) : RaycastResult?
	local result = nil
	while not result do
		local raycastResult = game.Workspace:Raycast(origin, direction, params)
		if not raycastResult then
			break
		end

		if raycastResult.Instance.Transparency == 1 then
			params:AddToFilter(raycastResult.Instance)
		else
			result = raycastResult
		end
	end

	return result
end

function UtilFunctions.GetNonInvisibleRaycastResultOfCollisionGroup(origin, direction, params, collisionGroup : string) : RaycastResult?
	local result = nil
	while not result do
		local raycastResult = UtilFunctions.GetNonInvisibleRaycastResult(origin, direction, params)
		if not raycastResult then
			break
		end

		if raycastResult.Instance.CollisionGroup ~= collisionGroup then
			params:AddToFilter(raycastResult.Instance)
		else
			result = raycastResult
		end
	end

	return result
end

function UtilFunctions.RaycastResultToCFrame(result: RaycastResult): CFrame
	local up = result.Normal
	local right = up:Cross(Vector3.xAxis)

	-- Handle vertical surfaces
	if right.Magnitude < 1e-5 then
		right = up:Cross(Vector3.zAxis)
	end

	right = right.Unit
	local forward = right:Cross(up)

	return CFrame.fromMatrix(result.Position, right, up, -forward)
end

function UtilFunctions.PlayCopyOfSound(sound)
	local newSound = sound:Clone()
	newSound.Parent = sound.Parent

	newSound:Play()

	newSound.Ended:Connect(function()
		newSound:Destroy()
	end)

	newSound.Stopped:Connect(function()
		newSound:Destroy()
	end)

	return newSound
end

function UtilFunctions.PlaySoundAtLocation(sound, cframe)
	-- This function takes a non-looping sound
	-- and play's it once at a given location
	local newPart = Instance.new("Part")
	newPart.Anchored = true
	newPart.CanCollide = false
	newPart.CanQuery = false
	newPart.Transparency = 1
	newPart.CFrame = cframe
	newPart.Parent = game.Workspace

	local newSound = sound:Clone()
	newSound.Parent = newPart

	newSound:Play()

	newSound.Ended:Connect(function()
		newPart:Destroy()
	end)

	newSound.Stopped:Connect(function()
		newPart:Destroy()
	end)

	return newSound
end

function UtilFunctions.EnableBeams(instance)
	-- This function enables all beam descendants
	-- and also enables the instance (if its a beam)
	if instance:IsA("Beam") then
		instance.Enabled = true
	end

	for _, descendant in pairs(instance:GetDescendants()) do
		if descendant:IsA("Beam") then
			descendant.Enabled = true
		end
	end
end

function UtilFunctions.DisableBeams(instance)
	-- This function disables all beam descendants
	-- and also disables the instance (if its a beam)
	if instance:IsA("Beam") then
		instance.Enabled = false
	end

	for _, descendant in pairs(instance:GetDescendants()) do
		if descendant:IsA("Beam") then
			descendant.Enabled = false
		end
	end
end

function UtilFunctions.EnableLights(instance)
	-- This function enables all lights
	-- and also enabled the instance (if its a light)
	if instance:IsA("Light") then
		instance.Enabled = true
	end

	for _, descendant in pairs(instance:GetDescendants()) do
		if descendant:IsA("Light") then
			descendant.Enabled = true
		end
	end
end

function UtilFunctions.DisableLights(instance)
	-- This function disables all lights
	-- and also disables the instance (if its a light)
	if instance:IsA("Light") then
		instance.Enabled = false
	end

	for _, descendant in pairs(instance:GetDescendants()) do
		if descendant:IsA("Light") then
			descendant.Enabled = false
		end
	end
end

function UtilFunctions.DisableParticles(instance)
	-- This function disables all particle effect descendants
	-- and also disables the instance (if its a particle emitter)

	if instance:IsA("ParticleEmitter") then
		instance.Enabled = false
	end

	for _, descendant in pairs(instance:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
		end
	end
end

function UtilFunctions.EnableParticles(instance)
	if instance:IsA("ParticleEmitter") then
		instance.Enabled = true
	end

	for _, descendant in pairs(instance:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = true
		end
	end
end

function UtilFunctions.EmitParticles(instance)
	-- This function takes an instance and searches through it's descendants for
	-- ParticleEmitters. If it finds an emitter, it will force it to emit a given
	-- number of particles. The amount is dictated by the ParticleEmitters
	-- attribute "EmitCount" (Defaults to Rate if there is no EmitCount attribute)
	-- The instance given can also be a ParticleEmitter and will emit

	local particlesToEmit = {}
	if instance:IsA("ParticleEmitter") then
		table.insert(particlesToEmit, instance)
	end

	for _, descendant in pairs(instance:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			table.insert(particlesToEmit, descendant)
		end
	end

	for _, particleEmitter in pairs(particlesToEmit) do
		local count = particleEmitter:GetAttribute("EmitCount") or particleEmitter.Rate
		if not count then
			continue
		end

		particleEmitter:Emit(count)
	end
end

function UtilFunctions.EnableTrails(instance)
	if instance:IsA("Trail") then
		instance.Enabled = true
	end

	for _, descendant in pairs(instance:GetDescendants()) do
		if descendant:IsA("Trail") then
			descendant.Enabled = true
		end
	end
end

function UtilFunctions.DisableTrails(instance)
	if instance:IsA("Trail") then
		instance.Enabled = false
	end

	for _, descendant in pairs(instance:GetDescendants()) do
		if descendant:IsA("Trail") then
			descendant.Enabled = false
		end
	end
end

function UtilFunctions.PlaySounds(instance)
	for _, descendant : Sound in pairs(instance:GetDescendants()) do
		if descendant:IsA("Sound") then
			descendant:Play()
		end
	end
end

function UtilFunctions.GetLongestEmitter(instance)
	local longestEmitTime = 0
	local longestEmitter
	for _, descendant in pairs(instance:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			if descendant.Lifetime.Max > longestEmitTime then
				longestEmitTime = descendant.Lifetime.Max
				longestEmitter = descendant
			end
		end
	end

	return longestEmitter, longestEmitTime
end

function UtilFunctions.GetLongestSound(instance)
	local longestSoundTime = 0
	local longestSound
	for _, descendant : Sound in pairs(instance:GetDescendants()) do
		if descendant:IsA("Sound") then
			while not descendant.IsLoaded do
				task.wait()
			end

			if descendant.TimeLength > longestSoundTime then
				longestSoundTime = descendant.TimeLength
				longestSound = descendant
			end
		end
	end

	return longestSound, longestSoundTime
end

function UtilFunctions.ScaleZOffsetOfParticles(instance, scale)
	for _, descendant in pairs(instance:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.ZOffset = descendant.ZOffset * scale
		end
	end
end

function UtilFunctions.GetRandomPointInsidePart(part)
	local newRandom = Random.new()

	local randomX = ((newRandom:NextInteger(0, 1) * 2) - 1) * newRandom:NextNumber() * (part.Size.X / 2)
	local randomY = ((newRandom:NextInteger(0, 1) * 2) - 1) * newRandom:NextNumber() * (part.Size.Y / 2)
	local randomZ = ((newRandom:NextInteger(0, 1) * 2) - 1) * newRandom:NextNumber() * (part.Size.Z / 2)

	local randomVector = Vector3.new(randomX, randomY, randomZ)
	local position = part.Position + randomVector
	return position, randomVector
end

function UtilFunctions.GetRandomPointInsideBox(cframe, size)
	local newRandom = Random.new()

	local randomX = ((newRandom:NextInteger(0, 1) * 2) - 1) * newRandom:NextNumber() * (size.X / 2)
	local randomY = ((newRandom:NextInteger(0, 1) * 2) - 1) * newRandom:NextNumber() * (size.Y / 2)
	local randomZ = ((newRandom:NextInteger(0, 1) * 2) - 1) * newRandom:NextNumber() * (size.Z / 2)

	local randomVector = Vector3.new(randomX, randomY, randomZ)
	local position = cframe.Position + randomVector
	return position, randomVector
end

function UtilFunctions.GetClosestPointToBox(cframe, size, point)
	-- Given a box (a cframe and size), you can find the closest point on the surface
	-- of the box to the given point
	-- This can be useful for finding the closest point on a part to a player

	local Transform = cframe:PointToObjectSpace(point) -- Transform into local space
	local HalfSize = size * 0.5
	return cframe * Vector3.new( -- Clamp & transform into world space
		math.clamp(Transform.x, -HalfSize.x, HalfSize.x),
		math.clamp(Transform.y, -HalfSize.y, HalfSize.y),
		math.clamp(Transform.z, -HalfSize.z, HalfSize.z)
	)
end

function UtilFunctions.SetPercentageForCircleClockwise(circle, percentage)
	-- Given a circle gui, set the percentage and set the gradients to the
	-- correct rotations. Percentage is a number 0-1

	local leftGradient = circle:FindFirstChild("LeftGradient", true)
	if not leftGradient then
		return
	end

	local rightGradient = circle:FindFirstChild("RightGradient", true)
	if not rightGradient then
		return
	end

	local rotation = math.floor(math.clamp(percentage * 100 * 3.6, 0, 360))

	rightGradient.Rotation = math.clamp(rotation, 0, 180)
	leftGradient.Rotation = math.clamp(rotation, 180, 360)

	leftGradient.Enabled = rotation >= 180
	leftGradient.Parent.BackgroundTransparency = (rotation >= 180) and 0 or 1
end

function UtilFunctions.GetChildrenNamed(parent, name)
	local children = {}
	for _, child in pairs(parent:GetChildren()) do
		if child.Name == name then
			table.insert(children, child)
		end
	end

	return children
end

function UtilFunctions.GetDescendantsOfClass(parent, class)
	local descendants = {}
	for _, descendant in pairs(parent:GetDescendants()) do
		if descendant:IsA(class) then
			table.insert(descendants, descendant)
		end
	end

	return descendants
end

function UtilFunctions.AnchorAllDescendants(parent, anchored)
	for _, descendant in pairs(parent:GetDescendants()) do
		if not descendant:IsA("BasePart") then
			continue
		end

		descendant.Anchored = anchored
	end
end

function UtilFunctions.CanCollideAllDescendants(parent, canCollide)
	for _, descendant in pairs(parent:GetDescendants()) do
		if not descendant:IsA("BasePart") then
			continue
		end

		descendant.CanCollide = canCollide
	end
end

function UtilFunctions.CanQueryAllDescendants(parent, canQuery)
	for _, descendant in pairs(parent:GetDescendants()) do
		if not descendant:IsA("BasePart") then
			continue
		end

		descendant.CanQuery = canQuery
	end
end

function UtilFunctions.CanTouchAllDescendants(parent, canTouch)
	for _, descendant in pairs(parent:GetDescendants()) do
		if not descendant:IsA("BasePart") then
			continue
		end

		descendant.CanTouch = canTouch
	end
end

function UtilFunctions.CastShadowAllDescendants(parent, castShadow)
	for _, descendant in pairs(parent:GetDescendants()) do
		if not descendant:IsA("BasePart") then
			continue
		end

		descendant.CastShadow = castShadow
	end
end

function UtilFunctions.MasslessAllDescendants(parent, massless)
	for _, descendant in pairs(parent:GetDescendants()) do
		if not descendant:IsA("BasePart") then
			continue
		end

		descendant.Massless = massless
	end
end

function UtilFunctions.SetTransparencyAllDescendants(parent, transparency, onlyNonInvisible)
	for _, descendant in pairs(parent:GetDescendants()) do
		if not descendant:IsA("BasePart") then
			continue
		end

		if onlyNonInvisible and (descendant.Transparency >= 1) then
			continue
		end

		descendant.Transparency = transparency
	end
end

function UtilFunctions.SetCollisionGroupAllDescendants(parent, collisionGroup)
	for _, descendant in pairs(parent:GetDescendants()) do
		if not descendant:IsA("BasePart") then
			continue
		end

		descendant.CollisionGroup = collisionGroup
	end
end

function UtilFunctions.ShakeModel(model, totalTime, amplitude, frequency)
	totalTime = totalTime or 0
	amplitude = amplitude or 0
	frequency = frequency or 30

	local originalPivot = model:GetPivot()
	local total = 0
	local random = Random.new()
	local shakeOffset = Vector3.zero
	local connection

	connection = RunService.Heartbeat:Connect(function(dt)
		total += dt

		if total >= totalTime then
			model:PivotTo(originalPivot)
			connection:Disconnect()

			return
		end

		if math.floor((total - dt) * frequency) ~= math.floor(total * frequency) then
			shakeOffset = Vector3.new(
				random:NextNumber(-amplitude, amplitude),
				random:NextNumber(-amplitude, amplitude),
				random:NextNumber(-amplitude, amplitude)
			)
		end

		model:PivotTo(originalPivot * CFrame.new(shakeOffset))
	end)

	return connection
end

function UtilFunctions.TweenModelScale(model, goalScale, totalTime, scaleFunc, easingStyle, easingDirection)
	local function lerp(start, goal, alpha)
		return start + (goal - start) * alpha
	end

	local connection
	local originalScale = model:GetScale()
	local total = 0
	connection = RunService.Heartbeat:Connect(function(dt)
		total += dt

		local percentage = math.clamp(total / totalTime, 0, 1)

		if easingStyle and easingDirection then
			percentage = TweenService:GetValue(percentage, easingStyle, easingDirection)
		end

		local newScale = lerp(originalScale, goalScale, percentage)
		model:ScaleTo(newScale)

		if scaleFunc then
			scaleFunc(newScale)
		end

		if total >= totalTime then
			connection:Disconnect()
		end
	end)

	return connection
end

function UtilFunctions.TweenModelPivot(model, tweenInfo, endPivot)
	local obj = Instance.new("NumberValue")
	obj.Value = 0
	local tween = TweenService:Create(obj, tweenInfo, {
		Value = 1
	})

	local currentPivot = model:GetPivot()

	obj:GetPropertyChangedSignal("Value"):Connect(function()
		local newCFrame = currentPivot:Lerp(endPivot, obj.Value)
		model:PivotTo(newCFrame)
	end)

	tween.Completed:Connect(function()
		obj:Destroy()
	end)

	return tween
end

function UtilFunctions.TweenCFrame(beginCFrame, endCFrame, tweenInfo)
	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Value = beginCFrame

	local tween = TweenService:Create(cframeValue, tweenInfo, {
		Value = endCFrame
	})

	tween.Completed:Connect(function()
		cframeValue:Destroy()
	end)

	return tween, cframeValue
end

function UtilFunctions.TweenNumberValue(startNumber, endNumber, tweenInfo)
	local numberValue = Instance.new("NumberValue")
	numberValue.Value = startNumber

	local tween = TweenService:Create(numberValue, tweenInfo, {
		Value = endNumber
	})

	tween.Completed:Connect(function()
		numberValue:Destroy()
	end)

	return tween, numberValue
end

function UtilFunctions.CreateProximityPrompt(parent, args)
	args = args or {}

	local newProximityPrompt = Instance.new("ProximityPrompt")
	newProximityPrompt.KeyboardKeyCode = args.KeyboardKeyCode or Enum.KeyCode.E
	newProximityPrompt.ObjectText = args.ObjectText or ""
	newProximityPrompt.ActionText = args.ActionText or ""
	newProximityPrompt.RequiresLineOfSight = args.RequiresLineOfSight or false
	newProximityPrompt.GamepadKeyCode = args.GamepadKeyCode or Enum.KeyCode.ButtonX
	newProximityPrompt.MaxActivationDistance = args.MaxActivationDistance or 10
	newProximityPrompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	newProximityPrompt.HoldDuration = args.HoldDuration or 0
	newProximityPrompt.Style = args.Style or Enum.ProximityPromptStyle.Custom

	if args.Size then
		newProximityPrompt:SetAttribute("Size", args.Size)
	end

	newProximityPrompt.Parent = parent

	return newProximityPrompt
end

function UtilFunctions.EquipToolToCharacter(character, tool)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	humanoid:UnequipTools()

	local function equipAccessories()
		for _, accessory in pairs(tool:GetDescendants()) do
			if not accessory:IsA("Accessory") then
				continue
			end

			humanoid:AddAccessory(accessory)

			local accessoryObjectValue = Instance.new("ObjectValue", tool)
			accessoryObjectValue.Name = "AccessoryObject"
			accessoryObjectValue.Value = accessory
		end
	end

	local function removeAccessories()
		for _, accessoryObjectValue in pairs(tool:GetDescendants()) do
			if accessoryObjectValue.Name ~= "AccessoryObject" then
				continue
			end

			if not accessoryObjectValue.Value then
				continue
			end

			accessoryObjectValue.Value.Parent = tool
			accessoryObjectValue:Destroy()
		end
	end

	local handWeld
	local function weldToPlayer()
		if tool.RequiresHandle then
			return
		end

		local hand = character:FindFirstChild("RightHand")
		if not hand then
			return
		end

		if handWeld then
			handWeld:Destroy()
		end

		local weld = Instance.new("Motor6D")
		weld.Part0 = hand
		weld.Part1 = tool.PrimaryPart
		weld.Name = "RightGrip"
		weld.Parent = hand

		handWeld = weld
	end

	tool.Equipped:Connect(function()
		weldToPlayer()
		equipAccessories()
	end)

	tool.Parent = character

	tool.Unequipped:Connect(function()
		if handWeld then
			handWeld:Destroy()
		end

		removeAccessories()
	end)
end

function UtilFunctions.MoveModelByBoundingBox(model, cframe)
	-- This function is used to place a model, whose pivot is at its
	-- primary part, to where its bounding box will be centered at
	-- the given cframe
	if not model.PrimaryPart then
		model:PivotTo(cframe)

		return
	end

	local currentCFrame = model:GetBoundingBox()

	local primaryPartDifference = model.PrimaryPart.CFrame:ToObjectSpace(currentCFrame)

	model:PivotTo(cframe * primaryPartDifference:Inverse())
end

function UtilFunctions.EquipAccessoryToCharacter(character, accessory)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	local function equipAccessories()
		for _, childAccessory in pairs(accessory:GetDescendants()) do
			if not childAccessory:IsA("Accessory") then
				continue
			end

			humanoid:AddAccessory(childAccessory)

			local accessoryObjectValue = Instance.new("ObjectValue", accessory)
			accessoryObjectValue.Name = "AccessoryObject"
			accessoryObjectValue.Value = childAccessory
		end
	end

	local function removeAccessories()
		for _, accessoryObjectValue in pairs(accessory:GetDescendants()) do
			if accessoryObjectValue.Name ~= "AccessoryObject" then
				continue
			end

			if not accessoryObjectValue.Value then
				continue
			end

			accessoryObjectValue.Value.Parent = accessory
			accessoryObjectValue:Destroy()
		end
	end

	accessory.Parent = character

	equipAccessories()

	accessory.Destroying:Connect(function()
		removeAccessories()
	end)
end

function UtilFunctions.TriggerProximityPrompts(parent, excludeList)
	excludeList = excludeList or {}

	for _, child in pairs(parent:GetChildren()) do
		if child:IsA("ProximityPrompt") and (not table.find(excludeList, child)) then
			child:InputHoldBegin()
			child:InputHoldEnd()
		end
	end
end

function UtilFunctions.RemoveAllAttributes(instance)
	for name in pairs(instance:GetAttributes()) do
		instance:SetAttribute(name, nil)
	end
end

function UtilFunctions.Recolor(instance : Instance, color : Color3)
	-- Get surface appearance, color the SA
	local surfaceAppearances = UtilFunctions.GetDescendantsOfClass(instance, "SurfaceAppearance") :: {SurfaceAppearance}
	if instance:IsA("SurfaceAppearance") then
		table.insert(surfaceAppearances, instance)
	end

	if #surfaceAppearances > 0 then
		for _, surfaceAppearance in pairs(surfaceAppearances) do
			surfaceAppearance.Color = color
		end
	end

	-- If no surface appearance, find the mesh part/special mesh and remove texture id and color the base part
	local specialMeshes = UtilFunctions.GetDescendantsOfClass(instance, "SpecialMesh") :: {SpecialMesh}
	if instance:IsA("SpecialMesh") then
		table.insert(specialMeshes, instance)
	end

	for _, specialMesh in pairs(specialMeshes) do
		specialMesh.TextureId = ""
		specialMesh.VertexColor = Vector3.new(color.R, color.G, color.B)
	end

	local meshParts = UtilFunctions.GetDescendantsOfClass(instance, "MeshPart") :: {MeshPart}
	if instance:IsA("MeshPart") then
		table.insert(meshParts, instance)
	end

	for _, meshPart in pairs(meshParts) do
		meshPart.TextureID = ""
	end

	local parts = UtilFunctions.GetDescendantsOfClass(instance, "BasePart") :: {BasePart}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end

	for _, part in pairs(parts) do
		part.Color = color
	end
end

function UtilFunctions.RecolorSelection(instance : Instance, color : Color3, selection : number)
	local selectionParts = UtilFunctions.GetChildrenNamed(instance, tostring(selection))
	if (#selectionParts <= 0) and (selection == 1) then
		UtilFunctions.Recolor(instance, color)
	else
		for _, selectionPart in pairs(selectionParts) do
			UtilFunctions.Recolor(selectionPart, color)
		end
	end
end

function UtilFunctions.Retexture(instance : Instance, texture : string)
	local surfaceAppearances = UtilFunctions.GetDescendantsOfClass(instance, "SurfaceAppearance") :: {SurfaceAppearance}
	if instance:IsA("SurfaceAppearance") then
		table.insert(surfaceAppearances, instance)
	end

	for _, surfaceAppearance in pairs(surfaceAppearances) do
		surfaceAppearance:Destroy()
	end

	local specialMeshes = UtilFunctions.GetDescendantsOfClass(instance, "SpecialMesh") :: {SpecialMesh}
	if instance:IsA("SpecialMesh") then
		table.insert(specialMeshes, instance)
	end

	for _, specialMesh in pairs(specialMeshes) do
		specialMesh.TextureId = texture
	end

	local meshParts = UtilFunctions.GetDescendantsOfClass(instance, "MeshPart") :: {MeshPart}
	if instance:IsA("MeshPart") then
		table.insert(meshParts, instance)
	end

	for _, meshPart in pairs(meshParts) do
		meshPart.TextureID = texture
	end
end

function UtilFunctions.RetextureSelection(instance : Instance, texture : string, selection : number)
	local selectionParts = UtilFunctions.GetChildrenNamed(instance, tostring(selection))
	if (#selectionParts <= 0) and (selection == 1) then
		UtilFunctions.Retexture(instance, texture)
	else
		for _, selectionPart in pairs(selectionParts) do
			UtilFunctions.Retexture(selectionPart, texture)
		end
	end
end

function UtilFunctions.GetNumberedChildren(instance : Instance)
	local selections = {}
	for _, child in pairs(instance:GetChildren()) do
		local name = child.Name
		local selectionNumber = tonumber(name)
		if not selectionNumber then
			continue
		end

		if not table.find(selections, selectionNumber) then
			table.insert(selections, selectionNumber)
		end
	end

	table.sort(selections)

	return selections
end

function UtilFunctions.GetTimeStringFromTime(time)
	local timeLeft = time

	local daysLeft = math.floor(timeLeft / 24 / 60 / 60)

	timeLeft -= (daysLeft * 24 * 60 * 60)

	local hoursLeft = math.floor(timeLeft / 60 / 60)
	timeLeft -= (hoursLeft * 60 * 60)

	local minutesLeft = math.floor(timeLeft / 60)
	timeLeft -= (minutesLeft * 60)

	local secondsLeft = timeLeft
	if daysLeft > 0 then
		return string.format("%dd%dh", daysLeft, hoursLeft)
	else
		if hoursLeft <= 0 then
			if minutesLeft <= 0 then
				return string.format("%ds", secondsLeft)
			else
				return string.format("%dm%ds", minutesLeft, secondsLeft)
			end
		else
			return string.format("%dh%dm", hoursLeft, minutesLeft)
		end
	end
end

function UtilFunctions.GetColorFromColorSequence(sequence: ColorSequence, t: number): Color3
	t = t or 0.5

	local keypoints = sequence.Keypoints

	-- Edge case: no keypoints (shouldn't happen)
	if #keypoints == 0 then
		return Color3.new(1, 1, 1)
	end

	-- If only one keypoint, return it
	if #keypoints == 1 then
		return keypoints[1].Value
	end

	-- Find the two keypoints surrounding t
	for i = 1, #keypoints - 1 do
		local a = keypoints[i]
		local b = keypoints[i + 1]

		if t >= a.Time and t <= b.Time then
			local alpha = (t - a.Time) / (b.Time - a.Time)
			return a.Value:Lerp(b.Value, alpha)
		end
	end

	-- Fallback (if something weird happens)
	return keypoints[#keypoints].Value
end

function UtilFunctions.DoFlyingDebris(
	part: BasePart,
	debrisSize: Vector3,
	options: {
		Count: number?,
		Force: number?,
		UpwardBias: number?,
		CollisionGroup : string?,
		Lifetime: number?,
		Randomness: number?,
		ExplosionOrigin: Vector3?,
		Parent: Instance?,
	}?
)
	options = options or {}

	local count = options.Count or 12
	local force = options.Force or 60
	local upwardBias = options.UpwardBias or 0.6
	local collisionGroup = options.CollisionGroup or "Default"
	local lifetime = options.Lifetime or 5
	local randomness = options.Randomness or 0.35
	local origin = options.ExplosionOrigin
	local parent = options.Parent or Workspace

	for _ = 1, count do
		local cframe = origin and CFrame.new(origin) or (part.CFrame * CFrame.new(
			(math.random() - 0.5) * part.Size.X,
			(math.random() - 0.5) * part.Size.Y,
			(math.random() - 0.5) * part.Size.Z
		))

		local debrisPart = Instance.new("Part")
		debrisPart.Size = debrisSize * (1 + (math.random() - 0.5) * randomness)
		debrisPart.CollisionGroup = collisionGroup
		debrisPart.CFrame = cframe

		-- Visual consistency
		debrisPart.Color = part.Color
		debrisPart.Material = part.Material
		debrisPart.MaterialVariant = part.MaterialVariant
		debrisPart.Reflectance = part.Reflectance
		debrisPart.Transparency = part.Transparency

		debrisPart.Anchored = false
		debrisPart.CanCollide = true
		debrisPart.Massless = false
		debrisPart.Parent = parent

		-- Velocity
		local direction = (debrisPart.Position - cframe.Position)
		if origin then
			direction = Vector3.new(
				math.random() - 0.5,
				0,
				math.random() - 0.5
			).Unit
		else
			direction = Vector3.new(
				direction.X,
				0,
				direction.Z
			).Unit
		end

		local unit = direction.Unit
		local impulse = Vector3.new(
			unit.X * force * debrisPart.AssemblyMass,
			upwardBias * force * debrisPart.AssemblyMass,
			unit.Z * force * debrisPart.AssemblyMass
		)

		debrisPart:ApplyImpulse(impulse)

		debrisPart.AssemblyAngularVelocity = Vector3.new(
			math.random(-10, 10),
			math.random(-10, 10),
			math.random(-10, 10)
		)

		task.delay(lifetime, function()
			local shrinkTime = 0.15
			local tweenInfo = TweenInfo.new(shrinkTime)
			local tween = TweenService:Create(debrisPart, tweenInfo, {
				Size = Vector3.zero
			})
			tween:Play()
			Debris:AddItem(debrisPart, shrinkTime)
		end)
	end
end

function UtilFunctions.ThrobModel(model : Model, scaleMultiplier, totalTime)
	local currentScale = model:GetScale()
	local goalScale = currentScale * scaleMultiplier

	local currentConnect = UtilFunctions.TweenModelScale(model, goalScale, totalTime / 2, nil, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local currTask = task.delay(totalTime / 2, function()
		currentConnect = UtilFunctions.TweenModelScale(model, currentScale, totalTime / 2, nil, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	end)

	return function()
		model:ScaleTo(currentScale)
		currentConnect:Disconnect()
		task.cancel(currTask)
	end
end

function UtilFunctions.WeldUnlessDestroyed(part, partToWeldTo)
	local newWeld = Instance.new("WeldConstraint")
	newWeld.Part0 = part
	newWeld.Part1 = partToWeldTo
	newWeld.Parent = part

	local connection
	connection = partToWeldTo.AncestryChanged:Connect(function(_, parent)
		if not parent then
			part.Anchored = true
			if connection then
				connection:Disconnect()
				connection = nil
			end
		end
	end)

	part.AncestryChanged:Connect(function(_, parent)
		if not parent then
			if connection then
				connection:Disconnect()
				connection = nil
			end
		end
	end)
end

function UtilFunctions.QuadraticBezier(p0: Vector3, p1: Vector3, p2: Vector3, t: number): Vector3
	local inverse = 1 - t

	return
		inverse * inverse * p0 +
		2 * inverse * t * p1 +
		t * t * p2
end

function UtilFunctions.QuadraticBezierTangent(p0: Vector3, p1: Vector3, p2: Vector3, t: number): Vector3
	return (
		2 * (1 - t) * (p1 - p0) +
		2 * t * (p2 - p1)
	).Unit
end

function UtilFunctions.SetGuiTransparency(guiObject: GuiObject, transparency: number)
	if guiObject:IsA("TextLabel") then
		guiObject.TextTransparency = transparency
	elseif guiObject:IsA("ImageLabel") then
		guiObject.ImageTransparency = transparency
	elseif guiObject:IsA("UIStroke") then
		guiObject.Transparency = transparency
	end
end

function UtilFunctions.SetGuiTransparencyDescendants(guiObject: GuiObject, transparency: number)
	UtilFunctions.SetGuiTransparency(guiObject, transparency)

	for _, descendant in pairs(guiObject:GetDescendants()) do
		UtilFunctions.SetGuiTransparency(descendant, transparency)
	end
end

return UtilFunctions
