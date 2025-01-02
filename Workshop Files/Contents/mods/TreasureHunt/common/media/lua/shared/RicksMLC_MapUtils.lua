-- RicksMLC_MapUtils.lua

require "RicksMLC_MapInfo"

local function CountTowns()
    local n = 0
    local mapInfo = RicksMLC_MapInfo
    for k, v in pairs(RicksMLC_MapInfo) do
        n = n + 1
    end
    return n
end

--local numTowns = CountTowns()

-- Work around for the barricade buildings fault in the vanilla code
-- x,y is the centre of the building
local noBarricadeBuildings = {}
noBarricadeBuildings[1] = {x = 6442, y = 5448} -- Riverside school

-----------------------------------------------------------
RicksMLC_MapUtils = {}

local defaultMap = 'media/maps/Muldraugh, KY'
function RicksMLC_MapUtils.DefaultMap() return defaultMap end

function RicksMLC_MapUtils.AddTown(townName, boundsList)
    RicksMLC_MapInfo[townName] = boundsList
end


function RicksMLC_MapUtils.IsNoBarricadeBuilding(buildingCentreX, buildingCentreY)
    for i, buildingXY in ipairs(noBarricadeBuildings) do
        if buildingXY.x == buildingCentreX and buildingXY.y == buildingCentreY then
            return true
        end
    end
    return false
end


function RicksMLC_MapUtils.GetDefaultMapPath()
    return defaultMap
end

function RicksMLC_MapUtils.GetMapExtents(townName, mapNum)
    local mapExtents = RicksMLC_MapInfo[townName]
    if mapNum then
        mapExtents = mapExtents[townName  .. "Map" .. tostring(mapNum)]
    end
    if not mapExtents then
        DebugLog.log(DebugType.Mod, "ERROR: RicksMLC_MapUtils.GetMapExtents() No map found for Town: '" .. townName .. "' MapNum: " .. tostring(mapNum))
        return nil
    end
    return {x1 = mapExtents[1], y1 = mapExtents[2], x2 = mapExtents[3], y2 = mapExtents[4], MapPath = mapExtents[5]}
end

function RicksMLC_MapUtils.GetRandomTown()
    numTowns = CountTowns()
    local n = ZombRand(1, numTowns)
    local i = 0
    for k, v in pairs(RicksMLC_MapInfo) do
        i = i + 1
        if i == n then
            if k == "Louisville" then -- I really don't like coding for LV as a special case
                local m = ZombRand(1, 9)
                local j = 0
                for kl, v1 in pairs(v) do
                    j = j + 1
                    if j == m then
                        return {Town = k, MapNum = j}
                    end
                end
            end
            return {Town = k}
        end
    end
end

----------------------------------------------------------------

-- Copied from client/ISUI/Maps/ISMapDefinitions.lua

local MINZ = 0
local MAXZ = 24

local WATER_TEXTURE = false

function RicksMLC_MapUtils.ReplaceWaterStyle(mapUI)
	if not WATER_TEXTURE then return end
	local mapAPI = mapUI.javaObject:getAPIv1()
	local styleAPI = mapAPI:getStyleAPI()
	local layer = styleAPI:getLayerByName("water")
	if not layer then return end
	layer:setMinZoom(MINZ)
	layer:setFilter("water", "river")
	layer:removeAllFill()
	layer:removeAllTexture()
	layer:addFill(MINZ, 59, 141, 149, 255)
	layer:addFill(MAXZ, 59, 141, 149, 255)
end

function RicksMLC_MapUtils.OverlayPNG(mapUI, x, y, scale, layerName, tex, alpha)
	local texture = getTexture(tex)
	if not texture then return end
	local mapAPI = mapUI.javaObject:getAPIv1()
	local styleAPI = mapAPI:getStyleAPI()
	local layer = styleAPI:newTextureLayer(layerName)
	layer:setMinZoom(MINZ)
	layer:addFill(MINZ, 255, 255, 255, (alpha or 1.0) * 255)
	layer:addTexture(MINZ, tex)
	layer:setBoundsInSquares(x, y, x + texture:getWidth() * scale, y + texture:getHeight() * scale)
end

--------------------------------------

-- Note that AmbientStreamManager is not on the server in vanilla.
-- See function RicksMLC_TreasureHuntMgrServer.OnServerStarted() which instantiates one on the server
function RicksMLC_MapUtils.getNearestBuildingDef(x, y, ...)
    local nearestBuildingDef = AmbientStreamManager.getNearestBuilding(x, y, Vector2f.new())
end
-- Copied from java class AmbientStreamManager
-- function RicksMLC_MapUtils.getNearestBuildingDef(x, y, ...)
--     local isoWorldInstance = IsoWorld.instance
--     local metaGrid = IsoWorld.instance:getMetaGrid();
--     local targetCellX = PZMath.fastfloor(x / 300.0);
--     local targetCellY = PZMath.fastfloor(y / 300.0);
--     local buildingDef = nil;
--     local maxDist = Float.MAX_VALUE;
--     local closestXY = Vector2f:new(0, 0)
--     --closestXY:set(0.0);
--     local tmpClosestXY = Vector2f:new(1000, 1000);

--     for cellY = targetCellY - 1, targetCellY + 1 do
--         for cellX = targetCellX - 1, targetCellX + 1 do
--             local isoMetaCell = metaGrid:getCellData(cellX, cellY);
--             if (isoMetaCell ~= nil and isoMetaCell.info ~= nil) then
--                 local iterator = isoMetaCell.info.Buildings:iterator();

--                 while iterator:hasNext() do
--                     local tmpBuildingDef = iterator:next();
--                     local dist = tmpBuildingDef:getClosestPoint(x, y, tmpClosestXY);
--                     if (dist < maxDist) then
--                         maxDist = dist;
--                         buildingDef = tmpBuildingDef;
--                         closestXY:set(tmpClosestXY);
--                     end
--                 end
--             end
--         end
--     end

--     return buildingDef
-- end