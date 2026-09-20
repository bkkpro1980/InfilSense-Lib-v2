local UIBuilder = {}
local Constants = require(script.Parent.Parent.constants)

function UIBuilder.create(className, properties)
    local inst = Instance.new(className)
    for k, v in pairs(properties or {}) do
        inst[k] = v
    end
    return inst
end

function UIBuilder.createGradient(parent)
    local frame = UIBuilder.create("Frame", {
        Name = "gradient",
        Visible = false,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 2,
        Parent = parent,
    })
    
    UIBuilder.create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0.9)
        }),
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Constants.Colors.accent),
            ColorSequenceKeypoint.new(1, Constants.Colors.accent)
        }),
        Parent = frame
    })
    
    return frame
end

return UIBuilder