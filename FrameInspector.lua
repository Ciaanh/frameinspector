-- FrameInspector.lua
-- A simplified, Blizzard-style frame stack overlay inspector
-- Activates with /fi

local FrameInspector = CreateFrame("Frame", "FrameInspectorAddon")

-- Configuration
local MAX_LAYERS = 6
local OVERLAY_COLORS = {
    {1, 0, 0, 0.4}, -- Red
    {1, 0.5, 0, 0.4}, -- Orange
    {1, 1, 0, 0.4}, -- Yellow
    {0, 1, 0, 0.4}, -- Green
    {0, 0, 1, 0.4}, -- Blue
    {0.5, 0, 1, 0.4} -- Purple
}

-- State variables
local overlays = {}
local isActive = false
local lastStack = {}
local tooltip = nil

-- Utility functions
local function SafeHide(frame)
    if frame and frame:IsShown() then
        frame:Hide()
    end
end

local function SafeShow(frame)
    if frame and not frame:IsShown() then
        frame:Show()
    end
end

-- Dedicated function for retrieving frame display names
-- Tries multiple approaches: GetName(), template info, object type, and fallbacks
local function GetFrameDisplayName(frame)
    if not frame then
        return "<nil>"
    end

    -- Try GetName() first (most common case)
    local name = frame:GetName()
    if name and name ~= "" then
        return name
    end

    -- Try to get template information if available
    -- Note: WoW doesn't have a direct GetTemplate() method, but we can try some approaches
    local templateInfo = nil

    -- Check if frame has a template-related field (some addons store this)
    if frame.template then
        templateInfo = frame.template
    elseif frame.Template then
        templateInfo = frame.Template
    elseif frame._template then
        templateInfo = frame._template
    end

    -- Try to get debug name which sometimes contains template info
    if frame.GetDebugName then
        local debugName = frame:GetDebugName()
        if debugName and debugName ~= "" and debugName ~= name then
            -- If we have template info, combine it
            if templateInfo then
                return string.format("<%s:%s>", templateInfo, debugName)
            else
                return string.format("<%s>", debugName)
            end
        end
    end

    -- If we have template info but no other name
    if templateInfo then
        local objectType = frame:GetObjectType() or "Frame"
        return string.format("<%s:%s>", templateInfo, objectType)
    end

    -- Fallback to object type with additional context
    local objectType = frame:GetObjectType() or "Unknown"

    -- Try to add parent context for better identification
    local parent = frame:GetParent()
    if parent then
        local parentName = parent:GetName()
        if parentName then
            return string.format("<Anonymous %s in %s>", objectType, parentName)
        else
            return string.format("<Anonymous %s>", objectType)
        end
    end

    return string.format("<Anonymous %s>", objectType)
end

-- Create tooltip for frame details
local function CreateTooltip()
    if tooltip then
        return
    end

    -- Create custom tooltip frame
    tooltip = CreateFrame("Frame", "FrameInspectorTooltip", UIParent)
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetFrameLevel(10000)
    tooltip:SetClampedToScreen(true)
    tooltip:SetSize(300, 200)
    SafeHide(tooltip)

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
end

-- Get anchor information for a frame
local function GetFrameAnchorInfo(frame)
    if not frame then
        return nil
    end

    -- Get the first anchor point (frames can have multiple, but we'll show the first)
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)

    if point and relativeTo then
        return {
            point = point,
            relativeFrame = relativeTo, -- Changed from relativeTo to relativeFrame
            relativePoint = relativePoint,
            offsetX = x or 0,
            offsetY = y or 0
        }
    end

    return nil
end

-- Format frame information for tooltip
local function GetFrameInfo(frame)
    if not frame then
        return "No frame"
    end

    local info = {}

    -- Frame name
    local name = GetFrameDisplayName(frame)
    table.insert(info, "|cffffd700Name:|r " .. name)

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
    table.insert(info, "|cffffd700Shown:|r " .. (isShown and "|cff00ff00Yes|r" or "|cffff0000No|r")) -- Parent frame
    local parent = frame:GetParent()
    local parentName = parent and GetFrameDisplayName(parent)
    table.insert(info, "|cffffd700Parent:|r " .. (parentName or "|cffff0000<Anonymous/None>|r")) -- Anchor information
    local anchorInfo = GetFrameAnchorInfo(frame)
    if anchorInfo then
        local relativeToName = GetFrameDisplayName(anchorInfo.relativeFrame) -- Changed from relativeTo to relativeFrame
        table.insert(info, "|cffffd700Anchor:|r " .. anchorInfo.point)
        table.insert(info, "|cffffd700Relative To:|r " .. relativeToName)
        table.insert(info, "|cffffd700Relative Point:|r " .. (anchorInfo.relativePoint or "UNKNOWN"))
        table.insert(
            info,
            "|cffffd700Offset:|r " .. string.format("%.1f, %.1f", anchorInfo.offsetX, anchorInfo.offsetY)
        )
    else
        table.insert(info, "|cffffd700Anchor:|r |cffff0000No anchor points|r")
    end

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
    SafeShow(tooltip)

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

    for i = 1, MAX_LAYERS do
        local overlay = CreateFrame("Frame", "FrameInspectorOverlay" .. i, UIParent)
        overlay:SetFrameStrata("TOOLTIP")
        overlay:SetFrameLevel(9999 - i)
        SafeHide(overlay)

        overlay.bg = overlay:CreateTexture(nil, "ARTWORK")
        overlay.bg:SetAllPoints()
        overlay.bg:SetColorTexture(unpack(OVERLAY_COLORS[i]))
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

-- Helper function to calculate anchor position based on anchor point
local function GetAnchorPosition(left, bottom, width, height, point)
    local x, y = left, bottom

    if point == "TOPLEFT" then
        x, y = left, bottom + height
    elseif point == "TOP" then
        x, y = left + width / 2, bottom + height
    elseif point == "TOPRIGHT" then
        x, y = left + width, bottom + height
    elseif point == "LEFT" then
        x, y = left, bottom + height / 2
    elseif point == "CENTER" then
        x, y = left + width / 2, bottom + height / 2
    elseif point == "RIGHT" then
        x, y = left + width, bottom + height / 2
    elseif point == "BOTTOMLEFT" then
        x, y = left, bottom
    elseif point == "BOTTOM" then
        x, y = left + width / 2, bottom
    elseif point == "BOTTOMRIGHT" then
        x, y = left + width, bottom
    end

    return x, y
end

-- Create anchor indicators for the top overlay showing frame anchor, parent anchor, and connecting line
local function CreateAnchorIndicator(overlay, frame, anchorInfo)
    -- Only show anchor indicators for the top overlay
    if overlay ~= overlays[1] then
        if overlay.frameAnchor then
            overlay.frameAnchor:Hide()
        end
        if overlay.parentAnchor then
            overlay.parentAnchor:Hide()
        end
        if overlay.connectionLine then
            overlay.connectionLine:Hide()
        end
        return
    end -- Create frame anchor indicator (red dot)
    if not overlay.frameAnchor then
        overlay.frameAnchor = CreateFrame("Frame", nil, UIParent)
        overlay.frameAnchor:SetSize(6, 6)
        overlay.frameAnchor:SetFrameStrata("TOOLTIP")
        overlay.frameAnchor:SetFrameLevel(10000)

        overlay.frameAnchor.texture = overlay.frameAnchor:CreateTexture(nil, "OVERLAY")
        overlay.frameAnchor.texture:SetAllPoints()
        overlay.frameAnchor.texture:SetColorTexture(1, 0, 0, 0.9) -- Red for frame anchor

        overlay.frameAnchor.border = overlay.frameAnchor:CreateTexture(nil, "BORDER")
        overlay.frameAnchor.border:SetPoint("TOPLEFT", overlay.frameAnchor, "TOPLEFT", -1, 1)
        overlay.frameAnchor.border:SetPoint("BOTTOMRIGHT", overlay.frameAnchor, "BOTTOMRIGHT", 1, -1)
        overlay.frameAnchor.border:SetColorTexture(0, 0, 0, 0.8)
    end -- Show red dot if we have a frame to track
    if frame and anchorInfo then
        local frameLeft, frameBottom, frameWidth, frameHeight = frame:GetRect()

        if frameLeft and frameBottom and frameWidth and frameHeight then
            -- Calculate the actual anchor position on the frame
            local anchorX, anchorY =
                GetAnchorPosition(frameLeft, frameBottom, frameWidth, frameHeight, anchorInfo.point)

            overlay.frameAnchor:ClearAllPoints()
            overlay.frameAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", anchorX, anchorY)
            overlay.frameAnchor:Show()
        else
            overlay.frameAnchor:Hide()
        end
    else
        overlay.frameAnchor:Hide()
    end
    -- Hide the other indicators for now during testing
    if overlay.parentAnchor then
        overlay.parentAnchor:Hide()
    end
    if overlay.connectionLine then
        overlay.connectionLine:Hide()
    end
end

local function GetFrameStack()
    -- Hide overlays temporarily during frame detection to prevent self-detection
    for i = 1, #overlays do
        if overlays[i] and overlays[i]:IsShown() then
            SafeHide(overlays[i])
        end
    end

    -- Check if FrameStackTooltip dependencies are available
    if not FrameStackTooltip then
        return {}
    end

    if not FrameStackTooltip.SetFrameStack then
        return {}
    end

    -- Get the highlighted frame from Blizzard's system
    local highlightFrame = FrameStackTooltip:SetFrameStack(false, false)

    -- No frame under mouse cursor
    if not highlightFrame then
        return {}
    end

    local stack = {}
    local current = highlightFrame
    local depth = 0

    while current and depth < MAX_LAYERS do
        -- Since overlays are hidden during detection, we shouldn't encounter them
        if not IsOurOverlay(current) then
            table.insert(stack, current)
        end

        -- Check parent chain
        local parent = current:GetParent()
        if not parent or parent == UIParent or parent == current then
            break
        end

        current = parent
        depth = depth + 1

        -- Maximum depth reached
        if depth >= MAX_LAYERS then
            break
        end
    end

    return stack
end

-- Update overlays every frame
local function Update()
    if not isActive then
        return
    end

    local stack = GetFrameStack()
    local n = math.min(#stack, MAX_LAYERS)

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
    end -- Always update overlays to ensure they're shown after being hidden during frame detection
    for i = 1, MAX_LAYERS do
        local overlay = overlays[i]
        if i <= n and stack[i] and not IsOurOverlay(stack[i]) then
            -- Only reposition overlay if stack changed (performance optimization)
            if stackChanged then
                overlay:ClearAllPoints()
                overlay:SetAllPoints(stack[i])
            end

            -- Always update anchor indicator for top overlay so it follows cursor
            if i == 1 then
                local anchorInfo = GetFrameAnchorInfo(stack[i])
                CreateAnchorIndicator(overlay, stack[i], anchorInfo)
            else
                -- Hide anchor indicators for non-top overlays
                CreateAnchorIndicator(overlay, nil, nil)
            end

            SafeShow(overlay)
        else
            SafeHide(overlay)
            -- Hide anchor indicators when overlay is hidden
            CreateAnchorIndicator(overlay, nil, nil)
        end
    end

    -- Update lastStack only when stack changed (performance optimization)
    if stackChanged then
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
            SafeHide(tooltip)
        end
    end
end

-- Activate/deactivate functions
local function Activate()
    isActive = true
    CreateOverlays()
    CreateTooltip()
    FrameInspector:SetScript("OnUpdate", Update)
end

local function Deactivate()
    isActive = false
    FrameInspector:SetScript("OnUpdate", nil)
    for i = 1, #overlays do
        SafeHide(overlays[i])
        -- Hide all anchor indicators
        if overlays[i].frameAnchor then
            overlays[i].frameAnchor:Hide()
        end
        if overlays[i].parentAnchor then
            overlays[i].parentAnchor:Hide()
        end
        if overlays[i].connectionLine then
            overlays[i].connectionLine:Hide()
        end
    end
    lastStack = {} -- Clear cached stack to avoid stale data
    if tooltip then
        SafeHide(tooltip)
    end
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
