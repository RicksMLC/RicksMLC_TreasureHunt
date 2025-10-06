-- RicksMLC_TreasureHunt stash

RicksMLC_TreasureHuntStash = {}

function RicksMLC_TreasureHuntStash.DefaultDecorator(stashMap, x, y)
    stashMap:addStamp("Circle", nil, x, y, 1, 0, 0)
    stashMap:addStamp("ArrowWest", nil, x + 10, y, 1, 0, 0)
    stashMap:addStamp(nil, "Stash_RicksMLC_TreasureMap_Text1", x + 20, y - 10, 1, 0, 0)
end

-- spawnTable is the name of the distribution in the SuburbsDistributions
-- The newStash() adds the stash to the vanilla StashDescriptions, which is used in the StashSystem load()/save() functions.
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

function RicksMLC_TreasureHuntStash.AddStashToStashSystem(stashMapName)
    -- Check if the StashSystem is initialised.
    local allStashes = StashSystem.getAllStashes()
    if allStashes == nil or allStashes:isEmpty() then
        -- Do we init, or just return to let the vanilla code init all?
        return
    end

    -- Add the new stash to the StashSystem.  This code is a similar process to the StashSystem.initAllStashes()
    for _,stashDesc in ipairs(StashDescriptions) do
        if stashDesc.name == stashMapName then
            -- Check if the stash is already in the StashSystem
            for i=0, allStashes:size()-1 do   
                local existingStash = allStashes:get(i)
                if existingStash and existingStash:getName() == stashMapName then
                    --DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntStash:AddStashToStashSystem() StashSystem already has stash: " .. stashMapName)
                    return
                end
            end
            local newStash = Stash.new(stashDesc.name)
            newStash:load(stashDesc)
            allStashes:add(newStash)

            local possibleStashes = StashSystem.getPossibleStashes()
            local stashBuilding = StashBuilding.new(stashDesc.name, stashDesc.buildingX, stashDesc.buildingY)
            possibleStashes:add(stashBuilding)

            --DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntStash:AddStashToStashSystem() Added to StashSystem: " .. stashMapName)
            return
        end
	end
end

