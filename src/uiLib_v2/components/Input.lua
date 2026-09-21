local Input = {}
local State = require("@lib/state")
local Constants = require("@lib/constants")
local UIBuilder = require("@utils/UIBuilder")

function Input.create(tabObj, config, parentOverride)
	local parent = parentOverride or tabObj.tabData.scroll
	local info = config.Info or {}
	local internalInfo = config.InternalInfo or {}
	local commandId = internalInfo.UniqueCommandId or Constants.randomString()

	local isToggle = config.Toggle == true 
		or internalInfo.Toggle == true 
		or info.Action == "Toggle" 
		or false

	local isBindable = internalInfo.Bindable or false
	local isStartup = internalInfo.StartupAvailable or false
	local callback = config.Callback or function() end
	local aliases = config.Aliases or info.Aliases or internalInfo.Aliases or {}

	local frame = UIBuilder.create("Frame", {
		Name = "frame",
		BackgroundColor3 = Constants.Colors.background,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 20),
		ClipsDescendants = true,
		Parent = parent
	})

	local gradient = UIBuilder.createGradient(frame)

	local textbox = UIBuilder.create("TextBox", {
		Name = "textbox",
		Size = UDim2.new(0.5, -6, 1, -4),
		Position = UDim2.new(0, 3, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Constants.Colors.inputBackground,
		TextColor3 = Constants.Colors.text,
		PlaceholderColor3 = Constants.Colors.placeholder,
		Text = config.DefaultText or "",
		FontFace = Constants.Fonts.regular,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		BorderSizePixel = 0,
		Parent = frame
	})
	UIBuilder.create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = textbox })

	local button = UIBuilder.create("ImageButton", {
		Name = "button",
		Size = UDim2.new(0.5, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = frame
	})

	local defaultButtonTitle = isToggle and (info.Title or "Toggle") or (info.Title or "Submit")
	local text = UIBuilder.create("TextLabel", {
		Name = "text",
		Size = UDim2.new(1, -6, 1, 0),
		Position = UDim2.new(0, 3, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		TextColor3 = Constants.Colors.text,
		Text = defaultButtonTitle,
		FontFace = Constants.Fonts.regular,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ClipsDescendants = true,
		Active = false,
		Parent = button
	})
	UIBuilder.create("UIPadding", { PaddingLeft = UDim.new(0, 3), Parent = text })

	local enabledIndicator = UIBuilder.create("Frame", {
		Name = "enabled",
		Visible = isToggle,
		Size = UDim2.new(0, 2, 1, -8),
		Position = UDim2.new(1, -6, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Constants.Colors.muted,
		BorderSizePixel = 0,
		Active = false,
		Parent = button
	})

	local function updateVisuals(state)
		if not isToggle then return end
		local color = state and Constants.Colors.accent or Constants.Colors.muted
		enabledIndicator.BackgroundColor3 = color
		gradient.Visible = state
	end

	State.values[commandId] = State.values[commandId] or false
	updateVisuals(State.values[commandId])

	button.MouseEnter:Connect(function() 
		frame.BackgroundColor3 = Constants.darkenColor(Constants.Colors.background, 0.02) 
		if info.Description then State.showTooltip(info.Description) end
	end)
	button.MouseLeave:Connect(function() 
		frame.BackgroundColor3 = Constants.Colors.background 
		if info.Description then State.hideTooltip(info.Description) end
	end)

	local function executeCommand(customVal, explicitState)
		local val = customVal or textbox.Text
		if isToggle then
			local nextState = explicitState
			if nextState == nil then
				nextState = not State.values[commandId]
			end
			State.values[commandId] = nextState
			updateVisuals(nextState)
			task.spawn(callback, nextState, val)
		else
			task.spawn(callback, val)
		end
	end

	button.Activated:Connect(function() executeCommand() end)

	textbox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			if isToggle then
				if State.values[commandId] then
					task.spawn(callback, true, textbox.Text)
				end
			else
				executeCommand(textbox.Text)
			end
		end
	end)

	if (isBindable or isStartup) and not parentOverride then
		button.MouseButton2Down:Connect(function()
			local ownerKey = commandId .. "::"
			tabObj:openMore(ownerKey, frame, function(moreScroll)
				tabObj:buildContextMenu(moreScroll, commandId, isBindable, isStartup, executeCommand)
			end)
		end)
	end

	State.registerCommand({
		id = commandId,
		title = info.Title or "Input",
		aliases = aliases,
		description = info.Description or "",
		type = isToggle and "ToggleInput" or "Input",
		usage = isToggle and "[on/off] <text>" or "<text>",
		execute = function(args)
			if isToggle then
				if #args > 0 then
					local firstArg = tostring(args[1]):lower()
					if firstArg == "on" or firstArg == "true" or firstArg == "1" then
						local remaining = table.concat(args, " ", 2)
						if remaining ~= "" then textbox.Text = remaining end
						executeCommand(textbox.Text, true)
					elseif firstArg == "off" or firstArg == "false" or firstArg == "0" then
						local remaining = table.concat(args, " ", 2)
						if remaining ~= "" then textbox.Text = remaining end
						executeCommand(textbox.Text, false)
					else
						local txt = table.concat(args, " ")
						textbox.Text = txt
						executeCommand(txt, true)
					end
				else
					executeCommand()
				end
			else
				local txt = table.concat(args, " ")
				if txt ~= "" then textbox.Text = txt end
				executeCommand(txt ~= "" and txt or nil)
			end
		end
	})

	State.onThemeChanged(function(themeType, newColor)
		if frame and frame.Parent then
			if themeType == "accent" and isToggle and State.values[commandId] then
				enabledIndicator.BackgroundColor3 = newColor
			elseif themeType == "text" then
				text.TextColor3 = newColor
				textbox.TextColor3 = newColor
			elseif themeType == "background" then
				frame.BackgroundColor3 = newColor
			elseif themeType == "inputBackground" then
				textbox.BackgroundColor3 = newColor
			elseif themeType == "placeholder" then
				textbox.PlaceholderColor3 = newColor
			elseif themeType == "muted" then
				if not isToggle or not State.values[commandId] then
					enabledIndicator.BackgroundColor3 = newColor
				end
			end
		end
	end)

	return {
		getValue = function() return textbox.Text end,
		getId = function() return commandId end,
		isToggled = function() return State.values[commandId] == true end
	}
end

return Input