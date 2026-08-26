local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonConfig = require(ReplicatedStorage.Shared.Config.DragonConfig)
local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)

local BackpackService = require(script.Parent.BackpackService)
local CarryService = require(script.Parent.CarryService)
local DownedService = require(script.Parent.DownedService)
local ExtractionService = require(script.Parent.ExtractionService)
local LootService = require(script.Parent.LootService)
local MovementModifierService = require(script.Parent.MovementModifierService)
local NoiseService = require(script.Parent.NoiseService)

local DamageService = {}

local HP_ATTR = "HP"
local MAX_HP_ATTR = "MaxHP"

local hp: { [Player]: number } = {}
local started = false

-- Optional gate from MatchService: only Alive can take damage
local canTakeDamage: ((Player) -> boolean)? = nil
local absorbDamage: ((Player, number) -> number)? = nil

local function getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function DamageService.getMaxHP(player: Player): number
	local mul = ClassConfig.get(player:GetAttribute("ClassId") :: any).MaxHPMultiplier
	return math.floor(DragonConfig.MaxPlayerHP * mul)
end

local function syncAttributes(player: Player)
	local maxHp = DamageService.getMaxHP(player)
	local current = hp[player]
	if current == nil then
		current = maxHp
		hp[player] = current
	else
		current = math.clamp(current, 0, maxHp)
		hp[player] = current
	end
	player:SetAttribute(HP_ATTR, current)
	player:SetAttribute(MAX_HP_ATTR, maxHp)
end

function DamageService.bindCanTakeDamage(fn: (Player) -> boolean)
	canTakeDamage = fn
end

function DamageService.bindAbsorb(fn: (Player, number) -> number)
	absorbDamage = fn
end

function DamageService.getHP(player: Player): number
	return hp[player] or DamageService.getMaxHP(player)
end

function DamageService.setHP(player: Player, value: number)
	local maxHp = DamageService.getMaxHP(player)
	hp[player] = math.clamp(value, 0, maxHp)
	syncAttributes(player)
end

function DamageService.syncAttributes(player: Player)
	syncAttributes(player)
end

function DamageService.isDead(player: Player): boolean
	return player:GetAttribute("MatchStatus") == "Dead"
end

function DamageService.isDownedOrDead(player: Player): boolean
	local status = player:GetAttribute("MatchStatus")
	return status == "Downed" or status == "Dead" or status == "Extracted" or DownedService.isDowned(player)
end

function DamageService.resetPlayer(player: Player)
	hp[player] = DamageService.getMaxHP(player)
	syncAttributes(player)
end

function DamageService.dropLootAt(player: Player)
	CarryService.dropForPlayer(player, true)
	local root = getRoot(player)
	local pos = if root then root.Position else Vector3.new(0, 5, 0)
	local items = BackpackService.dropAll(player)
	for i, item in items do
		local offset = Vector3.new((i % 3) - 1, 0, math.floor(i / 3))
		LootService.spawnDroppedLoot(item.Id, pos + offset * 2)
	end
	if #items > 0 then
		NoiseService.add(4, "DeathDrop", pos)
	end
	MovementModifierService.applyForPlayer(player)
end

function DamageService.dropLootAtPosition(player: Player, position: Vector3)
	CarryService.dropForPlayer(player, true)
	local items = BackpackService.dropAll(player)
	for i, item in items do
		local offset = Vector3.new((i % 3) - 1, 0, math.floor(i / 3))
		LootService.spawnDroppedLoot(item.Id, position + offset * 2)
	end
	if #items > 0 then
		NoiseService.add(4, "DeathDrop", position)
	end
end

function DamageService.applyDamage(player: Player, amount: number, _source: string)
	if not NoiseService.isMatchActive() then
		return
	end
	if amount <= 0 then
		return
	end
	if DownedService.isDowned(player) then
		return
	end
	if canTakeDamage and not canTakeDamage(player) then
		return
	end

	ExtractionService.cancelOnDamage(player)

	-- Guardian Shield: attribute is source of truth
	local charges = player:GetAttribute("ShieldCharges")
	if typeof(charges) == "number" and charges > 0 then
		player:SetAttribute("ShieldCharges", (charges :: number) - 1)
		if absorbDamage then
			absorbDamage(player, amount)
		end
		return
	end

	local incoming = amount
	local maxHp = DamageService.getMaxHP(player)
	local current = hp[player] or maxHp
	current = math.max(0, current - incoming)
	hp[player] = current
	syncAttributes(player)

	if current <= 0 then
		DownedService.enterDowned(player)
	end
end

function DamageService.applyAoE(center: Vector3, radius: number, amount: number, source: string)
	for _, player in Players:GetPlayers() do
		if DownedService.isDowned(player) then
			continue
		end
		if canTakeDamage and not canTakeDamage(player) then
			continue
		end
		local root = getRoot(player)
		if root and (root.Position - center).Magnitude <= radius then
			DamageService.applyDamage(player, amount, source)
		end
	end
end

function DamageService.applyCone(
	origin: Vector3,
	look: Vector3,
	range: number,
	halfAngleDeg: number,
	amount: number,
	source: string
)
	local lookUnit = if look.Magnitude > 0 then look.Unit else Vector3.new(0, 0, -1)
	local cosLimit = math.cos(math.rad(halfAngleDeg))
	for _, player in Players:GetPlayers() do
		if DownedService.isDowned(player) then
			continue
		end
		if canTakeDamage and not canTakeDamage(player) then
			continue
		end
		local root = getRoot(player)
		if not root then
			continue
		end
		local offset = root.Position - origin
		local dist = offset.Magnitude
		if dist > range or dist < 0.1 then
			continue
		end
		if lookUnit:Dot(offset.Unit) >= cosLimit then
			DamageService.applyDamage(player, amount, source)
		end
	end
end

function DamageService.init()
	if started then
		return
	end
	started = true

	DownedService.bindDamageHelpers({
		SetHP = DamageService.setHP,
		DropLootAt = DamageService.dropLootAt,
		SyncAttributes = DamageService.syncAttributes,
	})

	local function hook(player: Player)
		DamageService.resetPlayer(player)
		player.CharacterAdded:Connect(function()
			local status = player:GetAttribute("MatchStatus")
			if status == "Alive" or status == nil then
				DamageService.resetPlayer(player)
			end
			task.defer(function()
				MovementModifierService.applyForPlayer(player)
			end)
		end)
	end

	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(function(player)
		hp[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return DamageService
