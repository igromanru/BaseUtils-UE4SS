
function GetNameNone()
    return NAME_None
end

local WaitingToStartName = NAME_None
function GetNameWaitingToStart()
    if WaitingToStartName == NAME_None then
        WaitingToStartName = FName("WaitingToStart", EFindName.FNAME_Find)
    end
    return WaitingToStartName
end

local InProgressName = NAME_None
function GetNameInProgress()
    if InProgressName == NAME_None then
        InProgressName = FName("InProgress", EFindName.FNAME_Find)
    end
    return InProgressName
end