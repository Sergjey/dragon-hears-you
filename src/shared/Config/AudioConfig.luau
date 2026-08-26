-- Tunable SFX / tension bus. Use built-in rbxasset sounds so Studio works without Creator Store.
-- Swap SoundIds later; empty / rbxassetid://0 skips playback (soft fail).

export type StageAudio = {
	Volume: number,
	Pitch: number,
}

local AudioConfig = {
	MasterVolume = 0.85,
	SfxVolume = 0.9,
	TensionVolume = 0.35,

	Sounds = {
		LootPickup = "rbxasset://sounds/electronicpingshort.wav",
		ExtractSuccess = "rbxasset://sounds/swoosh.wav",
		Downed = "rbxasset://sounds/impact_water.mp3",
		StageUp = "rbxasset://sounds/switch.wav",
		DragonGrowl = "rbxasset://sounds/impact_water.mp3",
		DragonBreath = "rbxasset://sounds/swoosh.wav",
		FullAwakeStinger = "rbxasset://sounds/switch.wav",
		Ability = "rbxasset://sounds/swoosh.wav",
		Gadget = "rbxasset://sounds/electronicpingshort.wav",
	},

	StageTension = {
		Sleeping = { Volume = 0.05, Pitch = 0.9 } :: StageAudio,
		Disturbed = { Volume = 0.15, Pitch = 1.0 } :: StageAudio,
		PartialWake = { Volume = 0.28, Pitch = 1.08 } :: StageAudio,
		FullAwake = { Volume = 0.45, Pitch = 1.2 } :: StageAudio,
	},

	-- Soft ambient loop; replace with custom music later
	TensionLoopId = "rbxasset://sounds/action_get_up.mp3",
}

return AudioConfig
