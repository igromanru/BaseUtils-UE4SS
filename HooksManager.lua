--[[
    Author: Igromanru
    Created Date: 09.08.2026
    Description: Class to automatically handle function hooks
]]

local source = debug.getinfo(1, "S").source
local currentDir = source:match("@(.+[\\/])")
if currentDir then
    package.path = package.path .. ";" .. currentDir .. "?.lua"
    require("BaseUtils")
end

---@class HookInfo
---@field functionName string
---@field preId number
---@field postId number
---@field preCallback? fun(self: UObject, ...)
---@field postCallback? fun(self: UObject, ...)
---@field IsActive fun(self: HookInfo): boolean Returns whether this hook is currently active.
local HookInfo = {
    functionName = "",
    preId = -1,
    postId = -1,
    preCallback = nil, -- When hooking a `/Script/`-function it gets executed before the function call, otherwise always after
    postCallback = nil, -- Works only when hooking a `/Script/`-function

    IsActive = function (self)
        return false
    end
}

---@param hookInfo? HookInfo
---@return boolean
local function IsActiveHook(hookInfo)
    return hookInfo ~= nil and hookInfo:IsActive()
end

---Creates a new hook info object with default values
---@param functionName? string Default: ""
---@param preId? number Default: -1
---@param postId? number Default: -1
---@param preCallback? fun(self: UObject, ...) Default: nil
---@param postCallback? fun(self: UObject, ...) Default: nil
---@return HookInfo
local function CreateHookInfo(functionName, preId, postId, preCallback, postCallback)
    functionName = functionName or ""
    preId = preId or -1
    postId = postId or -1

    return {
        functionName = functionName,
        preId = preId,
        postId = postId,
        preCallback = preCallback,
        postCallback = postCallback,

        IsActive = function (self)
            return IsStringNotEmpty(self.functionName) and IsValidId(self.preId)
        end
    }
end

---@class HooksManager
---@field hooks { [string]: HookInfo }
---@field hooksQueue { [string]: HookInfo } Delays hooks that will be registered on ClientRestart
local HooksManager = {
    hooks = {}, -- Key is the function name/path
    hooksQueue = {}
}

---@param functionName string
---@return HookInfo|nil
function HooksManager:GetHookInfo(functionName)
    local hookInfo = self.hooks[functionName]
    if not IsActiveHook(hookInfo) then return nil end

    return self.hooks[functionName]
end

---Hook function and register in the hook manager
---@param functionName string
---@param preCallback fun(self: UObject, ...)|nil
---@param postCallback fun(self: UObject, ...)|nil
---@return HookInfo|nil
function HooksManager:Hook(functionName, preCallback, postCallback)
    if type(functionName) ~= "string" or functionName == "" then
        LogError("HooksManager:Hook: Parameter `functionName` has to be a valid string that contains full function path!")
        return nil
    end

    if type(preCallback) ~= "function" and type(postCallback) ~= "function" then
        LogError("HooksManager:Hook: Either `preCallback` or `postCallback` has to be set!")
        return nil
    end

    local hookInfo = self.hooks[functionName]
    
    if not hookInfo or hookInfo.preId < 0 then
        -- local success, error = pcall(LoadAsset, ExtractClassPath(functionName))

        local success, preIdOrErr, postId = pcall(RegisterHook, functionName, preCallback, postCallback)
        if success then
            hookInfo.functionName = functionName
            hookInfo.preId = preIdOrErr
            hookInfo.postId = postId
            hookInfo.preCallback = preCallback
            hookInfo.postCallback = postCallback
            self.hooks[functionName] = hookInfo
        else
            LogError("HooksManager:Hook: Failed to register hook.\nError:", preIdOrErr)
        end
    else
        LogWarn("HooksManager:Hook: A hook for the function already exists. It's better to use a single hook for the same function per mod!\nFunction:", functionName)
    end

    return hookInfo
end

---@param delay integer Delay in milliseconds
---@param functionName string
---@param preCallback fun(self: UObject, ...)|nil
---@param postCallback fun(self: UObject, ...)|nil
function HooksManager:HookWithDelay(delay, functionName, preCallback, postCallback)


    ExecuteWithDelay(delay, function()
        HooksManager:Hook(functionName, preCallback, postCallback)
    end)
end

---@param functionName string
---@param preCallback fun(self: UObject, ...)|nil
---@param postCallback fun(self: UObject, ...)|nil
function HooksManager:HookOnClientRestart(functionName, preCallback, postCallback)

end

---@param functionName string
---@return boolean Success
function HooksManager:UnhookByFunctionName(functionName)
    if type(functionName) ~= "string" or functionName == "" then
        LogError("HooksManager:UnhookByFunctionName: Parameter `functionName` has to be a valid string that contains full function path!")
        return false
    end

    local hookInfo = self.hooks[functionName]

    if not hookInfo then
        LogWarn("HooksManager:UnhookByFunctionName: There is no hook for the function:", functionName)
        return false
    end

    local success, error = pcall(UnregisterHook, functionName, hookInfo.preId, hookInfo.postId)
    if not success then
        LogError("HooksManager:UnhookByFunctionName: Failed to unregister hook.\nError:", error)
        return false
    end

    self.hooks[functionName] = nil

    return true
end

---@param hookInfo HookInfo
---@return boolean Success
function HooksManager:Unhook(hookInfo)
    if not hookInfo or type(hookInfo.functionName) ~= "string" then
        LogError("HooksManager:Unhook: Parameter `hookInfo` has to be a valid object of type `HookInfo` and contain the key `functionName`!")
        return false
    end

    return self:UnhookByFunctionName(hookInfo.functionName)
end

return HooksManager