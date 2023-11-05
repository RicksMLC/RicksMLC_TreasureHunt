-- RicksMLC_SampleTreasureHunts.lua
-- 
-- Static Sample for Mod Makers.  This sample is typically at startup, but the RicksMLC_TreasureHuntMgr functions can be run at any time.

-- These sample treaure hunts are provided to illustrate and instruct how to make treaure hunts.
-- Treasure Hunt Definition:
--    { Name = string,                       -- This is a unique name for the hunt - no duplicates allowed.
--      Town = nil | string,                 -- Town (optional) Name must match name in RicksMLC_MapInfo. Add custom Town with AddTown(). nil => random.
--      Barricades = {min, max} | n,         -- % Barricades. Range for random between min and max, or a single number. 0 => no barricades.
--      Zombies = {min, max} | n,            -- Number of zombies in the building.  Range for random between min and max.
--      Treasures = {string [, string...] }  -- TreasureList.  Comma separated list of items.  Each item will have its own map in sequence.
--    }
--
-- Possible change: Treasure can spawn in a specified building or location:
--  {
--      {Item="BorisBadger"},                               -- Random building in random Town
--      {Item="BorisBadger", Town=townName},                -- Random building in specific Town
--      {Item="BorisBadger", BuildingX = x, BuildingY = y},   -- Specific building.
--      {Item="BorisBadger", X = x, Y = y, Z = z},                -- Stash container at that specific square.  The building set will be for that square.
--  }
--
-- Town:
--      A Town consists of the bounds of the town from x1, y1 to x2, y2 and the map image data.  For vanilla map regions
--      use the default RicksMLC_MapUtils.DefaultMap() ie: 'media/maps/Muldraugh, KY'.  If the treasure is in a Mod map
--      use the string 'media/maps/<modMapName>'.  For example, the Greenport Mod map name is 'media/maps/Greenport'

require "RicksMLC_MapUtils"
require "RicksMLC_TreasureHuntMgr"

local RicksMLC_SampleTreasureHunts = {}

RicksMLC_SampleTreasureHunts.TreasureHuntDefinitions = {
    {Name = "Spiffo And Friends", Town = nil, Barricades = {1, 100}, Zombies = {3, 15}, Treasures = {
        "BorisBadger",
        "FluffyfootBunny",
        "FreddyFox",
        "FurbertSquirrel",
        "JacquesBeaver",
        "MoleyMole",
        "PancakeHedgehog",
        "Spiffo" }},
    {Name = "Maybe Helpful", Town = "SampleEkronTown", Barricades = 90, Zombies = 30, Treasures = {"ElectronicsMag4"}}, -- GenMag
}

-- Optional example to add a custom Town to the list of possible towns.
local function AddSampleTownToTreasureHunt()
    DebugLog.log(DebugType.Mod, "AddSampleTownToTreasureHunt()")
    local bounds = {6900, 8000, 7510, 8570, RicksMLC_MapUtils.DefaultMap()} -- Town bounds and map name
    RicksMLC_MapUtils.AddTown("SampleEkronTown", bounds)
end

-- Treasure Hunt PreInit event subscriber. Typically use this event to add custom Towns.
local function PreInitTreasureHunt()
    AddSampleTownToTreasureHunt()
end

-- Treasure Hunt InitDone event subscriber.  Add Treasure Hunts after this event.
local function LoadSampleTreasureHunts()
    if SandboxVars.RicksMLC_TreasureHunt.SamplesOn then
        RicksMLC_TreasureHuntMgr.Instance():LoadTreasureHuntDefinitions(RicksMLC_SampleTreasureHunts.TreasureHuntDefinitions)
    end
end

-- RicksMLC_TreasureHunt events to subscribe to for initialisation and action:
Events.RicksMLC_TreasureHuntMgr_PreInit.Add(PreInitTreasureHunt)
Events.RicksMLC_TreasureHuntMgr_InitDone.Add(LoadSampleTreasureHunts)
