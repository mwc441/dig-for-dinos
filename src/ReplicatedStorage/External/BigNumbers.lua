local DATA = {
	{ Long = "Thousand", Short = "K", Places = 3 },
	{ Long = "Million", Short = "M", Places = 6 },
	{ Long = "Billion", Short = "B", Places = 9 },
	{ Long = "Trillion", Short = "T", Places = 12 },
	{ Long = "Quadrillion", Short = "Qa", Places = 15 },
	{ Long = "Quintillion", Short = "Qn", Places = 18 },
	{ Long = "Sextillion", Short = "S", Places = 21 },
	{ Long = "Septillion", Short = "Sp", Places = 24 },
	{ Long = "Octillion", Short = "O", Places = 27 },
	{ Long = "Nonillion", Short = "N", Places = 30 },
	{ Long = "Decillion", Short = "D", Places = 33 },
	{ Long = "Undecillion", Short = "Ud", Places = 36 },
	{ Long = "Duodecillion", Short = "Dd", Places = 39 },
	{ Long = "Tredecillion", Short = "Td", Places = 42 },
	{ Long = "Quattuordecillion", Short = "Qt", Places = 45 },
	{ Long = "Quinquadecillion", Short = "Qd", Places = 48 },
	{ Long = "Sexdecillion", Short = "Sd", Places = 51 },
	{ Long = "Septendecillion", Short = "St", Places = 54 },
	{ Long = "Octodecillion", Short = "Od", Places = 57 },
	{ Long = "Novendecillion", Short = "Nd", Places = 60 },
	{ Long = "Vigintillion", Short = "Vt", Places = 63 },
	{ Long = "Unvigintillion", Short = "Ut", Places = 66 },
}

local SHORTENED_FORMAT = "%s%s"
local SCIENTIFIC_FORMAT = "%se+%s"
local SMALL_NUMBER_DECIMAL_FORMAT = "%0.1f"
local BIG_NUMBER_DECIMAL_FORMAT = "%0.1f"

local BigNumberNames = {}

function BigNumberNames.GetNumberDisplay(value)
	local index = 0

	for _ = 1, #DATA do
		if value < 1000 then
			break
		end

		value /= 1000
		index += 1
	end

	if index == 0 then
		if (value % 1) == 0 then
			return tostring(value)
		else
			return SMALL_NUMBER_DECIMAL_FORMAT:format(value):gsub("%.0$", "")
		end
	elseif index <= #DATA then
		value = BIG_NUMBER_DECIMAL_FORMAT:format(math.floor(value * 10) / 10)
		value = value:gsub("%.0$", "")
		return SHORTENED_FORMAT:format(value, DATA[index].Short)
	else
		local showValue = tostring(math.floor(value))
		return SCIENTIFIC_FORMAT:format(showValue:sub(1, 1), (index * 3) + showValue:len())
	end
end

return BigNumberNames
