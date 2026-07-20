local NumberFormatter = {}

local SUFFIXES = {
	"K",
	"M",
	"B",
	"T",
	"Qa",
	"Qi",
	"Sx",
	"Sp",
	"Oc",
	"No",
	"Dc",
}

local function isFinite(value)
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function trimTrailingZeros(value)
	return value:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
end

local function decimalPlaces(value)
	if value >= 100 then
		return 0
	elseif value >= 10 then
		return 1
	end
	return 2
end

local function round(value, places)
	local scale = 10 ^ places
	return math.floor(value * scale + 0.5) / scale
end

local function formatScientific(absoluteValue, sign)
	local exponent = math.floor(math.log(absoluteValue) / math.log(10))
	local mantissa = absoluteValue / (10 ^ exponent)
	local places = decimalPlaces(mantissa)
	local rounded = round(mantissa, places)

	if rounded >= 10 then
		rounded /= 10
		exponent += 1
		places = decimalPlaces(rounded)
	end

	local text = trimTrailingZeros(string.format("%." .. places .. "f", rounded))
	return sign .. text .. "e" .. tostring(exponent)
end

function NumberFormatter.Format(value)
	local numberValue = tonumber(value)
	if not numberValue or not isFinite(numberValue) then
		return "0"
	end

	local sign = numberValue < 0 and "-" or ""
	local absoluteValue = math.abs(numberValue)

	if absoluteValue < 1000 then
		return sign .. tostring(math.floor(absoluteValue))
	end

	local group = 0
	local divisor = 1
	while absoluteValue >= divisor * 1000 and group < #SUFFIXES do
		group += 1
		divisor *= 1000
	end

	local shortened = absoluteValue / divisor
	if group == #SUFFIXES and shortened >= 1000 then
		return formatScientific(absoluteValue, sign)
	end

	local places = decimalPlaces(shortened)
	local rounded = round(shortened, places)

	if rounded >= 1000 then
		if group >= #SUFFIXES then
			return formatScientific(absoluteValue, sign)
		end
		group += 1
		divisor *= 1000
		shortened = absoluteValue / divisor
		places = decimalPlaces(shortened)
		rounded = round(shortened, places)
	end

	local text = trimTrailingZeros(string.format("%." .. places .. "f", rounded))
	return sign .. text .. SUFFIXES[group]
end

NumberFormatter.FormatCompact = NumberFormatter.Format

return NumberFormatter
