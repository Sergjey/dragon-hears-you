-- Balance for Gorynych AI stages, perception, and placeholder attacks.
local DragonConfig = {
	MaxPlayerHP = 100,
	RespawnDelaySeconds = 3,

	-- After Disturbed event
	PostDisturbedNoise = 28,
	DisturbedEventCooldownSeconds = 12,

	-- Partial wake calm
	PartialCalmSeconds = 20,
	PostCalmNoise = 25,

	-- Hot breath (Stage 1)
	HotBreathTelegraphSeconds = 1.4,
	HotBreathDamageMin = 20,
	HotBreathDamageMax = 30,
	HotBreathRadius = 14,
	HotBreathOffsetStuds = 10, -- in front of chosen head

	-- Earthquake
	EarthquakeDurationMin = 3,
	EarthquakeDurationMax = 5,

	-- Perception
	VisionRange = 70,
	VisionHalfAngleDeg = 40,
	HearMinStrength = 1.5,
	HearMemorySeconds = 8,

	-- Hunting attacks
	FireBreathDamage = 35,
	FireBreathRange = 45,
	FireBreathHalfAngleDeg = 25,
	FireBreathCooldownSeconds = 6,
	FireBreathTelegraphSeconds = 1.0,

	SmokeSlowMultiplier = 0.55,
	SmokeDurationSeconds = 5,
	SmokeRadius = 16,
	SmokeCooldownSeconds = 10,
	SmokeCoughNoise = 2,

	AcidDamagePerTick = 8,
	AcidTickSeconds = 1,
	AcidDurationSeconds = 6,
	AcidRadius = 10,
	AcidCooldownSeconds = 9,

	HuntAttackIntervalSeconds = 4,
	HeadRiseStuds = 6,
	HeadRiseSeconds = 0.6,

	-- Head mapping on placeholder
	Heads = {
		Red = "Head1",
		Blue = "Head2",
		Green = "Head3",
	},
}

return DragonConfig
