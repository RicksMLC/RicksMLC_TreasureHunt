-- RicksMLC_TreasureHunt stash

RicksMLC_TreasureHuntStash = {}

function RicksMLC_TreasureHuntStash.DefaultDecorator(stashMap, x, y)
    stashMap:addStamp("Circle", nil, x, y, 1, 0, 0)
    stashMap:addStamp("ArrowWest", nil, x + 10, y, 1, 0, 0)
    stashMap:addStamp(nil, "Stash_RicksMLC_TreasureMap_Text1", x + 20, y - 10, 1, 0, 0)
end

-- spawnTable is the name of the distribution in the SuburbsDistributions
function RicksMLC_TreasureHuntStash.AddStash(newStashName, x, y, barricades, zombies, mapItemName, spawnTable, customName)
    local stashMap = StashUtil.newStash(newStashName, "Map", mapItemName, "Stash_AnnotedMap")
    stashMap.buildingX = x
    stashMap.buildingY = y
    stashMap.barricades = barricades
    stashMap.zombies = zombies
    stashMap.spawnTable = spawnTable
    if customName then stashMap.customName = customName end
    -- StashUtil:addContainer(containerType,containerSprite,containerItem,room,x,y,z)
    -- NOTE: The containerItem matches with the distribution defined in RicksMLC_TreasureHuntDistributions:AddTreasureToDistribution(itemType)
    stashMap:addContainer(nil,nil,"Base.Bag_DuffelBagTINT",nil,nil,nil,nil) 
    return stashMap
end
