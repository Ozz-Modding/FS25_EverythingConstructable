ECAdvancePhaseEvent = {}
local ECAdvancePhaseEvent_mt = Class(ECAdvancePhaseEvent, Event)
InitEventClass(ECAdvancePhaseEvent, "ECAdvancePhaseEvent")

function ECAdvancePhaseEvent.emptyNew()
    return Event.new(ECAdvancePhaseEvent_mt)
end

function ECAdvancePhaseEvent.new(projectId, newPhaseIndex, totalPaid)
    local self = ECAdvancePhaseEvent.emptyNew()
    self.projectId = projectId
    self.newPhaseIndex = newPhaseIndex
    self.totalPaid = totalPaid
    return self
end

function ECAdvancePhaseEvent:readStream(streamId, connection)
    self.projectId = streamReadInt32(streamId)
    self.newPhaseIndex = streamReadInt32(streamId)
    self.totalPaid = streamReadFloat32(streamId)
    self:run(connection)
end

function ECAdvancePhaseEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.projectId)
    streamWriteInt32(streamId, self.newPhaseIndex)
    streamWriteFloat32(streamId, self.totalPaid)
end

function ECAdvancePhaseEvent:run(connection)
    local manager = g_currentMission.ecProjectManager
    if manager == nil then
        return
    end

    if connection:getIsServer() then
        manager:onPhaseAdvancedOnClient(self.projectId, self.newPhaseIndex, self.totalPaid)
    end
end
