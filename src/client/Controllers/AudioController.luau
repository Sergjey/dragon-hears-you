local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local RemotesClient = require(ReplicatedStorage.Shared.Net.RemotesClient)
local DragonTypes = require(ReplicatedStorage.Shared.Types.DragonTypes)
local MatchTypes = require(ReplicatedStorage.Shared.Types.MatchTypes)

type DragonEventPayload = DragonTypes.DragonEventPayload
type MatchStatePayload = MatchTypes.MatchStatePayload

local AudioController = {}

local player = Players.LocalPlayer
local sfxGroup: SoundGroup?
local tensionGroup: SoundGroup?
local tensionLoop: Sound?
local lastStage: string? = nil
local warnedIds: { [string]: boolean } = {}

local function ensureGroups()
	if sfxGroup and tensionGroup then
		return
	end
	sfxGroup = SoundService:FindFirstChild("GorynychSfx") :: SoundGroup?
	if not sfxGroup then
		sfxGroup = Instance.new("SoundGroup")
		sfxGroup.Name = "GorynychSfx"
		sfxGroup.Volume = AudioConfig.SfxVolume * AudioConfig.MasterVolume
		sfxGroup.Parent = SoundService
	end
	tensionGroup = SoundService:FindFirstChild("GorynychTension") :: SoundGroup?
	if not tensionGroup then
		tensionGroup = Instance.new("SoundGroup")
		tensionGroup.Name = "GorynychTension"
		tensionGroup.Volume = AudioConfig.TensionVolume * AudioConfig.MasterVolume
		tensionGroup.Parent = SoundService
	end
end

local function isPlayable(soundId: string?): boolean
	if typeof(soundId) ~= "string" or soundId == "" or soundId == "rbxassetid://0" then
		return false
	end
	return true
end

local function playOneShot(soundId: string?, volume: number?, parent: Instance?)
	ensureGroups()
	if not isPlayable(soundId) then
		return
	end
	local id = soundId :: string
	local holder = parent or Workspace.CurrentCamera or player:FindFirstChild("PlayerGui")
	if not holder then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 1
	sound.SoundGroup = sfxGroup
	sound.Parent = holder
	local played = false
	local ok, err = pcall(function()
		sound:Play()
		played = true
	end)
	if not ok then
		if not warnedIds[id] then
			warnedIds[id] = true
			warn("[Gorynych] Audio play failed:", id, err)
		end
		sound:Destroy()
		return
	end
	if not played then
		sound:Destroy()
		return
	end
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(6, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function applyStageTension(stage: string)
	ensureGroups()
	local cfg = AudioConfig.StageTension[stage] or AudioConfig.StageTension.Sleeping
	if tensionGroup then
		tensionGroup.Volume = cfg.Volume * AudioConfig.MasterVolume
	end
	if not tensionLoop then
		if not isPlayable(AudioConfig.TensionLoopId) then
			return
		end
		tensionLoop = Instance.new("Sound")
		tensionLoop.Name = "TensionLoop"
		tensionLoop.SoundId = AudioConfig.TensionLoopId
		tensionLoop.Looped = true
		tensionLoop.Volume = 0.4
		tensionLoop.SoundGroup = tensionGroup
		tensionLoop.Parent = SoundService
		local ok = pcall(function()
			tensionLoop:Play()
		end)
		if not ok and not warnedIds[AudioConfig.TensionLoopId] then
			warnedIds[AudioConfig.TensionLoopId] = true
			warn("[Gorynych] Tension loop failed:", AudioConfig.TensionLoopId)
		end
	end
	if tensionLoop then
		tensionLoop.PlaybackSpeed = cfg.Pitch
	end
end

function AudioController.start()
	ensureGroups()
	applyStageTension("Sleeping")

	RemotesClient.lootFx().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.UserId ~= player.UserId then
			return
		end
		playOneShot(AudioConfig.Sounds.LootPickup, 0.8)
	end)

	RemotesClient.matchResult().OnClientEvent:Connect(function()
		playOneShot(AudioConfig.Sounds.ExtractSuccess, 1)
	end)

	RemotesClient.matchEnded().OnClientEvent:Connect(function()
		-- keep soft; extract already covered for success path
	end)

	RemotesClient.extractionState().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) == "table" and payload.Success == true then
			playOneShot(AudioConfig.Sounds.ExtractSuccess, 1)
		end
	end)

	RemotesClient.dragonEvent().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or typeof(payload.Kind) ~= "string" then
			return
		end
		local kind = (payload :: DragonEventPayload).Kind
		if kind == "Growl" or kind == "Earthquake" then
			playOneShot(AudioConfig.Sounds.DragonGrowl, 0.9)
		elseif string.find(kind, "Breath") or kind == "Smoke" or kind == "Acid" then
			playOneShot(AudioConfig.Sounds.DragonBreath, 0.85)
		elseif kind == "FullAwakeBanner" then
			playOneShot(AudioConfig.Sounds.FullAwakeStinger, 1)
		end
	end)

	RemotesClient.dragonState().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.FullAwakeLocked then
			applyStageTension("FullAwake")
		end
	end)

	RemotesClient.matchState().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or typeof(payload.Stage) ~= "string" then
			return
		end
		local stage = (payload :: MatchStatePayload).Stage
		if stage ~= lastStage then
			if lastStage ~= nil then
				playOneShot(AudioConfig.Sounds.StageUp, 0.7)
			end
			lastStage = stage
			applyStageTension(stage)
		end
	end)

	RemotesClient.abilityFx().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.UserId == player.UserId then
			playOneShot(AudioConfig.Sounds.Ability, 0.7)
		end
	end)

	RemotesClient.gadgetFx().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.UserId == player.UserId then
			playOneShot(AudioConfig.Sounds.Gadget, 0.75)
		end
	end)

	player:GetAttributeChangedSignal("MatchStatus"):Connect(function()
		if player:GetAttribute("MatchStatus") == "Downed" then
			playOneShot(AudioConfig.Sounds.Downed, 0.9)
		end
	end)
end

return AudioController
