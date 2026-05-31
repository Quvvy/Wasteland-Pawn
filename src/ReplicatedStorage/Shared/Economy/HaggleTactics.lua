-- Tactic ids for buy-side (seller) and sell-side (buyer) haggling.
local HaggleTactics = {
	Buy = {
		Lowball = "lowball",
		SplitDifference = "split_difference",
		PointOutFlaw = "point_out_flaw",
		Pressure = "pressure",
		AcceptPrice = "accept_price",
		Pass = "pass",
	},
	Sell = {
		SmallBump = "small_bump",
		PitchValue = "pitch_value",
		HoldFirm = "hold_firm",
		Bluff = "bluff",
		AcceptOffer = "accept_offer",
		FindAnotherBuyer = "find_another_buyer",
	},
}

HaggleTactics.BuyList = {
	HaggleTactics.Buy.Lowball,
	HaggleTactics.Buy.SplitDifference,
	HaggleTactics.Buy.PointOutFlaw,
	HaggleTactics.Buy.Pressure,
}

HaggleTactics.SellList = {
	HaggleTactics.Sell.SmallBump,
	HaggleTactics.Sell.PitchValue,
	HaggleTactics.Sell.HoldFirm,
	HaggleTactics.Sell.Bluff,
}

return HaggleTactics
