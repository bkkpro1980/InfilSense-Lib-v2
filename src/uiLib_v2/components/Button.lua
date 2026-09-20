local Button = {}
local State = require(script.Parent.Parent.state)
local Constants = require(script.Parent.Parent.constants)
local UIBuilder = require(script.Parent.Parent.utils.UIBuilder)
local ConfigManager = require(script.Parent.Parent.config.ConfigManager)
local KeybindManager = require(script.Parent.Parent.config.KeybindManager)

function Button.create(tabObj, config, parentOverride)
    local parent = parentOverride or tabObj.tabData.scroll
    local info = config.Info or {}
    local internalInfo = config.InternalInfo or {}
    local commandId = internalInfo.UniqueCommandId or Constants.randomString()
    
    local isToggle = internalInfo.Toggle or false
    local isBindable = internalInfo.Bindable or false
    local isStartup = internalInfo.StartupAvailable or false
    local callback = config.Callback or function() end
    local aliases = config.Aliases or info.Aliases or internalInfo.Aliases or {}

    local frame = UIBuilder.create("Frame", {
        Name = "frame",
        BackgroundColor3 = Constants.Colors.dark,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 20),
        ClipsDescendants = true,
        Parent = parent
    })

    local gradient = UIBuilder.createGradient(frame)

    local button = UIBuilder.create("ImageButton", {
        Name = "button",
        AutoButtonColor = false,
        ImageTransparency = 1,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 5,
        Parent = frame
    })

    local text = UIBuilder.create("TextLabel", {
        Name = "text",
        FontFace = Constants.Fonts.regular,
        TextColor3 = Constants.Colors.text,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 14,
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClipsDescendants = true,
        Active = false,
        Parent = button
    })
    UIBuilder.create("UIPadding", { PaddingLeft = UDim.new(0, 3), Parent = text })

    local enabledIndicator = UIBuilder.create("Frame", {
        Name = "enabled",
        Visible = isToggle,
        Size = UDim2.new(0, 2, 1, -6),
        Position = UDim2.new(1, -3, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Constants.Colors.gray,
        BorderSizePixel = 0,
        Active = false,
        Parent = button
    })

    local function updateText()
        local bind = ConfigManager.get("Keybinds")[commandId]
        text.Text = (info.Title or "Button") .. (bind and (" [" .. bind .. "]") or "")
    end
    updateText()

    local function updateVisuals(state)
        if not isToggle then return end
        local color = state and Constants.Colors.accent or Constants.Colors.gray
        text.TextColor3 = not state and Constants.Colors.text or color
        enabledIndicator.BackgroundColor3 = color
        gradient.Visible = state
    end

    State.values[commandId] = State.values[commandId] or false
    updateVisuals(State.values[commandId])

    button.MouseEnter:Connect(function() 
        frame.BackgroundColor3 = Constants.darkenColor(Constants.Colors.dark, 0.02)
        if info.Description then State.showTooltip(info.Description) end
    end)
    button.MouseLeave:Connect(function() 
        frame.BackgroundColor3 = Constants.Colors.dark 
        if info.Description then State.hideTooltip(info.Description) end
    end)

    local function executeCommand(explicitState)
        if isToggle then
            local nextState = explicitState
            if nextState == nil then
                nextState = not State.values[commandId]
            end
            State.values[commandId] = nextState
            updateVisuals(nextState)
            callback(nextState)
        else
            callback()
        end
    end
    button.Activated:Connect(function() executeCommand() end)

    if (isBindable or isStartup) and not parentOverride then
        button.MouseButton2Down:Connect(function()
            local ownerKey = commandId .. "::"
            tabObj:openMore(ownerKey, frame, function(moreScroll)
                tabObj:buildContextMenu(moreScroll, commandId, isBindable, isStartup, executeCommand, updateText)
            end)
        end)
    end

    local buttonObj = {
        frame = frame,
        button = button,
        text = text,
        isToggle = isToggle,
        getValue = function() return State.values[commandId] end,
        getId = function() return commandId end,
        updateText = updateText,
        setVisualState = function(state)
            State.values[commandId] = state
            updateVisuals(state)
        end,
        activate = executeCommand
    }

    State.buttons[commandId] = buttonObj

    State.registerCommand({
        id = commandId,
        title = info.Title or "Button",
        aliases = aliases,
        description = info.Description or "",
        type = isToggle and "Toggle" or "Button",
        usage = isToggle and "[on/off]" or "",
        execute = function(args)
            if isToggle and #args > 0 then
                local a = tostring(args[1]):lower()
                if a == "on" or a == "true" or a == "1" then
                    executeCommand(true)
                elseif a == "off" or a == "false" or a == "0" then
                    executeCommand(false)
                else
                    executeCommand()
                end
            else
                executeCommand()
            end
        end
    })

    if isBindable then
        local saved = ConfigManager.get("Keybinds")[commandId]
        if saved and Enum.KeyCode[saved] then
            pcall(function() KeybindManager.bind(commandId, executeCommand, Enum.KeyCode[saved]) end)
            updateText()
        end
    end

    if isStartup and ConfigManager.get("Startup")[commandId] == true then
        State.values[commandId] = true
        updateVisuals(true)
        task.spawn(function()
            callback(true)
        end)
    end

    return buttonObj
end

return Button