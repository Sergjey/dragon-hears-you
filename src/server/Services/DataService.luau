local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local EconomyTypes = require(ReplicatedStorage.Shared.Types.EconomyTypes)

type PlayerEconomyProfile = EconomyTypes.PlayerEconomyProfile
type BagId = EconomyTypes.BagId

local DataService = {}

local store: DataStore? = nil
local profiles: { [Player]: PlayerEconomyProfile } = {}
local dirty: { [Player]: boolean } = {}
local saveTokens: { [Player]: number } = {}
local started = false

local function listHas(list: { string }, id: string): boolean
	for _, v in list do
		if v == id then
			return true
		end
	end
	return false
end

local function sanitize(raw: any): PlayerEconomyProfile
	local profile = EconomyConfig.defaultProfile()
	if typeof(raw) ~= "table" then
		return profile
	end

	if typeof(raw.Gold) == "number" then
		profile.Gold = math.max(0, math.floor(raw.Gold))
	end

	if EconomyConfig.isValidBag(raw.EquippedBagId) then
		profile.EquippedBagId = raw.EquippedBagId :: BagId
	end

	if typeof(raw.OwnedBags) == "table" then
		local owned = {}
		for _, id in raw.OwnedBags do
			if EconomyConfig.isValidBag(id) and not listHas(owned, id :: string) then
				table.insert(owned, id :: string)
			end
		end
		if not listHas(owned, EconomyConfig.DefaultBagId) then
			table.insert(owned, 1, EconomyConfig.DefaultBagId)
		end
		if #owned > 0 then
			profile.OwnedBags = owned
		end
	end
	if not listHas(profile.OwnedBags, profile.EquippedBagId) then
		profile.EquippedBagId = EconomyConfig.DefaultBagId
	end

	if typeof(raw.UnlockedClasses) == "table" then
		local unlocked = {}
		for _, id in raw.UnlockedClasses do
			if typeof(id) == "string" and not listHas(unlocked, id) then
				table.insert(unlocked, id)
			end
		end
		if not listHas(unlocked, "Thief") then
			table.insert(unlocked, 1, "Thief")
		end
		profile.UnlockedClasses = unlocked
	end

	if typeof(raw.OwnedGadgets) == "table" then
		local ownedG = {}
		for _, id in raw.OwnedGadgets do
			if EconomyConfig.isValidGadget(id) and not listHas(ownedG, id :: string) then
				table.insert(ownedG, id :: string)
			end
		end
		profile.OwnedGadgets = ownedG
	end

	if typeof(raw.EquippedGadgetId) == "string" and EconomyConfig.isValidGadget(raw.EquippedGadgetId) then
		if listHas(profile.OwnedGadgets, raw.EquippedGadgetId) then
			profile.EquippedGadgetId = raw.EquippedGadgetId
		end
	else
		profile.EquippedGadgetId = nil
	end

	return profile
end

local function keyFor(userId: number): string
	return `u_{userId}`
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(EconomyConfig.DataStoreName)
	end)
	if ok then
		store = result
		return store
	end
	warn("[Gorynych] DataStore unavailable:", result)
	return nil
end

function DataService.getProfile(player: Player): PlayerEconomyProfile
	local existing = profiles[player]
	if existing then
		return existing
	end
	local profile = EconomyConfig.defaultProfile()
	profiles[player] = profile
	return profile
end

function DataService.markDirty(player: Player)
	dirty[player] = true
	local token = (saveTokens[player] or 0) + 1
	saveTokens[player] = token
	task.delay(EconomyConfig.SaveDebounceSeconds, function()
		if saveTokens[player] ~= token then
			return
		end
		DataService.savePlayer(player)
	end)
end

function DataService.loadPlayer(player: Player): PlayerEconomyProfile
	local profile = EconomyConfig.defaultProfile()
	local ds = getStore()
	if ds then
		local ok, data = pcall(function()
			return ds:GetAsync(keyFor(player.UserId))
		end)
		if ok then
			profile = sanitize(data)
		else
			warn(`[Gorynych] DataStore GetAsync failed for {player.Name}:`, data)
		end
	end
	profiles[player] = profile
	dirty[player] = false
	return profile
end

function DataService.savePlayer(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	if not dirty[player] then
		return true
	end
	local ds = getStore()
	if not ds then
		dirty[player] = false
		return false
	end
	local payload = {
		Gold = profile.Gold,
		EquippedBagId = profile.EquippedBagId,
		OwnedBags = profile.OwnedBags,
		UnlockedClasses = profile.UnlockedClasses,
		OwnedGadgets = profile.OwnedGadgets,
		EquippedGadgetId = profile.EquippedGadgetId,
	}
	local ok, err = pcall(function()
		ds:SetAsync(keyFor(player.UserId), payload)
	end)
	if not ok then
		warn(`[Gorynych] DataStore SetAsync failed for {player.Name}:`, err)
		return false
	end
	dirty[player] = false
	return true
end

function DataService.init()
	if started then
		return
	end
	started = true
	getStore()

	Players.PlayerRemoving:Connect(function(player)
		DataService.savePlayer(player)
		profiles[player] = nil
		dirty[player] = nil
		saveTokens[player] = nil
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			DataService.savePlayer(player)
		end
	end)
end

return DataService
