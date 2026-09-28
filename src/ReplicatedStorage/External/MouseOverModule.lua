local Player = game.Players.LocalPlayer or game.Players:GetPropertyChangedSignal("LocalPlayer")

local Mouse = Player:GetMouse()

local CurrentItems = {}

--Private functions
local function IsInFrame(v)
	local X = Mouse.X
	local Y = Mouse.Y

	if X>v.AbsolutePosition.X and Y>v.AbsolutePosition.Y and X<v.AbsolutePosition.X+v.AbsoluteSize.X and Y<v.AbsolutePosition.Y+v.AbsoluteSize.Y then
		return true
	else
		return false
	end
end

local function CheckMouseExited(Object)
	if not Object.MouseIsInFrame and Object.MouseWasIn then --Mouse was previously over object, fire leave event
		Object.MouseWasIn = false
		Object.LeaveEvent:Fire()
	end
end

local function CheckMouseEntered(Object)
	if Object.MouseIsInFrame and not Object.MouseWasIn then
		Object.MouseWasIn = true
		Object.EnteredEvent:Fire()
	end
end

game:GetService("RunService").Heartbeat:Connect(function()
	--Check each UI object
	--All exit events fire before all enter events for ease of use, so check for mouse exit events here
	for _, Object in pairs(CurrentItems) do
		Object.MouseIsInFrame = IsInFrame(Object.UIObj)
		CheckMouseExited(Object)
	end

	--Now check if the mouse entered any frames
	for _, Object in pairs(CurrentItems) do
		CheckMouseEntered(Object)
	end
end)

--Public functions

local module = {}

function module.MouseEnterLeaveEvent(UIObj : GuiObject)
	if CurrentItems[UIObj] then
		return CurrentItems[UIObj].EnteredEvent.Event,CurrentItems[UIObj].LeaveEvent.Event
	end

	local newObj = {}

	newObj.UIObj = UIObj

	local EnterEvent = Instance.new("BindableEvent")
	local LeaveEvent = Instance.new("BindableEvent")

	newObj.EnteredEvent = EnterEvent
	newObj.LeaveEvent = LeaveEvent
	newObj.MouseWasIn = false
	CurrentItems[UIObj] = newObj

	newObj.Connection = UIObj.AncestryChanged:Connect(function()
		if not UIObj.Parent then
			module.Disconnect(UIObj)
		end
	end)

	return EnterEvent.Event,LeaveEvent.Event
end

function module.Disconnect(UIObj)
	local obj = CurrentItems[UIObj]
	if not obj then
		return
	end

	obj.Connection:Disconnect()
	obj.EnteredEvent:Destroy()
	obj.LeaveEvent:Destroy()
	CurrentItems[UIObj] = nil
end

return module