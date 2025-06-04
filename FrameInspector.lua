-- FrameInspector.lua
-- A simplified, Blizzard-style frame stack overlay inspector
-- Activates with /fi

local FrameInspector = CreateFrame("Frame", "FrameInspectorAddon")
local overlays = {}
local maxLayers = 5
local isActive = false
local lastStack = {}

-- Create overlays (Blizzard-style)
local function CreateOverlays()
    if #overlays > 0 then return end
    local colors = {
        {1, 0, 0, 0.4},    -- Red
        {1, 0.5, 0, 0.4},  -- Orange
        {1, 1, 0, 0.4},    -- Yellow
        {0, 1, 0, 0.4},    -- Green
        {0, 0, 1, 0.4},    -- Blue
    }
    for i = 1, maxLayers do
        local overlay = CreateFrame("Frame", "FrameInspectorOverlay"..i, UIParent)
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
    if not frame then return false end
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
            if not parent or parent == UIParent or parent == current then break end
            current = parent
            depth = depth + 1
        end
        return stack
    end
    return {}
end

-- Update overlays every frame
local function Update()
    if not isActive then return end
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
end

-- Activate/deactivate
local function Activate()
    isActive = true
    CreateOverlays()
    FrameInspector:SetScript("OnUpdate", Update)
    print("|cff00ff00FrameInspector activated!|r Hover over frames to inspect them.")
end

local function Deactivate()
    isActive = false
    FrameInspector:SetScript("OnUpdate", nil)
    for i = 1, #overlays do overlays[i]:Hide() end
    lastStack = {} -- Clear cached stack to avoid stale data
    print("|cffff0000FrameInspector deactivated!|r")
end

local function Toggle()
    if isActive then Deactivate() else Activate() end
end

-- Register chat command
SLASH_FRAMEINSPECTOR1 = "/fi"
SlashCmdList["FRAMEINSPECTOR"] = Toggle
