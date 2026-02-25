-- src/server/QueueSystem.lua
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

-- We require the RaceManager so we can check its state and start the race
local RaceManager = require(ServerScriptService.Server.RaceManager)

local queuePad = Workspace:WaitForChild("QueuePad")
local billboard = queuePad:WaitForChild("BillboardGui")
local timerDisplay = billboard:WaitForChild("TextLabel")

local COUNTDOWN_START = 15
local MIN_PLAYERS = 1 -- Set to 2 if you want to force multiplayer!

-- Create the BillboardGui via code
local billboard = Instance.new("BillboardGui")
billboard.Name = "QueueUI"
billboard.Adornee = queuePad
billboard.Size = UDim2.new(0, 200, 0, 50)
billboard.StudsOffset = Vector3.new(0, 5, 0) -- Floats 5 studs above the pad
billboard.AlwaysOnTop = true
billboard.Parent = queuePad

-- Create the TextLabel via code
local timerDisplay = Instance.new("TextLabel")
timerDisplay.Name = "StatusLabel"
timerDisplay.Size = UDim2.new(1, 0, 1, 0)
timerDisplay.BackgroundTransparency = 1
timerDisplay.TextColor3 = Color3.new(1, 1, 1) -- White
timerDisplay.TextStrokeTransparency = 0 -- Easy to read
timerDisplay.TextScaled = true
timerDisplay.Font = Enum.Font.GothamBold
timerDisplay.Text = "Step here to race!"
timerDisplay.Parent = billboard

-- A helper function to see who is physically touching the pad
local function getPlayersInZone()
    local players = {}
    
    -- We define a box based on the pad's position but make it taller (20 studs)
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Blacklist
    overlapParams.FilterDescendantsInstances = {queuePad}

    local partsInZone = Workspace:GetPartBoundsInBox(
        queuePad.CFrame * CFrame.new(0, 10, 0), -- Center of the box (10 studs up)
        Vector3.new(queuePad.Size.X, 20, queuePad.Size.Z), -- Size of the box
        overlapParams
    )
    
    for _, part in ipairs(partsInZone) do
        local character = part.Parent
        if character and character:FindFirstChild("Humanoid") then
            local player = Players:GetPlayerFromCharacter(character)
            if player and not table.find(players, player) then
                table.insert(players, player)
            end
        end
    end
    return players
end

local function queueLoop()
    local emptyTime = 0 -- Track how long the pad has been empty
    
    while task.wait(1) do
        local playersInZone = getPlayersInZone()
        
        if #playersInZone >= MIN_PLAYERS and RaceManager.State == "Waiting" then
            emptyTime = 0 -- Reset empty timer because someone is here
            local timer = COUNTDOWN_START
            
            while timer > 0 do
                timerDisplay.Text = "Starting in: " .. timer .. "s\n(" .. #playersInZone .. " Players)"
                task.wait(1)
                
                playersInZone = getPlayersInZone()
                
                if #playersInZone < MIN_PLAYERS then
                    emptyTime += 1
                    -- Only cancel if the pad has been empty for more than 2 seconds
                    if emptyTime > 2 then
                        timerDisplay.Text = "Waiting for players..."
                        break 
                    end
                else
                    emptyTime = 0
                    timer -= 1 -- Only count down if someone is actually there
                end
            end
            if timer <= 0 then
                -- Grab the players one last time right before the call
                local finalRacers = getPlayersInZone() 
                
                if #finalRacers > 0 then
                    timerDisplay.Text = "Race in Progress!"
                    -- Log it to the output so we can see if it's working
                    print("Starting race for: " .. #finalRacers .. " players") 
                    RaceManager.StartRace("Pocono", finalRacers) 
                else
                    timerDisplay.Text = "No players found! Resetting..."
                    task.wait(2)
                end
            end
        else
            -- Standard idle display
            timerDisplay.Text = (RaceManager.State == "Waiting") and "Step here to race!\n(0 Players)" or "Race in Progress..."
        end
    end
end

-- Start the endless monitoring loop
task.spawn(queueLoop)