
--[[
  Author: Igromanru © 2025
  Created: 2025-07-26
  Description: Universal Unreal Engine No Clip feature
]]

local UEHelpers = require("UEHelpers")

local NoClip = {}
local CollisionWasDisabled = false
local OriginalCollisionResponse = {} ---@type ECollisionChannel[]|nil[]

local CollisionsCount = 32
for i = 1, CollisionsCount do
    table.insert(OriginalCollisionResponse, nil)
end

local myPlayerControllerCache = CreateInvalidObject() ---@cast myPlayerControllerCache APlayerController
---@return APlayerController
local function GetMyPlayerController()
    if myPlayerControllerCache:IsValid() then
        return myPlayerControllerCache
    end

    local gameInstance = UEHelpers.GetGameInstance()
    if gameInstance:IsValid() and gameInstance.LocalPlayers and #gameInstance.LocalPlayers > 0 then
        local localPlayer = gameInstance.LocalPlayers[1]
        if localPlayer:IsValid() then
            myPlayerControllerCache = localPlayer.PlayerController
        end
    else
        local playerController = UEHelpers.GetPlayerController()
        if playerController:IsValid() then
            myPlayerControllerCache = playerController
        end
    end
    return myPlayerControllerCache
end

---Returns Pawn from player controller of the first local player
---@return ACharacter|APawn|UObject
local function GetMyPlayer()
    local playerController = GetMyPlayerController()
    if playerController:IsValid() then
        return playerController.Pawn
    end
    return CreateInvalidObject()
end

---@return UCharacterMovementComponent
local function GetMyCharacterMovement()
    local myPlayer = GetMyPlayer()
    if myPlayer:IsValid() then
        return myPlayer.CharacterMovement
    end
    return CreateInvalidObject() ---@type UCharacterMovementComponent
end

---@return UCapsuleComponent
local function GetMyCapsuleComponent()
    local myPlayer = GetMyPlayer()
    if myPlayer:IsValid() then
        return myPlayer.CapsuleComponent
    end
    return CreateInvalidObject() ---@type UCapsuleComponent
end

---@param CapsuleComponent UCapsuleComponent
local function BackUpCollisionResponses(CapsuleComponent)
    for i = 1, CollisionsCount, 1 do
        OriginalCollisionResponse[i] = CapsuleComponent:GetCollisionResponseToChannel(i - 1)
        -- print(string.format("BackUpCollisionResponses Channel: %d, Value: %d", i, OriginalCollisionResponse[i]))
    end
end

---@param CapsuleComponent UCapsuleComponent
---@param ChannelsCount integer? # Default 32
local function RestoreCollisionResponses(CapsuleComponent, ChannelsCount)
    ChannelsCount = ChannelsCount or CollisionsCount
    for i = 1, ChannelsCount, 1 do
        local response = OriginalCollisionResponse[i]
        if response then
            CapsuleComponent:SetCollisionResponseToChannel(i - 1, response)
            OriginalCollisionResponse[i] = nil
        end
    end
end

---@param CapsuleComponent UCapsuleComponent
---@param NewResponse ECollisionResponse|integer|nil # Default 0 (ECR_Ignore)
---@param ChannelsCount integer? # Default 32
local function SetCollisionResponses(CapsuleComponent, NewResponse, ChannelsCount)
    NewResponse = NewResponse or 0
    ChannelsCount = ChannelsCount or CollisionsCount
    for i = 1, ChannelsCount, 1 do
        CapsuleComponent:SetCollisionResponseToChannel(i - 1, NewResponse)
    end
end

---@param WithCollision boolean? # Default false
---@return boolean
NoClip.Enable = function (WithCollision)
    WithCollision = WithCollision or false

    local myCapsuleComponent = GetMyCapsuleComponent()
    local myCharacterMovement = GetMyCharacterMovement()
    if not myCapsuleComponent:IsValid() or not myCharacterMovement:IsValid() then return false end

    myCharacterMovement.bCheatFlying = true;
    myCharacterMovement:SetMovementMode(5, 0)

    if not WithCollision then
        -- BackUpCollisionResponses(myCapsuleComponent)
        SetCollisionResponses(myCapsuleComponent, 0, 3)
        CollisionWasDisabled = true
    end

    return true
end

---@return boolean
NoClip.Disable = function ()
    local myCapsuleComponent = GetMyCapsuleComponent()
    local myCharacterMovement = GetMyCharacterMovement()
    if not myCapsuleComponent:IsValid() or not myCharacterMovement:IsValid() then return false end

    SetCollisionResponses(myCapsuleComponent, 2, 3)
    -- if CollisionWasDisabled then
    --     RestoreCollisionResponses(myCapsuleComponent, 2)
    --     CollisionWasDisabled = false
    -- end

    myCharacterMovement.bCheatFlying = false;
    myCharacterMovement:SetMovementMode(1, 0)

    return true
end

return NoClip