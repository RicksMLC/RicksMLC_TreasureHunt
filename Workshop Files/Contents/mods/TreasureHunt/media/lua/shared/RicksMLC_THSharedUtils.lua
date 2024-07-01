
RicksMLC_THSharedUtils = {}

function RicksMLC_THSharedUtils.is_array(t)
    return t ~= nil and type(t) == 'table' and t[1] ~= nil
end

function RicksMLC_THSharedUtils.DumpArgs(args, lvl, desc)
    if not lvl then lvl = 0 end
    if lvl == 0 then
        DebugLog.log(DebugType.Mod, "RicksMLC_THSharedUtils.DumpArgs() " .. desc .. " begin")
        if not args then DebugLog.log(DebugType.Mod, " args is nil.") return end
    end
    local argIndent = ''
    for i = 1, lvl do
        argIndent = argIndent .. "   "
    end
    if RicksMLC_THSharedUtils.is_array(args) then
        for idx, v in ipairs(args) do 
            local argStr = argIndent .. ' [' .. idx .. ']=' .. tostring(v) 
            DebugLog.log(DebugType.Mod, argStr)
            if type(v) == "table" then
                RicksMLC_THSharedUtils.DumpArgs(v, lvl + 1)
            end
        end
    elseif type(args) == "table" then
        for k, v in pairs(args) do 
            local argStr = argIndent .. ' ' .. k .. '=' .. tostring(v) 
            DebugLog.log(DebugType.Mod, argStr)
            if type(v) == "table" then
                RicksMLC_THSharedUtils.DumpArgs(v, lvl + 1)
            end
        end
    end
    if lvl == 0 then
        DebugLog.log(DebugType.Mod, "RicksMLC_THSharedUtils.DumpArgs() " .. desc .. " end")
    end
end