local NpcTells = {}

local CUSTOMER_TELLS = {
	desperate_survivor = { "Keeps glancing at the door.", "Looks desperate.", "Hands won't stop shaking." },
	shady_scammer = { "Trying too hard to sell it.", "Smiles too wide.", "Avoids your eyes on the price tag." },
	rich_collector = { "Clearly knows the market.", "Seems proud.", "Inspects the item like a museum piece." },
	robot_trader = { "Acts calm, maybe too calm.", "Recites specs from memory.", "No emotion in their voice." },
	mutant_drifter = { "In a hurry.", "Keeps tapping their foot.", "Low patience written on their face." },
	nervous_rookie = { "Avoids eye contact.", "First-day energy.", "Keeps checking their scrap pouch." },
	soldier = { "Stands rigid. Dislikes games.", "In a hurry.", "Fair-deal vibe, not chatty." },
	junk_dealer = { "Clearly knows the market.", "Experienced eyes.", "Unimpressed by theatrics." },
	alien_tourist = { "Confused by Earth pricing.", "Keeps staring at the item.", "Might misjudge value." },
	silent_stranger = { "Hard to read.", "Barely speaks.", "Few tells. High mystery." },
}

local BUYER_TELLS = {
	cheap_scavenger = { "Counts scraps twice.", "Opens insultingly low.", "Wants a steal." },
	rich_collector = { "Keeps staring at the item.", "Seems proud of their wallet.", "Might pay big for the right piece." },
	desperate_mechanic = { "Keeps staring at the part.", "In a hurry.", "Really needs this category." },
	alien_tourist = { "Confused but excited.", "Might overvalue weird stuff.", "Unpredictable mood." },
	robot_appraiser = { "Runs numbers silently.", "Pays close to true value.", "No emotional tells." },
	black_market_dealer = { "Acts calm, maybe too calm.", "Tough negotiator.", "Testing your nerve." },
}

local function pick(pool: { string }, rng: Random?): string
	if #pool == 0 then
		return "Hard to read."
	end
	local random = rng or Random.new()
	return pool[random:NextInteger(1, #pool)]
end

local function tellFromStats(npc, rng: Random?): string
	local pool = {}

	if (npc.desperation or 0) >= 0.7 then
		table.insert(pool, "Looks desperate.")
		table.insert(pool, "Keeps glancing at the door.")
	end
	if (npc.knowledge or 0) >= 0.7 then
		table.insert(pool, "Clearly knows the market.")
	end
	if (npc.greed or 0) >= 0.7 then
		table.insert(pool, "Trying too hard to sell it.")
	end
	if (npc.temper or 0) >= 0.7 then
		table.insert(pool, "Short fuse energy.")
	end
	if (npc.scamBias or 0) >= 0.4 then
		table.insert(pool, "Price feels inflated.")
	end
	if (npc.urgency or 0) >= 0.7 then
		table.insert(pool, "In a hurry.")
	end
	if (npc.patience or 0.5) <= 0.35 then
		table.insert(pool, "Low patience. Watch yourself.")
	end

	if #pool == 0 then
		table.insert(pool, "Neutral. Read them carefully.")
		table.insert(pool, "Could go either way.")
	end

	return pick(pool, rng)
end

function NpcTells.forCustomer(customer, rng: Random?): string
	local pool = CUSTOMER_TELLS[customer.id]
	if pool then
		return pick(pool, rng)
	end
	return tellFromStats(customer, rng)
end

function NpcTells.forBuyer(buyer, itemCategory: string?, rng: Random?): string
	local pool = BUYER_TELLS[buyer.id]
	if pool then
		local tell = pick(pool, rng)
		if buyer.id == "desperate_mechanic" and itemCategory then
			if itemCategory == "Scrap" or itemCategory == "Old World Tech" then
				return "Keeps staring at the part. They need this."
			end
		end
		if buyer.id == "rich_collector" and itemCategory then
			if itemCategory == "Collectibles" or itemCategory == "Cursed Junk" then
				return "Eyes light up. Collector interest."
			end
		end
		return tell
	end
	return tellFromStats(buyer, rng)
end

function NpcTells.inspectBonusTell(customer, rarityId: string, inflated: boolean): string?
	if inflated and (customer.scamBias or 0) > 0.2 then
		return "Tell update: they're overselling this."
	end
	if rarityId == "Legendary" or rarityId == "Epic" then
		return "Tell update: this might be a jackpot item."
	end
	return nil
end

function NpcTells.getCustomerReadHint(customer): string
	if customer.id == "desperate_survivor" then
		return "Read: pressure or a careful lowball may work."
	elseif customer.id == "shady_scammer" then
		return "Read: inspect or point out flaws."
	elseif customer.id == "rich_collector" then
		return "Read: play fair. Avoid lowball pressure."
	elseif customer.id == "robot_trader" then
		return "Read: facts beat emotion."
	elseif customer.id == "mutant_drifter" then
		return "Read: move fast. Pressure can work, but heat rises quickly."
	elseif customer.id == "nervous_rookie" then
		return "Read: easy to shake, easy to scare off."
	elseif customer.id == "soldier" then
		return "Read: split fairly. Do not pressure."
	elseif customer.id == "junk_dealer" then
		return "Read: knows junk. Use facts, not intimidation."
	elseif customer.id == "alien_tourist" then
		return "Read: unpredictable. Weird logic may work."
	elseif customer.id == "silent_stranger" then
		return "Read: hard to move. Keep it clean."
	end

	if (customer.scamBias or 0) >= 0.4 then
		return "Read: point out flaws may work."
	elseif (customer.desperation or 0) >= 0.7 then
		return "Read: emotional leverage may work."
	elseif (customer.knowledge or 0) >= 0.7 then
		return "Read: avoid risky nonsense."
	end

	return "Read: start safe, then decide."
end

function NpcTells.getBuyerReadHint(buyer, itemCategory: string?): string
	if buyer.id == "cheap_scavenger" then
		return "Read: small bumps only. Bluff likely fails."
	elseif buyer.id == "rich_collector" then
		if itemCategory == "Collectibles" or itemCategory == "Cursed Junk" then
			return "Read: pitch value, then hold firm."
		end
		return "Read: likes a good pitch, hates obvious bluffs."
	elseif buyer.id == "desperate_mechanic" then
		if itemCategory == "Scrap" or itemCategory == "Old World Tech" then
			return "Read: pitch the practical value."
		end
		return "Read: urgency helps, but category still matters."
	elseif buyer.id == "alien_tourist" then
		return "Read: pitch or bluff can work on strange items."
	elseif buyer.id == "robot_appraiser" then
		return "Read: numbers only. Bluff likely fails."
	elseif buyer.id == "black_market_dealer" then
		return "Read: test them, then hold firm."
	end

	return "Read: match the pitch to the buyer."
end

return NpcTells
