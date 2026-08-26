local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local LootConfig = require(ReplicatedStorage.Shared.Config.LootConfig)
local LootTypes = require(ReplicatedStorage.Shared.Types.LootTypes)

local ReplayService = require(script.Parent.ReplayService)

type BackpackItem = LootTypes.BackpackItem
type BackpackState = LootTypes.BackpackState

local BackpackService = {}

local bags: { [Player]: BackpackState } = {}
local listeners: { (Player) -> () } = {}

local function emptyBag(): BackpackState
	return {
		Items = {},
		UsedWeight = 0,
		Capacity = GameConfig.DefaultBagCapacity,
		TotalValue = 0,
	}
end

local function recompute(state: BackpackState)
	local used = 0
	local value = 0
	for _, item in state.Items do
		used += item.Weight
		value += item.Value
	end
	state.UsedWeight = used
	state.TotalValue = value
end

function BackpackService.onChanged(callback: (Player) -> ())
	table.insert(listeners, callback)
end

function BackpackService.notify(player: Player)
	for _, callback in listeners do
		callback(player)
	end
end

function BackpackService.ensure(player: Player): BackpackState
	local state = bags[player]
	if not state then
		state = emptyBag()
		bags[player] = state
	end
	return state
end

function BackpackService.get(player: Player): BackpackState
	return BackpackService.ensure(player)
end

function BackpackService.setCapacity(player: Player, capacity: number)
	local state = BackpackService.ensure(player)
	state.Capacity = math.max(1, math.floor(capacity))
	BackpackService.notify(player)
end

function BackpackService.applyBagId(player: Player, bagId: string)
	local def = EconomyConfig.getBag(bagId)
	BackpackService.setCapacity(player, def.Capacity)
end

function BackpackService.getFillRatio(player: Player): number
	local state = BackpackService.ensure(player)
	if state.Capacity <= 0 then
		return 1
	end
	return math.clamp(state.UsedWeight / state.Capacity, 0, 1)
end

function BackpackService.canAdd(player: Player, lootId: string): (boolean, string?)
	local def = LootConfig.get(lootId)
	if not def then
		return false, "UnknownLoot"
	end
	if def.LootType ~= "Backpack" then
		return false, "NotBackpackLoot"
	end
	local state = BackpackService.ensure(player)
	if state.UsedWeight + def.Weight > state.Capacity then
		return false, "OverCapacity"
	end
	return true, nil
end

function BackpackService.add(player: Player, lootId: string): boolean
	local ok = BackpackService.canAdd(player, lootId)
	if not ok then
		return false
	end
	local def = LootConfig.get(lootId)
	if not def then
		return false
	end
	local state = BackpackService.ensure(player)
	local value = math.floor(def.Value * ReplayService.getLootValueMultiplier() + 0.5)
	table.insert(state.Items, {
		Id = def.Id,
		Value = value,
		Weight = def.Weight,
		Rarity = def.Rarity,
	})
	recompute(state)
	BackpackService.notify(player)
	return true
end

function BackpackService.clear(player: Player): (number, number)
	local state = BackpackService.ensure(player)
	local value = state.TotalValue
	local count = #state.Items
	state.Items = {}
	recompute(state)
	BackpackService.notify(player)
	return value, count
end

function BackpackService.dropAll(player: Player): { BackpackItem }
	local state = BackpackService.ensure(player)
	local items = table.clone(state.Items)
	state.Items = {}
	recompute(state)
	BackpackService.notify(player)
	return items
end

function BackpackService.init()
	Players.PlayerAdded:Connect(function(player)
		BackpackService.ensure(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		bags[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		BackpackService.ensure(player)
	end
end

return BackpackService
