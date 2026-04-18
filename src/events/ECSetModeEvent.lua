ECSetModeEvent = {}
local ECSetModeEvent_mt = Class(ECSetModeEvent, Event)
InitEventClass(ECSetModeEvent, "ECSetModeEvent")

function ECSetModeEvent.emptyNew()
    return Event.new(ECSetModeEvent_mt)
end

function ECSetModeEvent.new(projectId, mode)
    local self = ECSetModeEvent.emptyNew()
    self.projectId = projectId
    self.mode = mode
    return self
end

function ECSetModeEvent:readStream(streamId, connection)
    self.projectId = streamReadInt32(streamId)
    self.mode = streamReadString(streamId)
    self:run(connection)
end

function ECSetModeEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.projectId)
    streamWriteString(streamId, self.mode)
end

function ECSetModeEvent:run(connection)
    local manager = g_currentMission.ecProjectManager
    if manager == nil then
        return
    end

    manager:setProjectMode(self.projectId, self.mode)

    if not connection:getIsServer() then
        g_server:broadcastEvent(ECSetModeEvent.new(self.projectId, self.mode))
    end
end
