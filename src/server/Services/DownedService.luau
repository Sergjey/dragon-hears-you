local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DragonConfig = require(ReplicatedStorage.Shared.Config.DragonConfig)
local MultiplayerConfig = require(ReplicatedStorage.Shared.Config.MultiplayerConfig)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local ExtractionService = require(script.Parent.ExtractionService)
local MovementModifierService = require(script.Parent.MovementModifierService)

local DownedService = {}

type DownedSession = {
	BleedoutRemaining: number,
	Prompt: ProximityPrompt?,
}

local sessions: { [Player]: DownedSession } = {}
local started = false
local matchActiveChecker: (() -> boolean)? = nil

local onDowned: ((Player) -> ())? = nil
local onRevived: ((Player) -> ())? = nil
local onBleedoutDead: ((Player) -> ())? = nil

local setHP: ((Player, number) -> ())? = nil
local dropLootAt: ((Player) -> ())? = nil
local syncAttrs: ((Player) -> ())? = nil
local canRevive: ((Player) -> boolean)? = nil

function DownedService.bindMatchCallbacks(callbacks: {
	OnDowned: (Player) -> (),
	OnRevived: (Player) -> (),
	OnBleedoutDead: (Player) -> (),
	CanRevive: (Player) -> boolean,
	IsMatchActive: () -> boolean,
})
	onDowned = callbacks.OnDowned
	onRevived = callbacks.OnRevived
	onBleedoutDead = callbacks.OnBleedoutDead
	canRevive = callbacks.CanRevive
	matchActiveChecker = callbacks.IsMatchActive
end

function DownedService.bindDamageHelpers(helpers: {
	SetHP: (Player, number) -> (),
	DropLootAt: (Player) -> (),
	SyncAttributes: (Player) -> (),
})
	setHP = helpers.SetHP
	dropLootAt = helpers.DropLootAt
	syncAttrs = helpers.SyncAttributes
end

function DownedService.isDowned(player: Player): boolean
	return sessions[player] ~= nil
end

function DownedService.getBleedoutRemaining(player: Player): number
	local session = sessions[player]
	return if session then session.BleedoutRemaining else 0
end

local function clearPrompt(session: DownedSession)
	if session.Prompt then
		session.Prompt:Destroy()
		session.Prompt = nil
	end
end

local function applyDownedPhysics(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.PlatformStand = true
		humanoid.AutoRotate = false
	end
end

local function clearDownedPhysics(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
		humanoid.JumpPower = 50
	end
	MovementModifierService.applyForPlayer(player)
end

local function attachRevivePrompt(player: Player, session: DownedSession)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	clearPrompt(session)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "Revive"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = MultiplayerConfig.ReviveHoldSeconds
	prompt.MaxActivationDistance = MultiplayerConfig.ReviveMaxDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	session.Prompt = prompt

	prompt.Triggered:Connect(function(reviver: Player)
		DownedService.tryRevive(reviver, player)
	end)
end

function DownedService.enterDowned(player: Player)
	if sessions[player] then
		return
	end
	if matchActiveChecker and not matchActiveChecker() then
		return
	end

	ExtractionService.cancelOnDamage(player)
	if setHP then
		setHP(player, 0)
	end
	if syncAttrs then
		syncAttrs(player)
	end

	local session: DownedSession = {
		BleedoutRemaining = MultiplayerConfig.BleedoutSeconds,
		Prompt = nil,
	}
	sessions[player] = session
	applyDownedPhysics(player)
	attachRevivePrompt(player, session)
	player:SetAttribute("MatchStatus", "Downed")

	if onDowned then
		onDowned(player)
	end
end

function DownedService.tryRevive(reviver: Player, target: Player): boolean
	if reviver == target then
		return false
	end
	if not sessions[target] then
		return false
	end
	if sessions[reviver] then
		return false
	end
	if canRevive and not canRevive(reviver) then
		return false
	end

	local revRoot = reviver.Character and reviver.Character:FindFirstChild("HumanoidRootPart")
	local tgtRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not revRoot or not tgtRoot or not revRoot:IsA("BasePart") or not tgtRoot:IsA("BasePart") then
		return false
	end
	if (revRoot.Position - tgtRoot.Position).Magnitude > MultiplayerConfig.ReviveMaxDistance then
		return false
	end

	local session = sessions[target]
	clearPrompt(session)
	sessions[target] = nil

	local heal = math.floor(DragonConfig.MaxPlayerHP * MultiplayerConfig.ReviveHealthFraction)
	if setHP then
		setHP(target, heal)
	end
	if syncAttrs then
		syncAttrs(target)
	end
	clearDownedPhysics(target)
	target:SetAttribute("MatchStatus", "Alive")

	if onRevived then
		onRevived(target)
	end
	return true
end

local function finishBleedout(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	clearPrompt(session)
	sessions[player] = nil

	if dropLootAt then
		dropLootAt(player)
	end

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end
	end
	player:SetAttribute("MatchStatus", "Dead")

	if onBleedoutDead then
		onBleedoutDead(player)
	end
end

function DownedService.clear(player: Player)
	local session = sessions[player]
	if session then
		clearPrompt(session)
		sessions[player] = nil
	end
end

-- Studio / tests: expire bleedout on next Heartbeat
function DownedService.debugExpireBleedout(player: Player): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	session.BleedoutRemaining = 0
	return true
end

function DownedService.init()
	if started then
		return
	end
	started = true

	-- Revive is ProximityPrompt-only (HoldDuration = ReviveHoldSeconds).
	-- Ignore RequestRevive so clients cannot skip the hold.
	Remotes.requestRevive().OnServerEvent:Connect(function(_reviver: Player, _targetUserId: unknown) end)

	Players.PlayerRemoving:Connect(function(player)
		DownedService.clear(player)
	end)

	RunService.Heartbeat:Connect(function(dt)
		if matchActiveChecker and not matchActiveChecker() then
			return
		end
		for player, session in sessions do
			if not player.Parent then
				continue
			end
			applyDownedPhysics(player)
			session.BleedoutRemaining -= dt
			if session.BleedoutRemaining <= 0 then
				finishBleedout(player)
			end
		end
	end)
end

return DownedService
