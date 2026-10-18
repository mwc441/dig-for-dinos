local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local EventBoardGui = ClientAssets:WaitForChild("EventBoardGui")
local EventBoardTitleGui = ClientAssets:WaitForChild("EventBoardTitleGui")

local BOARD_TAG = "EventBoard"
local TITLE_TAG = "EventBoardTitle"
local SLOT_SECONDS = 15 * 60
local WINDOW_SECONDS = 5 * 60 * 60

local EventBoardController = {
	Name = "EventBoardController",
	_Boards = {},
	_Titles = {},
	_Events = {},
	_Rows = {},
	_TimeController = nil,
	_WindowStart = nil,
	_WindowLabel = nil
}

local function getUnixTime()
	return math.floor(Workspace:GetServerTimeNow())
end

local function formatLocalTime(timestamp)
	local localTime = DateTime.fromUnixTimestamp(timestamp):ToLocalTime()
	local hour = localTime.Hour % 12
	if hour == 0 then hour = 12 end

	return string.format("%d:%02d %s", hour, localTime.Minute, localTime.Hour < 12 and "AM" or "PM")
end

local function formatCountdown(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(seconds / 60) % 60
	local remainingSeconds = seconds % 60
	if hours > 0 then
		return string.format("%dh%dm%ds", hours, minutes, remainingSeconds)
	end
	return string.format("%dm%ds", minutes, remainingSeconds)
end

local function getAdornee(component, gui)
	if component:IsA("BasePart") then
		return component
	elseif component:IsA("Model") then
		return component.PrimaryPart or component:FindFirstChildWhichIsA("BasePart", true)
	elseif component:IsA("Attachment") and gui:IsA("BillboardGui") then
		return component
	end
end

function EventBoardController:GetWindowBounds(now)
	local localTime = DateTime.fromUnixTimestamp(now):ToLocalTime()
	local secondsIntoHour = localTime.Minute * 60 + localTime.Second
	local windowStart = now - (secondsIntoHour % SLOT_SECONDS)
	return windowStart, windowStart + WINDOW_SECONDS
end

function EventBoardController:KnitStart()
	self._PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self._TimeController = require(ReplicatedStorage.Controllers.Time.TimeController)
	self:_RefreshTimeline(getUnixTime())

	CollectionService:GetInstanceAddedSignal(BOARD_TAG):Connect(function(board)
		self:_AddBoard(board)
	end)
	CollectionService:GetInstanceRemovedSignal(BOARD_TAG):Connect(function(board)
		self:_RemoveBoard(board)
	end)
	CollectionService:GetInstanceAddedSignal(TITLE_TAG):Connect(function(title)
		self:_AddTitle(title)
	end)
	CollectionService:GetInstanceRemovedSignal(TITLE_TAG):Connect(function(title)
		self:_RemoveTitle(title)
	end)

	for _, board in ipairs(CollectionService:GetTagged(BOARD_TAG)) do
		self:_AddBoard(board)
	end
	for _, title in ipairs(CollectionService:GetTagged(TITLE_TAG)) do
		self:_AddTitle(title)
	end

	self._TimeController.TimeUpdatedSignal:Connect(function()
		local now = getUnixTime()
		local windowStart = self:GetWindowBounds(now)
		if windowStart ~= self._WindowStart or formatLocalTime(windowStart) ~= self._WindowLabel then
			self:_RefreshTimeline(now)
		end
		self:_UpdateTitleCountdown(now)
	end)
end

-- Schedule or replace an event by ID. Times are Unix seconds.
-- eventInfo = { StartsAt = number, EndsAt = number, Text = string, Icon = string? }
function EventBoardController:ScheduleEvent(eventId, eventInfo)
	if type(eventId) ~= "string" or eventId == "" or type(eventInfo) ~= "table" then
		return false
	end

	local startsAt = eventInfo.StartsAt
	local endsAt = eventInfo.EndsAt
	if type(startsAt) ~= "number" or type(endsAt) ~= "number"
		or startsAt ~= startsAt or endsAt ~= endsAt
		or math.abs(startsAt) == math.huge or math.abs(endsAt) == math.huge
		or endsAt <= startsAt then
		return false
	end

	self._Events[eventId] = {
		Id = eventId,
		StartsAt = startsAt,
		EndsAt = endsAt,
		Text = type(eventInfo.Text) == "string" and eventInfo.Text or eventId,
		Icon = type(eventInfo.Icon) == "string" and eventInfo.Icon or nil,
		Color = eventInfo.Color
	}

	if self._WindowStart then
		local now = getUnixTime()
		self:_RefreshTimeline(now)
		self:_UpdateTitleCountdown(now)
	end
	return true
end

function EventBoardController:RemoveEvent(eventId)
	if not self._Events[eventId] then
		return false
	end

	self._Events[eventId] = nil
	if self._WindowStart then
		local now = getUnixTime()
		self:_RefreshTimeline(now)
		self:_UpdateTitleCountdown(now)
	end
	return true
end

function EventBoardController:_BuildRows(windowStart, windowEnd)
	local events = {}

	local function addEmptyRows(rows, startsAt, endsAt)
		while startsAt < endsAt do
			local nextBoundary = windowStart + (math.floor((startsAt - windowStart) / SLOT_SECONDS) + 1) * SLOT_SECONDS
			local rowEnd = math.min(endsAt, nextBoundary)
			table.insert(rows, { StartsAt = startsAt, EndsAt = rowEnd })
			startsAt = rowEnd
		end
	end

	for eventId, event in pairs(self._Events) do
		if event.EndsAt <= windowStart then
			self._Events[eventId] = nil
		elseif event.StartsAt < windowEnd then
			table.insert(events, event)
		end
	end

	table.sort(events, function(first, second)
		if first.StartsAt == second.StartsAt then
			return first.Id < second.Id
		end
		return first.StartsAt < second.StartsAt
	end)

	local rows = {}
	local cursor = windowStart
	for _, event in ipairs(events) do
		local visibleStart = math.max(event.StartsAt, windowStart)
		if visibleStart > cursor then
			addEmptyRows(rows, cursor, visibleStart)
		end

		table.insert(rows, { StartsAt = event.StartsAt, EndsAt = event.EndsAt, Event = event })
		cursor = math.max(cursor, math.min(event.EndsAt, windowEnd))
	end

	if cursor < windowEnd then
		addEmptyRows(rows, cursor, windowEnd)
	end
	return rows
end

function EventBoardController:_RefreshTimeline(now)
	local windowStart, windowEnd = self:GetWindowBounds(now)
	self._WindowStart = windowStart
	self._WindowLabel = formatLocalTime(windowStart)
	self._Rows = self:_BuildRows(windowStart, windowEnd)

	for _, boardState in pairs(self._Boards) do
		self:_RenderBoard(boardState)
	end
end

function EventBoardController:_AddBoard(board)
	if self._Boards[board] or not board:IsDescendantOf(Workspace) then
		return
	end

	local adornee = getAdornee(board, EventBoardGui)
	if not adornee then
		return
	end

	local gui = EventBoardGui:Clone()
	gui.Adornee = adornee
	gui.Parent = self._PlayerGui

	local boardState = { Gui = gui, Templates = {} }
	self._Boards[board] = boardState
	self:_RenderBoard(boardState)
end

function EventBoardController:_RemoveBoard(board)
	local boardState = self._Boards[board]
	if not boardState then
		return
	end

	self._Boards[board] = nil
	boardState.Gui:Destroy()
end

function EventBoardController:_AddTitle(title)
	if self._Titles[title] or not title:IsDescendantOf(Workspace) then
		return
	end

	local adornee = getAdornee(title, EventBoardTitleGui)
	if not adornee then
		return
	end

	local gui = EventBoardTitleGui:Clone()
	gui.Adornee = adornee
	gui.Parent = self._PlayerGui
	self._Titles[title] = gui
	self:_UpdateTitleCountdown(getUnixTime())
end

function EventBoardController:_RemoveTitle(title)
	local gui = self._Titles[title]
	if not gui then
		return
	end

	self._Titles[title] = nil
	gui:Destroy()
end

function EventBoardController:_UpdateTitleCountdown(now)
	local nextStart
	for _, event in pairs(self._Events) do
		if event.StartsAt > now and (not nextStart or event.StartsAt < nextStart) then
			nextStart = event.StartsAt
		end
	end

	for _, gui in pairs(self._Titles) do
		local nextText = gui.Content.NextText
		nextText.Visible = nextStart ~= nil
		if nextStart then
			nextText.Text = "Next: " .. formatCountdown(math.ceil(nextStart - now))
		end
	end
end

function EventBoardController:_RenderBoard(boardState)
	for _, template in ipairs(boardState.Templates) do
		template:Destroy()
	end
	table.clear(boardState.Templates)

	local gui = boardState.Gui :: typeof(EventBoardGui)
	local templateSource = gui.Templates.EventTemplate
	local list = gui.EventsList.EventsList
	for order, row in ipairs(self._Rows) do
		local template = templateSource:Clone()
		template.LayoutOrder = order
		template.Visible = true
		template.BackgroundTransparency = order % 2 == 1 and templateSource.BackgroundTransparency or 1
		template.TimeText.Text = formatLocalTime(row.StartsAt) .. " - " .. formatLocalTime(row.EndsAt)

		local eventInfo = template.EventInfo
		local eventFrame = eventInfo.EventFrame
		if row.Event then
			eventFrame.EventText.Text = row.Event.Text
			eventFrame.EventText.TextColor3 = row.Event.Color or eventFrame.EventText.TextColor3
			eventInfo.Icon.Image = row.Event.Icon or ""
			eventInfo.Icon.Visible = row.Event.Icon ~= nil and row.Event.Icon ~= ""
		else
			eventInfo.Icon.Image = ""
			eventInfo.Icon.Visible = false
			eventFrame.EventText.Text = "No Event"
		end

		template.Parent = list
		table.insert(boardState.Templates, template)
	end
end

return EventBoardController
