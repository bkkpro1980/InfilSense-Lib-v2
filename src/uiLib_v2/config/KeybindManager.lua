local KeybindManager = {}
local ConfigManager = require("@config/ConfigManager")
local State = require("@lib/state")
local UIS = game:GetService("UserInputService")

KeybindManager.binds = {}
local lastRebindTimestamp = 0

UIS.InputBegan:Connect(function(input, gpe)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if UIS:GetFocusedTextBox() then return end
		
		for commandId, bindData in pairs(KeybindManager.binds) do
			if input.KeyCode == bindData.keyCode then
				local btn = State.buttons[commandId]
				if btn and btn.isToggle then
					State.values[commandId] = not State.values[commandId]
					if btn.setVisualState then
						btn.setVisualState(State.values[commandId])
					end
					task.spawn(bindData.callback, State.values[commandId])
				else
					task.spawn(bindData.callback)
				end
			end
		end
	end
end)

UIS.InputEnded:Connect(function(input, gpe)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if UIS:GetFocusedTextBox() then return end
		if (tick() - lastRebindTimestamp) < 0.3 then return end
		
		-- visibility toggle
		if State.menuToggleKeybind and input.KeyCode == State.menuToggleKeybind then
			if State.toggleTabs then
				State.toggleTabs()
			end
			return
		end

		-- quick commands togle
		if State.quickCommandsKeybind and input.KeyCode == State.quickCommandsKeybind then
			if State.toggleQuickCommands then
				State.toggleQuickCommands()
			end
			return
		end
	end
end)

function KeybindManager.bind(commandId, callback, keyCode)
	ConfigManager.set(commandId, keyCode.Name, "Keybinds")
	KeybindManager.binds[commandId] = { callback = callback, keyCode = keyCode }
end

function KeybindManager.unbind(commandId)
	ConfigManager.set(commandId, nil, "Keybinds")
	KeybindManager.binds[commandId] = nil
end

function KeybindManager.setMenuToggle(keyCode)
	lastRebindTimestamp = tick()
	ConfigManager.set("MenuToggle", keyCode.Name)
	State.menuToggleKeybind = keyCode
end

function KeybindManager.setQuickCommandsToggle(keyCode)
	lastRebindTimestamp = tick()
	ConfigManager.set("QuickCommandsToggle", keyCode.Name)
	State.quickCommandsKeybind = keyCode
end

return KeybindManager