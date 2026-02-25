local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RaceManager = {}
RaceManager.State = "Waiting"

local COUNTDOWN_TIME = 3
local LAPS = 3

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CheckpointService = require(Shared:WaitForChild("CheckpointService"))
local KartConfig = require(Shared:WaitForChild("KartConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local checkpoints = nil
local checkpointService = nil
local playerBoosts = {}

local function fireRemote(remoteEvent, ...)
    if remoteEvent then
        remoteEvent:FireAllClients(...)
    end
end

function RaceManager.StartRace(mapName, racers)
    -- 1. GUARD CLAUSE: Prevents the "nil" crash if the queue is empty
    if not racers or type(racers) ~= "table" then
        warn("RaceManager Error: No racers table provided!")
        return
    end

    RaceManager.State = "Countdown"
    
    -- 2. LOAD MAP
    local MapLoader = require(script.Parent.MapLoader)
    local mapModel = MapLoader.Load(mapName)
    if not mapModel then 
        RaceManager.State = "Waiting"
        return 
    end
    
    -- NEW: Force the script to pause and let the map physically load 
    -- before doing anything else!
    print("Map spawned! Waiting 2 seconds for physics to settle...")
    task.wait(2)

    -- 3. GET CHECKPOINTS
    checkpoints = {}
    for _, obj in ipairs(mapModel:GetDescendants()) do
        if string.find(obj.Name, "Checkpoint") and obj:IsA("BasePart") then
            table.insert(checkpoints, obj)
        end
    end
    table.sort(checkpoints, function(a, b) return a.Name < b.Name end)
    
    -- 4. INITIALIZE LAP SERVICE
    checkpointService = CheckpointService.new(checkpoints, LAPS)

    -- 5. SPAWN KARTS
    for index, player in ipairs(racers) do
        local character = player.Character or player.CharacterAdded:Wait() 
        checkpointService:InitPlayer(player)
        
        local KartSpawner = require(script.Parent.KartSpawner)
        
        -- FIX: Added 'true' so it searches deep inside the map's folders
        local spawnPart = mapModel:FindFirstChild("Spawn" .. index, true) 
        
        if not spawnPart then
            warn("Could not find Spawn" .. index .. " in the map! Using fallback.")
        end
        
        local gridPosition = spawnPart and spawnPart.CFrame or checkpoints[1].CFrame * CFrame.new(index * 8, 5, -30)
        
        local newKart = KartSpawner.setupKartForPlayer(player, gridPosition)
    end

    -- 6. COUNTDOWN
    for i = 3, 1, -1 do
        fireRemote(Remotes.RaceCountdown, i)
        task.wait(1)
    end
    fireRemote(Remotes.RaceGo)
    
    RaceManager.State = "Racing"
    local finishedCount = 0

    -- 7. LAP TRACKING LOGIC
    for _, checkpoint in ipairs(checkpoints) do
        checkpoint.Touched:Connect(function(hit)
            local character = hit.Parent
            local player = game.Players:GetPlayerFromCharacter(character)
            
            if player and table.find(racers, player) then
                local result = checkpointService:ProcessTouch(player, checkpoint)
                
                -- NEW: Tell the player their current lap progress
                if result == "Lap" or result == "Checkpoint" then
                    local data = checkpointService.playerData[player]
                    local currentLap = (data.laps or 0) + 1
                    Remotes.UpdateLap:FireClient(player, currentLap, LAPS)
                elseif result == "Finished" then
                    finishedCount += 1
                    Remotes.UpdateLap:FireClient(player, LAPS, LAPS) -- Show 3/3
                    
                    if finishedCount >= #racers then
                        task.wait(2)
                        RaceManager.EndRace(racers)
                    end
                end
            end
        end)
    end
end -- THIS IS LINE 73: It must close the StartRace function!

function RaceManager.EndRace(racers)
    print("Race Over! Teleporting back to lobby...")
    
    for _, player in ipairs(racers) do
        local character = player.Character
        local kart = workspace:FindFirstChild(player.Name .. "_Kart")
        
        -- 1. Safely eject the player BEFORE teleporting
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.Sit = false -- Force them to stand up
            end
        end
        
        task.wait(0.1) -- Give the server a split second to process the stand-up
        
        -- 2. Teleport back to lobby
        local lobbySpawn = workspace:FindFirstChild("LobbySpawn")
        if character and character.PrimaryPart and lobbySpawn then
            character:SetPrimaryPartCFrame(lobbySpawn.CFrame + Vector3.new(0, 3, 0))
        else
            warn("Could not find a part named 'LobbySpawn' in the Workspace!")
        end
        
        -- 3. Now it is safe to destroy the kart
        if kart then kart:Destroy() end
    end
    
    RaceManager.State = "Waiting"
end

return RaceManager