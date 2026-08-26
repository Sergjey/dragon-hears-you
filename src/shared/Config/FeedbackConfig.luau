local LootTypes = require(script.Parent.Parent.Types.LootTypes)

type Rarity = LootTypes.Rarity

local FeedbackConfig = {
	ShakeScale = 1.15,
	TelegraphFadeSeconds = 0.2,

	LootBobAmplitude = 0.35,
	LootBobSpeed = 2.2,
	LootSpinSpeed = 0.9,

	PopupLifetime = 1.1,
	ParticleLifetime = 0.85,

	RarityColors = {
		Common = Color3.fromRGB(180, 180, 180),
		Uncommon = Color3.fromRGB(80, 180, 100),
		Rare = Color3.fromRGB(70, 140, 230),
		Epic = Color3.fromRGB(160, 80, 220),
		Legendary = Color3.fromRGB(232, 160, 40),
		Mythic = Color3.fromRGB(232, 80, 80),
	} :: { [Rarity]: Color3 },

	StageVignette = {
		Sleeping = 0.95,
		Disturbed = 0.82,
		PartialWake = 0.68,
		FullAwake = 0.45,
	},

	AbilityColors = {
		SilentStep = Color3.fromRGB(140, 200, 255),
		Heal = Color3.fromRGB(80, 220, 120),
		Shield = Color3.fromRGB(230, 210, 90),
		NoiseMaker = Color3.fromRGB(232, 120, 48),
		TreasureSense = Color3.fromRGB(100, 180, 255),
		SmokeBomb = Color3.fromRGB(120, 130, 150),
		DragonBait = Color3.fromRGB(180, 60, 220),
	},
}

function FeedbackConfig.rarityColor(rarity: string?): Color3
	if rarity and FeedbackConfig.RarityColors[rarity :: Rarity] then
		return FeedbackConfig.RarityColors[rarity :: Rarity]
	end
	return FeedbackConfig.RarityColors.Common
end

return FeedbackConfig
