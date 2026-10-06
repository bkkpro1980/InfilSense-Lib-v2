local Selection = {}
local State = require("@lib/state")
local Constants = require("@lib/constants")
local ConfigManager = require("@config/ConfigManager")
local UIBuilder = require("@utils/UIBuilder")

local function copyArray(value)
	local result = {}
	if type(value) == "table" then
		for _, item in ipairs(value) do
			result[#result + 1] = item
		end
	end
	return result
end

local function containsValue(values, value)
	for _, item in ipairs(values) do
		if item == value then
			return true
		end
	end
	return false
end

function Selection.create(tabObj, config, parentOverride)
	local parent = parentOverride or tabObj.tabData.scroll
	local info = config.Info or {}
	local internalInfo = config.InternalInfo or {}
	local commandId = internalInfo.UniqueCommandId or Constants.randomString()
	local aliases = config.Aliases or info.Aliases or internalInfo.Aliases or {}

	local requestedSingleSelect = config.SingleSelect == true or internalInfo.SingleSelect == true
	local requestedMultiSelect = config.MultiSelect == true or internalInfo.MultiSelect == true
	if requestedSingleSelect and requestedMultiSelect then
		error("Selection cannot enable both SingleSelect and MultiSelect")
	end

	local isMultiSelect = requestedMultiSelect
	local isSingleSelect = requestedSingleSelect or not isMultiSelect

	local isBindable = internalInfo.Bindable or false
	local isStartup = internalInfo.StartupAvailable or false
	local callback = config.Callback or function() end
	local shouldSave = config.Save == true or internalInfo.Save == true or false

	local childOptions = {}
	local activeOptionButtons = {}

	local function normalizeMultiValue(value)
		if type(value) == "table" then
			local result = {}
			for _, item in ipairs(value) do
				if not containsValue(result, item) then
					result[#result + 1] = item
				end
			end
			return result
		end
		if value == nil then
			return {}
		end
		return { value }
	end

	local savedValue = nil
	if shouldSave then
		savedValue = ConfigManager.get("Settings")[commandId]
	end

	if State.values[commandId] == nil then
		local initialValue = savedValue
		if initialValue == nil then
			initialValue = config.DefaultValue
		end

		if isMultiSelect then
			State.values[commandId] = normalizeMultiValue(initialValue)
		else
			State.values[commandId] = initialValue
		end
	end

	local frame = UIBuilder.create("Frame", {
		Name = "frame",
		BackgroundColor3 = Constants.Colors.background,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 20),
		ClipsDescendants = true,
		Parent = parent
	})

	local header = UIBuilder.create("Frame", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = frame
	})

	local button = UIBuilder.create("ImageButton", {
		Size = UDim2.new(1, -20, 1, 0),
		BackgroundTransparency = 1,
		Parent = header
	})

	local text = UIBuilder.create("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		TextColor3 = Constants.Colors.text,
		FontFace = Constants.Fonts.regular,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = info.Title or "Selection",
		TextTruncate = Enum.TextTruncate.AtEnd,
		ClipsDescendants = true,
		Active = false,
		Parent = button
	})
	UIBuilder.create("UIPadding", { PaddingLeft = UDim.new(0, 3), Parent = text })

	local more = UIBuilder.create("ImageButton", {
		Size = UDim2.new(0, 20, 0, 20),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Parent = header
	})

	local img = UIBuilder.create("ImageLabel", {
		Size = UDim2.new(0, 10, 0, 10),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = "rbxassetid://71488146016369",
		ImageColor3 = Constants.Colors.muted,
		Active = false,
		Parent = more
	})

	local gradient = UIBuilder.createGradient(frame)

	local function formatSummaryText(summaryText)
		if not summaryText or type(summaryText) == "table" then return info.Title or "" end
		return (info.Title or "") .. " - " .. tostring(summaryText)
	end

	local function isOptionSelected(value)
		if isSingleSelect then
			return State.values[commandId] == value
		elseif isMultiSelect then
			return containsValue(State.values[commandId] or {}, value)
		end
		return false
	end

	local function updateSelectionVisuals()
		if isMultiSelect then
			gradient.Visible = type(State.values[commandId]) == "table" and #State.values[commandId] > 0
		else
			gradient.Visible = State.values[commandId] ~= nil
		end
	end

	local function updateOptionButtonVisuals()
		for value, optBtn in pairs(activeOptionButtons) do
			if optBtn.setVisualState then
				optBtn.setVisualState(isOptionSelected(value))
			end
		end
	end

	local function setSelectionValue(value)
		if isMultiSelect then
			value = normalizeMultiValue(value)
		end

		State.values[commandId] = value
		updateSelectionVisuals()
		updateOptionButtonVisuals()
		if shouldSave then
			ConfigManager.set(commandId, value, "Settings")
		end
	end

	local function setMultiSelectionOption(value, enabled)
		local current = copyArray(State.values[commandId])
		local index = table.find(current, value)
		if enabled then
			if not index then
				current[#current + 1] = value
			end
		else
			if index then
				table.remove(current, index)
			end
		end
		setSelectionValue(current)
	end

	button.MouseEnter:Connect(function()
		frame.BackgroundColor3 = Constants.darkenColor(Constants.Colors.background, 0.02)
		if info.Description then State.showTooltip(info.Description) end
	end)
	button.MouseLeave:Connect(function()
		frame.BackgroundColor3 = Constants.Colors.background
		if info.Description then State.hideTooltip(info.Description) end
	end)

	local function getCallbackValue()
		if isMultiSelect then
			return copyArray(State.values[commandId])
		end
		return State.values[commandId]
	end

	local function executeCommand()
		if type(callback) == "function" then
			task.spawn(callback, getCallbackValue())
		end
	end
	button.Activated:Connect(executeCommand)

	local function addOption(childConfig)
		local selectionValue = childConfig.Value or (childConfig.Info and childConfig.Info.Title) or Constants.randomString()
		local cfg = {
			Info = childConfig.Info,
			InternalInfo = { Toggle = true, UniqueCommandId = childConfig.InternalInfo and childConfig.InternalInfo.UniqueCommandId or Constants.randomString() },
			Callback = nil
		}

		cfg.Callback = function(state)
			if isSingleSelect then
				if state then
					setSelectionValue(selectionValue)
					for val, optBtn in pairs(activeOptionButtons) do
						if val ~= selectionValue and optBtn.setVisualState then optBtn.setVisualState(false) end
					end
				elseif State.values[commandId] == selectionValue then
					setSelectionValue(nil)
				end
			elseif isMultiSelect then
				setMultiSelectionOption(selectionValue, state == true)
			end

			if childConfig.Callback then
				task.spawn(childConfig.Callback, state, getCallbackValue())
			end
			updateSelectionVisuals()
		end

		table.insert(childOptions, { cfg = cfg, val = selectionValue, ogConfig = childConfig, type = "Button" })
		return { UpdateSummary = function(_, txt) text.Text = formatSummaryText(txt) end }
	end

	more.Activated:Connect(function()
		local ownerKey = commandId .. "::"
		local opened = tabObj:openMore(ownerKey, frame, function(moreScroll)
			activeOptionButtons = {}
			for _, opt in ipairs(childOptions) do
				if opt.type == "Button" then
					local Button = require("@components/Button")
					local btn = Button.create(tabObj, opt.cfg, moreScroll)
					local valKey = opt.val or (opt.cfg.Info and opt.cfg.Info.Title) or Constants.randomString()
					activeOptionButtons[valKey] = btn
					if isOptionSelected(valKey) then
						btn.setVisualState(true)
					end
				elseif opt.type == "TextBox" then
					require("@components/Input").create(tabObj, opt.cfg, moreScroll)
				elseif opt.type == "Slider" then
					require("@components/Slider").create(tabObj, opt.cfg, moreScroll)
				elseif opt.type == "Label" then
					require("@components/Label").create(tabObj, opt.cfg, moreScroll)
				end
			end
		end, function()
			img.ImageColor3 = Constants.Colors.muted
		end)

		img.ImageColor3 = opened and Constants.Colors.accent or Constants.Colors.muted
	end)

	if (isBindable or isStartup) and not parentOverride then
		button.MouseButton2Down:Connect(function()
			local ownerKey = commandId .. "::bind"
			tabObj:openMore(ownerKey, frame, function(moreScroll)
				tabObj:buildContextMenu(moreScroll, commandId, isBindable, isStartup, executeCommand)
			end, function() img.ImageColor3 = Constants.Colors.muted end)
			img.ImageColor3 = Constants.Colors.accent
		end)
	end

	local function getOptionText(opt)
		local optVal = tostring(opt.val or "")
		local optTitle = tostring(opt.cfg and opt.cfg.Info and opt.cfg.Info.Title or "")
		return optVal:lower(), optTitle:lower()
	end

	local function matchOption(query)
		query = tostring(query or ""):lower()
		if query == "" then return nil end

		-- Preserve the existing matcher priority: exact > prefix > substring.
		for _, opt in ipairs(childOptions) do
			local optVal, optTitle = getOptionText(opt)
			if optVal == query or optTitle == query then
				return opt
			end
		end

		for _, opt in ipairs(childOptions) do
			local optVal, optTitle = getOptionText(opt)
			if optVal:sub(1, #query) == query or optTitle:sub(1, #query) == query then
				return opt
			end
		end

		for _, opt in ipairs(childOptions) do
			local optVal, optTitle = getOptionText(opt)
			if optVal:find(query, 1, true) or optTitle:find(query, 1, true) then
				return opt
			end
		end

		return nil
	end

	local function splitCommaValues(value)
		local values = {}
		local hasComma = false

		for part in string.gmatch(tostring(value or ""), "[^,]+") do
			hasComma = true
			part = string.match(part, "^%s*(.-)%s*$") or ""
			if part ~= "" then
				table.insert(values, part)
			end
		end

		if not hasComma then
			return { tostring(value or "") }, false
		end

		return values, true
	end

	local function executeMultiSelectCommand(args)
		local selectedValues = {}
		local consumedArgs = 0

		local function addSelectedValue(value)
			if not containsValue(selectedValues, value) then
				table.insert(selectedValues, value)
			end
		end

		local index = 1
		while index <= #args do
			local token = args[index]
			local parts, hasComma = splitCommaValues(token)

			if hasComma then
				local matchedValues = {}
				local allMatched = true

				for _, part in ipairs(parts) do
					local opt = matchOption(part)
					if not opt then
						allMatched = false
						break
					end
					table.insert(matchedValues, opt.val)
				end

				if not allMatched then
					break
				end

				for _, value in ipairs(matchedValues) do
					addSelectedValue(value)
				end

				consumedArgs = index
				index += 1
			else
				-- Try the longest multi-word option first, so values such as
				-- "Last Target" still work in multi-select commands.
				local matchedOpt = nil
				local matchedEnd = nil

				for endIndex = #args, index, -1 do
					local query = table.concat(args, " ", index, endIndex)
					local opt = matchOption(query)
					if opt then
						matchedOpt = opt
						matchedEnd = endIndex
						break
					end
				end

				if not matchedOpt then
					break
				end

				addSelectedValue(matchedOpt.val)
				consumedArgs = matchedEnd
				index = matchedEnd + 1
			end
		end

		-- `command true` can be useful for running the current selection with
		-- an additional argument, while an explicit option list replaces it.
		if #selectedValues == 0 then
			if #args > 0 then
				if callback then task.spawn(callback, getCallbackValue(), unpack(args)) end
			end
			return
		end

		setSelectionValue(selectedValues)
		if callback then
			task.spawn(callback, getCallbackValue(), unpack(args, consumedArgs + 1))
		end
	end

	State.registerCommand({
		id = commandId,
		title = info.Title or "Selection",
		aliases = aliases,
		description = info.Description or "",
		type = "Selection",
		usage = isMultiSelect and "<options...> [args...]" or "<option> [args...]",
		execute = function(args)
			if isMultiSelect then
				if #args > 0 then
					executeMultiSelectCommand(args)
				elseif callback then
					task.spawn(callback, getCallbackValue())
				end
				return
			end

			local function fireSel(val, ...)
				if isSingleSelect then
					setSelectionValue(val)
					if callback then task.spawn(callback, getCallbackValue(), ...) end
				else
					if callback then task.spawn(callback, val, ...) end
				end
			end

			if #args > 0 then
				for i = #args, 1, -1 do
					local query = table.concat(args, " ", 1, i):lower()
					local opt = matchOption(query)
					if opt then
						fireSel(opt.val, unpack(args, i + 1))
						return
					end
				end

				fireSel(args[1], unpack(args, 2))
			else
				if isSingleSelect and #childOptions > 0 then
					local currentIdx = 1
					for idx, opt in ipairs(childOptions) do
						if State.values[commandId] == opt.val then
							currentIdx = idx
							break
						end
					end
					local nextIdx = (currentIdx % #childOptions) + 1
					local nextOpt = childOptions[nextIdx]
					if nextOpt then
						fireSel(nextOpt.val)
					end
				end
			end
		end
	})

	if (isSingleSelect or isMultiSelect) and isStartup and ConfigManager.get("Startup")[commandId] == true then
		task.defer(function()
			if frame and frame.Parent then
				executeCommand()
			end
		end)
	end

	State.onThemeChanged(function(themeType, newColor)
		if frame and frame.Parent then
			if themeType == "text" then
				text.TextColor3 = newColor
			elseif themeType == "background" then
				frame.BackgroundColor3 = newColor
			elseif themeType == "muted" then
				img.ImageColor3 = newColor
			end
		end
	end)

	updateSelectionVisuals()

	return {
		getValue = function()
			if isMultiSelect then return copyArray(State.values[commandId]) end
			return State.values[commandId]
		end,
		GetValue = function()
			if isMultiSelect then return copyArray(State.values[commandId]) end
			return State.values[commandId]
		end,
		SetValue = function(_, v) setSelectionValue(v) end,
		UpdateSummary = function(_, txt) text.Text = formatSummaryText(txt) end,
		AddButton = function(self, cfg)
			if isSingleSelect or isMultiSelect then return addOption(cfg) end
			local btnVal = cfg.Value or (cfg.Info and cfg.Info.Title) or (cfg.InternalInfo and cfg.InternalInfo.UniqueCommandId) or Constants.randomString()
			table.insert(childOptions, { cfg = cfg, val = btnVal, type = "Button" })
			return self
		end,
		AddOption = function(self, cfg) return addOption(cfg) end,
		AddTextBox = function(self, cfg)
			local val = cfg.Value or (cfg.Info and cfg.Info.Title) or Constants.randomString()
			table.insert(childOptions, { cfg = cfg, val = val, type = "TextBox" })
			return self
		end,
		AddSlider = function(self, cfg)
			local val = cfg.Value or (cfg.Info and cfg.Info.Title) or Constants.randomString()
			table.insert(childOptions, { cfg = cfg, val = val, type = "Slider" })
			return self
		end,
		AddLabel = function(self, cfg)
			table.insert(childOptions, { cfg = cfg, type = "Label" })
			return self
		end
	}
end

return Selection
