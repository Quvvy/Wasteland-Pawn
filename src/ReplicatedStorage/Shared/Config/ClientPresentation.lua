-- Client-only presentation toggles and tuning (read by StarterPlayer controllers).
local ClientPresentation = {
	CounterPresentationV1Enabled = true,
	ForceLegacyDealUI = false,
	AutoFallbackWithoutCameraAnchors = true,

	CameraTweenSeconds = 0.6,
	CustomerMoveSeconds = 0.8,
	CustomerWalkSpeed = 9,
	CustomerMoveTimeoutSeconds = 8,
	CustomerAgentRadius = 2,
	CustomerAgentHeight = 5,

	ShopkeeperExplorePanMaxYawDegrees = 24,
	ShopkeeperExplorePanMaxPitchDegrees = 5,
	ShopkeeperDealPanMaxYawDegrees = 14,
	ShopkeeperDealPanMaxPitchDegrees = 4,
	ShopkeeperPanMaxYawDegrees = 24,
	ShopkeeperPanMaxPitchDegrees = 5,
	ShopkeeperPanSmoothness = 0.12,
	ShopkeeperCharacterPanHorizontalStuds = 16,
	ShopkeeperCharacterPanDepthStuds = 14,
	ShopkeeperCharacterPanDeadZoneStuds = 3.5,
	ShopkeeperDealCounterItemFocusStrength = 0.28,
	ShopkeeperShelfAssistStartDistanceStuds = 8,
	ShopkeeperShelfAssistFullDistanceStuds = 2.5,
	ShopkeeperShelfAimStrength = 0.55,
	ShopkeeperDealFocusDampen = 1,
	ShopkeeperShelfBiasStrength = 0.55,
	ShopkeeperExplorePlayerFocusStrength = 0.25,
}

return ClientPresentation
