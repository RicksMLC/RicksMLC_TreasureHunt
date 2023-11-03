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

function RicksMLC_TreasureHuntDistributions:AddTreasureToDistribution(itemType)
    DebugLog.log(DebugType.Mod, "AddTreasureToDist(itemType) Start")
    local treasureDist = {}
    local distKey = "RicksMLC_" .. itemType
    treasureDist[distKey] = { Bag_DuffelBagTINT = {rolls = 1, items = {itemType, 200000}}, junk = {rolls = 1, items = {}} }
    MergeDistributionRecursive(SuburbsDistributions, treasureDist)
    RicksMLC_THSharedUtils.DumpArgs(treasureDist, 0, "RicksMLC_Scratch_Distributions AddTreasureToDist treasureDist")

    local dist = SuburbsDistributions
    local tmpTable = dist[distKey]
    if tmpTable then
        RicksMLC_THSharedUtils.DumpArgs(tmpTable, 0, "AddTreasureToDist SuburbsDistributions '" .. distKey .. "'")
    end

    DebugLog.log(DebugType.Mod, "AddTreasureToDist(itemType) End")
end

function RicksMLC_TreasureHuntDistributions:AddTreasureListToDistribution(treasureList)
    for i, v in ipairs(treasureList) do
        self:AddTreasureToDistribution(v)
    end
end

local function postDistributionMerge()
    local defaultTreasures = {
        "BorisBadger",
        "FluffyfootBunny",
        "FreddyFox",
        "FurbertSquirrel",
        "JacquesBeaver",
        "MoleyMole",
        "PancakeHedgehog",
        "Spiffo"
    }
    RicksMLC_TreasureHuntDistributions.Instance():AddTreasureListToDistribution(defaultTreasures)
    RicksMLC_TreasureHuntDistributions.Instance():AddTreasureToDistribution("ElectronicsMag4")
end

Events.OnPostDistributionMerge.Add(postDistributionMerge)

-- FIXME: Commented Out Code: Remove if the pre distribution event is not needed.
-- local function makeTreasureDist()
--     --DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt_Distributions makeTreasureDist() start")
--     local treasureDist = {}

--     for i, v in ipairs(RicksMLC_TreasureHuntMgr.Instance().Treasures) do
--         local distKey = "RicksMLC_" .. v
--         treasureDist[distKey] = { Bag_DuffelBagTINT = {rolls = 1, items = {v, 200000}}, junk = {rolls = 1, items = {}} }
--     end
    
--     --RicksMLC_THSharedUtils.DumpArgs(treasureDist, 0, "RicksMLC_Scratch_Distributions makeTreasureDist() treasureDist")

--     table.insert(Distributions, 2, treasureDist)
--     DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt_Distributions makeTreasureDist() end")
-- end

-- local function preDistributionMerge()
--     -- Always insert at the 2nd entry - the vanilla distributions are always first.
--     DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt_Distributions preDistributionMerge()")

--     makeTreasureDist()
-- end


-- local function TestAddLoot(key)
--     if key == Keyboard.KEY_F10 then
--         AddTreasureToDist("Needle")
--     end
-- end

-- Events.OnPreDistributionMerge.Add(preDistributionMerge)

-- Events.OnKeyPressed.Add(TestAddLoot)