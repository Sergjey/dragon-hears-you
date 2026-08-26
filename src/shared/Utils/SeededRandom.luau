-- Tiny deterministic RNG for match seeding (Phase 8).
local SeededRandom = {}

export type Rng = {
	Next: (self: Rng) -> number, -- [0, 1)
	NextInt: (self: Rng, minInclusive: number, maxInclusive: number) -> number,
	Chance: (self: Rng, probability: number) -> boolean,
}

function SeededRandom.new(seed: number): Rng
	local state = math.floor(seed) % 2147483647
	if state <= 0 then
		state = 1
	end

	local rng = {}

	function rng:Next(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end

	function rng:NextInt(minInclusive: number, maxInclusive: number): number
		if maxInclusive <= minInclusive then
			return minInclusive
		end
		local span = maxInclusive - minInclusive + 1
		return minInclusive + math.floor(self:Next() * span)
	end

	function rng:Chance(probability: number): boolean
		return self:Next() < math.clamp(probability, 0, 1)
	end

	return rng :: Rng
end

function SeededRandom.utcDayKey(now: number?): number
	local t = now or os.time()
	return math.floor(t / 86400)
end

return SeededRandom
