local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local EconomyService = require(script.Parent.EconomyService)
local NoiseService = require(script.Parent.NoiseService)

local GadgetService = {}

local SMOKE_ATTR = "SmokeBombUntil"

local started = false
local matchActiveFor: { [Player]: boolean } = {}

local function canUse(player: Player): boolean
	if player:GetAttribute("GamePhase") ~= "Match" then
		return false
	end
	local status = player:GetAttribute("MatchStatus")
	if status ~= nil and status ~= "Alive" then
		return false
	end
	return matchActiveFor[player] == true
end

function GadgetService.lockForMatch(player: Player)
	matchActiveFor[player] = true
	player:SetAttribute(SMOKE_ATTR, nil)
	local gadgetId = EconomyService.getEquippedGadgetId(player)
	local def = EconomyConfig.getGadget(gadgetId)
	if def and def.IsActive then
		EconomyService.setGadgetCharges(player, 1)
	else
		EconomyService.setGadgetCharges(player, 0)
	end
end

function GadgetService.unlockAfterMatch(player: Player)
	matchActiveFor[player] = nil
	player:SetAttribute(SMOKE_ATTR, nil)
	EconomyService.clearGadgetCharges(player)
end

function GadgetService.tryUseGadget(player: Player): boolean
	if not canUse(player) then
		return false
	end
	local CarryService = require(script.Parent.CarryService)
	if CarryService.abilitiesDisabled(player) then
		return false
	end
	local gadgetId = EconomyService.getEquippedGadgetId(player)
	local def = EconomyConfig.getGadget(gadgetId)
	if not def or not def.IsActive then
		return false
	end

	if def.Id == "SmokeBomb" then
		if not EconomyService.consumeGadgetCharge(player) then
			return false
		end
		local duration = def.AbilityDurationSeconds or 5
		player:SetAttribute(SMOKE_ATTR, os.clock() + duration)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		Remotes.gadgetFx():FireAllClients({
			UserId = player.UserId,
			GadgetId = def.Id,
			Position = if root and root:IsA("BasePart") then root.Position else nil,
		})
		return true
	elseif def.Id == "DragonBait" then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return false
		end
		if not EconomyService.consumeGadgetCharge(player) then
			return false
		end
		local range = def.AbilityRange or 40
		local noise = def.AbilityNoise or 22
		local look = root.CFrame.LookVector
		local origin = root.Position + Vector3.new(0, 2, 0)
		local targetPos = origin + look * range
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local hit = Workspace:Raycast(origin, look * range, params)
		if hit then
			targetPos = hit.Position
		end
		NoiseService.add(noise, "DragonBait", targetPos)
		local marker = Instance.new("Part")
		marker.Name = "DragonBaitPing"
		marker.Shape = Enum.PartType.Ball
		marker.Size = Vector3.new(2.4, 2.4, 2.4)
		marker.Anchored = true
		marker.CanCollide = false
		marker.Material = Enum.Material.Neon
		marker.Color = Color3.fromRGB(180, 60, 220)
		marker.CFrame = CFrame.new(targetPos)
		marker.Parent = Workspace
		task.delay(2.5, function()
			if marker.Parent then
				marker:Destroy()
			end
		end)
		Remotes.gadgetFx():FireAllClients({
			UserId = player.UserId,
			GadgetId = def.Id,
			Position = targetPos,
		})
		return true
	end
	return false
end

function GadgetService.init()
	if started then
		return
	end
	started = true

	Remotes.requestUseGadget().OnServerEvent:Connect(function(player: Player)
		GadgetService.tryUseGadget(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		matchActiveFor[player] = nil
	end)
end

return GadgetService
