local State = {
	libName = "Unnamed",
	saveFolder = "",
	saveFileName = "config",
	
	mainGui = nil,
	tabsContainer = nil,
	overlayContainer = nil,
	isUiVisible = true,
	
	tabCount = 0,
	tabOrder = {},
	tabs = {},
	values = {},
	buttons = {},
	menuToggleKeybind = nil,
	quickCommandsKeybind = nil,
	
	commands = {},
	commandOrder = {},
	
	toggleTabs = nil,
	toggleQuickCommands = nil,
	
	tooltipGui = nil,
	hoveredTooltipText = nil,

	-- Reactive Theme Listeners
	themeListeners = {},
}

function State.onThemeChanged(callback)
	table.insert(State.themeListeners, callback)
end

function State.updateTheme(themeType, newColor)
	for _, callback in ipairs(State.themeListeners) do
		task.spawn(callback, themeType, newColor)
	end
end

function State.getValue(commandId)
	return State.values[commandId]
end

function State.setValue(commandId, value)
	State.values[commandId] = value
end

function State.registerCommand(data)
	if not State.commands[data.id] then
		table.insert(State.commandOrder, data.id)
	end
	State.commands[data.id] = data
end

function State.getHighestZ()
	local highest = 0
	if State.tabsContainer then
		for _, obj in ipairs(State.tabsContainer:GetChildren()) do
			if obj:IsA("GuiObject") then
				highest = math.max(highest, obj.ZIndex)
			end
		end
	end
	return highest
end

function State.hideAllMoreScrolls(exceptTabName, exceptOwner)
	for tabName, tabData in pairs(State.tabs) do
		if tabData.moreScroll then
			local keepOpen = (tabName == exceptTabName) and (tabData.moreScroll:GetAttribute("Owner") == exceptOwner)
			if not keepOpen and tabData.closeMoreFunc then
				tabData.closeMoreFunc()
			end
		end
	end
end

function State.showTooltip(text)
	State.hoveredTooltipText = text
end

function State.hideTooltip(text)
	if State.hoveredTooltipText == text then
		State.hoveredTooltipText = nil
	end
end

return State