--[[
    Author: Igromanru
    Created Date: 09.08.2026
    Description: Class to automatically handle function hooks
]]

local Queue

local source = debug.getinfo(1, "S").source
local currentDir = source:match("@(.+[\\/])")
if currentDir then
    package.path = package.path .. ";" .. currentDir .. "?.lua"
    require("BaseUtils")
    Queue = require("Queue")
end

---@class HookInfo
---@field functionName string
---@field preId number
---@field postId number
---@field preCallback? fun(self: UObject, ...)
---@field postCallback? fun(self: UObject, ...)
---@field loadAsset boolean
---@field IsActive fun(self: HookInfo): boolean Returns whether this hook is currently active.
---@field Reset fun(self: HookInfo)
local HookInfo = {}
HookInfo.__index = HookInfo

---Creates a new hook info object with default values
---@param functionName? string Default: ""
---@param preCallback? fun(self: UObject, ...) Default: nil
---@param postCallback? fun(self: UObject, ...) Default: nil
---@param preId? number Default: -1
---@param postId? number Default: -1
---@return HookInfo
function HookInfo.new(functionName, preCallback, postCallback, preId, postId, loadAsset)
    return setmetatable({
        functionName = functionName or "",
        preId = preId or -1,
        postId = postId or -1,
        preCallback = preCallback,
        postCallback = postCallback,
        loadAsset = loadAsset or false
    }, HookInfo)
end

---Returns whether this hook is currently active.
---@return boolean
function HookInfo:IsActive()
    return IsStringNotEmpty(self.functionName) and IsValidId(self.preId)
end

---Resets this hook info to its default values.
function HookInfo:Reset()
    self.functionName = ""
    self.preId = -1
    self.postId = -1
    self.preCallback = nil
    self.postCallback = nil
    self.loadAsset = false
end

---@class HooksManager
---@field private hooks { [string]: HookInfo? }
---@field private hooksQueue Queue<HookInfo> Queue of references to HookInfo entries in `hooks` table
local HooksManager = {
    hooks = {}, -- Key is the function name/path
    hooksQueue = Queue.new()
}
HooksManager.__index = HooksManager

---@param hookInfo? HookInfo
---@return boolean
local function IsActiveHook(hookInfo)
    return hookInfo ~= nil and hookInfo:IsActive()
end

---Adds a HookInfo reference to the queue
---@param hookInfo? HookInfo
local function PushToQueue(hookInfo)
    if not hookInfo then return end

    HooksManager.hooksQueue:Push(hookInfo)
end

---Returns true if the HookInfo is already in the queue
---@param hookInfo? HookInfo
---@return boolean
local function IsHookInfoInQueue(hookInfo)
    if hookInfo and HooksManager.hooksQueue and HooksManager.hooksQueue.items then
        for index, value in ipairs(HooksManager.hooksQueue.items) do
            if hookInfo == value then
                return true
            end
        end
    end

    return false
end

---@param functionName string
---@return HookInfo|nil
function HooksManager:GetHookInfo(functionName)
    local hookInfo = self.hooks[functionName]
    if not IsActiveHook(hookInfo) then return nil end

    return self.hooks[functionName]
end

---@param functionName string
---@param hookInfo HookInfo
---@return HookInfo
local function SetHookInfo(functionName, hookInfo)
    HooksManager.hooks[functionName] = hookInfo
    return hookInfo
end

---Register a hook and update HookInfo with pre and post IDs
---@param refHookInfo? HookInfo Keep in mind, that's a reference to the a table in self.hooks table
---@return HookInfo?
local function UnsafeHook(refHookInfo)
    if not refHookInfo then return nil end

    local success, preIdOrErr, postId = pcall(RegisterHook, refHookInfo.functionName, refHookInfo.preCallback, refHookInfo.postCallback)

    if success then
        refHookInfo.preId = preIdOrErr
        refHookInfo.postId = postId
    else
        refHookInfo:Reset()
        LogError("HooksManager: Failed to register hook.\nFunction:", refHookInfo.functionName, "\nError:", preIdOrErr)
    end

    return refHookInfo
end

---The function must be executed in a game thread!!!
---@param AssetPath string Asset path. Class path will be extracted from it automatically.
---@return boolean
local function PLoadAsset(AssetPath)
    if IsStringNotEmpty(AssetPath) then
        local classPath = ExtractClassPath(AssetPath)

        local success, err = pcall(LoadAsset, classPath)
        if success then
            return true
        else
            LogError("HooksManager: Failed to load asset.\nPath:", classPath, "\nError:", err)
        end
    else
        LogError("HooksManager:PLoadAsset: `AssetPath` parameter is empty or nil!")
    end

    return false
end

---Unregister a hook and reset the HookInfo
---@param refHookInfo? HookInfo Keep in mind, that's a reference to the a table in self.hooks table
---@return boolean
local function UnsafeUnhook(refHookInfo)
    if not refHookInfo then return false end

    local success, error = pcall(UnregisterHook, refHookInfo.functionName, refHookInfo.preId, refHookInfo.postId)

    if success then
        refHookInfo:Reset()
        return true
    else
        LogError("HooksManager: Failed to unregister hook.\nFunction:", refHookInfo.functionName, "\nError:", error)
        refHookInfo:Reset()
    end

    return false
end

---Callback function for the ClientRestart hook.<br>
---Goes through the `hooksQueue` and hooks the functions that were queued.
---@param Context RemoteUnrealParam APlayerController
---@param NewPawn RemoteUnrealParam APawn
local function OnClientRestart(Context, NewPawn)
    if HooksManager.hooksQueue then
        while not HooksManager.hooksQueue:IsEmpty() do
            local hookInfo = HooksManager.hooksQueue:Pop()

            if hookInfo and hookInfo.loadAsset then
                PLoadAsset(hookInfo.functionName)
            end

            UnsafeHook(hookInfo)
        end
    end
end

local clientResetPreId, clientResetPostId = nil, nil
---Hooks ClientRestart function if it's not done already
local function HookClientReset()
    if not IsValidId(clientResetPreId) then
        local success, preIdOrErr, postId = pcall(RegisterHook, "/Script/Engine.PlayerController:ClientRestart", OnClientRestart)
        if success then
            clientResetPreId = preIdOrErr
            clientResetPostId = postId
        else
            LogError("HooksManager:HookClientReset: Failed to register ClientRestart hook.\nError:", preIdOrErr)
        end
    end
end

---Hook function and register in the hook manager
---@param functionName string
---@param preCallback fun(self: UObject, ...)|nil
---@param postCallback fun(self: UObject, ...)|nil
---@return HookInfo|nil
function HooksManager:Hook(functionName, preCallback, postCallback)
    if type(functionName) ~= "string" or functionName == "" then
        LogError(
            "HooksManager:Hook: Parameter `functionName` has to be a valid string that contains full function path!")
        return nil
    end

    if type(preCallback) ~= "function" and type(postCallback) ~= "function" then
        LogError("HooksManager:Hook: Either `preCallback` or `postCallback` has to be set!")
        return nil
    end

    local hookInfo = self:GetHookInfo(functionName)

    if not IsActiveHook(hookInfo) then
        hookInfo = HookInfo.new(functionName, preCallback, postCallback)
        UnsafeHook(hookInfo)
        SetHookInfo(functionName, hookInfo)
    else
        LogWarn("HooksManager:Hook: A hook for the function already exists. It's better to use a single hook for the same function per mod!\nFunction:", functionName)
    end

    return hookInfo
end

---"Async" function that returns HookInfo reference, which will become "Active" after the hook is complete
---@param delay integer Delay in milliseconds
---@param functionName string
---@param preCallback fun(self: UObject, ...)|nil
---@param postCallback fun(self: UObject, ...)|nil
---@return HookInfo? Reference
function HooksManager:HookWithDelayAsync(delay, functionName, preCallback, postCallback)
    if type(functionName) ~= "string" or functionName == "" then
        LogError("HooksManager:HookWithDelay: Parameter `functionName` has to be a valid string that contains full function path!")
        return nil
    end

    if type(preCallback) ~= "function" and type(postCallback) ~= "function" then
        LogError("HooksManager:HookWithDelay: Either `preCallback` or `postCallback` has to be set!")
        return nil
    end

    local hookInfo = self:GetHookInfo(functionName)

    if IsActiveHook(hookInfo) then
        LogWarn("HooksManager:HookWithDelay: A hook for the function already exists. It's better to use a single hook for the same function per mod!\nFunction:", functionName)
        return hookInfo
    end

    hookInfo = HookInfo.new(functionName, preCallback, postCallback)
    SetHookInfo(functionName, hookInfo)

    ExecuteWithDelay(delay, function()
        UnsafeHook(hookInfo)
    end)

    return hookInfo
end

---"Async" function, registers function to a queue and returns a reference to HookInfo, which will be hooked next time `ClientRestart` is executed.
---If the `loadAsset` parameter is set to `true`, an attempt will be made to load the function's class with `LoadAsset` before hooking the function.
---@param functionName string
---@param preCallback fun(self: UObject, ...)|nil
---@param postCallback fun(self: UObject, ...)|nil
---@param loadAsset? boolean
---@return HookInfo? Reference
function HooksManager:HookOnClientRestartAsync(functionName, preCallback, postCallback, loadAsset)
    if type(functionName) ~= "string" or functionName == "" then
        LogError("HooksManager:HookOnClientRestart: Parameter `functionName` has to be a valid string that contains full function path!")
        return nil
    end

    if type(preCallback) ~= "function" and type(postCallback) ~= "function" then
        LogError("HooksManager:HookOnClientRestart: Either `preCallback` or `postCallback` has to be set!")
        return nil
    end

    HookClientReset()

    local hookInfo = self:GetHookInfo(functionName)

    if IsActiveHook(hookInfo) then
        LogWarn("HooksManager:HookOnClientRestart: A hook for the function already exists. It's better to use a single hook for the same function per mod!\nFunction:", functionName)
        return hookInfo
    end

    if IsHookInfoInQueue(hookInfo) then
        LogWarn("HooksManager:HookOnClientRestart: The hook for the function is already in the queue!\nFunction:", functionName)
        return hookInfo
    end

    hookInfo = HookInfo.new(functionName, preCallback, postCallback)
    hookInfo.loadAsset = loadAsset or false

    SetHookInfo(functionName, hookInfo)
    PushToQueue(hookInfo)

    return hookInfo
end

---"Async" function, returns a reference to HookInfo, which will be hooked in the next possible game thread execution.<br>
---An attempt will be made to load the function's class with `LoadAsset` before hooking the function.
---@param functionName string
---@param preCallback fun(self: UObject, ...)|nil
---@param postCallback fun(self: UObject, ...)|nil
---@return HookInfo? Reference
function HooksManager:HookAutoLoadAssetAsync(functionName, preCallback, postCallback)
    if type(functionName) ~= "string" or functionName == "" then
        LogError("HooksManager:HookAutoLoadAssetAsync: Parameter `functionName` has to be a valid string that contains full function path!")
        return nil
    end

    if type(preCallback) ~= "function" and type(postCallback) ~= "function" then
        LogError("HooksManager:HookAutoLoadAssetAsync: Either `preCallback` or `postCallback` has to be set!")
        return nil
    end

    local hookInfo = self:GetHookInfo(functionName)

    if IsActiveHook(hookInfo) then
        LogWarn("HooksManager:HookAutoLoadAssetAsync: A hook for the function already exists. It's better to use a single hook for the same function per mod!\nFunction:", functionName)
        return hookInfo
    end

    hookInfo = HookInfo.new(functionName, preCallback, postCallback, -1, -1, true)
    SetHookInfo(functionName, hookInfo)

    ExecuteInGameThread(function()
        if hookInfo then
            PLoadAsset(hookInfo.functionName)
            UnsafeHook(hookInfo)
        end
    end)

    return hookInfo
end

---@param functionName string
---@return boolean Success
function HooksManager:UnhookByFunctionName(functionName)
    if type(functionName) ~= "string" or functionName == "" then
        LogError("HooksManager:UnhookByFunctionName: Parameter `functionName` has to be a valid string that contains full function path!")
        return false
    end

    local hookInfo = self:GetHookInfo(functionName)

    if not IsActiveHook(hookInfo) then
        LogWarn("HooksManager:UnhookByFunctionName: There is no active hook for the function:", functionName)
        return false
    end

    return UnsafeUnhook(hookInfo)
end

---@param hookInfo? HookInfo
---@return boolean Success
function HooksManager:Unhook(hookInfo)
    if not IsActiveHook(hookInfo) then
        LogError("HooksManager:Unhook: Parameter `hookInfo` has to be a valid and active HookInfo object!")
        return false
    end

    return self:UnhookByFunctionName(hookInfo.functionName)
end

return HooksManager