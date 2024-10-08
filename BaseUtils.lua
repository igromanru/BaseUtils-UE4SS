
local UEHelpers = require("UEHelpers")

local currentDir = debug.getinfo(1, "S").source:match("@(.+\\)BaseUtils.lua")
if currentDir then
    package.path = package.path .. ';' .. currentDir .. '?.lua'
    require("MathUtils")
    require("FNames")
    require("DefaultObjects")
end

-- UEHelpers function shortcuts
GetKismetSystemLibrary = UEHelpers.GetKismetSystemLibrary ---@type fun(ForceInvalidateCache: boolean?): UKismetSystemLibrary
GetKismetMathLibrary = UEHelpers.GetKismetMathLibrary ---@type fun(ForceInvalidateCache: boolean?): UKismetMathLibrary
GetGameplayStatics = UEHelpers.GetGameplayStatics ---@type fun(ForceInvalidateCache: boolean?): UGameplayStatics

ModName = "BaseUtils"
ModVersion = "1.0.0"
DebugMode = false
IsModEnabled = false

function GetModInfoPrefix()
    return string.format("[%s v%s]", ModName, ModVersion)
end

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

function LogInfo(...)
    Log(GetModInfoPrefix().." ", {...})
end

function LogDebug(...)
    if DebugMode then
        LogInfo(...)
    end
end

function LogWarn(...)
    Log(GetModInfoPrefix() .. "[Warning] ", {...})
end

function LogError(...)
    Log(GetModInfoPrefix() .. "[Error] ", {...})
end

function LogDebugError(...)
    if DebugMode then
        LogError(...)
    end
end

-- Exported functions --
------------------------

local EngineCache = nil
---Returns instance of UEngine
---@return UEngine?
function GetEngine()
    if EngineCache and EngineCache:IsValid() then
        return EngineCache
    end

    EngineCache = FindFirstOf("Engine")
    ---@cast EngineCache UEngine?
    if EngineCache and EngineCache:IsValid() then
        return EngineCache
    end
    return nil
end

---Returns UGameViewportClient from UEngine
---@return UGameViewportClient?
function GetGameViewportClient()
    local engine = GetEngine()
    if not engine then return nil end

    
    if engine.GameViewport:IsValid() then
        return engine.GameViewport
    end
    return nil
end

---Returns main UWorld
---@return UWorld?
function GetWorld()
    local gameViewportClient = GetGameViewportClient()
    if not gameViewportClient then return nil end
    
    if gameViewportClient.World:IsValid() then
        return gameViewportClient.World
    end
    return nil
end

local GameStateCache = nil
---Returns AGameState
---@return AGameState?
function GetGameState()
    if GameStateCache and GameStateCache:IsValid() then
        return GameStateCache
    end

    GameStateCache = FindFirstOf("GameState")
    ---@cast GameStateCache AGameState
    if GameStateCache and GameStateCache:IsValid() then
        return GameStateCache
    end
    return nil
end

---Returns UWorld->PersistentLevel
---@return ULevel?
function GetPersistentLevel()
    local world = GetWorld()
    if not world then return nil end
    
    if world.PersistentLevel:IsValid() then
        return world.PersistentLevel
    end
    return nil
end

---Returns WorldSettings from PersistentLevel
---@return AWorldSettings?
function GetWorldSettings()
    local persistentLevel = GetPersistentLevel()
    if not persistentLevel then return nil end
    
    if persistentLevel.WorldSettings:IsValid() then
        return persistentLevel.WorldSettings
    end
    return nil
end

local GameInstanceCache = nil
---Returns instance of UGameInstance
---@return UGameInstance?
function GetGameInstance()
    if GameInstanceCache and GameInstanceCache:IsValid() then return GameInstanceCache end

    GameInstanceCache = FindFirstOf("GameInstance") ---@type UGameInstance
    if not GameInstanceCache:IsValid() then
        GameInstanceCache = nil
    end
    return GameInstanceCache
end

local MyPlayerControllerCache = nil
---Returns main APlayerController
---@return APlayerController?
function GetMyPlayerController()
    if MyPlayerControllerCache and MyPlayerControllerCache:IsValid() then
        return MyPlayerControllerCache
    end
    
    local gameInstance = GetGameInstance()
    if gameInstance and #gameInstance.LocalPlayers > 0 then
        MyPlayerControllerCache = gameInstance.LocalPlayers[1].PlayerController
    end
    if not MyPlayerControllerCache or not MyPlayerControllerCache:IsValid() then
        MyPlayerControllerCache = nil
    end
    
    return MyPlayerControllerCache
end

---Returns currently controlled pawn (usually the player chracter)
---@return APawn?
function GetMyPlayer()
    local playerController = GetMyPlayerController()
    local player = nil

    if playerController then
        player = playerController.Pawn
    end
    if player and player:IsValid() then
        return player
    end

    return nil
end

---Finds specific UActorComponent in BlueprintCreatedComponents array
---@param Actor AActor
---@param Class UClass
---@return UActorComponent?
function GetBlueprintCreatedComponentByClass(Actor, Class)
    if Actor and Class and Actor:IsValid() and Class:IsValid() then
        for i = 1, #Actor.BlueprintCreatedComponents, 1 do
            local component = Actor.BlueprintCreatedComponents[i]
            if component:IsValid() and component:IsA(Class) then
                return component
            end
        end
    end

    return nil
end

---Returns hit actor from FHitResult, it handles the struct differance between UE4 and UE5
---@param HitResult FHitResult
---@return AActor|nil
function GetActorFromHitResult(HitResult)
    if not HitResult then return nil end

    local actor = nil
    if UnrealVersion:IsBelow(5, 0) then
        actor = HitResult.Actor:Get()
    elseif UnrealVersion:IsBelow(5, 4) then
        actor = HitResult.HitObjectHandle.Actor:Get()
    else
        actor = HitResult.HitObjectHandle.ReferenceObject:Get()
    end

    if actor and actor:IsValid() then
        return actor
    end

    return nil
end

---Fires a line trace from start to end location
---@param StartLocation FVector
---@param EndLocation FVector
---@param TraceChannel ECollisionChannel|number|nil (Default: 1) It's actually ETraceTypeQuery enum but ECollisionChannel members are named according to their type (0 = WorldStatic, 1 = WorldDynamic, 2 = Pawn, 3 = Visibility)
---@return AActor|nil #Actor from hit result
function LineTraceByChannel(StartLocation, EndLocation, TraceChannel)
    if not StartLocation or not StartLocation.X or not EndLocation or not EndLocation.X then return nil end
    TraceChannel = TraceChannel or 1 -- WorldDynamic

    local playerController = GetMyPlayerController()
    if playerController and playerController:IsValid() then
        local traceColor = { R = 0, G = 0, B = 0, A = 0 }
        local actorsToIgnore = {}
        local outHitResult = {}
        local worldContext = playerController ---@type UObject
        if playerController.Pawn:IsValid() then
            -- Set Pawn as WorldContext to ignore own player with bIgnoreSelf parameter
            worldContext = playerController.Pawn
        end
        if GetKismetSystemLibrary():LineTraceSingle(worldContext, StartLocation, EndLocation, TraceChannel, false, actorsToIgnore, 0, outHitResult, true, traceColor, traceColor, 0.0) then
            return GetActorFromHitResult(outHitResult)
        end
    end
    return nil
end

---Fires a line trace in front of the camera that collides with objects based on collision channel
---@param TraceChannel ECollisionChannel|number|nil (Default: 1) It's actually ETraceTypeQuery enum but ECollisionChannel members are named according to their type (0 = WorldStatic, 1 = WorldDynamic, 2 = Pawn, 3 = Visibility)
---@param LengthInM number|nil (Default: 20) Trace line length in meter 
---@return AActor|nil #Actor from hit result
function ForwardLineTraceByChannel(TraceChannel, LengthInM)
    TraceChannel = TraceChannel or 1 -- WorldDynamic
    LengthInM = LengthInM or 20.0

    local playerController = GetMyPlayerController()
    if playerController and playerController.PlayerCameraManager:IsValid() then
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
        if GetKismetSystemLibrary():LineTraceSingle(worldContext, startLocation, endLocation, TraceChannel, false, actorsToIgnore, 0, outHitResult, true, traceColor, traceColor, 0.0) then
            return GetActorFromHitResult(outHitResult)
        end
    end
    return nil
end

---Teleports an actor to a close location of another
---@param Actor AActor # Actor that should be teleported
---@param TargetActor AActor # Target to teleport to
---@param Behind boolean? # If the actor should be teleported behind or infront of the target
---@param DistanceToActor integer? # Default 100 aka. 1m
---@return boolean
function TeleportActorToActor(Actor, TargetActor, Behind, DistanceToActor)
    if not Actor or not TargetActor or not Actor:IsValid() or not TargetActor:IsValid() then return false end
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

---@param ActorClassName string
---@param Location FVector
---@param Rotation FRotator?
---@return AActor?
function SpawnActorFromClass(ActorClassName, Location, Rotation)
    if type(ActorClassName) ~= "string" or not Location then return nil end
    Rotation = Rotation or FRotator()

    local kismetMathLibrary = GetKismetMathLibrary()
    local gameplayStatics = GetGameplayStatics()
    if not kismetMathLibrary or not gameplayStatics then return nil end

    local world = GetWorld()
    if not world then return nil end

    local actorClass = StaticFindObject(ActorClassName)
    if not actorClass:IsValid() then return nil end

    local transform = TransformToUserdata(kismetMathLibrary:MakeTransform(Location, Rotation, FVector(1, 1, 1)))
    LogDebug("SpawnActorFromClass: UWorld: " .. type(world))
    LogDebug("SpawnActorFromClass: class: " .. actorClass:type())
    LogDebug("SpawnActorFromClass: transform: " .. type(transform))
    local deferredActor  = gameplayStatics:BeginDeferredActorSpawnFromClass(world, actorClass, transform, 0, nil, 1)
    if deferredActor and deferredActor:IsValid() then
        LogDebug("SpawnActorFromClass: Deferred Actor successfully")
        return gameplayStatics:FinishSpawningActor(deferredActor, transform, 1)
    end
    return nil
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
    if uFunction and uFunction:IsValid() then
        OutHookIds = OutHookIds or {}
        OutHookIds.PreId, OutHookIds.PostId = RegisterHook(UFunctionName, Callback)
        return true
    end

    return false
end