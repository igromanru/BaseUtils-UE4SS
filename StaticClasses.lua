
-- Static Classes --
--------------------

local Actor_Class = CreateInvalidObject()
---@return UClass
function GetStaticClassActor()
    if not Actor_Class:IsValid() then
        Actor_Class = StaticFindObject("/Script/Engine.Actor") ---@cast Actor_Class UClass
    end
    return Actor_Class
end

local SkeletalMeshActor_Class = CreateInvalidObject()
---@return UClass
function GetStaticClassSkeletalMeshActor()
    if not SkeletalMeshActor_Class:IsValid() then
        SkeletalMeshActor_Class = StaticFindObject("/Script/Engine.SkeletalMeshActor") ---@cast SkeletalMeshActor_Class UClass
    end
    return SkeletalMeshActor_Class
end

local StaticMeshComponent_Class = CreateInvalidObject()
---@return UClass
function GetStaticClassStaticMeshComponent()
    if not StaticMeshComponent_Class:IsValid() then
        StaticMeshComponent_Class = StaticFindObject("/Script/Engine.StaticMeshComponent") ---@cast StaticMeshComponent_Class UClass
    end
    return StaticMeshComponent_Class
end

local SkeletalMeshComponent_Class = CreateInvalidObject()
---@return UClass
function GetStaticClassSkeletalMeshComponent()
    if not SkeletalMeshComponent_Class:IsValid() then
        SkeletalMeshComponent_Class = StaticFindObject("/Script/Engine.SkeletalMeshComponent") ---@cast SkeletalMeshComponent_Class UClass
    end
    return SkeletalMeshComponent_Class
end