
local UEHelpers = require("UEHelpers")

local currentDir = debug.getinfo(1, "S").source:match("@(.+\\)BaseUtils.lua")
if currentDir then
    package.path = package.path .. ';' .. currentDir .. '?.lua'
    require("MathUtils")
    require("FNames")
    require("DefaultObjects")
    require("StaticClasses")
end

-- UEHelpers function shortcuts
GetKismetSystemLibrary = UEHelpers.GetKismetSystemLibrary ---@type fun(ForceInvalidateCache: boolean?): UKismetSystemLibrary
GetKismetMathLibrary = UEHelpers.GetKismetMathLibrary ---@type fun(ForceInvalidateCache: boolean?): UKismetMathLibrary
GetKismetStringLibrary = UEHelpers.GetKismetStringLibrary ---@type fun(ForceInvalidateCache: boolean?): UKismetStringLibrary
GetGameplayStatics = UEHelpers.GetGameplayStatics ---@type fun(ForceInvalidateCache: boolean?): UGameplayStatics

ModName = "BaseUtils"
ModVersion = "1.0.0"
DebugMode = false
IsModEnabled = false

---Returns [ModName vModVersion] string
---@return string
function GetModInfoPrefix()
    return string.format("[%s v%s]", ModName, ModVersion)
end

---@param Prefix string
---@param Args any
local function Log(Prefix, Args)
    if not Args or #Args <= 0 then return end
    Prefix = Prefix or ""

    local message = Prefix
    for i, v in ipairs(Args) do
        if i > 1 then
            message = message .. " "
        end
        message = message .. tostring(v)
    end
    print(message .. "\n")
end

---@param ... any
function LogInfo(...)
    Log(GetModInfoPrefix().." ", {...})
end

---@param ... any
function LogDebug(...)
    if DebugMode then
        LogInfo(...)
    end
end

---@param ... any
function LogWarn(...)
    Log(GetModInfoPrefix() .. "[Warning] ", {...})
end

---@param ... any
function LogError(...)
    Log(GetModInfoPrefix() .. "[Error] ", {...})
end

---@param ... any
function LogDebugError(...)
    if DebugMode then
        LogError(...)
    end
end

---@param table table
function TableToString(table, prefix)
    prefix = prefix or ""

    local result = ""
    if type(table) == "table" then
        for key, value in pairs(table) do
            if result ~= "" then
                result = result .. "\n"
            end
            result = result .. prefix .. tostring(key) .. ": "
            if type(value) == "table" then
                result = result .. "\n" .. TableToString(value, prefix .. " ")
            else
                result = result .. tostring(value)
            end
        end
    else
        result = prefix .. tostring(table)
    end
    return result
end

-- Exported functions --
------------------------

---Ultimate check if an object is not nil and valid
---@param object UObject
---@return boolean Valid
function IsValid(object)
    return object ~= nil and object.IsValid ~= nil and object:IsValid()
end

---Ultimate check if an object isn't valid in any way
---@param object UObject
---@return boolean NotValid
function IsNotValid(object)
    return not IsValid(object)
end

---Returns always true unless client joins a server
---@return boolean
function IsServer()
    local world = GetWorld()
    if IsValid(world) then
        return GetKismetSystemLibrary():IsServer(world)
    end
    return false
end

---Returns always true unless client joins a server
---@return boolean
function IsDedicatedServer()
    local world = GetWorld()
    if IsValid(world) then
        return GetKismetSystemLibrary():IsDedicatedServer(world)
    end
    return false
end

---Returns true if local player is the host / has authority
---@return boolean
function IsHost()
    local word = GetWorld()
    return IsValid(word) and IsValid(word.AuthorityGameMode)
end

---Finds specific UActorComponent in BlueprintCreatedComponents array
---@param Actor AActor
---@param Class UClass
---@return UActorComponent?
function GetBlueprintCreatedComponentByClass(Actor, Class)
    if IsValid(Actor) and IsValid(Class) then
        for i = 1, #Actor.BlueprintCreatedComponents, 1 do
            local component = Actor.BlueprintCreatedComponents[i]
            if component:IsValid() and component:IsA(Class) then
                return component
            end
        end
    end

    return nil
end

local WorldCache = CreateInvalidObject() ---@cast WorldCache UWorld
---Returns the main UWorld
---@return UWorld
function GetWorld()
    if IsValid(WorldCache) then return WorldCache end

    local gameInstance = UEHelpers.GetGameInstance()
    if gameInstance:IsValid() then
        WorldCache = gameInstance:GetWorld()
    else
        local playerController = UEHelpers.GetPlayerController()
        if playerController:IsValid() then
            WorldCache = playerController:GetWorld()
        end
    end
    return WorldCache
end

local myPlayerControllerCache = CreateInvalidObject() ---@cast myPlayerControllerCache APlayerController
---@return APlayerController
function GetMyPlayerController()
    if IsValid(myPlayerControllerCache) then
        return myPlayerControllerCache
    end

    local gameInstance = UEHelpers.GetGameInstance()
    if IsValid(gameInstance) and gameInstance.LocalPlayers and #gameInstance.LocalPlayers > 0 then
        local localPlayer = gameInstance.LocalPlayers[1]
        if IsValid(localPlayer) then
            myPlayerControllerCache = localPlayer.PlayerController
        end
    else
        local playerController = UEHelpers.GetPlayerController()
        if IsValid(playerController) then
            myPlayerControllerCache = playerController
        end
    end
    return myPlayerControllerCache
end

---Returns Pawn from player controller of the first local player
---@return ACharacter|APawn|UObject
function GetMyPlayer()
    local playerController = GetMyPlayerController()
    if IsValid(playerController) then
        return playerController.Pawn
    end
    return CreateInvalidObject()
end

---Returns Pawn from first player controller
---@return ACharacter|APawn|UObject
function GetFirstPlayer()
    local playerController = UEHelpers.GetPlayerController()
    if IsValid(playerController) then
        return playerController.Pawn
    end
    return CreateInvalidObject()
end

---Returns hit actor from FHitResult, it handles the struct differance between UE4 and UE5
---@param HitResult FHitResult
---@return AActor|UObject
function GetActorFromHitResult(HitResult)
    local actor = CreateInvalidObject()
    if not HitResult then return actor end

    if UnrealVersion:IsBelow(5, 0) then
        actor = HitResult.Actor:Get()
    elseif UnrealVersion:IsBelow(5, 4) then
        actor = HitResult.HitObjectHandle.Actor:Get()
    else
        actor = HitResult.HitObjectHandle.ReferenceObject:Get()
    end

    return actor
end

---Fires a line trace from start to end location
---@param StartLocation FVector
---@param EndLocation FVector
---@param TraceChannel ECollisionChannel|number|nil (Default: 1) It's actually ETraceTypeQuery enum but ECollisionChannel members are named according to their type (0 = WorldStatic, 1 = WorldDynamic, 2 = Pawn, 3 = Visibility)
---@return AActor|UObject #Actor from hit result
function LineTraceByChannel(StartLocation, EndLocation, TraceChannel)
    if not StartLocation or not StartLocation.X or not EndLocation or not EndLocation.X then return CreateInvalidObject() end
    TraceChannel = TraceChannel or 1 -- WorldDynamic

    local playerController = UEHelpers.GetPlayerController()
    if IsValid(playerController) then
        local traceColor = { R = 0, G = 0, B = 0, A = 0 }
        local actorsToIgnore = {}
        local outHitResult = {}
        local worldContext = playerController ---@type UObject
        if IsValid(playerController.Pawn) then
            -- Set Pawn as WorldContext to ignore own player with bIgnoreSelf parameter
            worldContext = playerController.Pawn
        end
        if GetKismetSystemLibrary():LineTraceSingle(worldContext, StartLocation, EndLocation, TraceChannel, false, actorsToIgnore, 0, outHitResult, true, traceColor, traceColor, 0.0) then
            return GetActorFromHitResult(outHitResult)
        end
    end
    return CreateInvalidObject()
end

---Fires a line trace in front of the camera that collides with objects based on collision channel
---@param TraceChannel ECollisionChannel|number|nil (Default: 1) It's actually ETraceTypeQuery enum but ECollisionChannel members are named according to their type (0 = WorldStatic, 1 = WorldDynamic, 2 = Pawn, 3 = Visibility)
---@param LengthInM number|nil (Default: 20) Trace line length in meter 
---@return AActor|UObject #Actor from hit result
function ForwardLineTraceByChannel(TraceChannel, LengthInM)
    TraceChannel = TraceChannel or 1 -- WorldDynamic
    LengthInM = LengthInM or 20.0

    local playerController = UEHelpers.GetPlayerController()
    if IsValid(playerController) and IsValid(playerController.PlayerCameraManager) then
        local cameraManager = playerController.PlayerCameraManager
        local lookDirection = cameraManager:GetActorForwardVector()
        local lookDirOffset = GetKismetMathLibrary():Multiply_VectorFloat(lookDirection, MToUnits(LengthInM))
        local startLocation = cameraManager:GetCameraLocation()
        local endLocation = GetKismetMathLibrary():Add_VectorVector(startLocation, lookDirOffset)
        local traceColor = { R = 0, G = 0, B = 0, A = 0 }
        local worldContext = playerController ---@type UObject
        if IsValid(playerController.Pawn) then
            -- Set Pawn as WorldContext to ignore own player with bIgnoreSelf parameter
            worldContext = playerController.Pawn
        end
        local actorsToIgnore = {}
        local outHitResult = {}
        if GetKismetSystemLibrary():LineTraceSingle(worldContext, startLocation, endLocation, TraceChannel, false, actorsToIgnore, 0, outHitResult, true, traceColor, traceColor, 0.0) then
            return GetActorFromHitResult(outHitResult)
        end
    end
    return CreateInvalidObject()
end

---Fires a line trace from start to end location
---@param StartLocation FVector
---@param EndLocation FVector
---@param TraceObject ECollisionChannel|number|nil (Default: 1) It's actually EObjectTypeQuery enum but ECollisionChannel members are named according to their type (0 = WorldStatic, 1 = WorldDynamic, 2 = Pawn, 3 = Visibility)
---@return AActor|UObject #Actor from hit result
function LineTraceByObject(StartLocation, EndLocation, TraceObject)
    if not StartLocation or not StartLocation.X or not EndLocation or not EndLocation.X then return CreateInvalidObject() end
    TraceChannel = TraceChannel or 1 -- WorldDynamic

    local playerController = UEHelpers.GetPlayerController()
    if IsValid(playerController) then
        local traceColor = { R = 0, G = 0, B = 0, A = 0 }
        local actorsToIgnore = {}
        local outHitResult = {}
        local worldContext = playerController ---@type UObject
        if playerController.Pawn:IsValid() then
            -- Set Pawn as WorldContext to ignore own player with bIgnoreSelf parameter
            worldContext = playerController.Pawn
        end
        local traceObjects = { TraceObject }
        if GetKismetSystemLibrary():LineTraceSingleForObjects(worldContext, StartLocation, EndLocation, traceObjects, false, actorsToIgnore, 0, outHitResult, true, traceColor, traceColor, 0.0) then
            return GetActorFromHitResult(outHitResult)
        end
    end
    return CreateInvalidObject()
end

---Fires a line trace in front of the camera that collides with objects based on object type
---@param TraceObject ECollisionChannel|number|nil (Default: 1) It's actually EObjectTypeQuery enum but ECollisionChannel members are named according to their type (0 = WorldStatic, 1 = WorldDynamic, 2 = Pawn, 3 = Visibility)
---@param LengthInM number|nil (Default: 20) Trace line length in meter 
---@return AActor|UObject #Actor from hit result
function ForwardLineTraceByObject(TraceObject, LengthInM)
    TraceChannel = TraceChannel or 1 -- WorldDynamic
    LengthInM = LengthInM or 20.0

    local playerController = UEHelpers.GetPlayerController()
    if IsValid(playerController) and IsValid(playerController.PlayerCameraManager) then
        local cameraManager = playerController.PlayerCameraManager
        local lookDirection = cameraManager:GetActorForwardVector()
        local lookDirOffset = GetKismetMathLibrary():Multiply_VectorFloat(lookDirection, MToUnits(LengthInM))
        local startLocation = cameraManager:GetCameraLocation()
        local endLocation = GetKismetMathLibrary():Add_VectorVector(startLocation, lookDirOffset)
        local traceColor = { R = 0, G = 0, B = 0, A = 0 }
        local worldContext = playerController ---@type UObject
        if playerController.Pawn:IsValid() then
            -- Set Pawn as WorldContext to ignore own player with bIgnoreSelf parameter
            worldContext = playerController.Pawn
        end
        local actorsToIgnore = {}
        local outHitResult = {}
        local traceObjects = { TraceObject }
        if GetKismetSystemLibrary():LineTraceSingleForObjects(worldContext, startLocation, endLocation, traceObjects, false, actorsToIgnore, 0, outHitResult, true, traceColor, traceColor, 0.0) then
            return GetActorFromHitResult(outHitResult)
        end
    end
    return CreateInvalidObject()
end


---Teleports an actor to a close location of another
---@param Actor AActor # Actor that should be teleported
---@param TargetActor AActor # Target to teleport to
---@param Behind boolean? # If the actor should be teleported behind or infront of the target
---@param DistanceToActor integer? # Default 100 aka. 1m
---@return boolean
function TeleportActorToActor(Actor, TargetActor, Behind, DistanceToActor)
    if IsNotValid(Actor) or IsNotValid(TargetActor) then return false end
    Behind = Behind or false
    DistanceToActor = DistanceToActor or 100 -- 1m
    
    local direction = TargetActor:GetActorForwardVector()
    local tagetLocation = TargetActor:K2_GetActorLocation()
    tagetLocation.Z = tagetLocation.Z + 20
    local targetRotation = TargetActor:K2_GetActorRotation()
    if Behind then
        DistanceToActor = DistanceToActor * -1
    else
        targetRotation.Yaw = targetRotation.Yaw * -1
    end
    local locationOffset = GetKismetMathLibrary():Multiply_VectorVector(direction, FVector(DistanceToActor, DistanceToActor, 0))
    tagetLocation = GetKismetMathLibrary():Add_VectorVector(tagetLocation, locationOffset)

    return Actor:K2_TeleportTo(tagetLocation, targetRotation)
end

---Tries to find the UFunction object before executing RegisterHook. Can still resolve into an error if RegisterHook throws one<br>
---For RegisterHook details see: https://docs.ue4ss.com/lua-api/global-functions/staticfindobject.html
---@param UFunctionName string # Full name of a UFunction
---@param Callback fun(self: UObject, ...) # Hook
---@param OutHookIds? { PreId: integer, PostId: integer }
---@return boolean Success # Returns false if the UFunction doesn't exist, true if RegisterHook was executed and error when RegisterHook throws one
function TryRegisterHook(UFunctionName, Callback, OutHookIds)
    if not UFunctionName or not Callback then return false end

    local uFunction = StaticFindObject(UFunctionName)
    if IsValid(uFunction) then
        OutHookIds = OutHookIds or {}
        OutHookIds.PreId, OutHookIds.PostId = RegisterHook(UFunctionName, Callback)
        return true
    end

    return false
end

---Untested function
---@param ActorClassName string
---@param Location FVector
---@param Rotation FRotator?
---@return AActor
function SpawnActorFromClass(ActorClassName, Location, Rotation)
    local invalidActor = CreateInvalidObject() ---@cast invalidActor AActor
    if type(ActorClassName) ~= "string" or not Location then return invalidActor end
    Rotation = Rotation or FRotator()

    LoadAsset(ActorClassName)

    local kismetMathLibrary = GetKismetMathLibrary()
    local gameplayStatics = GetGameplayStatics()
    if not kismetMathLibrary or not gameplayStatics then return invalidActor end

    local world = UEHelpers.GetWorld()
    if IsNotValid(world) then return invalidActor end

    local actorClass = StaticFindObject(ActorClassName)
    if IsNotValid(actorClass) then
        LogError("SpawnActorFromClass: Couldn't find static object:", ActorClassName)
        return invalidActor
    end

    local transform = kismetMathLibrary:MakeTransform(Location, Rotation, FVector(1.0, 1.0, 1.0))
    -- LogDebug("SpawnActorFromClass: UWorld: " .. type(world))
    -- LogDebug("SpawnActorFromClass: class: " .. actorClass:type())
    -- LogDebug("SpawnActorFromClass: transform: " .. type(transform))
    -- for key, value in pairs(transform) do
    --     LogDebug("key:", key, "value:", value)
    --     for k, v in pairs(value) do
    --         LogDebug("  k:", k, "v:", v)
    --     end
    -- end
    local deferredActor  = gameplayStatics:BeginDeferredActorSpawnFromClass(world, actorClass, transform, 0, nil, 0)
    if IsValid(deferredActor) then
        LogDebug("SpawnActorFromClass: Deferred Actor successfully")
        return gameplayStatics:FinishSpawningActor(deferredActor, transform, 0)
    end
    return invalidActor
end

---Untested function
---@param ActorClassName string
---@param Location FVector
---@param Rotation FRotator?
---@return AActor
function SpawnActorByClassName(ActorClassName, Location, Rotation)
    local invalidActor = CreateInvalidObject() ---@cast invalidActor AActor
    if type(ActorClassName) ~= "string" or not Location then return invalidActor end
    Rotation = Rotation or FRotator()

    LoadAsset(ActorClassName)

    local world = UEHelpers.GetWorld()
    if IsNotValid(world) then return invalidActor end

    local actorClass = StaticFindObject(ActorClassName)
    if IsNotValid(actorClass) then
        LogError("SpawnActorFromClass: Couldn't find static object:", ActorClassName)
        return invalidActor
    end

    return world:SpawnActor(actorClass, Location, Rotation)
end