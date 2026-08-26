local ClassTypes = require(script.Parent.Parent.Types.ClassTypes)

type ClassId = ClassTypes.ClassId
type ClassDefinition = ClassTypes.ClassDefinition

local definitions: { [ClassId]: ClassDefinition } = {
	Thief = {
		Id = "Thief",
		DisplayName = "Thief",
		Description = "Stealth loot — quieter, faster steals",
		FootstepNoiseMultiplier = 0.7,
		WalkSpeedMultiplier = 1.1,
		LootPromptSpeedBonus = 0.15,
		ReviveSpeedMultiplier = 1,
		MaxHPMultiplier = 1,
		AbilityId = "SilentStep",
		AbilityName = "Silent Step",
		AbilityDurationSeconds = 5,
		AbilityCooldownSeconds = 30,
	},
	Medic = {
		Id = "Medic",
		DisplayName = "Medic",
		Description = "Support — faster revives and field heal",
		FootstepNoiseMultiplier = 1,
		WalkSpeedMultiplier = 1,
		LootPromptSpeedBonus = 0,
		ReviveSpeedMultiplier = 1.5,
		MaxHPMultiplier = 1,
		AbilityId = "Heal",
		AbilityName = "Heal",
		AbilityCooldownSeconds = 25,
		AbilityHealFraction = 0.4,
		AbilityRange = 18,
	},
	Guardian = {
		Id = "Guardian",
		DisplayName = "Guardian",
		Description = "Protector — tougher, emergency shield",
		FootstepNoiseMultiplier = 1,
		WalkSpeedMultiplier = 1,
		LootPromptSpeedBonus = 0,
		ReviveSpeedMultiplier = 1,
		MaxHPMultiplier = 1.3,
		AbilityId = "Shield",
		AbilityName = "Shield",
		AbilityDurationSeconds = 8,
		AbilityCooldownSeconds = 35,
	},
	Trickster = {
		Id = "Trickster",
		DisplayName = "Trickster",
		Description = "Gadgets — throw noise to distract the dragon",
		FootstepNoiseMultiplier = 1,
		WalkSpeedMultiplier = 1,
		LootPromptSpeedBonus = 0,
		ReviveSpeedMultiplier = 1,
		MaxHPMultiplier = 1,
		AbilityId = "NoiseMaker",
		AbilityName = "Noise Maker",
		AbilityCooldownSeconds = 20,
		AbilityNoise = 18,
		AbilityRange = 40,
	},
	Scout = {
		Id = "Scout",
		DisplayName = "Scout",
		Description = "Information — sense treasure and the dragon",
		FootstepNoiseMultiplier = 1,
		WalkSpeedMultiplier = 1.05,
		LootPromptSpeedBonus = 0,
		ReviveSpeedMultiplier = 1,
		MaxHPMultiplier = 1,
		AbilityId = "TreasureSense",
		AbilityName = "Treasure Sense",
		AbilityDurationSeconds = 5,
		AbilityCooldownSeconds = 30,
		AbilityRange = 120,
		SenseMinRarity = "Rare",
		PassiveLootRange = 45,
	},
}

local ClassConfig = {
	DefaultClassId = "Thief" :: ClassId,
	OrderedIds = { "Thief", "Medic", "Guardian", "Trickster", "Scout" } :: { ClassId },
}

function ClassConfig.get(id: string?): ClassDefinition
	if id and definitions[id :: ClassId] then
		return definitions[id :: ClassId]
	end
	return definitions[ClassConfig.DefaultClassId]
end

function ClassConfig.isValid(id: unknown): boolean
	return typeof(id) == "string" and definitions[id :: ClassId] ~= nil
end

function ClassConfig.list(): { ClassDefinition }
	local list = {}
	for _, id in ClassConfig.OrderedIds do
		table.insert(list, definitions[id])
	end
	return list
end

return ClassConfig
