local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local KartSpawner = {} -- THIS FIXES THE CRASH: We actually create the table!

local KART_MODEL_NAME = "KartTemplate"

function KartSpawner.setupKartForPlayer(player, spawnCFrame)
    local template = ServerStorage:FindFirstChild(KART_MODEL_NAME)
    if not template then
        warn("Kart template not found in ServerStorage!")
        return
    end
    
    local kart = template:Clone()
    kart.Name = player.Name .. "_Kart"
    kart.PrimaryPart = kart.PrimaryPart or kart:FindFirstChildWhichIsA("BasePart")
    
    -- Spawn exactly where the RaceManager tells us to (the starting line)
    -- Spawn exactly where the RaceManager tells us to
    local finalCFrame = spawnCFrame or CFrame.new(0, 10, 0)
    kart:SetPrimaryPartCFrame(finalCFrame)
    kart.Parent = Workspace
    
    -- Put the player in the driver's seat
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    
    -- FIX: Search all descendants for ANY VehicleSeat 
    local driveSeat = kart:FindFirstChild("DriveSeat", true) or kart:FindFirstChildWhichIsA("VehicleSeat", true)
    
    if driveSeat then
        task.wait(0.1)
        driveSeat:Sit(humanoid)
        print("Successfully seated " .. player.Name .. " in the kart!")
    else
        warn("CRITICAL ERROR: No VehicleSeat found inside the KartTemplate! Cannot teleport player.")
    end
    
    return kart
end

return KartSpawner