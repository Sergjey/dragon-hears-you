local GameConfig = {
	DefaultWalkSpeed = 16,
	DefaultJumpPower = 50,

	-- Cloth Bag (MVP default)
	DefaultBagCapacity = 10,

	ExtractionDurationSeconds = 5,
	LootPickupMaxDistance = 12,

	-- Bag fill % → movement / noise (inclusive upper bounds checked in order)
	BagFillTiers = {
		{ MaxFill = 0.30, SpeedMultiplier = 1.00, FootstepNoiseMultiplier = 1.00 },
		{ MaxFill = 0.60, SpeedMultiplier = 0.95, FootstepNoiseMultiplier = 1.00 },
		{ MaxFill = 0.90, SpeedMultiplier = 0.90, FootstepNoiseMultiplier = 1.10 },
		{ MaxFill = 1.00, SpeedMultiplier = 0.80, FootstepNoiseMultiplier = 1.25 },
	},

	-- Noise HUD / future dragon stage thresholds
	StageThresholds = {
		Sleeping = 34,
		Disturbed = 69,
		PartialWake = 99,
		-- FullAwake = noise >= 100
	},
}

return GameConfig
