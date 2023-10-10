require "Items/Distributions"
require "Items/ProceduralDistributions"
require "RicksMLC_TreasureHunt"

local function makeTreasureDist()
    --DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt_Distributions makeTreasureDist() start")
    local treasureDist = {}

    for i, v in ipairs(RicksMLC_TreasureHunt.Treasures) do
        local distKey = "RicksMLC_" .. v
        treasureDist[distKey] = { Bag_DuffelBagTINT = {rolls = 8, items = {v, 200}}, junk = {rolls = 1, items = {}} }
    end
    
    --RicksMLC_SharedUtils.DumpArgs(treasureDist, 0, "RicksMLC_Scratch_Distributions makeTreasureDist() treasureDist")

    table.insert(Distributions, 2, treasureDist)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt_Distributions makeTreasureDist() end")
end

local function preDistributionMerge()
    -- Always insert at the 2nd entry - the vanilla distributions are always first.
    DebugLog.log(DebugType.Mod, "RicksMLC_Scratch_Distributions preDistributionMerge()")

    makeTreasureDist()
end

Events.OnPreDistributionMerge.Add(preDistributionMerge)