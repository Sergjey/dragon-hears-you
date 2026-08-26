local Players = game:GetService("Players")

local Remotes = require(script.Parent.Parent.Net.Remotes)
local DungeonBootstrap = require(script.Parent.Parent.Bootstrap.DungeonBootstrap)

local BackpackService = require(script.Parent.BackpackService)
local DamageService = require(script.Parent.DamageService)
local DragonService = require(script.Parent.DragonService)
local ExtractionService = require(script.Parent.ExtractionService)
local LootService = require(script.Parent.LootService)
local MovementModifierService = require(script.Parent.MovementModifierService)
local NoiseService = require(script.Parent.NoiseService)

local MatchService = {}

local started = false

local function teleportToSpawn(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.CFrame = DungeonBootstrap.getSpawnCFrame()
	end
end

local function onCharacter(player: Player, character: Model)
	task.defer(function()
		local root = character:WaitForChild("HumanoidRootPart", 8)
		if root then
			teleportToSpawn(player)
		end
		MovementModifierService.applyForPlayer(player)
		NoiseService.broadcastMatchState(player)
	end)
end

local function bindDropRemote()
	Remotes.requestDropLoot().OnServerEvent:Connect(function(player: Player, mode: unknown)
		if typeof(mode) ~= "string" then
			return
		end
		if mode ~= "All" then
			return
		end
		local items = BackpackService.dropAll(player)
		if #items > 0 then
			local character = player.Character
			local pos: Vector3? = nil
			if character then
				local root = character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					pos = root.Position
				end
			end
			NoiseService.add(2, "DropLoot", pos)
			MovementModifierService.applyForPlayer(player)
		end
	end)
end

function MatchService.init()
	if started then
		return
	end
	started = true

	Remotes.init()
	NoiseService.init()
	BackpackService.init()
	MovementModifierService.init()
	ExtractionService.init()
	DamageService.init()
	bindDropRemote()

	DungeonBootstrap.build()
	ExtractionService.refreshZones()
	LootService.init()
	NoiseService.startMatch()
	DragonService.init()
	DragonService.reset()

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
		ExtractionService.resetPlayer(player)
		DamageService.resetPlayer(player)
		task.defer(function()
			NoiseService.broadcastMatchState(player)
		end)
	end)

	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
		DamageService.resetPlayer(player)
	end
end

return MatchService
