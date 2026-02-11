--[[
    ObjectFinder
    Utility for finding objects in the workspace
]]

local ObjectFinder = {}

-- Search for an object by name in common container locations
function ObjectFinder.FindInWorld(name, searchContainers)
    searchContainers = searchContainers or {"World", "Assets", "Objects", "Structures"}

    local workspace = game:GetService("Workspace")

    for _, containerName in ipairs(searchContainers) do
        local container = workspace:FindFirstChild(containerName)
        if container then
            local found = container:FindFirstChild(name, true)
            if found then
                return found
            end
        end
    end

    -- Fallback: search workspace directly
    return workspace:FindFirstChild(name, true)
end

return ObjectFinder
