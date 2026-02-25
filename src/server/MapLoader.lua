-- src/server/MapLoader.lua
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- FIX: Reference 'Shared' folder instead of 'Common'
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapData = require(Shared:WaitForChild("MapData"))

local MapLoader = {}
local currentMapInstance = nil

function MapLoader.Load(mapId)
    if currentMapInstance then currentMapInstance:Destroy() end
    
    local mapsFolder = ServerStorage:FindFirstChild("Maps")
    local mapTemplate = mapsFolder and mapsFolder:FindFirstChild(mapId)
    
    if mapTemplate then
        currentMapInstance = mapTemplate:Clone()
        currentMapInstance.Parent = workspace
        currentMapInstance.Name = "ActiveMap"
        return currentMapInstance
    else
        warn("Map " .. mapId .. " not found in ServerStorage.Maps")
    end
end

return MapLoader