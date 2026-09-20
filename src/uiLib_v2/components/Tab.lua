local Tab = {}
local State = require(script.Parent.Parent.state)
local Constants = require(script.Parent.Parent.constants)
local UIBuilder = require(script.Parent.Parent.utils.UIBuilder)
local ConfigManager = require(script.Parent.Parent.config.ConfigManager)
local TS = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local function getViewport()
    local camera = workspace.CurrentCamera
    return (camera and camera.ViewportSize) or Vector2.new(1280, 720)
end

local function clampPosition(pos)
    local vp = getViewport()
    local topInset = GuiService:GetGuiInset().Y
    local x = math.clamp(pos.X.Offset, 10, math.max(10, vp.X - 210))
    local y = math.clamp(pos.Y.Offset, topInset + 5, math.max(topInset + 5, vp.Y - 25))
    return UDim2.new(0, x, 0, y)
end

local function snapValue(val, step)
    return math.round(val / step) * step
end

function Tab.create(tabName, defaultPosition)
    State.tabCount = (State.tabCount or 0) + 1
    if not table.find(State.tabOrder, tabName) then
        table.insert(State.tabOrder, tabName)
    end

    local topInset = GuiService:GetGuiInset().Y
    local savedPositions = ConfigManager.get("TabPositions") or {}
    local savedPos = savedPositions[tabName]

    local initialPosition
    if savedPos and savedPos.X and savedPos.Y then
        local vp = getViewport()
        local x = (savedPos.X[1] * vp.X) + savedPos.X[2]
        local y = (savedPos.Y[1] * vp.Y) + savedPos.Y[2]
        initialPosition = clampPosition(UDim2.new(0, math.round(x), 0, math.round(y)))
    elseif defaultPosition then
        initialPosition = clampPosition(defaultPosition)
    else
        local yOffset = topInset + 10 + ((State.tabCount - 1) * 26)
        initialPosition = clampPosition(UDim2.new(0, 15, 0, yOffset))
    end

    local tab = UIBuilder.create("TextLabel", {
        Name = tabName,
        Text = tabName,
        TextColor3 = Constants.Colors.text,
        BackgroundColor3 = Constants.Colors.accent,
        BorderSizePixel = 0,
        FontFace = Constants.Fonts.medium,
        TextSize = 18,
        Size = UDim2.new(0, 200, 0, 20),
        Position = initialPosition,
        AnchorPoint = Vector2.new(0, 0),
        ClipsDescendants = false,
        Parent = State.tabsContainer
    })

    local drag = Instance.new("UIDragDetector")
    drag.ResponseStyle = Enum.UIDragDetectorResponseStyle.Offset
    drag.Parent = tab

    pcall(function()
        drag:AddConstraintFunction(1, function(proposedMotion, proposedRotation)
            local settings = ConfigManager.get("Settings") or {}
            if settings.GridSnap == false then
                return proposedMotion, proposedRotation
            end
            local gridSize = settings.GridSize or 15
            local snappedX = snapValue(proposedMotion.X.Offset, gridSize)
            local snappedY = snapValue(proposedMotion.Y.Offset, gridSize)
            return UDim2.new(0, snappedX, 0, snappedY), proposedRotation
        end)
    end)

    drag.DragEnd:Connect(function()
        local settings = ConfigManager.get("Settings") or {}
        local useGrid = settings.GridSnap ~= false
        local gridSize = settings.GridSize or 15

        local finalX = tab.Position.X.Offset
        local finalY = tab.Position.Y.Offset

        if useGrid then
            finalX = snapValue(finalX, gridSize)
            finalY = snapValue(finalY, gridSize)
        end

        local clamped = clampPosition(UDim2.new(0, finalX, 0, finalY))
        tab.Position = clamped

        ConfigManager.set(tabName, {
            X = { 0, clamped.X.Offset },
            Y = { 0, clamped.Y.Offset }
        }, "TabPositions")
    end)

    local camera = workspace.CurrentCamera
    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            local clamped = clampPosition(tab.Position)
            if clamped ~= tab.Position then
                tab.Position = clamped
            end
        end)
    end

    local isMinimized = true
    local isAnimating = false

    local openMin = UIBuilder.create("ImageButton", {
        Name = "openMin",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 20, 0, 20),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 10, 0.5, 0),
        Rotation = isMinimized and 180 or 0,
        Image = isMinimized and "rbxassetid://11295291707" or "rbxassetid://11293980042",
        Parent = tab
    })

    local scroll = UIBuilder.create("ScrollingFrame", {
        Name = "scroll",
        Visible = false,
        ScrollBarThickness = 6,
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, 20),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0,0,0,0),
        BackgroundColor3 = Constants.Colors.dark,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = tab
    })
    local scrollList = UIBuilder.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })

    local moreBlocker = UIBuilder.create("TextButton", {
        Name = "moreBlocker",
        Size = UDim2.new(100, 0, 100, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Text = "",
        Visible = false,
        Parent = tab
    })

    local moreScroll = UIBuilder.create("ScrollingFrame", {
        Name = "moreScroll",
        Visible = false,
        ScrollBarThickness = 6,
        Size = UDim2.new(1, 0, 0, 120),
        Position = UDim2.new(1, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0,0,0,0),
        BackgroundColor3 = Constants.Colors.dark,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = tab
    })
    local moreList = UIBuilder.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = moreScroll })

    local function bindDynamicSize(scrollingFrame, listLayout, minHeight)
        local function refresh()
            if isMinimized or isAnimating then return end
            local desired = math.max(minHeight or 20, listLayout.AbsoluteContentSize.Y)
            local vp = getViewport()
            local maxHeight = math.max(minHeight or 20, vp.Y - scrollingFrame.AbsolutePosition.Y - 40)
            local clamped = math.min(desired, maxHeight)
            scrollingFrame.Size = UDim2.new(scrollingFrame.Size.X.Scale, scrollingFrame.Size.X.Offset, 0, clamped)
        end

        listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refresh)
        scrollingFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(refresh)
        scrollingFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)

        if camera then
            camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
        end

        return refresh
    end

    local refreshScrollSize = bindDynamicSize(scroll, scrollList, 20)
    local refreshMoreSize = bindDynamicSize(moreScroll, moreList, 20)
    
    local currentOnClose = nil

    local function closeMore()
        moreScroll.Visible = false
        moreBlocker.Visible = false
        moreScroll:SetAttribute("Owner", nil)
        if currentOnClose then 
            currentOnClose()
            currentOnClose = nil
        end
    end
    moreBlocker.Activated:Connect(closeMore)

    local function calculateTargetHeight()
        local desired = math.max(20, scrollList.AbsoluteContentSize.Y)
        local vp = getViewport()
        local maxHeight = math.max(20, vp.Y - tab.AbsolutePosition.Y - 80)
        return math.min(desired, maxHeight)
    end

    openMin.Activated:Connect(function()
        if isAnimating then return end
        isAnimating = true
        tab.ZIndex = State.getHighestZ() + 1
        isMinimized = not isMinimized

        if isMinimized then
            closeMore()
            openMin.Image = "rbxassetid://11295291707"
            TS:Create(openMin, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { Rotation = 180 }):Play()
            
            local foldTween = TS:Create(scroll, TweenInfo.new(0.26, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0, 0) })
            foldTween:Play()
            foldTween.Completed:Connect(function()
                if isMinimized then scroll.Visible = false end
                isAnimating = false
            end)
        else
            openMin.Image = "rbxassetid://11293980042"
            scroll.Visible = true
            scroll.Size = UDim2.new(1, 0, 0, 0)
            TS:Create(openMin, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
            
            local targetH = calculateTargetHeight()
            local expandTween = TS:Create(scroll, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0, targetH) })
            expandTween:Play()
            expandTween.Completed:Connect(function()
                isAnimating = false
                refreshScrollSize()
            end)
        end
    end)

    tab.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            tab.ZIndex = State.getHighestZ() + 1
        end
    end)
    
    tab:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
        if not isMinimized and not isAnimating then
            refreshScrollSize()
        end
        refreshMoreSize()
    end)

    local tabData = {
        frame = tab,
        scroll = scroll,
        moreScroll = moreScroll,
        refreshMoreSize = refreshMoreSize,
        closeMoreFunc = closeMore
    }
    State.tabs[tabName] = tabData
    tab.ZIndex = State.getHighestZ() + 1

    local tabObj = {}
    tabObj.name = tabName
    tabObj.tabData = tabData

    function tabObj:AddButton(config, pOverride) return require(script.Parent.Button).create(self, config, pOverride) end
    function tabObj:AddInput(config, pOverride) return require(script.Parent.Input).create(self, config, pOverride) end
    function tabObj:AddTextBox(config, pOverride) return self:AddInput(config, pOverride) end
    function tabObj:AddTextbox(config, pOverride) return self:AddInput(config, pOverride) end
    function tabObj:AddSelection(config, pOverride) return require(script.Parent.Selection).create(self, config, pOverride) end
    function tabObj:AddSlider(config, pOverride) return require(script.Parent.Slider).create(self, config, pOverride) end
    function tabObj:AddLabel(config, pOverride) return require(script.Parent.Label).create(self, config, pOverride) end
    function tabObj:GetFrame() return tab end
    function tabObj:closeMore() closeMore() end

    function tabObj:openMore(ownerKey, sourceFrame, populateFunc, onCloseFunc)
        tab.ZIndex = State.getHighestZ() + 1
        for _, child in ipairs(moreScroll:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextButton") then child:Destroy() end
        end

        if moreScroll.Visible and moreScroll:GetAttribute("Owner") == ownerKey then
            self:closeMore()
            return false
        end

        State.hideAllMoreScrolls()
        moreScroll:SetAttribute("Owner", ownerKey)
        currentOnClose = onCloseFunc
        
        moreBlocker.ZIndex = tab.ZIndex + 5
        moreScroll.ZIndex = moreBlocker.ZIndex + 1
        moreBlocker.Visible = true
        moreScroll.Visible = true

        -- screen bounds checka
        local vp = getViewport()
        local tabX = tab.AbsolutePosition.X
        local moreWidth = 200
        local hasRightRoom = (tabX + 200 + moreWidth + 10 <= vp.X)
        local hasLeftRoom = (tabX >= moreWidth + 10)
        local placeOnLeft = not hasRightRoom and hasLeftRoom

        local xOffset = placeOnLeft and (-moreWidth - 4) or 204

        local sourceY = sourceFrame.AbsolutePosition.Y
        local relativeY = sourceY - tab.AbsolutePosition.Y
        local approxHeight = 150
        local overflowY = (sourceY + approxHeight) - (vp.Y - 20)
        if overflowY > 0 then
            relativeY = math.max(0, relativeY - overflowY)
        end

        moreScroll.Position = UDim2.new(0, xOffset, 0, relativeY)

        populateFunc(moreScroll)
        task.defer(refreshMoreSize)
        return true
    end

    function tabObj:buildContextMenu(moreScrollFrame, commandId, isBindable, isStartup, callback, updateTextFunc)
        local UIS = game:GetService("UserInputService")
        local KeybindManager = require(script.Parent.Parent.config.KeybindManager)

        if isBindable then
            local assignBtn = self:AddButton({ Info = { Title = "Assign a New Keybind" } }, moreScrollFrame)
            assignBtn.button.Activated:Connect(function()
                assignBtn.text.Text = "Press a key (timeout: 5s)"
                assignBtn.text.TextColor3 = Constants.Colors.accent
                
                local conn, timeoutConn
                local timedOut = false
                timeoutConn = task.delay(5, function()
                    timedOut = true
                    assignBtn.text.Text = "Assign a New Keybind"
                    assignBtn.text.TextColor3 = Constants.Colors.text
                    if conn then conn:Disconnect() end
                end)

                conn = UIS.InputBegan:Connect(function(input)
                    if UIS:GetFocusedTextBox() then return end
                    if timedOut then return end
                    
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        timedOut = true
                        KeybindManager.bind(commandId, callback, input.KeyCode)
                        conn:Disconnect()
                        task.cancel(timeoutConn)
                        if updateTextFunc then updateTextFunc() end
                        self:closeMore() 
                    end
                end)
            end)

            local savedBind = ConfigManager.get("Keybinds")[commandId]
            if savedBind then
                self:AddButton({
                    Info = { Title = "Remove Keybind [" .. savedBind .. "]" },
                    Callback = function()
                        KeybindManager.unbind(commandId)
                        if updateTextFunc then updateTextFunc() end
                        self:closeMore()
                    end
                }, moreScrollFrame)
            end
        end
        
        if isStartup then
            local startupBtn = self:AddButton({
                Info = { Title = "Toggle Startup" },
                InternalInfo = { Toggle = true, UniqueCommandId = commandId .. "_startup" },
                Callback = function(state) ConfigManager.set(commandId, state, "Startup") end
            }, moreScrollFrame)
            startupBtn.setVisualState(ConfigManager.get("Startup")[commandId] == true)
        end
    end

    tabData.tabObj = tabObj
    return tabObj
end

return Tab