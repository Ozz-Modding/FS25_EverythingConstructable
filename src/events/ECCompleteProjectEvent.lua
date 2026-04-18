ECCompleteProjectEvent = {}
local ECCompleteProjectEvent_mt = Class(ECCompleteProjectEvent, Event)
InitEventClass(ECCompleteProjectEvent, "ECCompleteProjectEvent")

function ECCompleteProjectEvent.emptyNew()
    return Event.new(ECCompleteProjectEvent_mt)
end

function ECCompleteProjectEvent.new(projectId)
    local self = ECCompleteProjectEvent.emptyNew()
    self.projectId = projectId
    return self
end

function ECCompleteProjectEvent:readStream(streamId, connection)
    self.projectId = streamReadInt32(streamId)
    self:run(connection)
end

function ECCompleteProjectEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.projectId)
end

function ECCompleteProjectEvent:run(connection)
    local manager = g_currentMission.ecProjectManager
    if manager == nil then
        return
    end

    if connection:getIsServer() then
        manager:onProjectCompletedOnClient(self.projectId)

        local project = manager:getProjectById(self.projectId)
        if project ~= nil then
            local name = project:getStoreItemName()
            g_currentMission:addGameNotification("", g_i18n:getText("ec_completed"):format(name))
        end
    end
end
