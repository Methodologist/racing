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
    
    -- Spawn exactly where the RaceManager tells us to
    local finalCFrame = spawnCFrame or CFrame.new(0, 10, 0)
    kart:SetPrimaryPartCFrame(finalCFrame)
    kart.Parent = Workspace

    -- ⚖️ UPDATED MASSLESS KART FIX (Prevents Physics Clamping & Anchoring)
    for _, part in ipairs(kart:GetDescendants()) do
        if part:IsA("BasePart") then
            -- 🟢 FIX: Unanchor everything so physics can take over
            part.Anchored = false 
            
            if part ~= kart.PrimaryPart then
                part.Massless = true
                if part.Name ~= "Wheel" then
                    part.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 0, 0, 0)
                end
            end
        end
    end
    
    -- NETWORK OWNERSHIP
    if kart.PrimaryPart and kart.PrimaryPart:CanSetNetworkOwnership() then
        kart.PrimaryPart:SetNetworkOwner(player)
    end
    
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    
    -- MASSLESS CHARACTER
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Massless = true
        end
    end
    
    local driveSeat = kart:FindFirstChild("DriveSeat", true) or kart:FindFirstChildWhichIsA("VehicleSeat", true)
    
    if driveSeat then
        task.wait(0.1)
        driveSeat:Sit(humanoid)
        
        -- Lock the player in the kart
        humanoid.UseJumpPower = true
        humanoid.JumpPower = 0
    else
        warn("CRITICAL ERROR: No VehicleSeat found!")
    end
    
    return kart
end

return KartSpawner