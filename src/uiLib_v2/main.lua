local Library = {}
local State = require(script.Parent.state)
local ConfigManager = require(script.Parent.config.ConfigManager)
local KeybindManager = require(script.Parent.config.KeybindManager)
local Tab = require(script.Parent.components.Tab)
local Constants = require(script.Parent.constants)
local QuickCommands = require(script.Parent.components.QuickCommands)
local UIBuilder = require(script.Parent.utils.UIBuilder)
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TS = game:GetService("TweenService")

local COREGUI = cloneref and cloneref(game:GetService("CoreGui")) or game:GetService("CoreGui")

function Library.new(config)
    config = config or {}
    State.libName = config.Name or "Unnamed"
    State.saveFolder = config.SaveFolder or ""
    State.saveFileName = config.SaveId or "config"
    State.tabCount = 0
    State.tabOrder = {}

    State.mainGui = Instance.new("ScreenGui")
    State.mainGui.Name = Constants.randomString()
    State.mainGui.Parent = COREGUI
    State.mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    State.mainGui.ResetOnSpawn = false
    State.mainGui.IgnoreGuiInset = true
    State.mainGui.DisplayOrder = 2147483647

    State.tabsContainer = Instance.new("Frame")
    State.tabsContainer.Name = "tabsContainer"
    State.tabsContainer.Size = UDim2.new(1, 0, 1, 0)
    State.tabsContainer.BackgroundTransparency = 1
    State.tabsContainer.Parent = State.mainGui

    State.overlayContainer = Instance.new("Frame")
    State.overlayContainer.Name = "overlayContainer"
    State.overlayContainer.Size = UDim2.new(1, 0, 1, 0)
    State.overlayContainer.BackgroundTransparency = 1
    State.overlayContainer.ZIndex = 100
    State.overlayContainer.Parent = State.mainGui

    -- tooltips
    State.tooltipGui = UIBuilder.create("TextLabel", {
        Name = "Tooltip",
        Visible = false,
        BackgroundColor3 = Constants.Colors.darkHover,
        TextColor3 = Constants.Colors.text,
        FontFace = Constants.Fonts.regular,
        TextSize = 13,
        Size = UDim2.new(0, 0, 0, 24),
        AutomaticSize = Enum.AutomaticSize.X,
        Parent = State.overlayContainer
    })
    UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = State.tooltipGui })
    UIBuilder.create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = State.tooltipGui })

    -- tooltip positioning
    local hoverTime = 0
    local lastMousePos = Vector2.new()

    RunService.RenderStepped:Connect(function(dt)
        if not State.tooltipGui then return end
        
        if State.hoveredTooltipText then
            local currentPos = UIS:GetMouseLocation()
            if (currentPos - lastMousePos).Magnitude > 2 then
                hoverTime = 0
                lastMousePos = currentPos
                State.tooltipGui.Visible = false
            else
                hoverTime = hoverTime + dt
                if hoverTime >= 1.0 and not State.tooltipGui.Visible then
                    State.tooltipGui.Text = State.hoveredTooltipText

                    local camera = workspace.CurrentCamera
                    local vp = camera and camera.ViewportSize or Vector2.new(1280, 720)
                    local tipWidth = State.tooltipGui.AbsoluteSize.X
                    if tipWidth == 0 then
                        tipWidth = State.tooltipGui.TextBounds.X + 20
                    end
                    local tipHeight = 24

                    -- flip to left of cursor
                    local posX = currentPos.X + 12
                    if posX + tipWidth > vp.X - 10 then
                        posX = currentPos.X - tipWidth - 12
                    end
                    posX = math.clamp(posX, 10, math.max(10, vp.X - tipWidth - 10))

                    -- flip to top of cursor
                    local posY = currentPos.Y + 12
                    if posY + tipHeight > vp.Y - 10 then
                        posY = currentPos.Y - tipHeight - 12
                    end
                    local topInset = GuiService:GetGuiInset().Y
                    posY = math.clamp(posY, topInset + 5, math.max(topInset + 5, vp.Y - tipHeight - 10))

                    State.tooltipGui.Position = UDim2.new(0, posX, 0, posY)
                    State.tooltipGui.Visible = true
                    State.tooltipGui.ZIndex = State.getHighestZ() + 100
                end
            end
        else
            hoverTime = 0
            State.tooltipGui.Visible = false
        end
    end)

    local savedConfig = ConfigManager.get()
    local menuKey = savedConfig.MenuToggle or "RightShift"
    if Enum.KeyCode[menuKey] then
        KeybindManager.setMenuToggle(Enum.KeyCode[menuKey])
    end

    local qcKey = savedConfig.QuickCommandsToggle or "F2"
    if Enum.KeyCode[qcKey] then
        KeybindManager.setQuickCommandsToggle(Enum.KeyCode[qcKey])
    end

    QuickCommands.init()

    State.isUiVisible = true
    State.toggleTabs = function(forcedState)
        if forcedState ~= nil then
            State.isUiVisible = forcedState
        else
            State.isUiVisible = not State.isUiVisible
        end
        State.tabsContainer.Visible = State.isUiVisible
        if not State.isUiVisible then
            State.hideAllMoreScrolls()
        end
    end

    local app = {}

    function app:CreateTab(name, pos)
        if State.tabs[name] and State.tabs[name].tabObj then
            return State.tabs[name].tabObj
        end
        return Tab.create(name, pos)
    end
    
    function app:GetTab(name)
        local tabData = State.tabs[name]
        return tabData and tabData.tabObj or nil
    end

    function app:ToggleGui(forcedState)
        State.toggleTabs(forcedState)
    end

    -- make built in settings
    local settingsTab = app:CreateTab("Settings")

    local currentMenuKeyName = ConfigManager.get().MenuToggle or "RightShift"
    local menuKeyBtn = settingsTab:AddButton({
        Info = { 
            Title = "UI Visibility Keybind [" .. currentMenuKeyName .. "]", 
            Description = "Click to rebind the key used to show/hide the UI tabs." 
        },
        Callback = function() end
    })

    local isRebindingMenu = false
    menuKeyBtn.button.Activated:Connect(function()
        if isRebindingMenu then return end
        isRebindingMenu = true
        menuKeyBtn.text.Text = "Press a key (5s timeout)..."
        menuKeyBtn.text.TextColor3 = Constants.Colors.accent

        local conn, timeout
        local function finish(newKey)
            if conn then conn:Disconnect(); conn = nil end
            if timeout then task.cancel(timeout); timeout = nil end
            isRebindingMenu = false
            local keyName = newKey and newKey.Name or (ConfigManager.get().MenuToggle or "RightShift")
            menuKeyBtn.text.Text = "UI Visibility Keybind [" .. keyName .. "]"
            menuKeyBtn.text.TextColor3 = Constants.Colors.text
        end

        timeout = task.delay(5, function() finish(nil) end)
        conn = UIS.InputBegan:Connect(function(input)
            if UIS:GetFocusedTextBox() then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape then
                    finish(nil)
                else
                    KeybindManager.setMenuToggle(input.KeyCode)
                    finish(input.KeyCode)
                end
            end
        end)
    end)

    -- quick commands bind
    local currentQCKeyName = ConfigManager.get().QuickCommandsToggle or "F2"
    local qcKeyBtn = settingsTab:AddButton({
        Info = { 
            Title = "Quick Commands Keybind [" .. currentQCKeyName .. "]", 
            Description = "Click to rebind the key used to open Quick Commands." 
        },
        Callback = function() end
    })

    local isRebindingQC = false
    qcKeyBtn.button.Activated:Connect(function()
        if isRebindingQC then return end
        isRebindingQC = true
        qcKeyBtn.text.Text = "Press a key (5s timeout)..."
        qcKeyBtn.text.TextColor3 = Constants.Colors.accent

        local conn, timeout
        local function finish(newKey)
            if conn then conn:Disconnect(); conn = nil end
            if timeout then task.cancel(timeout); timeout = nil end
            isRebindingQC = false
            local keyName = newKey and newKey.Name or (ConfigManager.get().QuickCommandsToggle or "F2")
            qcKeyBtn.text.Text = "Quick Commands Keybind [" .. keyName .. "]"
            qcKeyBtn.text.TextColor3 = Constants.Colors.text
        end

        timeout = task.delay(5, function() finish(nil) end)
        conn = UIS.InputBegan:Connect(function(input)
            if UIS:GetFocusedTextBox() then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape then
                    finish(nil)
                else
                    KeybindManager.setQuickCommandsToggle(input.KeyCode)
                    finish(input.KeyCode)
                end
            end
        end)
    end)

    -- grid snap
    local currentGridSnap = (ConfigManager.get("Settings") or {}).GridSnap ~= false
    local gridSnapBtn = settingsTab:AddButton({
        Info = {
            Title = "Grid Snapping",
            Description = "Enables magnetic snapping when moving tabs."
        },
        InternalInfo = {
            Toggle = true,
            UniqueCommandId = "setting_gridsnap"
        },
        Callback = function(enabled)
            ConfigManager.set("GridSnap", enabled, "Settings")
        end
    })
    gridSnapBtn.setVisualState(currentGridSnap)

    -- grid size slider
    local currentGridSize = (ConfigManager.get("Settings") or {}).GridSize or 15
    settingsTab:AddSlider({
        Info = {
            Title = "Grid Snap Size",
            Description = "Sets how many pixels between each magnetic grid line."
        },
        InternalInfo = {
            UniqueCommandId = "setting_gridsize",
            Save = true
        },
        Min = 5,
        Max = 30,
        Default = currentGridSize,
        Step = 5,
        Callback = function(val)
            ConfigManager.set("GridSize", val, "Settings")
        end
    })

    -- reset tabs pos
    settingsTab:AddButton({
        Info = {
            Title = "Reset Tab Positions",
            Description = "Restores all tabs to their exact initial order below the top bar."
        },
        Callback = function()
            ConfigManager.set("TabPositions", {})
            local topInset = GuiService:GetGuiInset().Y
            for index, tabName in ipairs(State.tabOrder) do
                local tabData = State.tabs[tabName]
                if tabData and tabData.frame then
                    local yOffset = topInset + 10 + ((index - 1) * 26)
                    local targetPos = UDim2.new(0, 15, 0, yOffset)
                    TS:Create(tabData.frame, TweenInfo.new(0.35, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                        Position = targetPos
                    }):Play()
                end
            end
        end
    })

    return app
end

return Library