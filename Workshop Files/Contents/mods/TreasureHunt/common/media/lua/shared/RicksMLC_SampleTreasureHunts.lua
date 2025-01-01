-- RicksMLC_SampleTreasureHunts.lua
-- 
-- Static Sample for Mod Makers.  This sample is typically at startup, but the RicksMLC_TreasureHuntMgr functions can be run at any time.

-- These sample treaure hunts are provided to illustrate and instruct how to make treaure hunts.
-- Treasure Hunt Definition:
--    { Name = string,                       -- This is a unique name for the hunt - no duplicates allowed.
--      Town = nil | string,                 -- Town (optional) Name must match name in RicksMLC_MapInfo. Add custom Town with AddTown(). nil => random.
--      Barricades = {min, max} | n,         -- % Barricades. Range for random between min and max, or a single number. 0 => no barricades.
--      Zombies = {min, max} | n,            -- % chance of zombie per tile in the zombie spawn formula. A non-zero value will have at least one zombie per room.
--                                              Set to nil to have no zombies in the building.
--      Treasures = {string | {table} [, string | {table}...] }  -- TreasureList.  Comma separated list of items.  Each entry will have its own map in sequence.
--      Decorators = {string}                -- Decorator functions to add annotations to the map.  If not supplied the RicksMLC_TreasureHuntStash.DefaultDecorator is called.
--    }
--
-- The Treasures= {} can be a simple list of strings or fine-grained entries.
-- A fine-grained entry is a more detailed definition of a treasure map which consists of an Item=itemType and 
--
-- Decorators: The map generator calls a callback function which the RicksMLC_TreasureHunt:AddStashMap will call
-- to decorate the map with custom annotations.
--
-- The Decorator function takes the stashMap as an argument to decorate, using the vanilla StashUtils calls to addStamp() and addContainer().
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
-- Note: More custom symbols can be added to the map by calling:
--          MapSymbolDefinitions.getInstance():addTexture("ArrowWest", "media/ui/LootableMaps/map_arrowwest.png")
--
---------------------------------------
--  TODO: Implement the updated format:
--  {
--      {Item="BorisBadger", Decorator=myDecoratorFunction},
--  }
--
--
-- Change #1: Treasure can spawn in a specified building or location:
--  {
--      {Item="BorisBadger"},                               -- Random building in random Town
--      {Item="FluffyfootBunny", Town=townName},            -- Random building in specific Town
--      {Item="FreddyFox", BuildingX = x, BuildingY = y},   -- Specific building.
--      {Item="FurbertSquirrel", X = x, Y = y, Z = z},      -- Stash container at that specific square.  The building set will be for that square.
--  }
--
--
-- Town:
--      A Town consists of the bounds of the town from x1, y1 to x2, y2 and the map image data.  For vanilla map regions
--      use the default RicksMLC_MapUtils.DefaultMap() ie: 'media/maps/Muldraugh, KY'.  If the treasure is in a Mod map
--      use the string 'media/maps/<modMapName>'.  For example, the Greenport Mod map name is 'media/maps/Greenport'
--
-- Change #3: Add more than one item to the treasure loot.  The "treasure" is still a single item, but other items can be found.
--      Perhaps use the junk = {rolls = 1, items = {}} to fill in other items in RicksMLC_TreasureHuntDistributions.lua

require "RicksMLC_MapUtils"
require "RicksMLC_TreasureHuntMgr"
require "Definitions/MapSymbolDefinitions"

RicksMLC_SampleTreasureHunts = {}

-- Optional Custom decorator functions to annotate each treaure map.
-- These functions must be registered with the RicksMLC_MapDecorators.Instance():Register(name, fn)
-- so they can be used when the map is generated.
-- Note: Setting a custom decorator replaces the call to the default decorator, but you can call the default here if you need it.
function RicksMLC_SampleTreasureHunts.GenMagDecorator(stashMap, stashX, stashY)
    -- If you want to still have the default decorator (circle icon on building and "<- look here") call the default:
    RicksMLC_TreasureHuntStash.DefaultDecorator(stashMap, stashX, stashY)

    -- Default symbols can be found in shared/Definitions/MapSymbolDefinitions.lua
    -- You can add your own .png textures to make the map really custom with your own symbols - see AddCustomTextures()
    stashMap:addStamp("Plonkies", nil, stashX - 100, stashY - 100, 0.75, 0.75, 0.75) -- symbol,text,mapX,mapY,r,g,b
    -- Add your own custom annotations.
    stashMap:addStamp(nil, "I think there will be Plonkies!", stashX - 80, stashY - 100, 0.2, 0.75, 0.25) -- symbol,text,mapX,mapY,r,g,b
    -- If the text matches a translation key, it will use the translated text:  See shared/Translate/EN/Stash_EN.txt
    stashMap:addStamp(nil, "Stash_RicksMLC_SampleMap_Text1", stashX - 80, stashY - 80, 0.8, 0.2, 0.5)
end

local function AddCustomTextures()
    -- You can add your own .png textures to make the map really custom with your own symbols
    MapSymbolDefinitions.getInstance():addTexture("Plonkies", "media/ui/LootableMaps/plonkies64.png")
end

local purple = {r = 0.8, g = 0.2, b = 0.5}

function RicksMLC_SampleTreasureHunts.FluffyFootDecorator(stashMap, x, y)
    stashMap:addStamp("Heart", nil, x, y, purple.r, purple.g, purple.b)
    stashMap:addStamp(nil, "I just love FluffyFoot! - maybe there is one here?", x + 20, y, purple.r, purple.g, purple.b)
end

function RicksMLC_SampleTreasureHunts.MetalworkKitDecorator(stashMap, x, y)
    stashMap:addStamp("Target", nil, x, y, 0, 0, 0.75)
    stashMap:addStamp(nil, "You'll need this", x + 20, y, 0, 0, 0.75)
    stashMap:addContainer(nil,nil,"EmptySandbag",nil, nil, nil, nil)
end

function RicksMLC_SampleTreasureHunts.MetalworkKitDecorator2(stashMap, x, y)
    stashMap:addStamp("Target", nil, x, y, 0, 0, 0.75)
    stashMap:addStamp(nil, "Oops... you will need this too", x + 20, y, 0, 0, 0.75)
end

local function RandomOffset(min, max)
    local n = (ZombRand(1, 100) <= 50 and 1) or -1
    return ZombRand(min, max) * n
end

local function DrawCoffeeStain(mapUI, x, y, visualDecoratorData)
    local scale = 1
    local layerName = "legend"
    local tex = "media/textures/worldMap/CoffeeStain2.png"

    -- Randomise the location of the coffee stain - Note this makes one only on the first pass through this function
    if not visualDecoratorData or not visualDecoratorData.CoffeeStain then
        visualDecoratorData = visualDecoratorData or {}
        local alpha = ZombRand(2, 6) / 10
        visualDecoratorData.CoffeeStain = { X = x + RandomOffset(100, 500), Y = y + RandomOffset(100, 400), Alpha = alpha }
    end
    RicksMLC_MapUtils.OverlayPNG(mapUI, visualDecoratorData.CoffeeStain.X, visualDecoratorData.CoffeeStain.Y, scale, layerName, tex, visualDecoratorData.CoffeeStain.Alpha)    
    return visualDecoratorData
end

-- Visual decorators can be used to add effects to the map, and record where they are so 
-- they are in the same place the next time the map is opened.  Update the visualDecoratorData 
-- and return it so the TreasureHunt will remember it.
-- NOTE: All visual decorators MUST return the visualDecoratorData argument, even if no changes are made to its contents.
local function SampleVisualDecorator(mapUI, x, y, visualDecoratorData)
    visualDecoratorData = DrawCoffeeStain(mapUI, x, y, visualDecoratorData)
    return visualDecoratorData
end

local function RegisterMapDecorators()
    RicksMLC_MapDecorators.Instance():Register("FluffyFootDecorator", RicksMLC_SampleTreasureHunts.FluffyFootDecorator)
    RicksMLC_MapDecorators.Instance():Register("SampleGenMagDecorator", RicksMLC_SampleTreasureHunts.GenMagDecorator)
    RicksMLC_MapDecorators.Instance():Register("MetalworkKitDecorator", RicksMLC_SampleTreasureHunts.MetalworkKitDecorator)
    RicksMLC_MapDecorators.Instance():Register("MetalworkKitDecorator2", RicksMLC_SampleTreasureHunts.MetalworkKitDecorator2)
    RicksMLC_MapDecorators.Instance():Register("SampleVisualDecorator", SampleVisualDecorator)
end

----
-- A distribution format (Basic SuburbsDistribution):
--      containerName = {rolls = n, items = {itemName, nProbability, itemName, nProbability ... }, junk = {rolls = 1, items = {}}}
--
-- For a procedural distribution the SuburbsDistribution format is:
--      containerName = {procedural = true, procList = { name = proceduralName, min=m, max=n, weightChance=o }}
-- eg:  crate = { procedural = true, procList = { name="CrateAntiqueStove", min=0, max=1, weightChance=5 } }
-- 
-- The ProceduralDistribution has the same format as the SuburbsDistribution basic format with a proceduralName instead of a containerName
--      proceduralName = {rolls = n, items = {itemName, nProbability, itemName, nProbability ... }, junk = {rolls = 1, items = {}}}
--
-- eg: CrateAntiqueStove = { rolls = 1, items = { "Mov_AntiqueStove", 100000, }, junk = { rolls = 1, items = {}}}
----

-- Treasure Hunt Definitions: 
-- The SuburbsDistributionsDefns are the same format as the vanilla SuburbsDistributions and the ProceduralDistributionsDefns are
-- the same format as the ProceduralDistributions.
-- The ProceduralDefns is a hybrid format which makes the Procs for each of the defined Containers.
RicksMLC_SampleTreasureHunts.TreasureHuntDefinitions = {
    {Name = "Spiffo And Friends", Town = nil, Barricades = {1, 100}, Zombies = {3, 15}, Treasures = {
        {Item = "BorisBadger", VisualDecorator = "SampleVisualDecorator"},
        "FluffyfootBunny",
        "FreddyFox",
        "FurbertSquirrel",
        "JacquesBeaver",
        "MoleyMole",
        "PancakeHedgehog",
        "Spiffo" },
        Decorators = {[2] = "FluffyFootDecorator"}
    },

--  FIXME: Commented out test map. Uncomment to have a test spawn map:
--    { Name = "TEST_MAPSPAWN", Treasures = {"Mov_MannequinFemale"}, Mode = "ChaosRace" },

    -- FIXME: Comment out for now to limit the test to Spiffo and Friends
    --{Name = "Maybe Helpful", Town = "SampleEkronTown", Barricades = 90, Zombies = 30, Treasures = {"ElectronicsMag4"}, Decorators = {[1] = "SampleGenMagDecorator"}}, -- GenMag
    -- {Name = "Metalworker Kit", 
    --  Barricades = 60,
    --  Town = "Rosewood",
    --  Treasures = {
    --     {Item = "BlowTorch", 
    --      Town = "Westpoint",
    --      Decorator = "MetalworkKitDecorator",
    --      VisualDecorator = "SampleVisualDecorator",
    --      SuburbsDisributionsDefns = {
    --             EmptySandbag = {rolls = 2, items = {"Acorn", 200000}, junk = {rolls = 1, items = {}}} ,
    --             wardrobe = {rolls = 3, items = {"Banjo", 100, "Hat_Fedora_Delmote", 20 }, junk = {rolls = 1, items = {}}}
    --         },
    --      ProceduralDistributionDefns = {
    --             RicksMLC_HandyThings = {rolls = 2, items = {"HandScythe", 200, "Yoghurt", 2000 }, junk = {rolls = 1, items = {}}},
    --         },
    --      ProceduralDefns = {
    --             {
    --                 Containers = {"crate", "metal_shelves", "shelves", "filingcabinet", "dresser"}, 
    --                 Procs = {{name="CrateMetalwork", min=1, max=9, weightChance=20}, 
    --                          {name="RicksMLC_HandyThings", min=1, max=3, weightChance=10}}
    --             },
    --             {
    --                 Containers = {"fridge"}, -- Note: freezer doesn't populate or requires real frozen food?
    --                 Procs = {{name="ArmyStorageGuns", min=1, max=2, weightChance=20},
    --                          {name="RicksMLC_HandyThings", min=1, max=7, weightChance=40},
    --                          {name="KitchenDryFood", min=1, max=2, weightChance=20}}
    --             }
    --         },
    --     },
    --     {Item = "WeldingMask", 
    --      Town = {"Louisville", MapNum = 1},
    --      Zombies = 5,
    --      Barricades = 60,
    --      Decorator = "MetalworkKitDecorator2", ProceduralDefns = {{Containers = {"cabinet"}, Procs = {{name=RicksMLC_HandyThings, min=1, max=1}}}}}
    --  }
    -- }
}

-- Optional example to add a custom Town to the list of possible towns.
local function AddSampleTownToTreasureHunt()
    DebugLog.log(DebugType.Mod, "RicksMLC_SampleTreasureHunts AddSampleTownToTreasureHunt()")
    local bounds = {6900, 8000, 7510, 8570, RicksMLC_MapUtils.DefaultMap()} -- Town bounds and map name
    RicksMLC_MapUtils.AddTown("SampleEkronTown", bounds)
end

-- Treasure Hunt PreInit event subscriber. Typically use this event to register map decorators and add custom Towns.
local function PreInitTreasureHunt()
    AddCustomTextures()
    RegisterMapDecorators()
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

