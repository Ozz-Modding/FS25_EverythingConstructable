ECCreateProjectEvent = {}
local ECCreateProjectEvent_mt = Class(ECCreateProjectEvent, Event)
InitEventClass(ECCreateProjectEvent, "ECCreateProjectEvent")

function ECCreateProjectEvent.emptyNew()
    return Event.new(ECCreateProjectEvent_mt)
end

function ECCreateProjectEvent.new(project)
    local self = ECCreateProjectEvent.emptyNew()
    self.project = project
    return self
end

function ECCreateProjectEvent:readStream(streamId, connection)
    self.project = ECProject.readStream(streamId)
    self:run(connection)
end

function ECCreateProjectEvent:writeStream(streamId, connection)
    self.project:writeStream(streamId)
end

function ECCreateProjectEvent:run(connection)
    if self.project == nil then
        return
    end

    local manager = g_currentMission.ecProjectManager
    if manager == nil then
        return
    end

    if not connection:getIsServer() then
        manager.projects[self.project.id] = self.project
        if self.project.id >= manager.nextProjectId then
            manager.nextProjectId = self.project.id + 1
        end

        ECFenceBuilder.buildFence(self.project)

        local deposit = self.project.depositAmount + self.project.displacementCosts
        g_currentMission:addMoney(-deposit, self.project.farmId, MoneyType.SHOP_PROPERTY_BUY, true, true)

        manager:setupClientProject(self.project)

        g_server:broadcastEvent(ECCreateProjectEvent.new(self.project))
    else
        manager:onProjectCreatedOnClient(self.project)
    end
end
