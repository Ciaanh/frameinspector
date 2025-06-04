-- FrameInspector.lua
-- A simplified, Blizzard-style frame stack overlay inspector
-- Activates with /fi

local FrameInspector = CreateFrame("Frame", "FrameInspectorAddon")
local overlays = {}
local maxLayers = 5
local isActive = false
local lastStack = {}
local tooltip = nil

local function HideFrame(frame, caller)
    if frame and frame:IsShown() then
        -- local frameName = frame:GetName() or "<Anonymous>"
        -- local callerInfo = caller or "Unknown"
        -- print(
        --     "|cffff9900[FrameInspector]|r HideFrame called from: |cff00ffff" ..
        --         callerInfo .. "|r - Hiding frame: |cffff0000" .. frameName .. "|r"
        -- )
        frame:Hide()
    end
end

local function ShowFrame(frame, caller)
    if frame and not frame:IsShown() then
        -- local frameName = frame:GetName() or "<Anonymous>"
        -- local callerInfo = caller or "Unknown"
        -- print(
        --     "|cffff9900[FrameInspector]|r ShowFrame called from: |cff00ffff" ..
        --         callerInfo .. "|r - Showing frame: |cff00ff00" .. frameName .. "|r"
        -- )
        frame:Show()
    end
end

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
    HideFrame(tooltip, "CreateTooltip")

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

    -- -- Make tooltip moveable
    -- tooltip:SetMovable(true)
    -- tooltip:EnableMouse(true)
    -- tooltip:RegisterForDrag("LeftButton")
    -- tooltip:SetScript(
    --     "OnDragStart",
    --     function(self)
    --         self:StartMoving()
    --     end
    -- )
    -- tooltip:SetScript(
    --     "OnDragStop",
    --     function(self)
    --         self:StopMovingOrSizing()
    --     end
    -- )
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
    ShowFrame(tooltip, "UpdateTooltip")

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
        HideFrame(overlay, "CreateOverlays")

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

local function GetFrameStack()
    -- Hide overlays temporarily during frame detection to prevent self-detection
    for i = 1, #overlays do
        if overlays[i] and overlays[i]:IsShown() then
            HideFrame(overlays[i], "GetFrameStack3-TempHide")
        end
    end

    -- Case 1: Check if FrameStackTooltip dependencies are available
    if not FrameStackTooltip then
        print(
            "|cffff9900[FrameInspector]|r |cffff0000Empty Stack Case 1:|r FrameStackTooltip global not found (Blizzard_FrameStack addon not loaded)"
        )
        return {}
    end

    if not FrameStackTooltip.SetFrameStack then
        print(
            "|cffff9900[FrameInspector]|r |cffff0000Empty Stack Case 1:|r SetFrameStack method missing on FrameStackTooltip"
        )
        return {}
    end

    -- Get the highlighted frame from Blizzard's system (overlays are hidden, so won't interfere)
    local highlightFrame = FrameStackTooltip:SetFrameStack(false, false)

    -- Case 2: No frame under mouse cursor
    if not highlightFrame then
        print(
            "|cffff9900[FrameInspector]|r |cffff0000Empty Stack Case 2:|r No frame under mouse cursor (empty space or game world)"
        )
        return {}
    end

    local stack = {}
    local current = highlightFrame
    local depth = 0
    local totalFramesProcessed = 0
    local overlayFramesSkipped = 0

    print(
        "|cffff9900[FrameInspector]|r |cff00ffccGetFrameStack Debug:|r Starting with highlightFrame: " ..
            (highlightFrame:GetName() or "<Anonymous>")
    )
    while current and depth < maxLayers do
        totalFramesProcessed = totalFramesProcessed + 1
        local frameName = current:GetName() or "<Anonymous>"

        -- Since overlays are hidden during detection, we shouldn't encounter them
        -- But keep the check as a safety measure
        if IsOurOverlay(current) then
            overlayFramesSkipped = overlayFramesSkipped + 1
            print(
                "|cffff9900[FrameInspector]|r |cffff6600Frame Filtered:|r Unexpected overlay frame detected: " ..
                    frameName
            )
        else
            table.insert(stack, current)
            print(
                "|cffff9900[FrameInspector]|r |cff00ff00Frame Added:|r [" ..
                    #stack .. "] " .. frameName .. " (Type: " .. (current:GetObjectType() or "Unknown") .. ")"
            )
        end

        -- Check parent chain
        local parent = current:GetParent()
        if not parent then
            print(
                "|cffff9900[FrameInspector]|r |cff888888Parent Chain End:|r Frame '" .. frameName .. "' has no parent"
            )
            break
        elseif parent == UIParent then
            print(
                "|cffff9900[FrameInspector]|r |cff888888Parent Chain End:|r Frame '" ..
                    frameName .. "' parent is UIParent"
            )
            break
        elseif parent == current then
            print(
                "|cffff9900[FrameInspector]|r |cffff0000Parent Chain Error:|r Frame '" ..
                    frameName .. "' has self-referencing parent"
            )
            break
        else
            local parentName = parent:GetName() or "<Anonymous>"
            print("|cffff9900[FrameInspector]|r |cff00ccffParent Chain:|r " .. frameName .. " -> " .. parentName)
        end

        current = parent
        depth = depth + 1

        -- Case 5: Maximum depth reached
        if depth >= maxLayers then
            print(
                "|cffff9900[FrameInspector]|r |cffff6600Depth Limit:|r Reached maximum depth (" ..
                    maxLayers .. "), stopping traversal"
            )
            break
        end
    end

    -- Final analysis and logging
    print(
        "|cffff9900[FrameInspector]|r |cff00ffccGetFrameStack Summary:|r Processed " ..
            totalFramesProcessed ..
                " frames, skipped " .. overlayFramesSkipped .. " overlays, final stack size: " .. #stack
    )

    -- Case 3 & 4: All frames filtered out or immediate termination
    if #stack == 0 then
        if overlayFramesSkipped > 0 then
            print(
                "|cffff9900[FrameInspector]|r |cffff0000Empty Stack Case 3:|r All " ..
                    overlayFramesSkipped .. " frames were our overlay frames (filtered out)"
            )
        elseif totalFramesProcessed == 1 then
            print(
                "|cffff9900[FrameInspector]|r |cffff0000Empty Stack Case 4:|r Initial frame had immediate parent chain termination"
            )
        else
            print(
                "|cffff9900[FrameInspector]|r |cffff0000Empty Stack Case 4:|r Parent chain terminated without valid frames"
            )
        end
    end

    -- Note: Overlays will be re-shown by the Update() function after this returns
    -- This prevents them from interfering with frame detection while still allowing proper display

    return stack
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

    -- Log stack size comparison
    -- print("|cffff9900[FrameInspector]|r Stack check: lastStack=#" .. #lastStack .. ", current=#" .. n)

    if #lastStack ~= n then
        stackChanged = true
        print(
            "|cffff9900[FrameInspector]|r |cffff0000Stack changed:|r Different sizes (" ..
                #lastStack .. " -> " .. n .. ")"
        )
    else
        -- if not stackChanged then
        --     print("|cffff9900[FrameInspector]|r |cff00ff00Stack unchanged:|r All " .. n .. " frames are identical")
        -- end
        for i = 1, n do
            if lastStack[i] ~= stack[i] then
                -- local lastFrameName = lastStack[i] and (lastStack[i]:GetName() or "<Anonymous>") or "nil"
                -- local currentFrameName = stack[i] and (stack[i]:GetName() or "<Anonymous>") or "nil"
                -- print(
                --     "|cffff9900[FrameInspector]|r |cffff0000Stack changed:|r Frame at position " ..
                --         i .. " changed from '" .. lastFrameName .. "' to '" .. currentFrameName .. "'"
                -- )
                stackChanged = true
                break
            end
        end
    end    -- Always update overlays to ensure they're shown after being hidden during frame detection
    -- Only update lastStack when the stack actually changed for performance optimization
    for i = 1, maxLayers do
        local overlay = overlays[i]
        if i <= n and stack[i] and not IsOurOverlay(stack[i]) then
            local frameName = stack[i]:GetName() or "<Anonymous>"
            -- Only reposition if stack changed (performance optimization)
            if stackChanged then
                overlay:ClearAllPoints()
                overlay:SetAllPoints(stack[i])
            end
            ShowFrame(overlay, "Update")
        else
            HideFrame(overlay, "Update")
        end
    end

    -- Update lastStack only when stack changed (performance optimization)
    if stackChanged then
        lastStack = {}
        for i = 1, n do
            lastStack[i] = stack[i]
        end
        -- print("|cffff9900[FrameInspector]|r |cff00ff00Cache updated:|r lastStack now contains " .. n .. " frames")
    -- else
    --     print(
    --         "|cffff9900[FrameInspector]|r |cff888888Keeping overlay visibility:|r Stack unchanged, but ensuring overlays are visible"
    --     )
    end

    -- Update tooltip with top frame information
    if stack[1] then
        UpdateTooltip(stack[1])
    else
        if tooltip then
            HideFrame(tooltip, "Update")
        end
    end
end

-- Activate/deactivate
local function Activate()
    isActive = true
    CreateOverlays()
    CreateTooltip()
    FrameInspector:SetScript("OnUpdate", Update)
    -- print("|cff00ff00FrameInspector activated!|r Hover over frames to inspect them.")
end

local function Deactivate()
    isActive = false
    FrameInspector:SetScript("OnUpdate", nil)
    for i = 1, #overlays do
        HideFrame(overlays[i], "Deactivate")
    end
    lastStack = {} -- Clear cached stack to avoid stale data
    if tooltip then
        HideFrame(tooltip, "Deactivate")
    end
    -- print("|cffff0000FrameInspector deactivated!|r")
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
