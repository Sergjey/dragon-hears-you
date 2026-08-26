local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonConfig = require(ReplicatedStorage.Shared.Config.DragonConfig)

local BackpackService = require(script.Parent.BackpackService)
local ExtractionService = require(script.Parent.ExtractionService)
local LootService = require(script.Parent.LootService)
local MovementModifierService = require(script.Parent.MovementModifierService)
local NoiseService = require(script.Parent.NoiseService)

local DamageService = {}

local HP_ATTR = "HP"
local MAX_HP_ATTR = "MaxHP"

local hp: { [Player]: number } = {}
local dead: { [Player]: boolean } = {}
local started = false

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

local function syncAttributes(player: Player)
	local maxHp = DragonConfig.MaxPlayerHP
	local current = hp[player] or maxHp
	player:SetAttribute(HP_ATTR, current)
	player:SetAttribute(MAX_HP_ATTR, maxHp)
end

function DamageService.getHP(player: Player): number
	return hp[player] or DragonConfig.MaxPlayerHP
end

function DamageService.isDead(player: Player): boolean
	return dead[player] == true
end

function DamageService.resetPlayer(player: Player)
	hp[player] = DragonConfig.MaxPlayerHP
	dead[player] = false
	syncAttributes(player)
end

local function dropLootAt(player: Player)
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

local function kill(player: Player, _source: string)
	if dead[player] then
		return
	end
	dead[player] = true
	hp[player] = 0
	syncAttributes(player)
	ExtractionService.cancelOnDamage(player)
	dropLootAt(player)

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end
	end

	task.delay(DragonConfig.RespawnDelaySeconds, function()
		if not player.Parent then
			return
		end
		dead[player] = false
		hp[player] = DragonConfig.MaxPlayerHP
		syncAttributes(player)
		player:LoadCharacter()
	end)
end

function DamageService.applyDamage(player: Player, amount: number, source: string)
	if not NoiseService.isMatchActive() then
		return
	end
	if dead[player] or amount <= 0 then
		return
	end

	ExtractionService.cancelOnDamage(player)
	local current = hp[player] or DragonConfig.MaxPlayerHP
	current = math.max(0, current - amount)
	hp[player] = current
	syncAttributes(player)

	if current <= 0 then
		kill(player, source)
	end
end

function DamageService.applyAoE(center: Vector3, radius: number, amount: number, source: string)
	for _, player in Players:GetPlayers() do
		if dead[player] then
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
		if dead[player] then
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

	local function hook(player: Player)
		DamageService.resetPlayer(player)
		player.CharacterAdded:Connect(function()
			if not dead[player] then
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
		dead[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return DamageService
