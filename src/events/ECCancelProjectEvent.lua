ECCancelProjectEvent = {}
local ECCancelProjectEvent_mt = Class(ECCancelProjectEvent, Event)
InitEventClass(ECCancelProjectEvent, "ECCancelProjectEvent")

function ECCancelProjectEvent.emptyNew()
    return Event.new(ECCancelProjectEvent_mt)
end

function ECCancelProjectEvent.new(projectId, refundAmount)
    local self = ECCancelProjectEvent.emptyNew()
    self.projectId = projectId
    self.refundAmount = refundAmount or 0
    return self
end

function ECCancelProjectEvent:readStream(streamId, connection)
    self.projectId = streamReadInt32(streamId)
    self.refundAmount = streamReadFloat32(streamId)
    self:run(connection)
end

function ECCancelProjectEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.projectId)
    streamWriteFloat32(streamId, self.refundAmount)
end

function ECCancelProjectEvent:run(connection)
    local manager = g_currentMission.ecProjectManager
    if manager == nil then
        return
    end

    if not connection:getIsServer() then
        local refund = manager:cancelProject(self.projectId)
        if refund == nil then
            return
        end
    else
        manager:onProjectCancelledOnClient(self.projectId, self.refundAmount)

        local formattedRefund = g_i18n:formatMoney(self.refundAmount, 0, true, true)
        g_currentMission:addGameNotification("", g_i18n:getText("ec_cancelled"):format(formattedRefund))
    end
end
