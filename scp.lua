--[[
    Script: L4 Keycard Automated Acquisition
    Architect: Callum
    Description: Locates the L4 Giver and fires the ClickDetector regardless of depth.
--]]

local Workspace = game:GetService("Workspace")

local function acquireL4Card()
    -- Define the target name
    local targetName = "L4 Keycard Giver"
    local targetObject = nil

    -- 1. High-speed lookup for the giver
    targetObject = Workspace:FindFirstChild(targetName, true) -- 'true' enables recursive search

    if targetObject then
        -- 2. Locate the ClickDetector within the giver
        local detector = targetObject:FindFirstChildOfClass("ClickDetector")
        
        if detector then
            -- 3. Execute the interaction
            -- fireclickdetector is the standard for modern execution environments
            fireclickdetector(detector)
            print("[Architect]: L4 Keycard acquired successfully.")
        else
            warn("[Architect]: Found '" .. targetName .. "' but it has no ClickDetector.")
        end
    else
        -- Fallback: Listing possible matches if the exact name differs slightly
        warn("[Architect]: '" .. targetName .. "' not found. Searching for similar names...")
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name:find("L4") and obj:FindFirstChildOfClass("ClickDetector") then
                fireclickdetector(obj:FindFirstChildOfClass("ClickDetector"))
                print("[Architect]: Found alternative L4 source: " .. obj:GetFullName())
                return
            end
        end
        warn("[Architect]: No L4 Keycard source could be identified.")
    end
end

-- Run the acquisition
acquireL4Card()
