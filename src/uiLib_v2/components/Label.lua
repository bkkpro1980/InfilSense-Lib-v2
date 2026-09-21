local Label = {}
local Constants = require("@lib/constants")
local UIBuilder = require("@utils/UIBuilder")

function Label.create(tabObj, config, parentOverride)
	local parent = parentOverride or tabObj.tabData.scroll
	local textContent = ""
	local textColor = Constants.Colors.text
	local textSize = 13

	if type(config) == "string" then
		textContent = config
	elseif type(config) == "table" then
		textContent = config.Text or (config.Info and config.Info.Title) or "Label"
		textColor = config.TextColor3 or textColor
		textSize = config.TextSize or textSize
	end

	local frame = UIBuilder.create("Frame", {
		Name = "labelFrame",
		BackgroundColor3 = Constants.Colors.dark,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 20),
		ClipsDescendants = true,
		Parent = parent
	})

	local textLabel = UIBuilder.create("TextLabel", {
		Name = "labelText",
		FontFace = Constants.Fonts.regular,
		TextColor3 = textColor,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = textSize,
		Size = UDim2.new(1, -6, 1, 0),
		Position = UDim2.new(0, 3, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Text = textContent,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ClipsDescendants = true,
		Active = false,
		Parent = frame
	})
	UIBuilder.create("UIPadding", { PaddingLeft = UDim.new(0, 3), Parent = textLabel })

	return {
		frame = frame,
		textLabel = textLabel,
		SetText = function(_, newText)
			textLabel.Text = tostring(newText)
		end,
		GetText = function()
			return textLabel.Text
		end
	}
end

return Label