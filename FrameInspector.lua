-- FrameInspector.lua
-- A simplified, Blizzard-style frame stack overlay inspector
-- Activates with /fi

local FrameInspector = CreateFrame("Frame", "FrameInspectorAddon")
local overlays = {}
local maxLayers = 5
local isActive = false
local lastStack = {}
local tooltip = nil

-- Create tooltip for frame details
local function CreateTooltip()
    if tooltip then
        return
    end

    -- Create custom tooltip frame without template
    tooltip = CreateFrame("Frame", "FrameInspectorTooltip", UIParent)
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetFrameLevel(10000)
    tooltip:SetClampedToScreen(true)
    tooltip:SetSize(300, 200)
    tooltip:Hide()

    -- Create background
    tooltip.bg = tooltip:CreateTexture(nil, "BACKGROUND")
    tooltip.bg:SetAllPoints()
    tooltip.bg:SetColorTexture(0, 0, 0, 0.9)

    -- Create border
    tooltip.border = tooltip:CreateTexture(nil, "BORDER")
    tooltip.border:SetAllPoints()
    tooltip.border:SetColorTexture(1, 1, 1, 0.3)
    tooltip.border:SetPoint("TOPLEFT", tooltip, "TOPLEFT", -1, 1)
    tooltip.border:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", 1, -1)

    -- Create text display
    tooltip.text = tooltip:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    tooltip.text:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 8, -8)
    tooltip.text:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -8, 8)
    tooltip.text:SetJustifyH("LEFT")
    tooltip.text:SetJustifyV("TOP")
    tooltip.text:SetWordWrap(true)

    -- Make tooltip moveable
    tooltip:SetMovable(true)
    tooltip:EnableMouse(true)
    tooltip:RegisterForDrag("LeftButton")
    tooltip:SetScript(
        "OnDragStart",
        function(self)
            self:StartMoving()
        end
    )
    tooltip:SetScript(
        "OnDragStop",
        function(self)
            self:StopMovingOrSizing()
        end
    )

    -- Add a close button (simple X)
    local closeButton = CreateFrame("Button", nil, tooltip)
    closeButton:SetSize(16, 16)
    closeButton:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT", -2, -2)

    closeButton.text = closeButton:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    closeButton.text:SetAllPoints()
    closeButton.text:SetText("X")
    closeButton.text:SetTextColor(1, 0.2, 0.2)

    closeButton:SetScript(
        "OnClick",
        function()
            tooltip:Hide()
        end
    )
    closeButton:SetScript(
        "OnEnter",
        function(self)
            self.text:SetTextColor(1, 0.5, 0.5)
        end
    )
    closeButton:SetScript(
        "OnLeave",
        function(self)
            self.text:SetTextColor(1, 0.2, 0.2)
        end
    )
end

-- Format frame information for tooltip
local function GetFrameInfo(frame)
    if not frame then
        return "No frame"
    end

    local info = {}

    -- Frame name
    local name = frame:GetName()
    table.insert(info, "|cffffd700Name:|r " .. (name or "|cffff0000<Anonymous>|r"))

    -- Frame type
    local objectType = frame:GetObjectType()
    table.insert(info, "|cffffd700Type:|r " .. (objectType or "Unknown"))

    -- Size information
    local width = frame:GetWidth()
    local height = frame:GetHeight()
    table.insert(info, "|cffffd700Size:|r " .. string.format("%.1f x %.1f", width or 0, height or 0))

    -- Position information
    local left = frame:GetLeft()
    local bottom = frame:GetBottom()
    if left and bottom then
        table.insert(info, "|cffffd700Position:|r " .. string.format("%.1f, %.1f", left, bottom))
    else
        table.insert(info, "|cffffd700Position:|r |cffff0000Unknown|r")
    end

    -- Frame strata and level
    local strata = frame:GetFrameStrata()
    local level = frame:GetFrameLevel()
    table.insert(info, "|cffffd700Strata:|r " .. (strata or "Unknown"))
    table.insert(info, "|cffffd700Level:|r " .. (level or "Unknown"))

    -- Visibility
    local isVisible = frame:IsVisible()
    local isShown = frame:IsShown()
    table.insert(info, "|cffffd700Visible:|r " .. (isVisible and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    table.insert(info, "|cffffd700Shown:|r " .. (isShown and "|cff00ff00Yes|r" or "|cffff0000No|r"))

    -- Parent frame
    local parent = frame:GetParent()
    local parentName = parent and parent:GetName()
    table.insert(info, "|cffffd700Parent:|r " .. (parentName or "|cffff0000<Anonymous/None>|r"))

    return table.concat(info, "\n")
end

-- Update tooltip with frame information
local function UpdateTooltip(frame)
    if not tooltip or not frame then
        return
    end

    local frameInfo = GetFrameInfo(frame)

    -- Create the display text with title
    local displayText = "|cff00ff00Frame Inspector Details|r\n\n" .. frameInfo

    -- Set the text
    tooltip.text:SetText(displayText)

    -- Auto-resize tooltip based on text
    local textWidth = tooltip.text:GetStringWidth()
    local textHeight = tooltip.text:GetStringHeight()

    local tooltipWidth = math.max(300, textWidth + 16)
    local tooltipHeight = math.max(100, textHeight + 16)

    tooltip:SetSize(tooltipWidth, tooltipHeight)
    tooltip:Show()

    -- Position tooltip away from mouse cursor to prevent interference
    local scale = tooltip:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x = x / scale
    y = y / scale

    -- Get screen dimensions
    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()

    -- Determine best position to avoid mouse cursor
    local offsetX, offsetY = 15, 15
    local anchorPoint, relativePoint

    -- If mouse is in right half of screen, position tooltip to the left
    if x > screenWidth / 2 then
        anchorPoint = "TOPRIGHT"
        relativePoint = "BOTTOMLEFT"
        offsetX = -offsetX
    else
        anchorPoint = "TOPLEFT"
        relativePoint = "BOTTOMLEFT"
    end

    -- If mouse is in top half of screen, position tooltip below
    if y > screenHeight / 2 then
        anchorPoint = anchorPoint:gsub("TOP", "BOTTOM")
        relativePoint = "TOPLEFT"
        offsetY = -offsetY
    end

    tooltip:ClearAllPoints()
    tooltip:SetPoint(anchorPoint, UIParent, "BOTTOMLEFT", x + offsetX, y + offsetY)
end

-- Create overlays (Blizzard-style)
local function CreateOverlays()
    if #overlays > 0 then
        return
    end
    local colors = {
        {1, 0, 0, 0.4}, -- Red
        {1, 0.5, 0, 0.4}, -- Orange
        {1, 1, 0, 0.4}, -- Yellow
        {0, 1, 0, 0.4}, -- Green
        {0, 0, 1, 0.4} -- Blue
    }
    for i = 1, maxLayers do
        local overlay = CreateFrame("Frame", "FrameInspectorOverlay" .. i, UIParent)
        overlay:SetFrameStrata("TOOLTIP")
        overlay:SetFrameLevel(9999 - i)
        overlay:Hide()
        overlay.bg = overlay:CreateTexture(nil, "ARTWORK")
        overlay.bg:SetAllPoints()
        overlay.bg:SetColorTexture(unpack(colors[i]))
        overlays[i] = overlay
    end
end

-- Check if a frame is one of our overlay frames
local function IsOurOverlay(frame)
    if not frame then
        return false
    end
    local name = frame:GetName()
    if name and name:match("^FrameInspectorOverlay%d+$") then
        return true
    end
    return false
end

-- Get frame stack (Blizzard-style, top to parent)
local function GetFrameStack()
    if FrameStackTooltip and FrameStackTooltip.SetFrameStack then
        local highlightFrame = FrameStackTooltip:SetFrameStack(false, false)
        local stack = {}
        local current = highlightFrame
        local depth = 0
        while current and depth < maxLayers do
            -- Skip our own overlay frames to prevent self-anchoring
            if not IsOurOverlay(current) then
                table.insert(stack, current)
            end
            local parent = current:GetParent()
            if not parent or parent == UIParent or parent == current then
                break
            end
            current = parent
            depth = depth + 1
        end
        return stack
    end
    return {}
end

-- Update overlays every frame
local function Update()
    if not isActive then
        return
    end
    local stack = GetFrameStack()
    local n = math.min(#stack, maxLayers)

    -- Check if stack has changed to reduce flickering
    local stackChanged = false
    if #lastStack ~= n then
        stackChanged = true
    else
        for i = 1, n do
            if lastStack[i] ~= stack[i] then
                stackChanged = true
                break
            end
        end
    end

    if stackChanged then
        for i = 1, maxLayers do
            local overlay = overlays[i]
            if i <= n and stack[i] and not IsOurOverlay(stack[i]) then
                overlay:ClearAllPoints()
                overlay:SetAllPoints(stack[i])
                overlay:Show()
            else
                overlay:Hide()
            end
        end

        -- Update lastStack
        lastStack = {}
        for i = 1, n do
            lastStack[i] = stack[i]
        end
    end

    -- Update tooltip with top frame information
    if stack[1] then
        UpdateTooltip(stack[1])
    else
        if tooltip then
            tooltip:Hide()
        end
    end
end

-- Activate/deactivate
local function Activate()
    isActive = true
    CreateOverlays()
    CreateTooltip()
    FrameInspector:SetScript("OnUpdate", Update)
    print("|cff00ff00FrameInspector activated!|r Hover over frames to inspect them.")
end

local function Deactivate()
    isActive = false
    FrameInspector:SetScript("OnUpdate", nil)
    for i = 1, #overlays do
        overlays[i]:Hide()
    end
    lastStack = {} -- Clear cached stack to avoid stale data
    if tooltip then
        tooltip:Hide()
    end
    print("|cffff0000FrameInspector deactivated!|r")
end

local function Toggle()
    if isActive then
        Deactivate()
    else
        Activate()
    end
end

-- Register chat command
SLASH_FRAMEINSPECTOR1 = "/fi"
SlashCmdList["FRAMEINSPECTOR"] = Toggle
