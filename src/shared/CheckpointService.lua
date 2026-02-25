local CheckpointService = {}
CheckpointService.__index = CheckpointService

function CheckpointService.new(checkpoints, maxLaps)
    local self = setmetatable({}, CheckpointService)
    self.checkpoints = checkpoints
    self.maxLaps = maxLaps
    self.playerData = {}
    return self
end

function CheckpointService:InitPlayer(player)
    self.playerData[player] = {
        nextCheckpoint = 1,
        laps = 0,
        hasStarted = false, -- NEW: Tracks if they've crossed the start line for the first time
        finished = false
    }
end

function CheckpointService:ProcessTouch(player, checkpointPart)
    local data = self.playerData[player]
    if not data or data.finished then return end

    local checkpointIndex = table.find(self.checkpoints, checkpointPart)
    if not checkpointIndex then return end

    -- Check if they hit the correct next checkpoint
    if checkpointIndex == data.nextCheckpoint then
        
        local result = "Checkpoint"

        -- 1. Check what crossing this specific line means
        if checkpointIndex == 1 then
            if data.hasStarted then
                -- They cycled the whole track and crossed the start/finish line again!
                data.laps += 1
                print(player.Name .. " completed lap " .. data.laps)
                
                if data.laps >= self.maxLaps then
                    data.finished = true
                    result = "Finished"
                else
                    result = "Lap"
                end
            else
                -- They just spawned and are crossing Checkpoint1 for the very first time
                data.hasStarted = true
                print(player.Name .. " started the race!")
                result = "Checkpoint"
            end
        else
            -- They hit a normal mid-track checkpoint (e.g., Checkpoint 2, 3, 4, 5)
            result = "Checkpoint"
        end

        -- 2. Advance their target to the next physical wall
        if data.nextCheckpoint == #self.checkpoints then
            data.nextCheckpoint = 1 -- Loop back to Checkpoint 1
        else
            data.nextCheckpoint += 1
        end

        return result
    end
end

return CheckpointService