local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local ATTEMPT_LIMIT = 5
local RETRY_DELAY = 1
local FLOOD_DELAY = 15

local RETRY_DELAYS = {
    Flooded = FLOOD_DELAY,
    Failure = RETRY_DELAY,
    GameFull = RETRY_DELAY
}

local failureCallbacks = {}
local failedTeleportAttempts = {}

local function clearPlayerFailureState(player)
    failureCallbacks[player] = nil
    failedTeleportAttempts[player] = nil
end

local function failPlayer(player)
    local failureCallback = failureCallbacks[player]
    clearPlayerFailureState(player)

    if failureCallback then
        failureCallback(player)
    end
end

local function SafeTeleport(placeId, players, options, failureCallback)
    if failureCallback then
        for _, player in pairs(players) do
            failureCallbacks[player] = failureCallback
            failedTeleportAttempts[player] = failedTeleportAttempts[player] or 0
        end
    end

    local attemptIndex = 0
    local success, result -- define pcall results outside of loop so results can be reported later on

    repeat
        success, result = pcall(function()
            return TeleportService:TeleportAsync(placeId, players, options) -- teleport the user in a protected call to prevent erroring
        end)
        attemptIndex += 1
        if not success then
            task.wait(RETRY_DELAY)
        end
    until success or attemptIndex == ATTEMPT_LIMIT -- stop trying to teleport if call was successful, or if retry limit has been reached

    if not success then
        warn(result) -- print the failure reason to output
    end

    return success, result
end

local function handleFailedTeleport(player, teleportResult, errorMessage, targetPlaceId, teleportOptions)
    local retryDelay = RETRY_DELAYS[teleportResult.Name]
    if not retryDelay then
        warn(("Invalid teleport [%s]: %s"):format(teleportResult.Name, errorMessage))
        failPlayer(player)
        return
    end

    failedTeleportAttempts[player] = (failedTeleportAttempts[player] or 0) + 1
    if failedTeleportAttempts[player] >= ATTEMPT_LIMIT then
        warn(("Teleport failed after %d attempts [%s]: %s"):format(ATTEMPT_LIMIT, teleportResult.Name, errorMessage))
        failPlayer(player)
        return
    end

    task.wait(retryDelay)
    local teleportSuccess = SafeTeleport(targetPlaceId, {player}, teleportOptions, failureCallbacks[player])
    if not teleportSuccess then
        failPlayer(player)
    end
end

TeleportService.TeleportInitFailed:Connect(handleFailedTeleport)
Players.PlayerRemoving:Connect(clearPlayerFailureState)

return SafeTeleport
