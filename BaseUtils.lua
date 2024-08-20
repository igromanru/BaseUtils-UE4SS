
ModName = "BaseUtils"
ModVersion = "1.0.0"
DebugMode = false

function GetModInfoPrefix()
    return string.format("[%s v%s]", ModName, ModVersion)
end

function LogInfo(message)
    print(string.format("%s %s\n", GetModInfoPrefix(), message))
end

function LogDebug(message)
    if DebugMode then
        LogInfo(message)
    end
end

function LogError(message)
    error(string.format("%s %s\n", GetModInfoPrefix(), message))
end