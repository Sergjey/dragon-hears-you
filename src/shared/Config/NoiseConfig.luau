local NoiseConfig = {
	Min = 0,
	Max = 100,

	-- Decay: -1 Noise every DecayIntervalSeconds while quiet
	DecayAmount = 1,
	DecayIntervalSeconds = 2,

	-- Movement (server-sampled)
	WalkNoisePerSecond = 0.2,
	RunNoisePerSecond = 1.0,
	RunSpeedThreshold = 18, -- WalkSpeed above this counts as run contribution
	JumpNoise = 2,
	FallNoiseMin = 3,
	FallNoiseMax = 15,
	FallStudsForMax = 40,

	FootstepSampleHz = 10, -- movement noise integration rate
}

return NoiseConfig
