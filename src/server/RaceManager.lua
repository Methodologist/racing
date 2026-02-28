local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RaceManager = {}
RaceManager.State = "Waiting"

local COUNTDOWN_TIME = 3
local LAPS = 3
local MIN_PLAYERS = 1
local TARGET_GRID_SIZE = 4

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CheckpointService = require(Shared:WaitForChild("CheckpointService"))
local KartConfig = require(Shared:WaitForChild("KartConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local BotController = require(Shared:WaitForChild("BotController"))

local checkpoints = nil
local checkpointService = nil
local playerBoosts = {}
local winnersList = {}
local activeBots = {} 

local function fireRemote(remoteEvent, ...)
    if remoteEvent then
        remoteEvent:FireAllClients(...)
    end
end

local function attachRaceUI(model, racerName)
    local attachPart = model:FindFirstChild("Head") or model.PrimaryPart
    if not attachPart then return end

    local oldUI = attachPart:FindFirstChild("RaceStatusUI")
    if oldUI then oldUI:Destroy() end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "RaceStatusUI"
    billboard.Adornee = attachPart
    
    -- 📏 Use Scale so it stays proportional to the 3D world
    billboard.Size = UDim2.new(8, 0, 3, 0) 
    billboard.StudsOffset = Vector3.new(0, 5, 0)
    
    -- 🛰️ Corrected Visibility Properties
    billboard.MaxDistance = 10000 -- Infinite-ish range
    billboard.AlwaysOnTop = true  -- See through walls
    billboard.LightInfluence = 0  -- Full brightness
    
    -- 1. Player Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0) 
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = racerName
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextScaled = true 
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextStrokeTransparency = 0 
    nameLabel.Parent = billboard

    -- 2. Place Label
    local placeLabel = Instance.new("TextLabel")
    placeLabel.Name = "PlaceLabel"
    placeLabel.Size = UDim2.new(1, 0, 0.5, 0) 
    placeLabel.Position = UDim2.new(0, 0, 0.5, 0)
    placeLabel.BackgroundTransparency = 1
    placeLabel.Text = "Waiting..."
    placeLabel.TextColor3 = Color3.fromRGB(255, 215, 0) 
    placeLabel.TextScaled = true
    placeLabel.Font = Enum.Font.GothamBlack
    placeLabel.TextStrokeTransparency = 0
    placeLabel.Parent = billboard

    billboard.Parent = attachPart
end

-- 🏁 POLISHED LEADERBOARD GENERATOR (Refactored)
local function createRaceLeaderboard(player)
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- 1. Main Container
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RaceLeaderboardUI"
    screenGui.ResetOnSpawn = false
    
    local container = Instance.new("Frame")
    container.Name = "MainFrame"
    container.Size = UDim2.new(0.15, 0, 0.4, 0) -- Adjusted height (no slider)
    container.Position = UDim2.new(0.84, 0, 0.05, 0) -- Top Right
    container.BackgroundTransparency = 0.4
    container.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    container.BorderSizePixel = 0
    container.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = container

    -- 2. Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.1, 0)
    title.BackgroundTransparency = 1
    title.Text = "TOP RACERS"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBlack
    title.TextScaled = true
    title.Parent = container

    -- 3. The Racer List (Uses full remaining height)
    local list = Instance.new("ScrollingFrame")
    list.Name = "RacerList"
    list.Size = UDim2.new(0.9, 0, 0.85, 0) 
    list.Position = UDim2.new(0.05, 0, 0.12, 0)
    list.BackgroundTransparency = 1
    list.ScrollBarThickness = 0
    list.Parent = container

    local layout = Instance.new("UIListLayout", list)
    layout.Padding = UDim.new(0, 5)

    screenGui.Parent = playerGui
    return screenGui
end

local function spawnItemRack(checkpoint)
    local rackPositions = {-12, 0, 12} 
    
    local masterModel = ReplicatedStorage.PowerUps:FindFirstChild("MysteryBoxModel")
    if not masterModel then
        warn("CRITICAL: 'MysteryBoxModel' not found in ReplicatedStorage.PowerUps! Skipping spawn.")
        return
    end

    for _, offset in ipairs(rackPositions) do
        local boxModel = masterModel:Clone() 
        local isActive = true -- 🟢 FIX 1: A true state variable for the cooldown!
        
        -- Ground snap math
        local horizontalCFrame = checkpoint.CFrame * CFrame.new(offset, 0, 0)
        local rayOrigin = horizontalCFrame.Position + Vector3.new(0, 50, 0)
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {checkpoint} 
        
        local hitResult = workspace:Raycast(rayOrigin, Vector3.new(0, -100, 0), rayParams)
        local spawnCFrame = hitResult and (CFrame.new(hitResult.Position + Vector3.new(0, 4, 0)) * checkpoint.CFrame.Rotation) 
            or (checkpoint.CFrame * CFrame.new(offset, -(checkpoint.Size.Y / 2) + 4, 0))
            
        boxModel:PivotTo(spawnCFrame)
        boxModel.Parent = workspace
        
        local hitbox = boxModel.PrimaryPart or boxModel:FindFirstChildWhichIsA("BasePart")
        if not hitbox then
            boxModel:Destroy()
            continue
        end

        task.spawn(function()
            while boxModel and boxModel.Parent do
                boxModel:PivotTo(boxModel:GetPivot() * CFrame.fromEulerAnglesXYZ(0, 0.05, 0))
                task.wait()
            end
        end)

        -- 🟢 FIX 2: Upgraded Interaction Logic
        hitbox.Touched:Connect(function(hit)
            if not isActive then return end -- Stop immediately if on cooldown
            
            local model = hit:FindFirstAncestorOfClass("Model")
            if not model then return end
            
            local racerEntity = nil

            -- 🔊 DYNAMIC AUDIO GENERATOR
            -- This guarantees the sound plays without needing pre-existing folders
            local pickupSound = Instance.new("Sound")
            pickupSound.SoundId = "rbxassetid://84872960927850" -- An arcade-style chime
            pickupSound.Volume = 1.0
            pickupSound.RollOffMaxDistance = 250 -- So nearby racers hear it too
            pickupSound.Parent = hitbox
            pickupSound:Play()

            -- Clean up the sound object from memory after it finishes
            game.Debris:AddItem(pickupSound, 2)
            
            -- Check if it's an AI Bot
            if table.find(activeBots, model) then
                racerEntity = model
            else
                -- Check if it's a Human's Kart (e.g., "macabrelli_Kart")
                local possiblePlayerName = string.gsub(model.Name, "_Kart", "")
                local player = game.Players:FindFirstChild(possiblePlayerName) 
                
                -- Fallback in case their actual character body hit it
                if not player then
                    player = game.Players:GetPlayerFromCharacter(model)
                end
                
                if player then racerEntity = player end
            end
            
            -- If we successfully identified who hit it:
            if racerEntity then
                isActive = false -- Lock the box so nobody else can grab it
                
                -- Visual Feedback: Hide the box
                for _, part in ipairs(boxModel:GetDescendants()) do
                    if part:IsA("BasePart") then part.Transparency = 1 end
                end
                
                local ItemData = require(ReplicatedStorage.Shared.ItemData)
                local rolledItem = ItemData.getRandomItem()
                print(racerEntity.Name .. " rolled a " .. rolledItem .. "!")
                
                -- Try to play sound
                local sfx = ReplicatedStorage.Sounds:FindFirstChild("ItemPickup")
                if sfx then
                    local clone = sfx:Clone()
                    clone.Parent = hitbox
                    clone:Play()
                    game.Debris:AddItem(clone, 2)
                end
                
                -- 10 Second Respawn Timer
                task.wait(10) 
                if boxModel and boxModel.Parent then
                    for _, part in ipairs(boxModel:GetDescendants()) do
                        if part:IsA("BasePart") and part.Name ~= "Hitbox" then 
                            part.Transparency = 0 
                        end
                    end
                    isActive = true -- Unlock the box!
                end
            end
        end)
    end
end

function RaceManager.StartRace(mapName, racers)
    if not racers or #racers < MIN_PLAYERS then
        warn("RaceManager: Not enough players to start. Need at least " .. MIN_PLAYERS)
        return
    end

    RaceManager.State = "Countdown"
    activeBots = {} 
    
    local mapModel = workspace:FindFirstChild(mapName)
    if not mapModel then 
        warn("CRITICAL: Could not find map '" .. tostring(mapName) .. "' in Workspace!")
        RaceManager.State = "Waiting"
        return 
    end
    
    checkpoints = {}
    for _, obj in ipairs(mapModel:GetDescendants()) do
        if string.find(obj.Name, "Checkpoint") and obj:IsA("BasePart") then
            table.insert(checkpoints, obj)
        end
    end
    -- ... existing checkpoint gathering code ...
    table.sort(checkpoints, function(a, b) return a.Name < b.Name end)

    -- 📦 SPAWN POWERUP BOXES EVERY 100th CHECKPOINT
    for i = 1, #checkpoints do
        if i % 100 == 0 then
            spawnItemRack(checkpoints[i])
        end
    end
    
    checkpointService = CheckpointService.new(checkpoints, LAPS)

    -- 3. SPAWN HUMAN KARTS
    local spawnIndex = 1
    for index, player in ipairs(racers) do
        checkpointService:InitPlayer(player) 
        local character = player.Character or player.CharacterAdded:Wait() 
        
        local KartSpawner = require(script.Parent.KartSpawner)
        local spawnPart = mapModel:FindFirstChild("Spawn" .. index, true) 
        
        local gridPosition = spawnPart and spawnPart.CFrame or checkpoints[1].CFrame * CFrame.new(index * 8, 5, -30)
        
        -- Spawn the Kart first
        local kart = KartSpawner.setupKartForPlayer(player, gridPosition)
        
        -- NOW attach the UI to the Kart instead of the character
        if kart then
            attachRaceUI(kart, player.Name)
        end
        
        spawnIndex += 1
    end

    -- 🤖 3.5 SPAWN AI BOTS TO FILL THE GRID
    if spawnIndex <= TARGET_GRID_SIZE then
        print("Filling empty slots with AI Bots...")
        for i = spawnIndex, TARGET_GRID_SIZE do
            local spawnPart = mapModel:FindFirstChild("Spawn" .. i, true) 
            local gridPosition = spawnPart and spawnPart.CFrame or checkpoints[1].CFrame * CFrame.new(i * 8, 5, -30)
            
            local botKart = ReplicatedStorage:WaitForChild("KartModel"):Clone()
            botKart.Name = "Bot_" .. i .. "_Kart"
            botKart:PivotTo(gridPosition)
            botKart.Parent = workspace
            
            -- 🟢 FIX: Register the bot in the checkpoint service so it can be ranked!
            checkpointService:InitPlayer(botKart)
            attachRaceUI(botKart, "AI Racer " .. (i - spawnIndex + 1))

            table.insert(activeBots, botKart)
        end
    end

    task.wait(1.5)

    for i = COUNTDOWN_TIME, 1, -1 do
        fireRemote(Remotes.RaceCountdown, i)
        task.wait(1)
    end
    fireRemote(Remotes.RaceGo)

    RaceManager.State = "Racing"
    local humanFinishedCount = 0

    for _, botKart in ipairs(activeBots) do
        BotController.StartBot(botKart, checkpoints)
    end

    -- 🏆 MASTER LIVE STANDINGS TRACKER (Final Robust Version)
    task.spawn(function()
        for _, p in ipairs(racers) do
            createRaceLeaderboard(p)
        end

        while RaceManager.State == "Racing" do
            local allCompetitors = {}

            -- 1. Identify everyone by their KART or Character
            for _, p in ipairs(racers) do 
                -- Look for the Kart first, then the character
                local kart = workspace:FindFirstChild(p.Name .. "_Kart")
                table.insert(allCompetitors, {entity = p, name = p.Name, model = kart or p.Character}) 
            end
            for _, b in ipairs(activeBots) do 
                table.insert(allCompetitors, {entity = b, name = b.Name, model = b}) 
            end
            
            -- 2. Sort by Laps, then Checkpoints
            table.sort(allCompetitors, function(a, b)
                local dataA = checkpointService.playerData[a.entity]
                local dataB = checkpointService.playerData[b.entity]
                if not dataA or not dataB then return false end
                if dataA.laps ~= dataB.laps then return dataA.laps > dataB.laps end
                return dataA.nextCheckpoint > dataB.nextCheckpoint
            end)

            -- 3. Update the Top 10 Screen UI
            for _, observer in ipairs(racers) do
                local board = observer.PlayerGui:FindFirstChild("RaceLeaderboardUI")
                if board then
                    local list = board.MainFrame.RacerList
                    for _, child in ipairs(list:GetChildren()) do
                        if child:IsA("Frame") then child:Destroy() end
                    end

                    for rank = 1, math.min(10, #allCompetitors) do
                        local racer = allCompetitors[rank]
                        local entry = Instance.new("Frame")
                        entry.Size = UDim2.new(1, 0, 0, 25)
                        entry.BackgroundColor3 = (rank == 1 and Color3.fromRGB(218, 165, 32)) or Color3.fromRGB(60, 60, 60)
                        entry.BackgroundTransparency = 0.2
                        entry.Parent = list
                        
                        local txt = Instance.new("TextLabel")
                        txt.Size = UDim2.new(0.9, 0, 1, 0)
                        txt.Position = UDim2.new(0.05, 0, 0, 0)
                        txt.BackgroundTransparency = 1
                        txt.Text = rank .. ". " .. racer.name
                        txt.TextColor3 = Color3.fromRGB(255, 255, 255)
                        txt.Font = Enum.Font.GothamMedium
                        txt.TextXAlignment = Enum.TextXAlignment.Left
                        txt.TextScaled = true
                        txt.Parent = entry
                        Instance.new("UICorner", entry).CornerRadius = UDim.new(0, 4)
                    end
                end
            end

            -- 4. Update the 3D Billboard Head Tags
            for rank, racerData in ipairs(allCompetitors) do
                local visualModel = racerData.model
                if visualModel then
                    -- Search deep for the UI to ensure we find the right one
                    local billboard = visualModel:FindFirstChild("RaceStatusUI", true)
                    if billboard then
                        local placeLabel = billboard:FindFirstChild("PlaceLabel")
                        if placeLabel then
                            local suffix = (rank == 1 and "st") or (rank == 2 and "nd") or (rank == 3 and "rd") or "th"
                            placeLabel.Text = rank .. suffix .. " Place"
                            placeLabel.TextColor3 = (rank == 1 and Color3.fromRGB(255, 215, 0)) or Color3.fromRGB(255, 255, 255)
                        end
                    end
                end
            end
            
            task.wait(0.5)
        end
    end)

    task.spawn(function()
        local ignoreList = {workspace:FindFirstChild("GeneratedForest"), workspace:FindFirstChild("GeneratedForest1"), workspace:FindFirstChild("GeneratedForest2"), workspace:FindFirstChild("GeneratedForest3")}

        while RaceManager.State == "Racing" do
            for _, player in ipairs(racers) do
                local kart = workspace:FindFirstChild(player.Name .. "_Kart")
                
                if kart and kart:IsA("Model") and kart.PrimaryPart then
                    local rootPart = kart.PrimaryPart
                    local pos = rootPart.Position
                    local isOutOfBounds = pos.Y < -1000
                    
                    if not isOutOfBounds then
                        local rayParams = RaycastParams.new()
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                        local finalIgnore = {kart}
                        for _, folder in ipairs(ignoreList) do if folder then table.insert(finalIgnore, folder) end end
                        rayParams.FilterDescendantsInstances = finalIgnore
                        
                        local groundRay = workspace:Raycast(pos, Vector3.new(0, -40, 0), rayParams)
                        if groundRay and groundRay.Instance:IsA("Terrain") then
                            isOutOfBounds = true
                        end
                    end

                    if isOutOfBounds then
                        local data = checkpointService.playerData[player]
                        local lastTarget = data.nextCheckpoint - 1
                        if lastTarget < 1 then lastTarget = #checkpoints end
                        
                        local safeDropCFrame = checkpoints[lastTarget].CFrame * CFrame.new(0, 7, 0)
                        rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        
                        kart:PivotTo(safeDropCFrame)
                    end
                end
            end
            task.wait(0.5) 
        end
    end)

    -- 5. LAP TRACKING LOGIC
    for _, checkpoint in ipairs(checkpoints) do
        checkpoint.Touched:Connect(function(hit)
            if RaceManager.State ~= "Racing" then return end
            
            local model = hit:FindFirstAncestorOfClass("Model")
            if not model then return end

            local racerEntity = nil
            local isHuman = false
            local player = game.Players:GetPlayerFromCharacter(model)
            
            if player and table.find(racers, player) then
                racerEntity = player
                isHuman = true
            elseif table.find(activeBots, model) then
                racerEntity = model
            end
            
            if racerEntity then
                local result = checkpointService:ProcessTouch(racerEntity, checkpoint)
                
                if result then 
                    if isHuman then
                        local data = checkpointService.playerData[racerEntity]
                        
                        -- 🔊 🔕 THE SPAM FILTER (The Modulo Check)
                        -- Only play sound/popup if it's a Lap, a Finish, 
                        -- or if the checkpoint number is divisible by 50.
                        local isMajorCheckpoint = (data.nextCheckpoint - 1) % 50 == 0
                        
                        if result == "Finished" then
                            local sound = Instance.new("Sound")
                            sound.SoundId = "rbxassetid://1835495594" 
                            sound.Parent = checkpoint
                            sound:Play()
                            game.Debris:AddItem(sound, 2)
                            Remotes.ShowPopup:FireClient(player, "FINISH!", "Victory")
                            
                        elseif result == "Lap" then
                            local sound = Instance.new("Sound")
                            sound.SoundId = "rbxassetid://1836846781" 
                            sound.Parent = checkpoint
                            sound:Play()
                            game.Debris:AddItem(sound, 2)
                            Remotes.ShowPopup:FireClient(player, "LAP " .. data.laps .. " COMPLETE!", "Lap")
                            
                        elseif result == "Checkpoint" and isMajorCheckpoint then
                            -- Only plays every 50 checkpoints
                            local sound = Instance.new("Sound")
                            sound.SoundId = "rbxassetid://1848255131" 
                            sound.Parent = checkpoint
                            sound:Play()
                            game.Debris:AddItem(sound, 2)
                            Remotes.ShowPopup:FireClient(player, "KEEP GOING!", "Normal")
                        end

                        -- Always update the UI numbers (those aren't spammy)
                        if result == "Lap" or result == "Checkpoint" then
                            local currentLap = (data.laps or 0) + 1
                            Remotes.UpdateLap:FireClient(player, currentLap, LAPS)
                        end
                    end
                    
                    -- Handle Win Condition for everyone
                    if result == "Finished" then
                        local racerName = isHuman and player.Name or model.Name
                        if not table.find(winnersList, racerName) then
                            table.insert(winnersList, racerName)
                        end
                        
                        if isHuman then
                            humanFinishedCount += 1
                            Remotes.UpdateLap:FireClient(player, LAPS, LAPS)
                            
                            if humanFinishedCount >= #racers then
                                task.wait(1)
                                Remotes.RaceFinished:FireAllClients(winnersList)
                                task.wait(5)
                                RaceManager.EndRace(racers)
                                winnersList = {}
                            end
                        end
                    end
                end
            end
        end)
    end
end

function RaceManager.EndRace(racers)
    print("Race Over! Teleporting back to lobby...")
    RaceManager.State = "Waiting" 
    
    for _, player in ipairs(racers) do
        if not player or not player.Parent then continue end
        
        local character = player.Character
        local kart = workspace:FindFirstChild(player.Name .. "_Kart")
        
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then humanoid.Sit = false end
            
            task.wait(0.1)
            local lobbySpawn = workspace:FindFirstChild("LobbySpawn")
            if character.PrimaryPart and lobbySpawn then
                character:PivotTo(lobbySpawn.CFrame + Vector3.new(0, 3, 0))
            end
        end
        
        if kart then kart:Destroy() end
    end

    for _, botKart in ipairs(activeBots) do
        if botKart then botKart:Destroy() end
    end
    activeBots = {}
end

return RaceManager