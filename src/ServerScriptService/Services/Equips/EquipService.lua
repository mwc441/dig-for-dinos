local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local ServerConfigs = ServerScriptService:WaitForChild("ServerConfigs")
local DataKeys = require(ServerConfigs:WaitForChild("DataKeys"))
local Signal = require(External:WaitForChild("Signal"))
local Knit = require(External:WaitForChild("Knit"))

local EQUIPS_KEY = DataKeys.Equips
local EQUIPS_DEFAULT_DATA = {
	Version = 1,
	Equips = {}
}

local function isValidId(value)
	return type(value) == "string" and value ~= ""
end

local EquipService = {
	Name = "EquipService",
	Client = {},
	_DataService = nil,
	PlayerEquipUpdated = Signal.new()
}

function EquipService:KnitStart()
	self._DataService = require(ServerScriptService.Services.Data.DataService)
end

function EquipService:OnPlayerAdded(player)
	self:GetEquipDataForPlayer(player)
end

function EquipService:GetEquipDataForPlayer(player)
	local equipData = self._DataService:GetPlayerData(player, EQUIPS_KEY, EQUIPS_DEFAULT_DATA)
	local changed = false

	if changed then
		self._DataService:SetPlayerData(player, EQUIPS_KEY, equipData, true)
	end

	return equipData
end

function EquipService:GetEquipsForPlayer(player)
	return self:GetEquipDataForPlayer(player).Equips
end

function EquipService:GetEquippedItemForPlayer(player, slotId)
	if not isValidId(slotId) then
		return
	end

	local equips = self:GetEquipsForPlayer(player)
	return equips[slotId]
end

function EquipService:EquipItemForPlayer(player, slotId, itemId)
	if not isValidId(slotId) or not isValidId(itemId) then
		return false
	end

	local equipData = self:GetEquipDataForPlayer(player)
	local equips = equipData.Equips
	if equips[slotId] == itemId then
		return true
	end

	-- A slot contains one item, so equipping a new item replaces the old one.
	equips[slotId] = itemId
	self._DataService:SetPlayerData(player, EQUIPS_KEY, equipData, true)
	self.PlayerEquipUpdated:Fire(player, slotId, itemId)

	return true
end

function EquipService:UnequipItemForPlayer(player, slotId)
	if not isValidId(slotId) then
		return false
	end

	local equipData = self:GetEquipDataForPlayer(player)
	local equips = equipData.Equips
	if equips[slotId] == nil then
		return false
	end

	equips[slotId] = nil
	self._DataService:SetPlayerData(player, EQUIPS_KEY, equipData, true)
	self.PlayerEquipUpdated:Fire(player, slotId, nil)

	return true
end

return EquipService
