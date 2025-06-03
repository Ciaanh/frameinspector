local FrameInspector = CreateFrame("Frame", "FrameInspectorAddon")
local isActive = false
local overlayFrames = {} -- Table to store multiple overlay frames
local tooltip = nil
local maxLayers = 5 -- Maximum number of layers to show

-- Security check function based on Blizzard implementation
local function CanAccessObject(obj)
    return issecure() or not obj:IsForbidden()
end

-- Frame stack display configuration
local stackDisplayConfig = {
    maxDepth = 15, -- Maximum depth to show in hierarchy
    showDetailedInfo = true, -- Show level, strata, etc.
    showInteractions = false, -- Show script handlers
    compactMode = false, -- Compact display for limited space
    colorCoding = true, -- Use color coding for different levels
    indentSize = 2 -- Spaces per indentation level
}

-- Toggle stack display options
local function ToggleStackDisplayOption(option)
    if stackDisplayConfig[option] ~= nil then
        stackDisplayConfig[option] = not stackDisplayConfig[option]
        print(
            "|cff00ff00FrameInspector:|r " ..
                option .. " is now " .. (stackDisplayConfig[option] and "|cff00ff00enabled|r" or "|cffff0000disabled|r")
        )
        return true
    end
    return false
end

-- Get texture information for a frame
local function GetTextureInfoForFrame(frame)
    if not frame.GetRegions then
        return nil
    end

    local regions = {frame:GetRegions()}
    local textureInfo = {}

    for _, region in ipairs(regions) do
        if region:GetObjectType() == "Texture" then
            local file = region:GetTexture()
            if file then
                table.insert(textureInfo, "|cff00ff00Texture:|r " .. tostring(file))
            end
        end
    end

    if #textureInfo > 0 then
        return table.concat(textureInfo, "\n")
    end
    return nil
end

-- Get anchor information for a frame
local function GetAnchorInfo(frame)
    if not frame.GetNumPoints then
        return ""
    end

    local anchorInfo = {}
    for i = 1, frame:GetNumPoints() do
        local point, relativeTo, relativePoint, xOffset, yOffset = frame:GetPoint(i)
        local relativeToName = relativeTo and (relativeTo:GetName() or relativeTo:GetDebugName() or "Unknown") or "nil"
        local anchorText =
            string.format(
            "%s -> %s (%s) [%.1f, %.1f]",
            point,
            relativeToName,
            relativePoint or "",
            xOffset or 0,
            yOffset or 0
        )
        table.insert(anchorInfo, "|cffcccccc" .. anchorText .. "|r")
    end

    return #anchorInfo > 0 and table.concat(anchorInfo, "\n") or ""
end

-- Get detailed frame information
local function GetFrameInfo(frame)
    local info = {}
    local success, result

    -- Basic properties
    success, result =
        pcall(
        function()
            return frame:GetObjectType()
        end
    )

    if success then
        info.type = result
    end

    success, result =
        pcall(
        function()
            return frame:GetName() or frame:GetDebugName() or ("Anonymous#" .. tostring(frame):match("(%x+)"))
        end
    )
    if success then
        info.name = result
    end

    success, result =
        pcall(
        function()
            return math.floor(frame:GetWidth() or 0)
        end
    )
    if success then
        info.width = result
    end

    success, result =
        pcall(
        function()
            return math.floor(frame:GetHeight() or 0)
        end
    )
    if success then
        info.height = result
    end

    -- Advanced properties
    success, result =
        pcall(
        function()
            return frame:GetFrameLevel()
        end
    )
    if success then
        info.level = result
    end

    success, result =
        pcall(
        function()
            return frame:GetFrameStrata()
        end
    )
    if success then
        info.strata = result
    end

    success, result =
        pcall(
        function()
            return frame:GetAlpha()
        end
    )
    if success then
        info.alpha = result
    end

    success, result =
        pcall(
        function()
            return frame:GetEffectiveScale()
        end
    )
    if success then
        info.scale = result
    end

    -- State information
    success, result =
        pcall(
        function()
            if frame.IsVisible then
                return frame:IsVisible()
            elseif frame.IsShown then
                return frame:IsShown()
            else
                return nil
            end
        end
    )
    if success and result ~= nil then
        info.visible = result
    end

    success, result =
        pcall(
        function()
            return frame:IsMouseEnabled()
        end
    )
    if success then
        info.mouseEnabled = result
    end

    success, result =
        pcall(
        function()
            return frame:IsEnabled()
        end
    )
    if success then
        info.enabled = result
    end

    -- Count children and regions
    success, result =
        pcall(
        function()
            local children = frame.GetChildren and {frame:GetChildren()} or {}
            return #children
        end
    )
    if success then
        info.childCount = result
    end

    success, result =
        pcall(
        function()
            local regions = frame.GetRegions and {frame:GetRegions()} or {}
            return #regions
        end
    )
    if success then
        info.regionCount = result
    end

    return info
end

-- Format frame stack layers with enhanced information
local function GetFormattedFrameLayers(frames)
    local layerInfo = {}

    for i = 1, math.min(#frames, maxLayers) do
        local frame = frames[i]
        if CanAccessObject(frame) then
            local info = GetFrameInfo(frame)
            local layerText = string.format("[%d] %s: %s", i, info.type or "Unknown", info.name or "Anonymous")

            -- Add level and strata for top layers
            if i <= 3 and info.level and info.strata then
                layerText = layerText .. string.format(" (L:%s S:%s)", info.level, info.strata)
            end

            -- Color code based on layer depth
            local colorCodes = {"|cffff0000", "|cffff8000", "|cffffff00", "|cff00ff00", "|cff0080ff"}
            local colorCode = colorCodes[i] or "|cffcccccc"

            table.insert(layerInfo, colorCode .. layerText .. "|r")
        end
    end

    if #frames > maxLayers then
        table.insert(layerInfo, "|cff808080... and " .. (#frames - maxLayers) .. " more layers|r")
    end

    return layerInfo
end

-- Add frame interaction detection
local function GetFrameInteractionInfo(frame)
    local interactions = {}
    local success, result

    -- Check for scripts
    success, result =
        pcall(
        function()
            local scripts = {}
            local commonScripts = {"OnClick", "OnEnter", "OnLeave", "OnShow", "OnHide", "OnUpdate"}
            for _, scriptType in ipairs(commonScripts) do
                if frame:GetScript(scriptType) then
                    table.insert(scripts, scriptType)
                end
            end
            return scripts
        end
    )
    if success and #result > 0 then
        interactions.scripts = result
    end

    -- Check mouse interaction
    success, result =
        pcall(
        function()
            return frame:IsMouseEnabled()
        end
    )
    if success and result then
        table.insert(interactions, "Mouse")
    end

    -- Check keyboard interaction
    success, result =
        pcall(
        function()
            return frame:IsKeyboardEnabled()
        end
    )
    if success and result then
        table.insert(interactions, "Keyboard")
    end

    return interactions
end

-- Advanced inspection function for integration with Blizzard's Table Inspector
local function HandleAdvancedInspection()
    if not isActive then
        return
    end

    local frames = GetMouseFoci and GetMouseFoci() or {}
    if frames and #frames > 0 and frames[1] ~= WorldFrame then
        local topFrame = frames[1]

        -- Use Blizzard's table inspector if available
        if TableAttributeDisplay then
            TableAttributeDisplay:InspectTable(topFrame)
            TableAttributeDisplay:Show()
        elseif DisplayTableInspectorWindow then
            DisplayTableInspectorWindow(topFrame)
        else
            print("|cffff8000Advanced inspection not available. Blizzard Debug Tools not loaded.|r")
        end
    end
end

-- Keybinding support for advanced features
local function OnKeyDown(self, key)
    if not isActive then
        return
    end

    -- Ctrl+` for advanced inspection
    if IsControlKeyDown() and key == "`" then
        HandleAdvancedInspection()
    end
end

-- Set up keybinding support
local function SetupKeybindings()
    if not FrameInspector.keyFrame then
        FrameInspector.keyFrame = CreateFrame("Frame")
        FrameInspector.keyFrame:SetPropagateKeyboardInput(true)
        FrameInspector.keyFrame:SetScript("OnKeyDown", OnKeyDown)
    end

    if isActive then
        FrameInspector.keyFrame:EnableKeyboard(true)
    else
        FrameInspector.keyFrame:EnableKeyboard(false)
    end
end

-- Create the overlay frames that highlight multiple layers
local function CreateOverlays()
    if #overlayFrames > 0 then
        return
    end

    -- Colors for different layers (RGBA with transparency for better visibility)
    local layerColors = {
        {1, 0, 0, 0.4}, -- Red for top layer
        {1, 0.5, 0, 0.4}, -- Orange for 2nd layer
        {1, 1, 0, 0.4}, -- Yellow for 3rd layer
        {0, 1, 0, 0.4}, -- Green for 4th layer
        {0, 0, 1, 0.4} -- Blue for 5th layer
    }

    for i = 1, maxLayers do
        local overlay = CreateFrame("Frame", "FrameInspectorOverlay" .. i, UIParent)
        overlay:SetFrameStrata("TOOLTIP")
        overlay:SetFrameLevel(9999 - i) -- Higher layers get higher frame levels
        overlay:Hide()

        -- Add main highlight
        overlay.highlight = overlay:CreateTexture(nil, "ARTWORK")
        overlay.highlight:SetAllPoints()
        overlay.highlight:SetColorTexture(unpack(layerColors[i]))

        -- Create border lines for this layer
        overlay.topBorder = overlay:CreateTexture(nil, "OVERLAY")
        overlay.topBorder:SetHeight(2)
        overlay.topBorder:SetPoint("TOPLEFT")
        overlay.topBorder:SetPoint("TOPRIGHT")
        overlay.topBorder:SetColorTexture(layerColors[i][1], layerColors[i][2], layerColors[i][3], 1) -- Full opacity for borders

        overlay.bottomBorder = overlay:CreateTexture(nil, "OVERLAY")
        overlay.bottomBorder:SetHeight(2)
        overlay.bottomBorder:SetPoint("BOTTOMLEFT")
        overlay.bottomBorder:SetPoint("BOTTOMRIGHT")
        overlay.bottomBorder:SetColorTexture(layerColors[i][1], layerColors[i][2], layerColors[i][3], 1)

        overlay.leftBorder = overlay:CreateTexture(nil, "OVERLAY")
        overlay.leftBorder:SetWidth(2)
        overlay.leftBorder:SetPoint("TOPLEFT")
        overlay.leftBorder:SetPoint("BOTTOMLEFT")
        overlay.leftBorder:SetColorTexture(layerColors[i][1], layerColors[i][2], layerColors[i][3], 1)

        overlay.rightBorder = overlay:CreateTexture(nil, "OVERLAY")
        overlay.rightBorder:SetWidth(2)
        overlay.rightBorder:SetPoint("TOPRIGHT")
        overlay.rightBorder:SetPoint("BOTTOMRIGHT")
        overlay.rightBorder:SetColorTexture(layerColors[i][1], layerColors[i][2], layerColors[i][3], 1)
        -- Add anchor points container
        overlay.anchorPoints = {}
        overlayFrames[i] = overlay
    end
end

-- Function to highlight anchor points like Blizzard does
local function HighlightAnchors(overlay, frame)
    -- Clear existing anchor points
    for _, point in ipairs(overlay.anchorPoints) do
        point:Hide()
    end

    if frame.GetNumPoints then
        for i = 1, frame:GetNumPoints() do
            local point, relativeTo, relativePoint = frame:GetPoint(i)
            if relativeTo then
                if not overlay.anchorPoints[i] then
                    overlay.anchorPoints[i] = overlay:CreateTexture(nil, "OVERLAY")
                    overlay.anchorPoints[i]:SetSize(4, 4)
                    overlay.anchorPoints[i]:SetColorTexture(1, 0, 0, 0.8)
                end

                overlay.anchorPoints[i]:ClearAllPoints()
                overlay.anchorPoints[i]:SetPoint("CENTER", relativeTo, relativePoint or "CENTER")
                overlay.anchorPoints[i]:Show()
            end
        end
    end
end

-- Create custom tooltip
local function CreateTooltip()
    if tooltip then
        return
    end

    tooltip = CreateFrame("Frame", "FrameInspectorTooltip", UIParent)
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetFrameLevel(10000)
    tooltip:SetSize(300, 200) -- Increased size for more information
    tooltip:Hide()

    -- Background
    tooltip.bg = tooltip:CreateTexture(nil, "BACKGROUND")
    tooltip.bg:SetAllPoints()
    tooltip.bg:SetColorTexture(0, 0, 0, 0.9) -- Slightly more opaque

    -- Border
    tooltip.border = tooltip:CreateTexture(nil, "BORDER")
    tooltip.border:SetAllPoints()
    tooltip.border:SetColorTexture(1, 1, 1, 0.3)

    -- Text
    tooltip.text = tooltip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tooltip.text:SetPoint("TOPLEFT", 10, -10)
    tooltip.text:SetPoint("BOTTOMRIGHT", -10, 10)
    tooltip.text:SetJustifyH("LEFT")
    tooltip.text:SetJustifyV("TOP")
    tooltip.text:SetTextColor(1, 1, 1)
    tooltip.text:SetSpacing(2) -- Add line spacing for better readability
end

-- Enhanced frame stack with detailed information
local function GetFrameStack(frame)
    local stack = {}
    local current = frame
    local depth = 0
    local maxDepth = stackDisplayConfig.maxDepth -- Use configuration for max depth

    while current and depth < maxDepth do
        local frameName = "Unknown"
        local frameType = "Unknown"
        local frameLevel = "?"
        local frameStrata = "?"
        local frameAlpha = "?"
        local frameScale = "?"
        local frameVisible = "?"
        local indent = string.rep(" ", stackDisplayConfig.indentSize * depth) -- Use configuration for indentation

        -- Safe property retrieval with error handling
        local success, result

        -- Name
        success, result =
            pcall(
            function()
                return current:GetName() or (current.GetDebugName and current:GetDebugName()) or
                    ("Anonymous#" .. tostring(current):match("(%x+)"))
            end
        )
        if success then
            frameName = result
        end

        -- Type
        success, result =
            pcall(
            function()
                return current:GetObjectType()
            end
        )
        if success then
            frameType = result
        end

        -- Frame level
        success, result =
            pcall(
            function()
                return current:GetFrameLevel()
            end
        )
        if success then
            frameLevel = tostring(result)
        end

        -- Frame strata
        success, result =
            pcall(
            function()
                return current:GetFrameStrata()
            end
        )
        if success then
            frameStrata = result
        end

        -- Alpha
        success, result =
            pcall(
            function()
                return string.format("%.2f", current:GetAlpha())
            end
        )
        if success then
            frameAlpha = result
        end

        -- Scale
        success, result =
            pcall(
            function()
                return string.format("%.2f", current:GetEffectiveScale())
            end
        )
        if success then
            frameScale = result
        end

        -- Visibility
        success, result =
            pcall(
            function()
                if current.IsVisible then
                    return current:IsVisible() and "visible" or "hidden"
                elseif current.IsShown then
                    return current:IsShown() and "shown" or "hidden"
                else
                    return "unknown"
                end
            end
        )
        if success then
            frameVisible = result
        end

        -- Build formatted line with color coding
        local depthIndicator = depth == 0 and "[0]" or string.format("[%d]", depth)
        local colorCode =
            stackDisplayConfig.colorCoding and
            (depth == 0 and "|cffff0000" or (depth == 1 and "|cffff8000" or "|cffcccccc")) or
            ""

        local frameLine = string.format("%s%s %s%s: %s|r", indent, depthIndicator, colorCode, frameType, frameName)

        -- Add detailed info for top few frames if enabled in configuration
        if stackDisplayConfig.showDetailedInfo and depth < 3 then
            frameLine =
                frameLine ..
                string.format(
                    "\n%s    |cff808080Level:%s Strata:%s Alpha:%s Scale:%s State:%s|r",
                    indent,
                    frameLevel,
                    frameStrata,
                    frameAlpha,
                    frameScale,
                    frameVisible
                )
        end

        table.insert(stack, frameLine)

        -- Check for parent
        success, result =
            pcall(
            function()
                return current:GetParent()
            end
        )
        if success and result then
            current = result
        else
            break
        end

        depth = depth + 1
    end

    -- Add truncation notice if we hit the limit
    if depth >= maxDepth then
        table.insert(stack, "|cff808080... (stack truncated at " .. maxDepth .. " levels)|r")
    end

    return table.concat(stack, "\n")
end

-- Update overlay position and tooltip
local function UpdateInspector()
    if not isActive then
        return
    end
    local frames = GetMouseFoci and GetMouseFoci() or {}

    -- Filter frames for security - only show accessible frames
    local accessibleFrames = {}
    for _, frame in ipairs(frames) do
        if CanAccessObject(frame) then
            table.insert(accessibleFrames, frame)
        end
    end
    frames = accessibleFrames

    if not frames or #frames == 0 or frames[1] == WorldFrame then
        -- Hide all overlays
        for i = 1, #overlayFrames do
            overlayFrames[i]:Hide()
        end
        if tooltip then
            tooltip:Hide()
        end
        return
    end

    -- Hide all overlays first
    local overlaysHidden = 0
    for i = 1, #overlayFrames do
        if overlayFrames[i]:IsShown() then
            overlaysHidden = overlaysHidden + 1
        end
        overlayFrames[i]:Hide()
    end

    -- Show overlays for up to maxLayers frames
    local layersToShow = math.min(#frames, maxLayers)

    for i = 1, layersToShow do
        local frame = frames[i]
        local overlay = overlayFrames[i]

        if frame and overlay then
            overlay:ClearAllPoints()
            overlay:SetAllPoints(frame)

            -- Highlight anchor points for the top frame
            if i == 1 then
                HighlightAnchors(overlay, frame)
            end
            overlay:Show()
        end
    end

    -- Get information for the top frame (for tooltip)
    local topFrame = frames[1]
    local frameInfo = GetFrameInfo(topFrame)
    local frameStack = GetFrameStack(topFrame)
    local formattedLayers = GetFormattedFrameLayers(frames)

    -- Update tooltip
    CreateTooltip() -- Ensure tooltip exists
    if not tooltip then
        return
    end

    tooltip:ClearAllPoints()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    tooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (x / scale) + 15, (y / scale) + 15)

    -- Enhanced tooltip text with more detailed information
    local tooltipText = "|cffffff00Frame Inspector v0.2|r\n\n"
    tooltipText = tooltipText .. "|cffff8000Layers Found: " .. #frames .. "|r\n\n"
    tooltipText = tooltipText .. "|cffff0000[TOP LAYER]|r\n"
    tooltipText = tooltipText .. "|cff00ff00Name:|r " .. (frameInfo.name or "Unknown") .. "\n"
    tooltipText = tooltipText .. "|cff00ff00Type:|r " .. (frameInfo.type or "Unknown") .. "\n"
    tooltipText =
        tooltipText .. "|cff00ff00Size:|r " .. (frameInfo.width or 0) .. " x " .. (frameInfo.height or 0) .. "\n"

    -- Add enhanced frame properties
    if frameInfo.level then
        tooltipText = tooltipText .. "|cff00ff00Level:|r " .. frameInfo.level .. "\n"
    end
    if frameInfo.strata then
        tooltipText = tooltipText .. "|cff00ff00Strata:|r " .. frameInfo.strata .. "\n"
    end
    if frameInfo.alpha then
        tooltipText = tooltipText .. "|cff00ff00Alpha:|r " .. string.format("%.2f", frameInfo.alpha) .. "\n"
    end
    if frameInfo.scale then
        tooltipText = tooltipText .. "|cff00ff00Scale:|r " .. string.format("%.2f", frameInfo.scale) .. "\n"
    end

    -- State information
    local stateInfo = {}
    if frameInfo.visible ~= nil then
        table.insert(stateInfo, frameInfo.visible and "|cff00ff00Visible|r" or "|cffff0000Hidden|r")
    end
    if frameInfo.mouseEnabled ~= nil then
        table.insert(stateInfo, frameInfo.mouseEnabled and "|cff00ff00Mouse|r" or "|cff808080NoMouse|r")
    end
    if frameInfo.enabled ~= nil then
        table.insert(stateInfo, frameInfo.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r")
    end
    if #stateInfo > 0 then
        tooltipText = tooltipText .. "|cff00ff00State:|r " .. table.concat(stateInfo, " ") .. "\n"
    end

    -- Children and regions count
    if frameInfo.childCount and frameInfo.childCount > 0 then
        tooltipText = tooltipText .. "|cff00ff00Children:|r " .. frameInfo.childCount .. "\n"
    end
    if frameInfo.regionCount and frameInfo.regionCount > 0 then
        tooltipText = tooltipText .. "|cff00ff00Regions:|r " .. frameInfo.regionCount .. "\n"
    end

    tooltipText = tooltipText .. "\n"

    -- Add texture information
    if topFrame then
        local textureInfo = GetTextureInfoForFrame(topFrame)
        if textureInfo then
            tooltipText = tooltipText .. "|cff80ff80Textures:|r\n" .. textureInfo .. "\n\n"
        end
    end

    -- Add anchor information
    local anchorInfo = GetAnchorInfo(topFrame)
    if anchorInfo ~= "" then
        tooltipText = tooltipText .. "|cff80ff80Anchors:|r\n" .. anchorInfo .. "\n\n"
    end

    -- Add information about other visible layers
    if #formattedLayers > 0 then
        tooltipText = tooltipText .. "|cff80ff80Other Layers:|r\n"
        tooltipText = tooltipText .. table.concat(formattedLayers, "\n") .. "\n\n"
    end

    tooltipText = tooltipText .. "|cff80ff80Frame Hierarchy:|r\n"

    -- Add frame stack with our enhanced formatting
    local stackLines = {strsplit("\n", frameStack)}
    for _, line in ipairs(stackLines) do
        tooltipText = tooltipText .. line .. "\n"
    end
    if tooltip and tooltip.text then
        tooltip.text:SetText(tooltipText)
        tooltip:Show()
    end
end

-- Activate inspector
local function ActivateInspector()
    isActive = true
    CreateOverlays()
    CreateTooltip()
    SetupKeybindings()

    -- Start update timer
    FrameInspector:SetScript("OnUpdate", UpdateInspector)
    print("|cff00ff00FrameInspector activated!|r Hover over frames to inspect them.")
    print("|cffccccccCommands: |cffffffff Ctrl+` |r for advanced inspection.")
end

-- Deactivate inspector
local function DeactivateInspector()
    isActive = false
    SetupKeybindings() -- This will disable keyboard input

    -- Stop update timer
    FrameInspector:SetScript("OnUpdate", nil)

    -- Hide all overlays
    for i = 1, #overlayFrames do
        overlayFrames[i]:Hide()
    end
    if tooltip then
        tooltip:Hide()
    end

    print("|cffff0000FrameInspector deactivated!|r")
end

-- Toggle inspector
local function ToggleInspector()
    if isActive then
        DeactivateInspector()
    else
        ActivateInspector()
    end
end

-- Chat command handler
local function HandleChatCommand(msg)
    ToggleInspector()
end

-- Register chat commands
SLASH_FRAMEINSPECTOR1 = "/frameinspector"
SLASH_FRAMEINSPECTOR2 = "/finspect"
SLASH_FRAMEINSPECTOR3 = "/fi"
SlashCmdList["FRAMEINSPECTOR"] = HandleChatCommand

-- Event handling
FrameInspector:RegisterEvent("ADDON_LOADED")
FrameInspector:SetScript(
    "OnEvent",
    function(self, event, addonName)
        if event == "ADDON_LOADED" and addonName == "FrameInspector" then
            print("|cff00ff00FrameInspector loaded!|r Use |cffffffff/fi|r to toggle.")
        end
    end
)
