-- RicksMLC_TreasureHuntDistributions.lua

require "Items/Distributions"
require "Items/ProceduralDistributions"
require "RicksMLC_TreasureHuntMgr"

require "ISBaseObject"

RicksMLC_TreasureHuntDistributionsInstance = nil
RicksMLC_TreasureHuntDistributions = ISBaseObject:derive("RicksMLC_TreasureHuntDistributions");

function RicksMLC_TreasureHuntDistributions.Instance()
    if not RicksMLC_TreasureHuntDistributionsInstance then
        RicksMLC_TreasureHuntDistributionsInstance = RicksMLC_TreasureHuntDistributions:new()
    end
    return RicksMLC_TreasureHuntDistributionsInstance
end

function RicksMLC_TreasureHuntDistributions:new()
	local o = {}
	setmetatable(o, self)
	self.__index = self

    return o
end

function RicksMLC_TreasureHuntDistributions:IsInDistribution(distKey)
    local dist = SuburbsDistributions
    local tmpTable = dist[distKey]
    return tmpTable ~= nil
end

function RicksMLC_TreasureHuntDistributions:GenerateProceduralDistribuions(proceduralDefns, treasureDist, distKey)
    local procDefn = {procedural = true,  procList = {}}
    --RicksMLC_THSharedUtils.DumpArgs(proceduralDefns, 0, "procDefn init")
    for _, v in ipairs(proceduralDefns) do
        for _, proc in ipairs(v.Procs) do
            table.insert(procDefn.procList, 1, proc) --TODO: weightChance is optional
        end
        for _, v in ipairs(v.Containers) do
            treasureDist[distKey][v] = procDefn
        end
        procDefn = {procedural = true,  procList = {}}
    end
end

function RicksMLC_TreasureHuntDistributions:AddTreasureToDistribution(treasure, distKey)
    DebugLog.log(DebugType.Mod, "AddTreasureToDist(itemType) Start")
    local itemType = treasure
    local proceduralDefns = nil
    if type(treasure) == 'table' then
        -- Fine-grained treasure item defn
        itemType = treasure.Item
        proceduralDefns = treasure.ProceduralDefns
    end
    if distKey == nil then
        distKey = "RicksMLC_" .. itemType
    end
    if self:IsInDistribution(distKey) then
        DebugLog.log(DebugType.Mod, "AddTreasureToDist(itemType) distKey '" .. distKey .. "' Item '" .. itemType .. "' is already in a distribution. End")
        return
    end
    local treasureDist = {}
    treasureDist[distKey] = { Bag_DuffelBagTINT = {rolls = 1, items = {itemType, 200000}}, junk = {rolls = 1, items = {}} }
    if proceduralDefns then
        self:GenerateProceduralDistribuions(proceduralDefns, treasureDist, distKey)
    end
    MergeDistributionRecursive(SuburbsDistributions, treasureDist)
    --RicksMLC_THSharedUtils.DumpArgs(treasureDist, 0, "RicksMLC_TreasureHuntDistributions AddTreasureToDistribution treasureDist")
    local dist = SuburbsDistributions
    local tmpTable = dist[distKey]
    if tmpTable then
        RicksMLC_THSharedUtils.DumpArgs(tmpTable, 0, "AddTreasureToDist SuburbsDistributions '" .. distKey .. "'")
    end
    DebugLog.log(DebugType.Mod, "AddTreasureToDist(itemType) End")
end

function RicksMLC_TreasureHuntDistributions:AddSingleTreasureToDistribution(treasure, distName)
    self:AddTreasureToDistribution(treasure, distName)
    ItemPickerJava.Parse() -- Call Parse() to repopulate the ItemPickerJava cache so it finds the added item.
end

function RicksMLC_TreasureHuntDistributions:AddTreasureListToDistribution(treasureList, distName)
    for i, v in ipairs(treasureList) do
        self:AddTreasureToDistribution(v)
    end
    ItemPickerJava.Parse() -- Call Parse() to repopulate the ItemPickerJava cache so it finds the added item.
end

-- local function TestAddLoot(key)
--     if key == Keyboard.KEY_F10 then
--         AddTreasureToDist("Needle")
--     end
-- end

-- Events.OnKeyPressed.Add(TestAddLoot)