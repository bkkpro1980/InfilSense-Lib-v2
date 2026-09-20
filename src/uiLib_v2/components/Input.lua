local Input = {}
local State = require(script.Parent.Parent.state)
local Constants = require(script.Parent.Parent.constants)
local UIBuilder = require(script.Parent.Parent.utils.UIBuilder)

function Input.create(tabObj, config, parentOverride)
    local parent = parentOverride or tabObj.tabData.scroll
    local info = config.Info or {}
    local internalInfo = config.InternalInfo or {}
    local commandId = internalInfo.UniqueCommandId or Constants.randomString()
    
    local isToggle = internalInfo.Toggle == true

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

    local textbox = UIBuilder.create("TextBox", {
        Name = "textbox",
        Size = UDim2.new(0.5, -6, 1, -4),
        Position = UDim2.new(0, 3, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Constants.Colors.inputBg,
        TextColor3 = Constants.Colors.text,
        PlaceholderColor3 = Constants.Colors.textPlaceholder,
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
        Size = UDim2.new(0, 2, 1, -6),
        Position = UDim2.new(1, -3, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Constants.Colors.gray,
        BorderSizePixel = 0,
        Active = false,
        Parent = button
    })

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

    local function executeCommand(customVal)
        local val = customVal or textbox.Text
        if isToggle then
            State.values[commandId] = not State.values[commandId]
            updateVisuals(State.values[commandId])
            callback(State.values[commandId] and val or nil)
        else
            callback(val)
        end
    end

    button.Activated:Connect(function() executeCommand() end)

    textbox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            if isToggle then
                if State.values[commandId] then
                    callback(textbox.Text)
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
            local txt = table.concat(args, " ")
            if isToggle then
                if #args > 0 then
                    local firstArg = tostring(args[1]):lower()
                    if firstArg == "on" or firstArg == "true" or firstArg == "1" then
                        local remaining = table.concat(args, " ", 2)
                        if remaining ~= "" then textbox.Text = remaining end
                        State.values[commandId] = true
                        updateVisuals(true)
                        callback(textbox.Text)
                    elseif firstArg == "off" or firstArg == "false" or firstArg == "0" then
                        State.values[commandId] = false
                        updateVisuals(false)
                        callback(nil)
                    else
                        textbox.Text = txt
                        State.values[commandId] = true
                        updateVisuals(true)
                        callback(txt)
                    end
                else
                    executeCommand()
                end
            else
                if txt ~= "" then textbox.Text = txt end
                executeCommand(txt ~= "" and txt or nil)
            end
        end
    })

    return {
        getValue = function() return textbox.Text end,
        getId = function() return commandId end,
        isToggled = function() return State.values[commandId] == true end
    }
end

return Input