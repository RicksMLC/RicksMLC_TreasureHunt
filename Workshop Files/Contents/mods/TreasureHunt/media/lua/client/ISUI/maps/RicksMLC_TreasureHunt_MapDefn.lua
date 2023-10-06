-- RicksMLC_TreasureHunt_MapDefn.lua

require "ISUI/Maps/ISMapDefinitions"
require "RicksMLC_TreasureHunt"
require "RicksMLC_MapUtils"

-- Note: This LootMaps.Init.GreenportRicksMLCMap function name must match the name of the item "map = " in /scripts/ricksmlcitems.txt
-- so it can connect the inventory item to the map function.

-- TODO: RicksMLCTreasureMap:
-- Make a list of treasure locations for the individual player {{Treasure, IsoBuilding chosen at random},{}}
-- Update this LootMap.Init to read the current treasure details to populate the map?
-- The treasureMap item needs to record the treasture so it can look up past treasures?
-- Or... the creation of a treasure map creates the LootMaps.Init.TreasureMapName with the details?
LootMaps.Init.RicksMLCTreasureMap = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
	MapUtils.initDefaultStyleV1(mapUI)
	replaceWaterStyle(mapUI)

	RicksMLC_TreasureHunt.setBoundsInSquares(mapAPI)
    --mapAPI:setBoundsInSquares(7970, 7130, 8869, 7889) -- Get from the Debug Map Bounds

	--overlayPNG(mapUI, 10868, 7314, 0.666, "badge", "media/textures/worldMap/WestPointBadge.png")
	--overlayPNG(mapUI, 8400, 7200, 0.333, "legend", "media/textures/worldMap/Legend.png")
	MapUtils.overlayPaper(mapUI)
--	overlayPNG(mapUI, 36*300, 21*300+190, 0.666, "lootMapPNG", "media/ui/LootableMaps/westpointmap.png", 0.5)
end
