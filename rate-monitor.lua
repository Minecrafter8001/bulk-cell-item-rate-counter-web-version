local title = "Bulk Cell Rate Monitor"
local refreshSeconds = 1
local itemIdRefreshSeconds = 60
local started = 0
local averager = require("averager")

local meBridge = peripheral.find("me_bridge")
local blockReaders = {}
local serverUrl = "http://your-server:8080/update"

if not meBridge then
	error("No meBridge peripheral found")
end

for _, name in ipairs(peripheral.getNames()) do
	if peripheral.getType(name) == "block_reader" then
		blockReaders[#blockReaders + 1] = peripheral.wrap(name)
	end
end

if #blockReaders == 0 then
	error("No block_reader peripheral found")
end

local previousSnapshot = {}
local cachedItemIds = {}
local lastItemIdRefresh = 0

local function toNumber(value)
	if type(value) == "number" then
		return value
	end

	if type(value) == "string" then
		return tonumber(value)
	end

	if type(value) == "table" then
		if value[1] ~= nil then
			return tonumber(value[1])
		end

		if value.count ~= nil then
			return tonumber(value.count)
		end
	end

	return nil
end

local function humanizeName(name)
	local shortName = name:match("[^:]+$") or name
	shortName = shortName:gsub("_", " ")
	return (shortName:gsub("(%a)([%w_']*)", function(first, rest)
		return first:upper() .. rest:lower()
	end))
end

local function isNugget(name)
	return name:sub(-7) == "_nugget"
end

local function normalizedName(name)
	if isNugget(name) then
		return name:gsub("_nugget$", "_ingot")
	end

	return name
end

local function normalizedItemId(name)
	return normalizedName(name)
end

local function formatNumber(value)
	value = tonumber(value)
	if not value then
		return ""
	end

	local sign = value < 0 and "-" or ""
	value = math.abs(value)

	local integerPart = tostring(math.floor(value))
	local decimalPart = value - math.floor(value)

	integerPart = integerPart:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if integerPart:sub(1, 1) == "," then
		integerPart = integerPart:sub(2)
	end

	if decimalPart > 0 then
		local decimals = string.format("%.1f", value):match("%.(%d+)")
		return sign .. integerPart .. "." .. decimals
	end

	return sign .. integerPart
end

local function formatItemCount(row)
	return formatNumber(row.value)
end

local function formatRate(row)
	local prefix = row.rate >= 0 and "+" or ""
	local value = formatNumber(row.rate)
	return prefix .. value .. "/s"
end

local function extractItemId(entry)
	if type(entry) ~= "table" then
		return nil
	end

	local components = entry.components or {}
	local bulkItem = components["megacells:bulk_item"] or entry["megacells:bulk_item"] or {}
	local itemId = bulkItem.id or entry.id

	if type(itemId) ~= "string" then
		return nil
	end

	return itemId
end

local function getStoredCount(itemId)
	local ok, item = pcall(meBridge.getItem, { name = itemId })
	if not ok or type(item) ~= "table" then
		return 0
	end

	return toNumber(item.count) or 0
end

local function collectItemIds()
	local itemIds = {}

	for _, reader in ipairs(blockReaders) do
		local ok, blockData = pcall(reader.getBlockData)
		if ok and type(blockData) == "table" and type(blockData.inv) == "table" then
			for _, item in pairs(blockData.inv) do
				local itemId = extractItemId(item)
				if itemId then
					itemIds[normalizedItemId(itemId)] = true
				end
			end
		end
	end

	return itemIds
end

local function getCachedItemIds(forceRefresh)
	local now = os.epoch("utc") / 1000
	if forceRefresh or next(cachedItemIds) == nil or now - lastItemIdRefresh >= itemIdRefreshSeconds then
		local itemIds = collectItemIds()
		if next(itemIds) ~= nil then
			cachedItemIds = itemIds
		end
		lastItemIdRefresh = now
	end

	return cachedItemIds
end

local function readItems()
	local aggregated = {}
	local itemIds = getCachedItemIds(false)

	for itemId in pairs(itemIds) do
		local count = getStoredCount(itemId)
		if count > 0 then
			if not aggregated[itemId] then
				aggregated[itemId] = {
					key = itemId,
					label = humanizeName(itemId),
					value = 0,
					rate = 0,
				}
			end

			aggregated[itemId].value = aggregated[itemId].value + count
		end
	end

	local rows = {}
	for _, row in pairs(aggregated) do
		local previous = previousSnapshot[row.key]

		if started == 0 or previous == nil then
			row.rate = 0
		else
			local instantRate = (row.value - previous) / refreshSeconds
			local smoothedRate = averager.average(instantRate, row.key)
			row.rate = smoothedRate or instantRate
		end

		rows[#rows + 1] = row
		previousSnapshot[row.key] = row.value
	end

	table.sort(rows, function(left, right)
		if left.value == right.value then
			return left.label < right.label
		end

		return left.value > right.value
	end)

	return rows
end
local function sendRows(rows)
	local payload = {
		title = title,
		refreshSeconds = refreshSeconds,
		timestamp = os.epoch("utc"),
		items = {},
	}

	for _, row in ipairs(rows) do
		payload.items[#payload.items + 1] = {
			id = row.key,
			name = row.label,
			count = row.value,
			rate = row.rate,
		}
	end

	local ok, err = pcall(function()
		http.post(
			serverUrl,
			textutils.serialiseJSON(payload),
			{
				["Content-Type"] = "application/json"
			}
		)
	end)

	if not ok then
		print("POST failed: " .. tostring(err))
	end
end

local function render()
	local rows = readItems()

	if started == 0 then
		started = 1
		return
	end

	sendRows(rows)
end

while true do
	render()
	sleep(refreshSeconds)
end
