local TableUtil = {}

function TableUtil.pickRandom<T>(list: { T }, rng: Random?): T?
	if #list == 0 then
		return nil
	end

	local random = rng or Random.new()
	return list[random:NextInteger(1, #list)]
end

function TableUtil.pickWeighted(weights: { [string]: number }, rng: Random?): string?
	local total = 0
	for _, weight in weights do
		total += weight
	end

	if total <= 0 then
		return nil
	end

	local random = rng or Random.new()
	local roll = random:NextNumber(0, total)
	local cumulative = 0

	for key, weight in weights do
		cumulative += weight
		if roll <= cumulative then
			return key
		end
	end

	return nil
end

function TableUtil.indexById<T>(list: { T }, getId: (T) -> string): { [string]: T }
	local map = {}
	for _, entry in list do
		map[getId(entry)] = entry
	end
	return map
end

return TableUtil
