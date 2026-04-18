ECInitialClientStateEvent = {}
local ECInitialClientStateEvent_mt = Class(ECInitialClientStateEvent, Event)
InitEventClass(ECInitialClientStateEvent, "ECInitialClientStateEvent")

function ECInitialClientStateEvent.emptyNew()
    return Event.new(ECInitialClientStateEvent_mt)
end

function ECInitialClientStateEvent.new()
    return ECInitialClientStateEvent.emptyNew()
end

function ECInitialClientStateEvent:readStream(streamId, connection)
    local manager = g_currentMission.ecProjectManager
    if manager ~= nil then
        manager:readInitialClientState(streamId, connection)
    end
end

function ECInitialClientStateEvent:writeStream(streamId, connection)
    local manager = g_currentMission.ecProjectManager
    if manager ~= nil then
        manager:writeInitialClientState(streamId, connection)
    end
end
