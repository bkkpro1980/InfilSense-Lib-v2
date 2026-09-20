local Constants = {}

Constants.Colors = {
    accent = Color3.new(0.667, 0, 1),
    dark = Color3.new(0.176, 0.176, 0.176),
    darkHover = Color3.new(0.156, 0.156, 0.156),
    gray = Color3.fromRGB(125, 125, 125),
    inputBg = Color3.new(0.118, 0.118, 0.118),
    text = Color3.new(1, 1, 1),
    textPlaceholder = Color3.new(0.7, 0.7, 0.7),
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