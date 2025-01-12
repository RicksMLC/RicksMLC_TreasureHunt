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

RicksMLC_MapInfo.Ekron = {263, 9271, 1201, 10065, defaultMap}
RicksMLC_MapInfo.Irvington = {1725, 13089, 3159, 14957, defaultMap}
RicksMLC_MapInfo.EchoCreek = {3381, 10687, 4429, 11765, defaultMap}
RicksMLC_MapInfo.Brandenburg = {1146, 5403, 2852, 6428, defaultMap}
RicksMLC_MapInfo.FallusLake = {7061, 8111, 7510, 8562, defaultMap}