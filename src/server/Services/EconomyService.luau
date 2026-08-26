local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local EconomyTypes = require(ReplicatedStorage.Shared.Types.EconomyTypes)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local BackpackService = require(script.Parent.BackpackService)
local DataService = require(script.Parent.DataService)

type ShopKind = EconomyTypes.ShopKind
type PlayerEconomyProfile = EconomyTypes.PlayerEconomyProfile
type EconomyStatePayload = EconomyTypes.EconomyStatePayload

local EconomyService = {}

local started = false
local gadgetCharges: { [Player]: number } = {}

local function listHas(list: { string }, id: string): boolean
	for _, v in list do
		if v == id then
			return true
		end
	end
	return false
end

local function inLobby(player: Player): boolean
	return player:GetAttribute("GamePhase") ~= "Match"
end

local function fireState(player: Player)
	local profile = DataService.getProfile(player)
	local charges = gadgetCharges[player]
	local payload: EconomyStatePayload = {
		Gold = profile.Gold,
		EquippedBagId = profile.EquippedBagId,
		OwnedBags = table.clone(profile.OwnedBags),
		UnlockedClasses = table.clone(profile.UnlockedClasses),
		OwnedGadgets = table.clone(profile.OwnedGadgets),
		EquippedGadgetId = profile.EquippedGadgetId,
		GadgetReady = if charges ~= nil then charges > 0 else nil,
		GadgetChargesLeft = charges,
	}
	Remotes.economyState():FireClient(player, payload)
	player:SetAttribute("Gold", profile.Gold)
	player:SetAttribute("EquippedBagId", profile.EquippedBagId)
	player:SetAttribute("EquippedGadgetId", profile.EquippedGadgetId)
end

function EconomyService.broadcast(player: Player?)
	if player then
		fireState(player)
		return
	end
	for _, p in Players:GetPlayers() do
		fireState(p)
	end
end

function EconomyService.getGold(player: Player): number
	return DataService.getProfile(player).Gold
end

function EconomyService.isClassUnlocked(player: Player, classId: string): boolean
	local price = EconomyConfig.getClassPrice(classId)
	if price == nil then
		return false
	end
	if price <= 0 then
		return true
	end
	return listHas(DataService.getProfile(player).UnlockedClasses, classId)
end

function EconomyService.getEquippedBagId(player: Player): string
	return DataService.getProfile(player).EquippedBagId
end

function EconomyService.getEquippedGadgetId(player: Player): string?
	return DataService.getProfile(player).EquippedGadgetId
end

function EconomyService.applyLoadout(player: Player)
	local profile = DataService.getProfile(player)
	local bag = EconomyConfig.getBag(profile.EquippedBagId)
	BackpackService.setCapacity(player, bag.Capacity)
	fireState(player)
end

function EconomyService.creditExtract(player: Player, securedValue: number)
	if typeof(securedValue) ~= "number" or securedValue <= 0 then
		return
	end
	local profile = DataService.getProfile(player)
	profile.Gold += math.floor(securedValue)
	DataService.markDirty(player)
	fireState(player)
end

function EconomyService.setGadgetCharges(player: Player, charges: number)
	gadgetCharges[player] = charges
	fireState(player)
end

function EconomyService.clearGadgetCharges(player: Player)
	gadgetCharges[player] = nil
	fireState(player)
end

function EconomyService.consumeGadgetCharge(player: Player): boolean
	local charges = gadgetCharges[player]
	if typeof(charges) ~= "number" or charges <= 0 then
		return false
	end
	gadgetCharges[player] = charges - 1
	fireState(player)
	return true
end

local function buyBag(player: Player, bagId: string): boolean
	if not EconomyConfig.isValidBag(bagId) then
		return false
	end
	local profile = DataService.getProfile(player)
	if listHas(profile.OwnedBags, bagId) then
		return false
	end
	local def = EconomyConfig.getBag(bagId)
	if profile.Gold < def.Price then
		return false
	end
	profile.Gold -= def.Price
	table.insert(profile.OwnedBags, bagId)
	profile.EquippedBagId = bagId :: any
	DataService.markDirty(player)
	EconomyService.applyLoadout(player)
	return true
end

local function buyClass(player: Player, classId: string): boolean
	if not ClassConfig.isValid(classId) then
		return false
	end
	local price = EconomyConfig.getClassPrice(classId)
	if price == nil then
		return false
	end
	local profile = DataService.getProfile(player)
	if listHas(profile.UnlockedClasses, classId) or price <= 0 then
		return false
	end
	if profile.Gold < price then
		return false
	end
	profile.Gold -= price
	table.insert(profile.UnlockedClasses, classId)
	DataService.markDirty(player)
	fireState(player)
	return true
end

local function buyGadget(player: Player, gadgetId: string): boolean
	if not EconomyConfig.isValidGadget(gadgetId) then
		return false
	end
	local profile = DataService.getProfile(player)
	if listHas(profile.OwnedGadgets, gadgetId) then
		return false
	end
	local def = EconomyConfig.getGadget(gadgetId)
	if not def then
		return false
	end
	if profile.Gold < def.Price then
		return false
	end
	profile.Gold -= def.Price
	table.insert(profile.OwnedGadgets, gadgetId)
	profile.EquippedGadgetId = gadgetId
	DataService.markDirty(player)
	fireState(player)
	return true
end

function EconomyService.tryBuy(player: Player, kind: string, id: string): boolean
	if not inLobby(player) then
		return false
	end
	if kind == "Bag" then
		return buyBag(player, id)
	elseif kind == "Class" then
		return buyClass(player, id)
	elseif kind == "Gadget" then
		return buyGadget(player, id)
	end
	return false
end

function EconomyService.tryEquip(player: Player, bagId: unknown, gadgetId: unknown): boolean
	if not inLobby(player) then
		return false
	end
	local profile = DataService.getProfile(player)
	local changed = false

	if typeof(bagId) == "string" and EconomyConfig.isValidBag(bagId) then
		if listHas(profile.OwnedBags, bagId) then
			profile.EquippedBagId = bagId :: any
			changed = true
		end
	end

	if gadgetId == false or gadgetId == nil or gadgetId == "" then
		if profile.EquippedGadgetId ~= nil then
			profile.EquippedGadgetId = nil
			changed = true
		end
	elseif typeof(gadgetId) == "string" and EconomyConfig.isValidGadget(gadgetId) then
		if listHas(profile.OwnedGadgets, gadgetId) then
			profile.EquippedGadgetId = gadgetId
			changed = true
		end
	end

	if not changed then
		return false
	end
	DataService.markDirty(player)
	EconomyService.applyLoadout(player)
	return true
end

local function onPlayerReady(player: Player)
	DataService.loadPlayer(player)
	EconomyService.applyLoadout(player)
	local classId = player:GetAttribute("ClassId")
	if not ClassConfig.isValid(classId) or not EconomyService.isClassUnlocked(player, classId :: string) then
		player:SetAttribute("ClassId", ClassConfig.DefaultClassId)
	end
	fireState(player)
end

function EconomyService.init()
	if started then
		return
	end
	started = true

	DataService.init()

	Remotes.requestBuy().OnServerEvent:Connect(function(player: Player, kind: unknown, id: unknown)
		if typeof(kind) ~= "string" or typeof(id) ~= "string" then
			return
		end
		EconomyService.tryBuy(player, kind, id)
	end)

	Remotes.requestEquipLoadout().OnServerEvent:Connect(function(player: Player, bagId: unknown, gadgetId: unknown)
		EconomyService.tryEquip(player, bagId, gadgetId)
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			onPlayerReady(player)
		end)
	end)

	for _, player in Players:GetPlayers() do
		task.defer(function()
			onPlayerReady(player)
		end)
	end
end

return EconomyService
