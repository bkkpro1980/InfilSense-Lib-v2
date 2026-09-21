local Constants = {}

Constants.Colors = {
	accent = Color3.fromRGB(70, 0, 180),
	tabHeading = Color3.fromRGB(255, 255, 255),
	background = Color3.fromRGB(15, 0, 40),
	hover = Color3.fromRGB(10, 0, 30),
	muted = Color3.fromRGB(125, 125, 125),
	inputBackground = Color3.fromRGB(30, 30, 30),
	text = Color3.fromRGB(255, 255, 255),
	placeholder = Color3.fromRGB(175, 175, 175),
}

Constants.Fonts = {
	regular = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Regular),
	medium = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
}

function Constants.randomString(length)
	length = length or 24
	local rng = Random.new()
	local output = {}
	for i = 1, length do
		output[i] = string.char(rng:NextInteger(1, 250))
	end
	return table.concat(output)
end

function Constants.darkenColor(color, amount)
	return Color3.new(
		math.max(0, color.R - amount),
		math.max(0, color.G - amount),
		math.max(0, color.B - amount)
	)
end

return Constants