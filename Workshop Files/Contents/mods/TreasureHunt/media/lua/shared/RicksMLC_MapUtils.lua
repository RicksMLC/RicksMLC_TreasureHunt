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

