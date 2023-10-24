-- RicksMLC_MapUtils.lua

-- It's annoying that the map details are hard-coded, so here is a summary:

-- Copied from client/ISUI/Maps/ISMapDefinitions.lua
-- Louisville co-ordinates.  
local LVx = 11700
local LVy = 900
local LVw = 300 * 4
local LVh = 300 * 4
local LVdx = 300 * 3
local LVdy = 300 * 3
local LVbadgeHgt = 150
local function lvGridX1(col)
	return LVx + LVdx * col
end
local function lvGridY1(row)
	return LVy + LVdy * row - LVbadgeHgt
end
local function lvGridX2(col)
	return lvGridX1(col) + LVw - 1
end
local function lvGridY2(row)
	return lvGridY1(row) + LVh - 1 + LVbadgeHgt
end

local defaultMap = 'media/maps/Muldraugh, KY'
RicksMLC_MapInfo = {}
RicksMLC_MapInfo.Louisville = {}
RicksMLC_MapInfo.Louisville.LouisvilleMap1 = {lvGridX1(0), lvGridY1(0), lvGridX2(0), lvGridY2(0), defaultMap}
RicksMLC_MapInfo.Louisville.LouisvilleMap2 = {lvGridX1(1), lvGridY1(0), lvGridX2(1), lvGridY2(0), defaultMap}
RicksMLC_MapInfo.Louisville.LouisvilleMap3 = {lvGridX1(2), lvGridY1(0), lvGridX2(2), lvGridY2(0), defaultMap}
RicksMLC_MapInfo.Louisville.LouisvilleMap4 = {lvGridX1(0), lvGridY1(1), lvGridX2(0), lvGridY2(1), defaultMap}
RicksMLC_MapInfo.Louisville.LouisvilleMap5 = {lvGridX1(1), lvGridY1(1), lvGridX2(1), lvGridY2(1), defaultMap}
RicksMLC_MapInfo.Louisville.LouisvilleMap6 = {lvGridX1(2), lvGridY1(1), lvGridX2(2), lvGridY2(1), defaultMap}
RicksMLC_MapInfo.Louisville.LouisvilleMap7 = {lvGridX1(0), lvGridY1(2), lvGridX2(0), lvGridY2(2), defaultMap}
RicksMLC_MapInfo.Louisville.LouisvilleMap8 = {lvGridX1(1), lvGridY1(2), lvGridX2(1), lvGridY2(2), defaultMap}
RicksMLC_MapInfo.Louisville.LouisvilleMap9 = {lvGridX1(2), lvGridY1(2), lvGridX2(2), lvGridY2(2), defaultMap}

RicksMLC_MapInfo.Muldraugh = {10540, 9240, 11217, 10696, defaultMap}
RicksMLC_MapInfo.Rosewood = {7900, 11140, 8604, 12139, defaultMap}
RicksMLC_MapInfo.Riverside = {6000, 5035, 6899, 5669, defaultMap}
RicksMLC_MapInfo.Westpoint = {10820, 6500, 12389, 7469, defaultMap}
RicksMLC_MapInfo.MarchRidge = {9700, 12470, 10579, 13199, defaultMap}
RicksMLC_MapInfo.FallusLake = {6900, 8000, 7510, 8570, defaultMap}

RicksMLC_MapInfo.SpecialCase = {6416, 5420, 6467, 5476, defaultMap} -- Riverside school

-- Work around for the barricade buildings fault in the vanilla code
-- Key is buildingX concat buildingY
RicksMLC_MapInfo.NoBarricadeBuildings = {{x = 6442, y = 5448}} -- Riverside school

function RicksMLC_MapInfo.AddTown(townName, boundsList)
    RicksMLC_MapInfo[townName] = boundsList
end

local function CountTowns()
    local n = 0
    local mapInfo = RicksMLC_MapInfo
    for k, v in pairs(RicksMLC_MapInfo) do
        n = n + 1
    end
    return n
end

local numTowns = CountTowns()

-----------------------------------------------------------
RicksMLC_MapUtils = {}

function RicksMLC_MapUtils.IsNoBarricadeBuilding(buildingCentreX, buildingCentreY)
    for i, buildingXY in ipairs(RicksMLC_MapInfo.NoBarricadeBuildings) do
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

