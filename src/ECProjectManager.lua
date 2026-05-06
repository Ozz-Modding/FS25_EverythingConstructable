ECProjectManager = {}
local ECProjectManager_mt = Class(ECProjectManager)

function ECProjectManager.new()
    local self = setmetatable({}, ECProjectManager_mt)
    self.projects = {}
    self.nextProjectId = 1
    self.isServer = false
    return self
end

function ECProjectManager:init()
    self.isServer = g_currentMission:getIsServer()

    if self.isServer then
        g_messageCenter:subscribe(MessageType.PERIOD_CHANGED, self.onPeriodChanged, self)
    end
end

function ECProjectManager:delete()
    g_messageCenter:unsubscribeAll(self)

    for _, project in pairs(self.projects) do
        self:cleanupProjectResources(project)
    end
    self.projects = {}
end

function ECProjectManager:cleanupProjectResources(project)
    if project.activatable ~= nil then
        g_currentMission.activatableObjectsSystem:removeActivatable(project.activatable)
        project.activatable = nil
    end

    if project.palletCollector ~= nil then
        project.palletCollector:delete()
        project.palletCollector = nil
    end
end

function ECProjectManager:createProject(farmId, storeItemXml, position, rotation, configurations, configurationData, totalPrice, displacementCosts, footprint)
    local id = self.nextProjectId
    self.nextProjectId = self.nextProjectId + 1

    local project = ECProject.new(id, farmId, storeItemXml, position, rotation, configurations, configurationData, totalPrice, displacementCosts, footprint)

    self.projects[id] = project

    if g_currentMission:getIsClient() then
        self:setupClientProject(project)
    end

    return project
end

function ECProjectManager:setupClientProject(project)
    if project.activatable == nil and not project.completed then
        project.activatable = ECConstructionActivatable.new(project)
        g_currentMission.activatableObjectsSystem:addActivatable(project.activatable)
    end

    if self.isServer and project.palletCollector == nil and not project.completed then
        local collector = ECPalletCollector.new(project)
        if collector:createTrigger() then
            project.palletCollector = collector
        end
    end
end

function ECProjectManager:getProjectById(id)
    return self.projects[id]
end

function ECProjectManager:getProjectsForFarm(farmId)
    local result = {}
    for _, project in pairs(self.projects) do
        if project.farmId == farmId and not project.completed then
            table.insert(result, project)
        end
    end
    return result
end

function ECProjectManager:onPeriodChanged()
    if not self.isServer then
        return
    end

    for _, project in pairs(self.projects) do
        if not project.completed then
            self:processProjectTick(project)
        end
    end
end

function ECProjectManager:processProjectTick(project)
    local phase = project:getCurrentPhase()
    if phase == nil or phase.completed then
        return
    end

    if project.mode == ECProject.MODE_PAUSED then
        return
    end

    self:advancePhase(project)
end

function ECProjectManager:advancePhase(project)
    local phase = project:getCurrentPhase()
    local phaseCost = project:getPhaseCost()

    local farm = g_farmManager:getFarmById(project.farmId)
    if farm == nil then
        return
    end

    if farm.money < phaseCost then
        return
    end

    if phaseCost > 0 then
        g_currentMission:addMoney(-phaseCost, project.farmId, MoneyType.SHOP_PROPERTY_BUY, true, true)
        project.totalPaid = project.totalPaid + phaseCost
    end

    phase.completed = true
    project:trimMaterials()

    if project.currentPhaseIndex >= project:getNumPhases() then
        self:completeProject(project)
    else
        project.currentPhaseIndex = project.currentPhaseIndex + 1
        g_server:broadcastEvent(ECAdvancePhaseEvent.new(project.id, project.currentPhaseIndex, project.totalPaid))
    end
end

function ECProjectManager:completeProject(project)
    project.completed = true

    self:cleanupProjectResources(project)

    ECFenceBuilder.removeFence(project)

    ECBuildingPlacer.placeBuilding(project, function(success)
        if success then
            g_server:broadcastEvent(ECCompleteProjectEvent.new(project.id))
        else
            print("EverythingConstructable: Failed to place building for project " .. project.id)
        end
    end)
end

function ECProjectManager:cancelProject(projectId)
    local project = self.projects[projectId]
    if project == nil or project.completed then
        return
    end

    local cashRefund = math.floor(project.totalPaid * ECConfig.CANCELLATION_REFUND_FRACTION)
    local materialRefund = math.floor(project.materialSuppliedValue * ECConfig.CANCELLATION_MATERIAL_REFUND_FRACTION)
    local refundAmount = cashRefund + materialRefund

    if refundAmount > 0 then
        g_currentMission:addMoney(refundAmount, project.farmId, MoneyType.SHOP_PROPERTY_SELL, true, true)
    end

    self:cleanupProjectResources(project)
    ECFenceBuilder.removeFence(project)

    project.completed = true

    if self.isServer then
        g_server:broadcastEvent(ECCancelProjectEvent.new(projectId, refundAmount))
    end

    return refundAmount
end

function ECProjectManager:setProjectMode(projectId, mode)
    local project = self.projects[projectId]
    if project == nil or project.completed then
        return
    end
    project.mode = mode
end

function ECProjectManager:deliverResource(projectId, fillTypeIndex, amount)
    local project = self.projects[projectId]
    if project == nil or project.completed then
        return 0
    end

    local delivered = 0
    for _, mat in ipairs(project.materials) do
        if mat.fillTypeIndex == fillTypeIndex then
            local remaining = mat.amount - mat.delivered
            local toDeliver = math.min(amount, remaining)
            if toDeliver > 0 then
                mat.delivered = mat.delivered + toDeliver
                delivered = toDeliver

                local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
                if fillType ~= nil then
                    project.materialSuppliedValue = project.materialSuppliedValue + (toDeliver * (fillType.pricePerLiter or 0))
                end
            end
            break
        end
    end

    project:trimMaterials()
    return delivered
end

function ECProjectManager:onProjectCreatedOnClient(project)
    self.projects[project.id] = project
    if project.id >= self.nextProjectId then
        self.nextProjectId = project.id + 1
    end
    self:setupClientProject(project)
end

function ECProjectManager:onPhaseAdvancedOnClient(projectId, newPhaseIndex, totalPaid)
    local project = self.projects[projectId]
    if project == nil then
        return
    end

    for i = 1, newPhaseIndex - 1 do
        if self.projects[projectId].phases[i] ~= nil then
            self.projects[projectId].phases[i].completed = true
        end
    end

    project.currentPhaseIndex = newPhaseIndex
    project.totalPaid = totalPaid
    project:trimMaterials()
end

function ECProjectManager:onProjectCompletedOnClient(projectId)
    local project = self.projects[projectId]
    if project == nil then
        return
    end

    project.completed = true
    self:cleanupProjectResources(project)
end

function ECProjectManager:onProjectCancelledOnClient(projectId, refundAmount)
    local project = self.projects[projectId]
    if project == nil then
        return
    end

    project.completed = true
    self:cleanupProjectResources(project)
end

function ECProjectManager:saveToXMLFile(xmlFile)
    local i = 0
    for _, project in pairs(self.projects) do
        local key = string.format("EverythingConstructable.projects.project(%d)", i)
        project:saveToXML(xmlFile, key)
        i = i + 1
    end
    setXMLInt(xmlFile, "EverythingConstructable#nextProjectId", self.nextProjectId)
end

function ECProjectManager:loadFromXMLFile(xmlFile)
    self.nextProjectId = getXMLInt(xmlFile, "EverythingConstructable#nextProjectId") or 1
    self.projects = {}

    local i = 0
    while true do
        local key = string.format("EverythingConstructable.projects.project(%d)", i)
        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local project = ECProject.loadFromXML(xmlFile, key)
        if project ~= nil then
            self.projects[project.id] = project
            if project.id >= self.nextProjectId then
                self.nextProjectId = project.id + 1
            end
        end
        i = i + 1
    end
end

function ECProjectManager:writeInitialClientState(streamId, connection)
    local activeProjects = {}
    for _, project in pairs(self.projects) do
        if not project.completed then
            table.insert(activeProjects, project)
        end
    end

    streamWriteInt32(streamId, #activeProjects)
    for _, project in ipairs(activeProjects) do
        project:writeStream(streamId)
    end
    streamWriteInt32(streamId, self.nextProjectId)
end

function ECProjectManager:readInitialClientState(streamId, connection)
    local numProjects = streamReadInt32(streamId)
    for _ = 1, numProjects do
        local project = ECProject.readStream(streamId)
        if project ~= nil then
            self.projects[project.id] = project
            self:setupClientProject(project)
        end
    end
    self.nextProjectId = streamReadInt32(streamId)
end
