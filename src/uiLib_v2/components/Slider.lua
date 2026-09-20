local Slider = {}
local State = require(script.Parent.Parent.state)
local Constants = require(script.Parent.Parent.constants)
local UIBuilder = require(script.Parent.Parent.utils.UIBuilder)
local UIS = game:GetService("UserInputService")
local ConfigManager = require(script.Parent.Parent.config.ConfigManager)

function Slider.create(tabObj, config, parentOverride)
    local parent = parentOverride or tabObj.tabData.scroll
    local info = config.Info or {}
    local internalInfo = config.InternalInfo or {}
    local commandId = internalInfo.UniqueCommandId or Constants.randomString()
    
    local isBindable = internalInfo.Bindable or false
    local isStartup = internalInfo.StartupAvailable or false
    local callback = config.Callback or function() end
    local aliases = config.Aliases or info.Aliases or internalInfo.Aliases or {}

    local shouldSave = config.Save == true or internalInfo.Save == true or (config.Settings and config.Settings.save == true) or false

    local min = config.Min or 0
    local max = config.Max or 100
    local default = config.Default or min
    local step = config.Step or 1
    local sliderType = config.SliderType or "number"

    if sliderType == "bool" then
        min, max, step = 0, 1, 1
        default = default and 1 or 0
    end

    local frame = UIBuilder.create("Frame", {
        Name = "frame",
        BackgroundColor3 = Constants.Colors.dark,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 35),
        ClipsDescendants = true,
        Parent = parent
    })

    local text = UIBuilder.create("TextLabel", {
        Name = "text",
        FontFace = Constants.Fonts.regular,
        TextColor3 = Constants.Colors.text,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 14,
        Size = UDim2.new(1, -50, 0, 20),
        Position = UDim2.new(0, 0, 0, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClipsDescendants = true,
        Active = false,
        Parent = frame
    })
    UIBuilder.create("UIPadding", { PaddingLeft = UDim.new(0, 3), Parent = text })

    local valueText = UIBuilder.create("TextLabel", {
        Name = "valueText",
        FontFace = Constants.Fonts.regular,
        TextColor3 = Constants.Colors.accent,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextSize = 14,
        Size = UDim2.new(0, 50, 0, 20),
        Position = UDim2.new(1, -6, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        Active = false,
        Parent = frame
    })

    local track = UIBuilder.create("Frame", {
        Name = "track",
        BackgroundColor3 = Constants.Colors.inputBg,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -12, 0, 4),
        Position = UDim2.new(0, 6, 0, 25),
        Parent = frame
    })

    local fill = UIBuilder.create("Frame", {
        Name = "fill",
        BackgroundColor3 = Constants.Colors.accent,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0),
        Active = false,
        Parent = track
    })

    local thumb = UIBuilder.create("ImageButton", {
        Name = "thumb",
        BackgroundColor3 = Constants.Colors.text,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 8, 0, 14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Parent = track
    })
    UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = thumb })

    frame.MouseEnter:Connect(function() 
        frame.BackgroundColor3 = Constants.darkenColor(Constants.Colors.dark, 0.02) 
        if info.Description then State.showTooltip(info.Description) end
    end)
    frame.MouseLeave:Connect(function() 
        frame.BackgroundColor3 = Constants.Colors.dark 
        if info.Description then State.hideTooltip(info.Description) end
    end)

    local function updateVisuals(value)
        local percent = (sliderType == "bool") and (value == 1 and 1 or 0) or math.clamp((value - min) / (max - min), 0, 1)
        fill.Size = UDim2.new(percent, 0, 1, 0)
        thumb.Position = UDim2.new(percent, 0, 0.5, 0)

        if sliderType == "bool" then
            valueText.Text = value == 1 and "On" or "Off"
        else
            valueText.Text = tostring(value)
        end
    end

    local currentVal = default
    if shouldSave then
        local saved = ConfigManager.get("Settings")[commandId]
        if saved ~= nil then currentVal = saved end
    end

    State.values[commandId] = currentVal
    text.Text = info.Title or "Slider"
    updateVisuals(currentVal)

    local isDragging = false
    local lastFiredVal = currentVal

    local function applyValue(val, forceCallback)
        val = math.clamp(val, min, max)
        if sliderType == "bool" then
            val = val >= 0.5 and 1 or 0
        else
            val = math.floor((val / step) + 0.5) * step
            val = math.clamp(val, min, max)
        end

        if forceCallback or val ~= lastFiredVal then
            lastFiredVal = val
            State.values[commandId] = val
            updateVisuals(val)
            callback(val)
            if shouldSave then
                ConfigManager.set(commandId, val, "Settings")
            end
        end
    end

    local function updateDrag(input)
        local relativeX = math.clamp(input.Position.X - track.AbsolutePosition.X, 0, track.AbsoluteSize.X)
        local percent = relativeX / track.AbsoluteSize.X
        local val = min + (max - min) * percent
        applyValue(val, false)
    end

    thumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
        end
    end)
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            updateDrag(input)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateDrag(input)
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)

    if (isBindable or isStartup) and not parentOverride then
        frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                local ownerKey = commandId .. "::"
                tabObj:openMore(ownerKey, frame, function(moreScroll)
                    tabObj:buildContextMenu(moreScroll, commandId, isBindable, isStartup, function()
                        if sliderType == "bool" then
                            local newVal = State.values[commandId] == 1 and 0 or 1
                            applyValue(newVal, true)
                        end
                    end)
                end)
            end
        end)
    end

    State.registerCommand({
        id = commandId,
        title = info.Title or "Slider",
        aliases = aliases,
        description = info.Description or "",
        type = "Slider",
        usage = sliderType == "bool" and "[on/off]" or ("<" .. tostring(min) .. "-" .. tostring(max) .. ">"),
        execute = function(args)
            if #args > 0 then
                if sliderType == "bool" then
                    local a = tostring(args[1]):lower()
                    applyValue((a == "on" or a == "1" or a == "true") and 1 or 0, true)
                else
                    local num = tonumber(args[1])
                    if num then applyValue(num, true) end
                end
            else
                if sliderType == "bool" then
                    local newVal = State.values[commandId] == 1 and 0 or 1
                    applyValue(newVal, true)
                else
                    applyValue(State.values[commandId] or default, true)
                end
            end
        end
    })

    return {
        getValue = function() return State.values[commandId] end,
        getId = function() return commandId end,
        setValue = function(_, val) applyValue(val, true) end
    }
end

return Slider