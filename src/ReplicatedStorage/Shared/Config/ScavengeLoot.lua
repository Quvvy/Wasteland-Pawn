local Items = require(script.Parent.Items)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local ScavengeLoot = {}

ScavengeLoot.Tables = {
	BasicJunk = {
		scrap_bent_pipe = 1,
		scrap_hubcap = 1,
		scrap_wire_bundle = 1,
		scrap_rusted_gear = 1,
		scrap_empty_can_stack = 1,
		scrap_broken_shovel = 1,
	},
}

function ScavengeLoot.roll(tableName: string, rng: Random?)
	local weights = ScavengeLoot.Tables[tableName]
	if not weights then
		return nil
	end

	local itemId = TableUtil.pickWeighted(weights, rng)
	if not itemId then
		return nil
	end

	return Items.get(itemId)
end

return ScavengeLoot
