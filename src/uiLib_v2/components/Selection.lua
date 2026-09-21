local Selection = {}
local State = require(script.Parent.Parent.state)
local Constants = require(script.Parent.Parent.constants)
local UIBuilder = require(script.Parent.Parent.utils.UIBuilder)

function Selection.create(tabObj, config, parentOverride)
	local parent = parentOverride or tabObj.tabData.scroll
	local info = config.Info or {}
	local internalInfo = config.InternalInfo or {}
	local commandId = internalInfo.UniqueCommandId or Constants.randomString()
	local aliases = config.Aliases or info.Aliases or internalInfo.Aliases or {}
	
	local isSingleSelect = config.SingleSelect == true or internalInfo.SingleSelect == true
	local isBindable = internalInfo.Bindable or false
	local isStartup = internalInfo.StartupAvailable or false
	local callback = config.Callback or function() end

	State.values[commandId] = State.values[commandId] or config.DefaultValue or nil

	local frame = UIBuilder.create("Frame", {
		Name = "frame",
		BackgroundColor3 = Constants.Colors.dark,
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
		ImageColor3 = Constants.Colors.gray,
		Active = false,
		Parent = more
	})

	local gradient = UIBuilder.createGradient(frame)

	local function formatSummaryText(summaryText)
		if not summaryText or type(summaryText) == "table" then return info.Title or "" end
		return (info.Title or "") .. " - " .. tostring(summaryText)
	end

	local function updateSelectionVisuals()
		gradient.Visible = State.values[commandId] ~= nil
	end

	button.MouseEnter:Connect(function() 
		frame.BackgroundColor3 = Constants.darkenColor(Constants.Colors.dark, 0.02) 
		if info.Description then State.showTooltip(info.Description) end
	end)
	button.MouseLeave:Connect(function() 
		frame.BackgroundColor3 = Constants.Colors.dark 
		if info.Description then State.hideTooltip(info.Description) end
	end)

	local function executeCommand()
		if type(callback) == "function" then
			local val = State.values[commandId]
			if type(val) == "table" and #val > 0 then
				task.spawn(callback, table.unpack(val))
			else
				task.spawn(callback, val)
			end
		end
	end
	button.Activated:Connect(executeCommand)

	local childOptions = {}
	local activeOptionButtons = {}

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
					State.values[commandId] = selectionValue
					for val, optBtn in pairs(activeOptionButtons) do
						if val ~= selectionValue and optBtn.setVisualState then optBtn.setVisualState(false) end
					end
				else
					if State.values[commandId] == selectionValue then State.values[commandId] = nil end
				end
			end
			if childConfig.Callback then task.spawn(childConfig.Callback, state, State.values[commandId]) end
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
					local Button = require(script.Parent.Button)
					local btn = Button.create(tabObj, opt.cfg, moreScroll)
					local valKey = opt.val or (opt.cfg.Info and opt.cfg.Info.Title) or Constants.randomString()
					activeOptionButtons[valKey] = btn
					if State.values[commandId] == valKey then btn.setVisualState(true) end
				elseif opt.type == "TextBox" then
					require(script.Parent.Input).create(tabObj, opt.cfg, moreScroll)
				elseif opt.type == "Slider" then
					require(script.Parent.Slider).create(tabObj, opt.cfg, moreScroll)
				elseif opt.type == "Label" then
					require(script.Parent.Label).create(tabObj, opt.cfg, moreScroll)
				end
			end
		end, function()
			img.ImageColor3 = Constants.Colors.gray
		end)
		
		img.ImageColor3 = opened and Constants.Colors.accent or Constants.Colors.gray
	end)

	if (isBindable or isStartup) and not parentOverride then
		button.MouseButton2Down:Connect(function()
			local ownerKey = commandId .. "::bind"
			tabObj:openMore(ownerKey, frame, function(moreScroll)
				tabObj:buildContextMenu(moreScroll, commandId, isBindable, isStartup, executeCommand)
			end, function() img.ImageColor3 = Constants.Colors.gray end)
			img.ImageColor3 = Constants.Colors.accent
		end)
	end

	State.registerCommand({
		id = commandId,
		title = info.Title or "Selection",
		aliases = aliases,
		description = info.Description or "",
		type = "Selection",
		usage = "<option> [args...]",
		execute = function(args)
			local function fireSel(val, ...)
				if isSingleSelect then
					State.values[commandId] = val
					updateSelectionVisuals()
				end
				if callback then task.spawn(callback, val, ...) end
			end

			if #args > 0 then
				for i = #args, 1, -1 do
					local query = table.concat(args, " ", 1, i):lower()
					for _, opt in ipairs(childOptions) do
						local optVal = tostring(opt.val or "")
						local optTitle = tostring(opt.cfg and opt.cfg.Info and opt.cfg.Info.Title or "")
						if optVal:lower() == query or optTitle:lower() == query then
							fireSel(opt.val, unpack(args, i + 1))
							return
						end
					end
				end

				for i = #args, 1, -1 do
					local query = table.concat(args, " ", 1, i):lower()
					for _, opt in ipairs(childOptions) do
						local optVal = tostring(opt.val or "")
						local optTitle = tostring(opt.cfg and opt.cfg.Info and opt.cfg.Info.Title or "")
						if optVal:lower():sub(1, #query) == query or optTitle:lower():sub(1, #query) == query then
							fireSel(opt.val, unpack(args, i + 1))
							return
						end
					end
				end

				for i = #args, 1, -1 do
					local query = table.concat(args, " ", 1, i):lower()
					for _, opt in ipairs(childOptions) do
						local optVal = tostring(opt.val or "")
						local optTitle = tostring(opt.cfg and opt.cfg.Info and opt.cfg.Info.Title or "")
						if optVal:lower():find(query, 1, true) or optTitle:lower():find(query, 1, true) then
							fireSel(opt.val, unpack(args, i + 1))
							return
						end
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

	return {
		getValue = function() return State.values[commandId] end,
		GetValue = function() return State.values[commandId] end,
		SetValue = function(_, v) State.values[commandId] = v; updateSelectionVisuals() end,
		UpdateSummary = function(_, txt) text.Text = formatSummaryText(txt) end,
		AddButton = function(self, cfg)
			if isSingleSelect then return addOption(cfg) end
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