local ReplicatedStorage = game:GetService("ReplicatedStorage")
--!strict
local ui = ReplicatedStorage:WaitForChild("Derpbar"):WaitForChild("DerpbarUI")
local TOOL_TEMPLATE = ReplicatedStorage:WaitForChild("Derpbar"):WaitForChild("ToolTemplate")

type ToolbarImpl = {
	Enabled: boolean, -- this just means you cannot toggle it on/off
	
	InventoryOpened: RBXScriptSignal,
	InventoryIsOpen: boolean,
	ToolTemplateChanged: RBXScriptSignal,
	GetToolTemplate: (tool: Tool) -> GuiObject?,
	GetToolForTemplate: (template: GuiObject) -> Tool?,

	ToggleSlot: (idx: number?) -> (),
	ToggleInventory: (force: boolean?) -> (),

	MoveItemToBackpack: Enum.KeyCode,
	GamepadInventoryButton: Enum.KeyCode,
	SwapKeybind: Enum.KeyCode -- canont rebind. this is more just for show
}


type ToolElementTemplate = typeof(TOOL_TEMPLATE)
type Device = "Unknown" | "PC" | "Mobile" | "Controller"
type ToolSlot = {
	tool: Tool?,
	element: ToolElementTemplate,
	slotIdx: number?,
	setTool: (Tool?) -> (),
}

type MoveSlotData = {
	conns: {RBXScriptConnection},
	toolSlot: ToolSlot,
	fakeContent: Frame
}

-- Module table:
local InventoryOpened = Instance.new("BindableEvent")
local ToolTemplateChanged = Instance.new("BindableEvent")
local CustomToolbar = {
	
	InventoryOpened = InventoryOpened.Event,
	InventoryIsOpen = true,
	ToolTemplateChanged = ToolTemplateChanged.Event,
	GetToolTemplate = function() return nil end,
	GetToolForTemplate = function() return nil end,
	
	ToggleSlot = function() end,
	ToggleInventory = function() end,
	
	MoveItemToBackpack = Enum.KeyCode.ButtonX,
	GamepadInventoryButton = Enum.KeyCode.ButtonY,
	SwapKeybind = Enum.KeyCode.ButtonA -- canont rebind. this is more just for show
} :: ToolbarImpl


-- this is here for usability. i did not want people calling
-- :SetEnabled to enable the module. it should be a boolean.
-- if you're forking, feel free to delete this if you don't need the 
-- enabled functionality
local derpbarEnabled = true
setmetatable(CustomToolbar, {
	__newindex = function(_, k, v)
		if k == "Enabled" then
			if typeof(v) ~= "boolean" then
				error("Enabled property can only be set to a boolean.")
			end
			
			derpbarEnabled = v
			ui.Enabled = derpbarEnabled
			return
		end
		-- read comment above
		error("Cannot access other properties of Derpbar. Find this error in the source to modify behavior.")
	end,
	
	__index = function(_, k, v)
		if k == "Enabled" then
			return derpbarEnabled
		end
		-- read comment above
		error("Cannot access other properties of Derpbar. Find this error in the source to modify behavior.")
	end,
	
})

export type CustomToolbarImpl = typeof(CustomToolbar)

-- Loaded services
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local GamepadService = game:GetService("GamepadService")


local MOBILE_ITEMS_VISIBLE = 4
local PC_ITEMS_VISIBLE = 10
local LOCAL_PLAYER = Players.LocalPlayer
local PLAYER_GUI = LOCAL_PLAYER:WaitForChild("PlayerGui") :: PlayerGui

local MOBILE_SIZE = 6 -- 10x the normal button
local PC_SIZE = 10 -- 10x normal button

local OPEN_ICON = "rbxassetid://18474505724"
local CLOSE_ICON = "rbxassetid://18474502697"

local INPUTS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10,
}

local PHONE_HEIGHT = 393
local PC_HEIGHT = 1080

-- Private variables

local toolsContainer = ui.Ctn.Tools
local backpackButton = toolsContainer.BackpackButton
local inventoryContainer = ui.Ctn.Inventory
local textbox = inventoryContainer.Content.TopBar.TextBox.TextBox
local inventoryItems = inventoryContainer.Content.Inventory.Frame
local gamepadControls = inventoryContainer.GamepadControls

local toolBarLookup: {[ToolElementTemplate]: ToolSlot} = {}
local elementLookup: {[ToolElementTemplate]: ToolSlot} = {}
local toolTemplateLookup: {[Tool]: ToolElementTemplate} = {}
local toolbar: {ToolSlot} = {}
local inventory: {ToolSlot} = {}

local backpack: Backpack
local character: Model & { Humanoid: Humanoid }

local device: Device = "Unknown"
local uiScale = ui.Ctn.UIScale
local camera = workspace.CurrentCamera

local alreadyMoving = false
local moveData: MoveSlotData? = nil

-- Private functions
local function resizeUI()
	local minSize = uiScale:GetAttribute("MinScale") or .75 -- phone size
	local maxSize = uiScale:GetAttribute("MaxScale") or 1 -- pc size
	
	local camera = workspace.CurrentCamera
	
	local function getAlpha(viewportSize: number): number
		return math.clamp((viewportSize - PHONE_HEIGHT) / (PC_HEIGHT - PHONE_HEIGHT), 0, 1)
	end
	
	local function update()
		local viewportSize = camera.ViewportSize.Y
		local alpha = getAlpha(viewportSize)
		uiScale.Scale = (minSize + (maxSize - minSize) * alpha)
	end
	
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
end
resizeUI()

local function callWithRetry(retryCount: number, delayBetween: number, func: () -> (), ...)
	local success, result
	while not success and retryCount > 0 do
		success, result = pcall(func, ...)
		retryCount -= 1
		if not success then
			task.wait(delayBetween)
		end
	end
	
	return success, result
end

local function toggleSlot(idx: number?)
	local humanoid: Humanoid?
	if character and character.Parent then
		humanoid = character.Humanoid
	end
	if humanoid == nil then return end
	
	if idx == nil or toolbar[idx] == nil then
		humanoid:UnequipTools()
		return
	end
	
	
	
	local selectedSlot = toolbar[idx]
	local selected = not selectedSlot.element:GetAttribute("Selected")
	if selected and selectedSlot.tool then
		humanoid:EquipTool(selectedSlot.tool)
	else
		humanoid:UnequipTools()
	end
end

-- updating selection order is VERY important in scrollingframes because
-- this will make the gamepad experience soooo much better
local updateThread: thread?
local function updateSelectionOrder()
	if updateThread then return end
	
	-- update at the end of every frame when necessary
	updateThread = task.defer(function()
		local positionValues = {}
		
		for _, v in inventory do
			local yPos = math.floor(v.element.AbsolutePosition.Y)
			if v.element and table.find(positionValues, yPos) == nil then
				table.insert(positionValues, yPos)
			end
		end
		
		table.sort(positionValues)
		
		for _, v in inventory do
			local yPos = math.floor(v.element.AbsolutePosition.Y)
			v.element.SelectionOrder = (table.find(positionValues, yPos) or 1)
		end
		
		updateThread = nil
	end)
end

local function getMouseScreenPosition()
	return UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
end

local tweens: {Tween} = {}
local lastTooltip: ImageButton? = nil
local function showTooltip(on: boolean, source: ImageButton?)
	if source ~= lastTooltip and source ~= nil and on == false then return end
	
	for _, v in tweens do v:Cancel() end
	table.clear(tweens)

	if on then
		lastTooltip = source
		
		inventoryContainer.ToolName.BackgroundTransparency = 0
		inventoryContainer.ToolName.TextTransparency = 0
		
		inventoryContainer.TooltipDescription.BackgroundTransparency = .4
		inventoryContainer.TooltipDescription.TextTransparency = 0
	else
		lastTooltip = nil
		table.insert(tweens, TweenService:Create(inventoryContainer.ToolName,
			TweenInfo.new(.125),
			{
				BackgroundTransparency = 1,
				TextTransparency = 1
			}
			)
		)

		table.insert(tweens, TweenService:Create(inventoryContainer.TooltipDescription,
			TweenInfo.new(.125),
			{
				BackgroundTransparency = 1,
				TextTransparency = 1
			}
			)
		)

		for _, v in tweens do
			v:Play()
		end
	end
end

local function setupButton(template: ToolElementTemplate)
	local content = template.Content
	local scale = content.UIScale
	local whiteFrame = content.WhiteFrame
	local tooltip = template:FindFirstChild("Tooltip")
	
	if tooltip then
		tooltip.BackgroundTransparency = 1
		tooltip.TextTransparency = 1	
	end
	
	local tooltipTween: Tween
	
	local function release()
		TweenService:Create(scale, TweenInfo.new(.05), { Scale = 1 }):Play()
		TweenService:Create(whiteFrame,TweenInfo.new(.05), { BackgroundTransparency = 1 }):Play()
		
		
		
		if tooltip then
			showTooltip(false, template)
			tooltipTween = TweenService:Create(tooltip, TweenInfo.new(.125), { BackgroundTransparency = 1, TextTransparency = 1 })
			tooltipTween:Play()
		end
	end
	
	local function mouseEnter()
		if tooltipTween then
			tooltipTween:Cancel()
		end

		TweenService:Create(scale, TweenInfo.new(.05), { Scale = 1.05 }):Play()
		TweenService:Create(whiteFrame, TweenInfo.new(.05), { BackgroundTransparency = .9 }):Play()


		if alreadyMoving == false and tooltip and tooltip.Text ~= "" then

			if template:IsDescendantOf(inventoryContainer) == false then
				tooltip.BackgroundTransparency = .25
				tooltip.TextTransparency = 0
			else
				showTooltip(true, template)
				inventoryContainer.ToolName.Text = template:GetAttribute("toolName") or ""
				inventoryContainer.TooltipDescription.Text = template:GetAttribute("toolDescription") or ""
			end
		end
	end
	
	template.MouseButton1Down:Connect(function()
		if inventoryContainer.Visible and device == "Controller" then return end -- selection shouldn't happen when editing

		TweenService:Create(scale, TweenInfo.new(.05), { Scale = .9 }):Play()	
		TweenService:Create(whiteFrame, TweenInfo.new(.05), { BackgroundTransparency = .7 }):Play()
	end)
	
	local conns: {RBXScriptConnection} = {}
	
	table.insert(conns, inventoryContainer:GetPropertyChangedSignal("Visible"):Connect(release))
	table.insert(conns, inventoryContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(release))
	

	template.MouseEnter:Connect(mouseEnter)
	template.SelectionGained:Connect(mouseEnter)
	template.Destroying:Connect(function() for _, v in conns do v:Disconnect() end end)
	template:GetPropertyChangedSignal("Visible"):Connect(release)
	template.Content:GetPropertyChangedSignal("Visible"):Connect(release)
	
	template:GetAttributeChangedSignal("toolName"):Connect(release)
	template:GetAttributeChangedSignal("toolDescription"):Connect(release)
	template.MouseLeave:Connect(release)
	template.MouseButton1Up:Connect(release)
	template.SelectionLost:Connect(release)
end

local createToolElement
local function stopMoving(swapPositions: boolean, input: InputObject?)
	alreadyMoving = false
	if moveData == nil then return end
	
	local currentToolSlot = moveData.toolSlot
	
	if swapPositions == true then
		
		local objects: {ToolElementTemplate} = {}
		if device == "Controller" then
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(ui) then
				table.insert(objects, GuiService.SelectedObject)
			end
		elseif input then
			objects = PLAYER_GUI:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
		end

		local swapped = false
		for _, v in objects do
			local targetToolSlot = toolBarLookup[v]
			if targetToolSlot then
				swapped = true
				local targetTool, currentTool =
					targetToolSlot.tool, currentToolSlot.tool

				targetToolSlot.setTool(currentTool)
				currentToolSlot.setTool(targetTool)
				break
			end
		end

		-- add to inventory
		-- controller can only add to inventory through a keybind
		if device ~= "Controller" and
			swapped == false and
			currentToolSlot.tool and
			currentToolSlot.slotIdx ~= nil then
			createToolElement(nil, currentToolSlot.tool)
			currentToolSlot.setTool(nil)
		end
	end
	
	for _, v in moveData.conns do
		v:Disconnect()
	end
	
	-- findfirstchild because if content gets destroyed then what
	local content = moveData.toolSlot.element:FindFirstChild("Content")
	if content then content.Visible = true end
	moveData.fakeContent:Destroy()
	
	moveData = nil
end

local function startMoving(input: InputObject, currentToolSlot: ToolSlot)
	-- stop moving
	if GamepadService.GamepadCursorEnabled then return end -- this should not work with gamepad cursor
	if input.UserInputState == Enum.UserInputState.Change then return end
	if inventoryContainer.Visible == false then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and
		input.UserInputType ~= Enum.UserInputType.Touch and
		input.KeyCode ~= Enum.KeyCode.ButtonA then return end

	stopMoving(false)
	alreadyMoving = true
	
	local template = currentToolSlot.element
	local content = template.Content
	local slotIdx = currentToolSlot.slotIdx
	local fakeContent = template:Clone()
	fakeContent.Tooltip:Destroy()
	
	local data: MoveSlotData = {
		conns = {},
		fakeContent = fakeContent,
		toolSlot = currentToolSlot
	}
	moveData = data

	fakeContent.Size = UDim2.fromOffset(template.AbsoluteSize.X * 1/uiScale.Scale, template.AbsoluteSize.Y * 1/uiScale.Scale)
	local function step()
		if device == "Controller" then return end

		local position: Vector2
		if device == "PC" then
			position = getMouseScreenPosition()
		elseif device == "Mobile" then
			position = Vector2.new(input.Position.X, input.Position.Y)
		end

		-- get position relative to ctn
		position = (position - ui.Ctn.AbsolutePosition) * 1/uiScale.Scale
		fakeContent.Position = UDim2.fromOffset(position.X, position.Y)			
	end
	step()
	
	fakeContent.ZIndex = 999999 -- really big value so fake content is on top of everything
	fakeContent.Parent = ui.Ctn			
	content.Visible = false

	-- if in bounds of self, select
	-- if in bounds of another slot, swap
	-- if anywhere else, add back to backpack
	local function updateSelected()
		local object = GuiService.SelectedObject
		if object == nil then return end

		local absolutePosition = (GuiService.SelectedObject.AbsolutePosition - ui.Ctn.AbsolutePosition) * 1/uiScale.Scale
		fakeContent.Position = UDim2.fromOffset(absolutePosition.X + fakeContent.AbsoluteSize.X/2, absolutePosition.Y + 20)
	end
	updateSelected()

	table.insert(data.conns, template.Destroying:Connect(stopMoving))
	table.insert(data.conns, GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(updateSelected))
	table.insert(data.conns, RunService.RenderStepped:Connect(step))
	table.insert(data.conns, inventoryContainer:GetPropertyChangedSignal("Visible"):Connect(stopMoving))
	table.insert(data.conns, UserInputService.InputEnded:Connect(function(endInput: InputObject)			
		if device == "Controller" or input ~= endInput then return end
		stopMoving(true, endInput)
	end))
end

local showToolbar: () -> ()
createToolElement = function(slotIdx: number?, tool: Tool?): ToolSlot
	local template = TOOL_TEMPLATE:Clone()
	local content = template.Content
	local currentToolSlot = { element = template, slotIdx = slotIdx } :: ToolSlot
	elementLookup[template] = currentToolSlot
	
	setupButton(template)
	template.Activated:Connect(function(input: InputObject)
		if inventoryContainer.Visible then
			if device ~= "Controller" then return end
			
			if alreadyMoving then
				stopMoving(true)
			else
				startMoving(input, currentToolSlot)
			end
		else
			if slotIdx then toggleSlot(slotIdx) end
		end	
	end)


	local function updateSelected()
		template.Content.UIStroke.Enabled = template:GetAttribute("Selected") == true
	end
	local changedConnection = template:GetAttributeChangedSignal("Selected"):Connect(updateSelected)
	updateSelected()
	
	local toolConns: {RBXScriptConnection} = {}
	template.Destroying:Connect(function()
		elementLookup[template] = nil
		local heldTool = currentToolSlot.tool
		if heldTool and toolTemplateLookup[heldTool] == template then
			toolTemplateLookup[heldTool] = nil
			ToolTemplateChanged:Fire(heldTool, nil)
		end
		currentToolSlot.setTool = function() end -- no longer want this to be called ever again

		changedConnection:Disconnect()

		for _, v in toolConns do v:Disconnect() end
		table.clear(toolConns)
	end)

	local function selectTool(tool: Tool?)
		for _, v in toolConns do v:Disconnect() end
		table.clear(toolConns)
		local previousTool = currentToolSlot.tool
		if previousTool and previousTool ~= tool and toolTemplateLookup[previousTool] == template then
			toolTemplateLookup[previousTool] = nil
			ToolTemplateChanged:Fire(previousTool, nil)
		end
		-- destroy, no longer needs to exist
		if tool == nil and toolBarLookup[template] == nil then
			currentToolSlot.element:Destroy()

			local idx = table.find(inventory, currentToolSlot)
			if idx then table.remove(inventory, idx) end
			return
		end

		currentToolSlot.tool = tool
		template:SetAttribute("Selected", false)
		if tool then
			if toolTemplateLookup[tool] ~= template then
				toolTemplateLookup[tool] = template
				ToolTemplateChanged:Fire(tool, template)
			end
			local function equipped()
				template:SetAttribute("Selected", true)
			end

			local function unequipped()
				template:SetAttribute("Selected", false)
			end
			
			local function changed()
				template.Content.TextLabel.Text = tool.Name
			end

			table.insert(toolConns, tool.Equipped:Connect(equipped))
			table.insert(toolConns, tool.Unequipped:Connect(unequipped))
			table.insert(toolConns, tool.Changed:Connect(changed))
			if tool.Parent == backpack then
				unequipped()
			else
				equipped()
			end
		end

		-- hide slot when a tool is selected
		-- calling showToolbar because it is not expensive +
		-- all requests are deferreed to the end of the frame
		if slotIdx ~= nil then showToolbar() end
		

		template.Content.ImageLabel.Image = if tool then tool.TextureId else ""
		template.Content.TextLabel.Text = if tool then tool.Name else ""
		template.Content.TextLabel.Visible = if tool then tool.TextureId == "" else false
		template.Tooltip.Text = if tool then tool.ToolTip else ""
		
		template:SetAttribute("toolName", if tool then tool.Name else nil)
		template:SetAttribute("toolDescription", if tool then tool.ToolTip else nil)
	end
	currentToolSlot.setTool = selectTool

	if slotIdx then
		template.Name = `ToolBar_{slotIdx}`
		template.Parent = toolsContainer

		toolBarLookup[template] = currentToolSlot
		table.insert(toolbar, currentToolSlot)
	else
		table.insert(inventory, currentToolSlot)
		template.Parent = inventoryItems
	end
	selectTool(tool)

	template.InputBegan:Connect(function(input: InputObject)
		if device == "Controller" then return end -- controller uses Activated, not InputBegan
		startMoving(input, currentToolSlot)
	end)

	if slotIdx then content.SlotNumber.Text = `{slotIdx % 10}` end
	content.SlotNumber.Visible = slotIdx ~= nil

	return currentToolSlot
end

-- create a thread to prevent spam requests in the same frame
local showToolbarThread: thread?
showToolbar = function()
	if showToolbarThread ~= nil then return end

	showToolbarThread = task.defer(function()
		local inventoryVisible = inventoryContainer.Visible

		for i, v in toolbar do
			local elementVisible = ((device == "Mobile" and i <= MOBILE_ITEMS_VISIBLE)
				or (device ~= "Mobile" and i <= PC_ITEMS_VISIBLE)) and (v.tool ~= nil or inventoryVisible)

			v.element.Visible = elementVisible

			if elementVisible == false and toolbar[i].tool then
				createToolElement(nil, toolbar[i].tool)
				toolbar[i].setTool(nil)
			end
		end
		
		showToolbarThread = nil
	end)
end

local function defineToolbarSelection()
	if device == "Controller" and inventoryContainer.Visible then
		GuiService:Select(toolsContainer)
	elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(ui) then
		GuiService.SelectedObject = nil
	end
end

local function toggleInventory(force: boolean?)
	if derpbarEnabled == false then return end
	
	local inventoryVisible = if force ~= nil then
		force else not inventoryContainer.Visible
	
	if CustomToolbar.InventoryIsOpen == inventoryVisible then return end -- already toggled bro
	
	inventoryContainer.Visible = inventoryVisible
	
	CustomToolbar.InventoryIsOpen = inventoryVisible
	InventoryOpened:Fire(inventoryVisible)

	showToolbar()
	
	backpackButton.Content.ImageLabel.Image = if inventoryVisible then
		OPEN_ICON else CLOSE_ICON
	
	
	defineToolbarSelection()
end

local function updateLastUserInput()
	local lastUserInput = UserInputService:GetLastInputType()
	local isGamepad = lastUserInput.Name:find("Gamepad")
	
	local lastDevice = device
	if lastUserInput.Name == "Touch" then
		device = "Mobile"
	elseif isGamepad then
		device = "Controller"
		textbox.Text = ""
	else
		device = "PC"
	end
	
	if device == lastDevice then return end
	
	showToolbar()
	stopMoving(false)

	textbox.Parent.Visible = device ~= "Controller"
	backpackButton.Visible = true
	
	local newSize = if device == "Mobile" then MOBILE_SIZE else PC_SIZE
	inventoryContainer.Size = UDim2.new(
		newSize,
		0,
		0,
		inventoryContainer.Size.Y.Offset
	)
	inventoryItems.UIGridLayout.CellSize = UDim2.fromScale(1/newSize, 1)
	
	gamepadControls.Visible = device == "Controller"
	
	-- enable selection and help keys
	defineToolbarSelection()
	
	updateSelectionOrder()
end

local function moveSlotDirection(direction: number, maximumSlots: number): number?
	-- Start from the last selection (could be nil)
	local idx: number? = nil
	for i, v in toolbar do
		if v.tool and v.tool.Parent == character :: Model then
			idx = i
		end
	end

	while true do
		-- Advance index (from nil jump to one end)
		if idx == nil then
			idx = direction == 1 and 1 or maximumSlots
		else
			idx = idx + direction
		end

		-- If we've stepped past either end, clear selection and bail out
		if idx < 1 or idx > maximumSlots then
			toggleSlot(nil)
			return nil
		end

		-- If there's an item in this slot, select it and return
		if idx and toolbar[idx] and toolbar[idx].element.Visible then
			toggleSlot(idx)
			return idx
		end
	end
end

local function toolAdded(instance: Instance)
	if instance:IsA("Tool") == false then return end
	
	
	-- check if tool already exists in inventory or toolbar
	local instance = instance :: Tool
	for _, v in toolbar do if v.tool == instance then return end end
	for idx, v in inventory do if v.tool == instance then return end end
	
	-- prioritize adding tool to toolbar
	for _, v in toolbar do
		if v.tool == nil then
			v.setTool(instance)
			return
		end
	end

	-- if not added to toolbar, add to inventory
	createToolElement(nil, instance)
end

local function removeToolFromToolbar(tool: Tool)
	for _, v in toolbar do
		if v.tool == tool then v.setTool(nil) end
	end
end

local function removeToolFromInventory(tool: Tool)
	for i = #inventory, 1, -1 do
		local v = inventory[i]
		if v.tool == tool then
			v.setTool(nil)
		end
	end
end

local function toolRemoved(instance: Instance)
	if instance:IsA("Tool") == false then return end
	if instance.Parent == character :: Model or instance.Parent == backpack then return end
	
	local instance = instance :: Tool
	removeToolFromToolbar(instance)
	removeToolFromInventory(instance)
end

local function clearBackpack()
	for _, v in toolbar do
		if v.tool then
			v.setTool(nil)
		end
	end

	for i = #inventory, 1, -1 do
		local v = inventory[i]
		if v.tool then
			v.setTool(nil)
		end
	end
end

local function characterAdded(refCharacter: Model & { Humanoid: Humanoid })
	clearBackpack()
	stopMoving(false)
	
	character = refCharacter
	character.ChildAdded:Connect(toolAdded)
	character.ChildRemoved:Connect(toolRemoved)
	for _, v in character:GetChildren() do
		toolAdded(v)
	end
	
	backpack = LOCAL_PLAYER:WaitForChild("Backpack") :: Backpack
	backpack.ChildAdded:Connect(toolAdded)
	backpack.ChildRemoved:Connect(toolRemoved)
	for _, v in backpack:GetChildren() do
		toolAdded(v)
	end
end

local function cleanString(str: string)
	return str
		:gsub(" ", "")                                         -- remove spaces
		:gsub("([%^%$%(%)%%%.%+%-%*%?%[%]])", "%%%1")  
end

local function search()
	local text = cleanString(textbox.Text:lower())
	for _, v in inventory do
		v.element.Visible = v.tool and cleanString(v.tool.Name:lower()):find(text)
	end
end

-- Create toolbar:
callWithRetry(math.huge, .2, function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
for i = 1, math.max(MOBILE_ITEMS_VISIBLE, PC_ITEMS_VISIBLE) do
	createToolElement(i).element.Parent = toolsContainer
end
toggleInventory(false)

LOCAL_PLAYER.CharacterAdded:Connect(characterAdded)
if LOCAL_PLAYER.Character then
	characterAdded(LOCAL_PLAYER.Character)
end
ui.Parent = LOCAL_PLAYER.PlayerGui

-- Setup search:
textbox:GetPropertyChangedSignal("Text"):Connect(search)
search()


UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed == true then return end
	if not derpbarEnabled then return end
	
	-- select option at x slot
	local slot = INPUTS[input.KeyCode]
	if slot then
		toggleSlot(slot) 
	elseif input.KeyCode == Enum.KeyCode.Backquote then
		toggleInventory()
	elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
		moveSlotDirection(1, PC_ITEMS_VISIBLE)
	elseif input.KeyCode == Enum.KeyCode.ButtonL1 then
		moveSlotDirection(-1, PC_ITEMS_VISIBLE)
	elseif input.KeyCode == CustomToolbar.GamepadInventoryButton then
		toggleInventory()
	elseif input.KeyCode == CustomToolbar.MoveItemToBackpack and alreadyMoving == false and GuiService.SelectedObject then
		
		local template = GuiService.SelectedObject
		
		local selectedSlot = toolBarLookup[template] 
		if selectedSlot and selectedSlot.tool then
			createToolElement(nil, selectedSlot.tool)
			selectedSlot.setTool(nil)
		else
			-- look for selected slot in inventory
			for _, v in inventory do
				if v.element == template then
					selectedSlot = v
					break
				end
			end
			
			if selectedSlot == nil then return end
			
			for _, v in toolbar do
				if v.tool == nil then
					v.setTool(selectedSlot.tool)
					selectedSlot.setTool(nil)
					break
				end
			end
		end
	end
end)

gamepadControls.CloseKeybind.ImageLabel.Image = UserInputService:GetImageForKeyCode(CustomToolbar.GamepadInventoryButton)
gamepadControls.HotbarKeybind.ImageLabel.Image = UserInputService:GetImageForKeyCode(CustomToolbar.MoveItemToBackpack)
gamepadControls.SwapKeybind.ImageLabel.Image = UserInputService:GetImageForKeyCode(CustomToolbar.SwapKeybind)

UserInputService.LastInputTypeChanged:Connect(updateLastUserInput)
updateLastUserInput()

backpackButton.Activated:Connect(function() toggleInventory() end)
setupButton(backpackButton)

showTooltip(false)

-- Setup module:
CustomToolbar.ToggleSlot = toggleSlot
CustomToolbar.ToggleInventory = toggleInventory
CustomToolbar.GetToolTemplate = function(tool: Tool): GuiObject?
	return toolTemplateLookup[tool]
end
CustomToolbar.GetToolForTemplate = function(template: GuiObject): Tool?
	local slot = elementLookup[template]
	return slot and slot.tool
end

return CustomToolbar
