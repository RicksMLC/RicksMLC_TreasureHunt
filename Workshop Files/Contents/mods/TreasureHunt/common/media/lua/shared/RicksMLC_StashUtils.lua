-- RicksMLC_StashUtils.lua

-- 
RicksMLC_StashUtils = {}

function RicksMLC_StashUtils.DumpContainer(mapEntryKV)
    Debuglog.log(DebugType.Mod, "    SpawnedContainer: " .. mapEntryKV:getKey() .. " value: "  .. tostring(mapEntryKV:getValue()))
end

-- FIXME: Remove at some point, or get working.
function RicksMLC_StashUtils.Dump(buildingDef, stashName, x, y)
    -- DebugLog.log(DebugType.Mod, "RicksMLC_StashUtils.Dump() : " .. stashName .. " (" .. tostring(x) .. ", " .. tostring(y) .. ")")
    -- local rooms = buildingDef:getRooms()
    -- DebugLog.log(DebugType.Mod, "  #rooms: " .. tostring(rooms:size()))
    -- for i = 0, rooms:size() - 1 do
    --     local room = rooms:get(i)
    --     local isoRoom = room:getIsoRoom()
    --     DebugLog.log(DebugType.Mod, "   Room: " .. room:getName())
    --     local spawnedContainers = room:getProceduralSpawnedContainer()
    --     if not spawnedContainers:isEmpty() then
    --         local entrySet = spawnedContainers:entrySet()
    --         local iter = entrySet:iterator()
    --         iter:forEachRemaining(RicksMLC_StashUtils.DumpContainer)
    --     end
    -- end
end


