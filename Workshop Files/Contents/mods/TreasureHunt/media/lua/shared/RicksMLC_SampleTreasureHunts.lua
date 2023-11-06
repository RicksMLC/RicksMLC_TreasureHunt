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
-- Change #1: Treasure can spawn in a specified building or location:
--  {
--      {Item="BorisBadger"},                               -- Random building in random Town
--      {Item="FluffyfootBunny", Town=townName},            -- Random building in specific Town
--      {Item="FreddyFox", BuildingX = x, BuildingY = y},   -- Specific building.
--      {Item="FurbertSquirrel", X = x, Y = y, Z = z},      -- Stash container at that specific square.  The building set will be for that square.
--  }
--
-- Change #2: To annotations: The caller can specify a callback function which the RicksMLC_TreasureHunt:AddStashMap will call
-- to decorate the map with custom annotations.
--  {
--      {Item="BorisBadger", Decorator=myDecoratorFunction},
--  }
--
-- The Decorator function takes the stashMap as an argument to decorate with the vanilla StashUtils calls to addStamp() and addContainer()
-- Params: stashMap: The stashMap to call addStamp() and addContainer().  x,y: Stash location.
--      function MyDecoratorFn(stashMap, x, y)
--          stashMap:addStamp("ArrowWest", nil, x+10, y, 1, 0, 0) -- The last three args are R G B colors between 0 and 1.
--          stashMap:addStamp(nil, "Don't, whatever you do, look in here!", x+20, y+10, 1, 0, 0)
--          stashMap:addStamp(nil, "Why not?", x+30, y-10, 0.25, 0.75, 0.1)
--          stashMap:addContainer( ...some custom distribution container goes here... )
--      end
-- Note: The StashUtil:addContainer(containerType,containerSprite,containerItem,room,x,y,z) call is used to connect to the distribution.
-- The containerItem matches with the distribution defined in RicksMLC_TreasureHuntDistributions:AddTreasureToDistribution(itemType)
--
-- Note: More custom symbols can be added by calling:
--       MapSymbolDefinitions.getInstance():addTexture("ArrowWest", "media/ui/LootableMaps/map_arrowwest.png")
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
