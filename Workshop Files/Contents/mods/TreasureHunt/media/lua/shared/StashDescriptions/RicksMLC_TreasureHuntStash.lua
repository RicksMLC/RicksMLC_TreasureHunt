-- RicksMLC_TreasureHunt stash
require "StashDescriptions/StashUtil"
require "../server/Items/Distributions"


local function dumpStash(stashMap)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntStash.AddStash() spawnTable " .. stashMap.spawnTable)
    local dist = SuburbsDistributions

    local tmpTable = dist[stashMap.spawnTable]
    if tmpTable then
        RicksMLC_THSharedUtils.DumpArgs(tmpTable, 0, "SuburbsDistributions stashMap.spawnTable")
    end
    local tmpProcTable = ProceduralDistributions.list[stashMap.spawnTable .. "Proc"]
    if tmpProcTable then
        RicksMLC_THSharedUtils.DumpArgs(tmpProcTable, 0, "stashMap.spawnTable .. Proc")
    end
end

RicksMLC_TreasureHuntStash = {}

function RicksMLC_TreasureHuntStash.AddStash(newStashName, x, y, barricades, zombies, mapItemName, itemName)

    local stashMap = StashUtil.newStash(newStashName, "Map", mapItemName, "Stash_AnnotedMap")
    stashMap.buildingX = x
    stashMap.buildingY = y
    stashMap.barricades = barricades
    stashMap.zombies = zombies
    stashMap:addStamp("Circle", nil, x, y, 1, 0, 0)
    stashMap:addStamp("ArrowWest", nil, x + 10, y, 1, 0, 0)
    stashMap:addStamp(nil, "Stash_RicksMLC_TreasureMap_Text1", stashMap.buildingX + 20, stashMap.buildingY - 10, 1, 0, 0)
    stashMap.spawnTable = "RicksMLC_" .. itemName
    stashMap:addContainer(nil,nil,"Base.Bag_DuffelBagTINT",nil,nil,nil,nil)
    dumpStash(stashMap)
    return stashMap
end
