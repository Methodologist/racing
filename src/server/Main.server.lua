local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Navigate the folders created by your JSON
local ServerFolder = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local RaceManager = require(ServerFolder.RaceManager)

-- 1. Setup Remotes
