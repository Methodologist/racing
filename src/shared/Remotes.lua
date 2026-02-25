local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
RemotesFolder.Name = "Remotes"
RemotesFolder.Parent = ReplicatedStorage

local function getOrCreateRemoteEvent(name)
    local remote = RemotesFolder:FindFirstChild(name)
    if not remote then
        remote = Instance.new("RemoteEvent")
        remote.Name = name
        remote.Parent = RemotesFolder
    end
    return remote
end

local function getOrCreateRemoteFunction(name)
    local remote = RemotesFolder:FindFirstChild(name)
    if not remote then
        remote = Instance.new("RemoteFunction")
        remote.Name = name
        remote.Parent = RemotesFolder
    end
    return remote
end

local Remotes = {
    RaceCountdown = getOrCreateRemoteEvent("RaceCountdown"),
    RaceGo = getOrCreateRemoteEvent("RaceGo"),
    ApplyBoost = getOrCreateRemoteEvent("ApplyBoost"),
    RaceFinished = getOrCreateRemoteEvent("RaceFinished"),
    UpdateLap = getOrCreateRemoteEvent("UpdateLap"), -- ADDED THIS
    RequestKartSpawn = getOrCreateRemoteFunction("RequestKartSpawn"),
}

return Remotes