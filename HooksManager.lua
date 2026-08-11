--[[
    Author: Igromanru
    Created Date: 09.08.2026
    Description: Class to automatically handle function hooks
]]

-- Important: BaseUtils.lua is required but it's currently loaded through the main.lua into global space.

local Queue = require("Queue")

---@class HookInfo
---@field functionName string
---@field preId number
---@field postId number
---@field preCallback? fun(self: UObject, ...)
---@field postCallback? fun(self: UObject, ...)
---@field loadAsset boolean
---@field IsActive fun(self: HookInfo): boolean Returns whether this hook is currently active.
---@field Reset fun(self: HookInfo)
---@field ToString fun(self: HookInfo): string
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

--- Returns HookInfo as formatted string:<br>
--- `functionName: %s,\npreId: %d,\npostId: %d,\npreCallback type: %s,\npostCallback type: %s,\nloadAsset: %s,\nIsActive: %s`
---@return string
function HookInfo:ToString()
    return string.format("functionName: %s,\npreId: %d,\npostId: %d,\npreCallback type: %s,\npostCallback type: %s,\nloadAsset: %s,\nIsActive: %s",
            self.functionName,
            self.preId,
            self.postId,
            type(self.preCallback),
            type(self.postCallback),
            tostring(self.loadAsset),
            tostring(self:IsActive()))
end

---@class HooksManager
---@field private hooks { [string]: HookInfo? }
---@field private hooksQueue Queue<HookInfo> Queue of references to HookInfo entries in `hooks` table
local HooksManager = {
    hooks = {}, -- Key is the function name/path
    hooksQueue = Queue.new()
}
HooksManager.__index = HooksManager

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

---@param hookInfo? HookInfo
---@return boolean
function HooksManager:IsHookActive(hookInfo)
    return hookInfo ~= nil and hookInfo:IsActive()
end

---@param functionName string
---@return HookInfo|nil
function HooksManager:GetHookInfo(functionName)
    local hookInfo = self.hooks[functionName]
    if not self:IsHookActive(hookInfo) then return nil end

    return self.hooks[functionName]
end

---@param functionName string
---@param hookInfo HookInfo
---@return HookInfo
local function SetHookInfo(functionName, hookInfo)
    HooksManager.hooks[functionName] = hookInfo
    return hookInfo
end

---The function must be executed in a game thread!!!
---@param AssetPath string Asset path. Class path will be extracted from it automatically.
---@return boolean
local function TryLoadAsset(AssetPath)
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

---Register a hook and update HookInfo with pre and post IDs
---@param refHookInfo? HookInfo Keep in mind, that's a reference to the a table in self.hooks table
---@return HookInfo?
local function HookByHookInfo(refHookInfo)
    if not refHookInfo then return nil end

    if refHookInfo.loadAsset then
        TryLoadAsset(refHookInfo.functionName)
    end

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

---Unregister a hook and reset the HookInfo
---@param refHookInfo? HookInfo Keep in mind, that's a reference to the a table in self.hooks table
---@param removeFromQueue? boolean If true, removes inactive hook from the queue 
---@return boolean
local function UnhookByHookInfo(refHookInfo, removeFromQueue)
    if not refHookInfo then return false end

    removeFromQueue = removeFromQueue or false

    local isHookActive = HooksManager:IsHookActive(refHookInfo)

   if removeFromQueue and HooksManager.hooksQueue:Remove(refHookInfo) and not isHookActive then
        LogInfo("HooksManager: Inactive hook was removed from queue.\nFunction:", refHookInfo.functionName)
        refHookInfo:Reset()
        return true
    end

    if not isHookActive then
        LogWarn("HooksManager: Can't unregister an inactive hook.\nFunction:", refHookInfo.functionName)
        refHookInfo:Reset()
        return false
    end

    local success, error = pcall(UnregisterHook, refHookInfo.functionName, refHookInfo.preId, refHookInfo.postId)

    if not success then
        LogError("HooksManager: Failed to unregister hook.\nFunction:", refHookInfo.functionName, "\nError:", error)
    end

    refHookInfo:Reset()

    return success
end

---Callback function for the ClientRestart hook.<br>
---Goes through the `hooksQueue` and hooks the functions that were queued.
---@param Context RemoteUnrealParam APlayerController
---@param NewPawn RemoteUnrealParam APawn
local function OnClientRestart(Context, NewPawn)
    if HooksManager.hooksQueue then
        while not HooksManager.hooksQueue:IsEmpty() do
            local hookInfo = HooksManager.hooksQueue:Pop()

            HookByHookInfo(hookInfo)
        end
    end
end

local clientResetPreId, clientResetPostId = nil, nil
---Hooks ClientRestart function if it's not done already
local function TryHookClientReset()
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

    if not self:IsHookActive(hookInfo) then
        hookInfo = HookInfo.new(functionName, preCallback, postCallback)
        HookByHookInfo(hookInfo)
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

    if self:IsHookActive(hookInfo) then
        LogWarn("HooksManager:HookWithDelay: A hook for the function already exists. It's better to use a single hook for the same function per mod!\nFunction:", functionName)
        return hookInfo
    end

    hookInfo = HookInfo.new(functionName, preCallback, postCallback)
    SetHookInfo(functionName, hookInfo)

    ExecuteWithDelay(delay, function()
        if hookInfo then
            HookByHookInfo(hookInfo)
        end
    end)

    return hookInfo
end

--- Queues a function hook to be registered during the next `ClientRestart` call.
--- If `loadAsset` is true, the system will attempt to load the function's parent class 
--- into memory (via `LoadAsset`) before attaching the hook.
---@param functionName string The full path/name of the UFunction to hook.
---@param preCallback fun(self: UObject, ...)|nil The callback to execute before the original function runs.
---@param postCallback fun(self: UObject, ...)|nil The callback to execute after the original function finishes.
---@param loadAsset? boolean If `true`, attempts to load the function's class into memory before hooking. (Default: `false`)
---@return HookInfo? hookReference A reference to the queued hook info.
function HooksManager:HookOnClientRestartAsync(functionName, preCallback, postCallback, loadAsset)
    if type(functionName) ~= "string" or functionName == "" then
        LogError("HooksManager:HookOnClientRestart: Parameter `functionName` has to be a valid string that contains full function path!")
        return nil
    end

    if type(preCallback) ~= "function" and type(postCallback) ~= "function" then
        LogError("HooksManager:HookOnClientRestart: Either `preCallback` or `postCallback` has to be set!")
        return nil
    end

    TryHookClientReset()

    local hookInfo = self:GetHookInfo(functionName)

    if self:IsHookActive(hookInfo) then
        LogWarn("HooksManager:HookOnClientRestart: A hook for the function already exists. Use a single hook for the same function per mod!\nFunction:", functionName)
        return hookInfo
    end

    if IsHookInfoInQueue(hookInfo) then
        LogWarn("HooksManager:HookOnClientRestart: A hook for the function is already in the queue!\nFunction:", functionName)
        return hookInfo
    end

    hookInfo = HookInfo.new(functionName, preCallback, postCallback)
    hookInfo.loadAsset = loadAsset or false

    SetHookInfo(functionName, hookInfo)
    PushToQueue(hookInfo)

    return hookInfo
end

--- Queues a function hook to be registered during the next available game thread execution.
---
--- Prior to registering the hook, this function will automatically attempt to load 
--- the target function's parent class into memory via `LoadAsset`.
---@param functionName string The full path/name of the UFunction to hook.
---@param preCallback fun(self: UObject, ...)|nil The callback to execute before the original function runs.
---@param postCallback fun(self: UObject, ...)|nil The callback to execute after the original function finishes.
---@return HookInfo? hookReference A reference to the queued hook info.
function HooksManager:LoadAssetAndHookAsync(functionName, preCallback, postCallback)
    if type(functionName) ~= "string" or functionName == "" then
        LogError("HooksManager:LoadAssetAndHookAsync: Parameter `functionName` has to be a valid string that contains full function path!")
        return nil
    end

    if type(preCallback) ~= "function" and type(postCallback) ~= "function" then
        LogError("HooksManager:LoadAssetAndHookAsync: Either `preCallback` or `postCallback` has to be set!")
        return nil
    end

    local hookInfo = self:GetHookInfo(functionName)

    if self:IsHookActive(hookInfo) then
        LogWarn("HooksManager:LoadAssetAndHookAsync: A hook for the function already exists. Use a single hook for the same function per mod!\nFunction:", functionName)
        return hookInfo
    end

    hookInfo = HookInfo.new(functionName, preCallback, postCallback)
    hookInfo.loadAsset = true
    SetHookInfo(functionName, hookInfo)

    ExecuteInGameThread(function()
        if hookInfo then
            HookByHookInfo(hookInfo)
        end
    end)

    return hookInfo
end

---@param functionName string
---@param removeFromQueue? boolean If true, removes inactive hook from the queue 
---@return boolean Success
function HooksManager:UnhookByFunctionName(functionName, removeFromQueue)
    if type(functionName) ~= "string" or functionName == "" then
        LogError("HooksManager:UnhookByFunctionName: Parameter `functionName` has to be a valid string that contains full function path!")
        return false
    end

    local hookInfo = self:GetHookInfo(functionName)

    return UnhookByHookInfo(hookInfo, removeFromQueue)
end

---@param hookInfo? HookInfo
---@param removeFromQueue boolean If true, removes inactive hook from the queue 
---@return boolean Success
function HooksManager:Unhook(hookInfo, removeFromQueue)
    if not hookInfo then return false end

    return self:UnhookByFunctionName(hookInfo.functionName, removeFromQueue)
end

--- Unregister all active hooks
---@param emptyQueue boolean If set to true, removes all hooks from the queue
function HooksManager:UnhookAll(emptyQueue)
    emptyQueue = emptyQueue or false

    if emptyQueue then
        self.hooksQueue:Clear()
    end

    for _, value in pairs(self.hooks) do
        UnhookByHookInfo(value)
    end
end

--- Unregister all active hooks, empty the queue and remove all HookInfo references
function HooksManager:FullReset()
    self:UnhookAll(true)

    for key in pairs(self.hooks) do
        self.hooks[key] = nil
    end
end

return HooksManager