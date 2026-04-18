ECResourceDeliveredEvent = {}
local ECResourceDeliveredEvent_mt = Class(ECResourceDeliveredEvent, Event)
InitEventClass(ECResourceDeliveredEvent, "ECResourceDeliveredEvent")

function ECResourceDeliveredEvent.emptyNew()
    return Event.new(ECResourceDeliveredEvent_mt)
end

function ECResourceDeliveredEvent.new(projectId, fillTypeIndex, amount)
    local self = ECResourceDeliveredEvent.emptyNew()
    self.projectId = projectId
    self.fillTypeIndex = fillTypeIndex
    self.amount = amount
    return self
end

function ECResourceDeliveredEvent:readStream(streamId, connection)
    self.projectId = streamReadInt32(streamId)
    self.fillTypeIndex = streamReadInt32(streamId)
    self.amount = streamReadFloat32(streamId)
    self:run(connection)
end

function ECResourceDeliveredEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.projectId)
    streamWriteInt32(streamId, self.fillTypeIndex)
    streamWriteFloat32(streamId, self.amount)
end

function ECResourceDeliveredEvent:run(connection)
    local manager = g_currentMission.ecProjectManager
    if manager == nil then
        return
    end

    manager:deliverResource(self.projectId, self.fillTypeIndex, self.amount)

    if not connection:getIsServer() then
        g_server:broadcastEvent(ECResourceDeliveredEvent.new(self.projectId, self.fillTypeIndex, self.amount))
    end
end
