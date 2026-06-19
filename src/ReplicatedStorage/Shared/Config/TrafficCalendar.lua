local TrafficCalendar = {}

local UPCOMING_BOARD_COUNT = 2

local boardCycle = {
	{
		id = "dusty_morning",
		displayName = "Dusty Morning",
		subtitle = "Normal traffic with a collector pocket.",
		shifts = {
			{
				shiftId = "scrap_rush",
				label = "Normal Day",
				description = "Reliable baseline traffic. Good for clearing practical stock.",
			},
			{
				shiftId = "collector_convention",
				label = "Collector Window",
				description = "Collectors are around. Displayed curios can help pull better traffic.",
			},
		},
	},
	{
		id = "twilight_crowd",
		displayName = "Twilight Crowd",
		subtitle = "Practical buyers by day, sketchier buyers after dark.",
		shifts = {
			{
				shiftId = "scrap_rush",
				label = "Normal Day",
				description = "Reliable baseline traffic. Lower ceiling, fewer surprises.",
			},
			{
				shiftId = "black_market_night",
				label = "Black Market",
				description = "Volatile buyers and rougher deals. Inspect before trusting big upside.",
			},
		},
	},
	{
		id = "market_surge",
		displayName = "Market Surge",
		subtitle = "Everyone is moving through the market today.",
		shifts = {
			{
				shiftId = "scrap_rush",
				label = "Normal Day",
				description = "Reliable fallback traffic if your shelf is messy.",
			},
			{
				shiftId = "collector_convention",
				label = "Collector Window",
				description = "A stronger day to sell collectibles, cursed junk, and weird shelf bait.",
			},
			{
				shiftId = "black_market_night",
				label = "Black Market",
				description = "High-risk traffic for dangerous, cursed, or contraband-feeling stock.",
			},
		},
	},
}

local function normalizeBoardIndex(boardIndex: number?): number
	local count = #boardCycle
	if count <= 0 then
		return 1
	end

	local index = if type(boardIndex) == "number" then math.floor(boardIndex) else 1
	return ((index - 1) % count) + 1
end

local function copyShiftEntry(entry, windowIndex: number)
	return {
		shiftId = entry.shiftId,
		label = entry.label,
		description = entry.description,
		windowIndex = windowIndex,
	}
end

local function copyBoardSummary(boardIndex: number)
	local normalized = normalizeBoardIndex(boardIndex)
	local board = boardCycle[normalized]
	return {
		boardIndex = normalized,
		boardId = board.id,
		boardName = board.displayName,
		boardSubtitle = board.subtitle,
	}
end

TrafficCalendar.DEFAULT_SHIFT_ID = "scrap_rush"

function TrafficCalendar.normalizeBoardIndex(boardIndex: number?): number
	return normalizeBoardIndex(boardIndex)
end

function TrafficCalendar.nextBoardIndex(boardIndex: number?): number
	return normalizeBoardIndex(normalizeBoardIndex(boardIndex) + 1)
end

function TrafficCalendar.getBoard(boardIndex: number?)
	return boardCycle[normalizeBoardIndex(boardIndex)]
end

function TrafficCalendar.getBoardShiftEntries(boardIndex: number?): { any }
	local board = TrafficCalendar.getBoard(boardIndex)
	local entries = {}
	for index, entry in board.shifts do
		table.insert(entries, copyShiftEntry(entry, index))
	end
	return entries
end

function TrafficCalendar.isShiftAvailable(boardIndex: number?, shiftId: string): boolean
	if type(shiftId) ~= "string" or shiftId == "" then
		return false
	end

	for _, entry in TrafficCalendar.getBoardShiftEntries(boardIndex) do
		if entry.shiftId == shiftId then
			return true
		end
	end
	return false
end

function TrafficCalendar.buildSnapshot(boardIndex: number?, completedWindows: number?): any
	local normalized = normalizeBoardIndex(boardIndex)
	local board = copyBoardSummary(normalized)
	local upcomingBoards = {}

	for offset = 1, math.min(UPCOMING_BOARD_COUNT, math.max(#boardCycle - 1, 0)) do
		table.insert(upcomingBoards, copyBoardSummary(normalized + offset))
	end

	return {
		boardIndex = board.boardIndex,
		boardId = board.boardId,
		boardName = board.boardName,
		boardSubtitle = board.boardSubtitle,
		completedWindows = completedWindows or 0,
		upcomingBoards = upcomingBoards,
	}
end

return TrafficCalendar
