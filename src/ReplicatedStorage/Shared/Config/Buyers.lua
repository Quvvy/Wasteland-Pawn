local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local buyerList = {
	{
		id = "cheap_scavenger",
		displayName = "Cheap Scavenger",
		patience = 0.35,
		greed = 0.85,
		urgency = 0.25,
		knowledge = 0.35,
		temper = 0.55,
		openingLine = "I'll take it off your hands. Cheap.",
		reactions = {
			accept = { "Fine. Scraps is scraps.", "Deal. Don't expect more.", "Grab it and go." },
			counter = { "Too rich for me. Lower.", "Nah. Meet me halfway down.", "I can't go that high." },
			reject = { "Dream on.", "Not paying that.", "You're joking." },
			walkaway = { "Forget it.", "I'm out.", "Waste of time." },
		},
	},
	{
		id = "rich_collector",
		displayName = "Rich Collector",
		patience = 0.85,
		greed = 0.45,
		urgency = 0.35,
		knowledge = 0.8,
		temper = 0.2,
		openingLine = "I may be interested. Convince me it's worth my offer.",
		reactions = {
			accept = { "Acceptable. I'll take it.", "Done. Have your scraps.", "Fine. Add it to the collection." },
			counter = { "A touch ambitious.", "Closer, but not quite.", "I'll stretch a little." },
			reject = { "Vulgar price.", "Absolutely not.", "You insult my taste." },
			walkaway = { "I'm leaving.", "No thank you.", "Good day." },
		},
	},
	{
		id = "desperate_mechanic",
		displayName = "Desperate Mechanic",
		patience = 0.5,
		greed = 0.35,
		urgency = 0.9,
		knowledge = 0.4,
		temper = 0.45,
		openingLine = "I need parts. What's your price?",
		reactions = {
			accept = { "Yes! Before someone else grabs it!", "Deal! My rig lives another day.", "Take the scraps!" },
			counter = { "Come on, I need this.", "Bump it down a little?", "So close..." },
			reject = { "I can't!", "That's shop robbery.", "My budget is dead." },
			walkaway = { "Forget it. I'll jury-rig something.", "Too rich for me.", "I'm gone." },
		},
	},
	{
		id = "alien_tourist",
		displayName = "Alien Tourist",
		patience = 0.75,
		greed = 0.3,
		urgency = 0.2,
		knowledge = 0.25,
		temper = 0.15,
		openingLine = "Souvenir purchase? Offer in scraps?",
		reactions = {
			accept = { "Joy! Trade complete.", "Yes yes. Scraps exchanged.", "Happy Earth shopping." },
			counter = { "Confusion. Price high?", "Adjust exchange?", "Hmm. More scraps?" },
			reject = { "Sad beeping.", "Too many scraps.", "No thank you." },
			walkaway = { "Leaving shop now.", "Bored.", "Bye Earth." },
		},
	},
	{
		id = "robot_appraiser",
		displayName = "Robot Appraiser",
		patience = 0.9,
		greed = 0.55,
		urgency = 0.15,
		knowledge = 0.95,
		temper = 0.1,
		openingLine = "APPRAISAL MODE. OPENING OFFER CALCULATED.",
		reactions = {
			accept = { "TRANSACTION ACCEPTED.", "DEAL LOGGED.", "TRANSFER AUTHORIZED." },
			counter = { "OFFER ADJUSTED UPWARD.", "RECALCULATING.", "PARTIAL MATCH." },
			reject = { "OVERVALUED.", "DENIED.", "OUT OF RANGE." },
			walkaway = { "EXITING NEGOTIATION.", "NO DEAL.", "SESSION END." },
		},
	},
	{
		id = "black_market_dealer",
		displayName = "Black Market Dealer",
		patience = 0.6,
		greed = 0.7,
		urgency = 0.55,
		knowledge = 0.65,
		temper = 0.5,
		openingLine = "Quiet sale. I open low. You know the game.",
		reactions = {
			accept = { "Pleasure.", "Moving product.", "Don't make me regret it." },
			counter = { "Split the difference.", "You're pushing.", "Meet me higher." },
			reject = { "You're dreaming.", "Not in this market.", "Hard pass." },
			walkaway = { "Deal's dead.", "Walk away.", "Find another mark." },
		},
	},
}

local Buyers = {
	List = buyerList,
	ById = TableUtil.indexById(buyerList, function(buyer)
		return buyer.id
	end),
}

function Buyers.get(buyerId: string)
	return Buyers.ById[buyerId]
end

function Buyers.getRandom(rng: Random?)
	return TableUtil.pickRandom(Buyers.List, rng)
end

return Buyers
