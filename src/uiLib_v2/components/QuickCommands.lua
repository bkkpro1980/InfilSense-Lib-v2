local QuickCommands = {}
local State = require("@lib/state")
local Constants = require("@lib/constants")
local UIBuilder = require("@utils/UIBuilder")
local UIS = game:GetService("UserInputService")

local function parseCommand(rawText)
	local trimmed = string.match(rawText, "^%s*(.-)%s*$") or ""
	local tokens = {}
	for word in string.gmatch(trimmed, "%S+") do
		table.insert(tokens, word)
	end
	local cmd = tokens[1] and tokens[1]:lower() or ""
	local args = {}
	for i = 2, #tokens do
		table.insert(args, tokens[i])
	end
	return cmd, args
end

function QuickCommands.init()
	local overlay = UIBuilder.create("TextButton", {
		Name = "QuickCommandsOverlay",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 9999,
		Parent = State.overlayContainer
	})

	local container = UIBuilder.create("Frame", {
		Size = UDim2.new(0, 440, 0, 44),
		Position = UDim2.new(0.5, 0, 0.2, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Constants.Colors.background,
		BorderSizePixel = 0,
		Parent = overlay
	})
	UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = container })

	local drag = Instance.new("UIDragDetector")
	drag.ResponseStyle = Enum.UIDragDetectorResponseStyle.Scale
	drag.Parent = container

	local inner = UIBuilder.create("Frame", {
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Constants.Colors.background,
		BorderSizePixel = 0,
		Parent = container
	})
	UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 7), Parent = inner })
	
	local gradient = UIBuilder.createGradient(container)
	gradient.Visible = true 

	local autoCompleteLabel = UIBuilder.create("TextLabel", {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		TextColor3 = Constants.Colors.placeholder,
		Text = "",
		FontFace = Constants.Fonts.regular,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Active = false,
		Parent = inner
	})

	local searchBox = UIBuilder.create("TextBox", {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		TextColor3 = Constants.Colors.text,
		PlaceholderColor3 = Constants.Colors.placeholder,
		PlaceholderText = "Search commands...",
		FontFace = Constants.Fonts.regular,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		Parent = inner
	})

	local resultsScroll = UIBuilder.create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 1, 8),
		BackgroundColor3 = Constants.Colors.background,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		Parent = container
	})
	UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = resultsScroll })
	local _listLayout = UIBuilder.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = resultsScroll })

	local function applyTheme(themeType, newColor)
		if not newColor then return end

		if themeType == "background" then
			container.BackgroundColor3 = newColor
			inner.BackgroundColor3 = newColor
			resultsScroll.BackgroundColor3 = newColor
		elseif themeType == "hover" then
			for _, child in ipairs(resultsScroll:GetChildren()) do
				if child:IsA("Frame") then
					child.BackgroundColor3 = newColor
				end
			end
		elseif themeType == "text" then
			searchBox.TextColor3 = newColor
			for _, child in ipairs(resultsScroll:GetChildren()) do
				if child:IsA("Frame") then
					local button = child:FindFirstChildWhichIsA("TextButton")
					if button and not button:GetAttribute("QuickCommandPrimary") then
						button.TextColor3 = newColor
					end
				end
			end
		elseif themeType == "placeholder" then
			searchBox.PlaceholderColor3 = newColor
			autoCompleteLabel.TextColor3 = newColor
		elseif themeType == "accent" then
			for _, child in ipairs(resultsScroll:GetChildren()) do
				if child:IsA("Frame") then
					local button = child:FindFirstChildWhichIsA("TextButton")
					if button and button:GetAttribute("QuickCommandPrimary") then
						button.TextColor3 = newColor
					end
				end
			end
		end
	end

	State.onThemeChanged(applyTheme)

	local function close()
		overlay.Visible = false
		searchBox.Text = ""
		autoCompleteLabel.Text = ""
		if searchBox:IsFocused() then
			searchBox:ReleaseFocus()
		end
	end

	local function open()
		overlay.Visible = true
		searchBox.Text = ""
		autoCompleteLabel.Text = ""
		overlay.ZIndex = State.getHighestZ() + 100
		
		task.defer(function()
			searchBox.Text = ""
			searchBox:CaptureFocus()
			searchBox.Text = ""
			searchBox.CursorPosition = 1
		end)
	end

	overlay.Activated:Connect(close)

	State.toggleQuickCommands = function()
		if overlay.Visible then close() else open() end
	end

	local currentFirstCommand = nil
	local currentFirstMatchedName = ""

	local function updateResults()
		if string.find(searchBox.Text, "\t") then
			searchBox.Text = string.gsub(searchBox.Text, "\t", "")
			searchBox.CursorPosition = #searchBox.Text + 1
		end

		local queryCmd, args = parseCommand(searchBox.Text)
		currentFirstCommand = nil
		currentFirstMatchedName = ""
		autoCompleteLabel.Text = ""
		
		for _, child in ipairs(resultsScroll:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end

		if queryCmd == "" then
			resultsScroll.Size = UDim2.new(1, 0, 0, 0)
			return
		end

		-- match priority: exact > prefix > substring
		local matches = {}

		for _, cmdData in pairs(State.commands) do
			local titleLower = cmdData.title:lower()
			local idLower = cmdData.id:lower()
			local bestScore = 999
			local bestMatchedKey = cmdData.title

			if titleLower == queryCmd or idLower == queryCmd then
				bestScore = 1
				bestMatchedKey = cmdData.title
			elseif titleLower:sub(1, #queryCmd) == queryCmd then
				bestScore = math.min(bestScore, 2)
				bestMatchedKey = cmdData.title
			elseif titleLower:find(queryCmd, 1, true) then
				bestScore = math.min(bestScore, 3)
				bestMatchedKey = cmdData.title
			end

			for _, alias in ipairs(cmdData.aliases or {}) do
				local aLower = alias:lower()
				if aLower == queryCmd then
					bestScore = 1
					bestMatchedKey = alias
					break
				elseif aLower:sub(1, #queryCmd) == queryCmd then
					if bestScore > 2 then
						bestScore = 2
						bestMatchedKey = alias
					end
				elseif aLower:find(queryCmd, 1, true) then
					if bestScore > 3 then
						bestScore = 3
						bestMatchedKey = alias
					end
				end
			end

			if bestScore < 999 then
				table.insert(matches, {
					cmd = cmdData,
					score = bestScore,
					matchedKey = bestMatchedKey
				})
			end
		end

		table.sort(matches, function(a, b)
			if a.score ~= b.score then
				return a.score < b.score
			end
			return a.cmd.title < b.cmd.title
		end)

		for i, match in ipairs(matches) do
			local cmdData = match.cmd
			local matchedKey = match.matchedKey

			local resFrame = UIBuilder.create("Frame", {
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundColor3 = Constants.Colors.hover,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Parent = resultsScroll
			})
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = resFrame })

			local aliasStr = ""
			if cmdData.aliases and #cmdData.aliases > 0 then
				aliasStr = " [" .. table.concat(cmdData.aliases, ", ") .. "]"
			end
			local usageStr = cmdData.usage ~= "" and (" " .. cmdData.usage) or ""

			local resBtn = UIBuilder.create("TextButton", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "  " .. cmdData.title .. aliasStr .. usageStr,
				TextColor3 = Constants.Colors.text,
				FontFace = Constants.Fonts.medium,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = resFrame
			})

			local function execute()
				local _, currentArgs = parseCommand(searchBox.Text)
				task.spawn(function()
					cmdData.execute(currentArgs)
				end)
				close()
			end

			if i == 1 then
				currentFirstCommand = cmdData
				currentFirstMatchedName = matchedKey
				resBtn:SetAttribute("QuickCommandPrimary", true)
				resBtn.TextColor3 = Constants.Colors.accent
				
				if #args == 0 and string.sub(matchedKey:lower(), 1, #queryCmd) == queryCmd then
					autoCompleteLabel.Text = queryCmd .. string.sub(matchedKey, #queryCmd + 1) .. usageStr
				end
			end

			resBtn.Activated:Connect(execute)
		end

		local resultHeight = math.min(#matches * 34, 220)
		resultsScroll.Size = UDim2.new(1, 0, 0, resultHeight)
		resultsScroll.CanvasSize = UDim2.new(0, 0, 0, #matches * 34)
	end

	searchBox:GetPropertyChangedSignal("Text"):Connect(updateResults)

	searchBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			if currentFirstCommand then
				local _, args = parseCommand(searchBox.Text)
				task.spawn(function()
					currentFirstCommand.execute(args)
				end)
			end
			close()
		end
	end)

	UIS.InputBegan:Connect(function(input)
		if searchBox:IsFocused() and input.KeyCode == Enum.KeyCode.Tab and currentFirstMatchedName ~= "" then
			searchBox.Text = currentFirstMatchedName .. " "
			searchBox.CursorPosition = #searchBox.Text + 1
			task.defer(function()
				searchBox.Text = string.gsub(searchBox.Text, "\t", "")
				searchBox.CursorPosition = #searchBox.Text + 1
				searchBox:CaptureFocus()
			end)
		end
	end)
end

return QuickCommands