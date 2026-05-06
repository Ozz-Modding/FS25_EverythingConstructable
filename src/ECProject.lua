ECProject = {}
local ECProject_mt = Class(ECProject)

ECProject.MODE_AUTOMATIC = "automatic"
ECProject.MODE_PAUSED = "paused"

function ECProject.new(id, farmId, storeItemXml, position, rotation, configurations, configurationData, totalPrice, displacementCosts, footprint)
    local self = setmetatable({}, ECProject_mt)

    self.id = id
    self.farmId = farmId
    self.storeItemXml = storeItemXml
    self.position = position or {0, 0, 0}
    self.rotation = rotation or {0, 0, 0}
    self.configurations = configurations or {}
    self.configurationData = configurationData or {}
    self.totalPrice = totalPrice or 0
    self.displacementCosts = displacementCosts or 0
    self.footprint = footprint or {}
    self.mode = ECConfig.DEFAULT_MODE
    self.completed = false

    local numMonths = ECConfig.getMonthsForPrice(self.totalPrice)
    self.depositAmount = ECConfig.getDepositAmount(self.totalPrice)
    self.totalPaid = self.depositAmount + self.displacementCosts

    local constructionCost = self.totalPrice - self.depositAmount
    self.labourPerPhase = ECConfig.getLabourPerPhase(constructionCost, numMonths)
    self.materialBudget = ECConfig.getMaterialBudget(constructionCost)
    self.materialSuppliedValue = 0

    self.materials = ECConfig.generateMaterialList(self.materialBudget)

    self.phases = {}
    for i = 1, numMonths do
        table.insert(self.phases, {
            completed = false,
        })
    end

    self.currentPhaseIndex = 1
    self.fencePlaceableId = nil
    self.activatable = nil
    self.storage = nil
    self.unloadingStation = nil

    self.startPeriod = nil
    self.startYear = nil
    if g_currentMission ~= nil and g_currentMission.environment ~= nil then
        self.startPeriod = g_currentMission.environment.currentPeriod
        self.startYear = g_currentMission.environment.currentYear or 1
    end

    return self
end

function ECProject:getCurrentPhase()
    return self.phases[self.currentPhaseIndex]
end

function ECProject:getNumPhases()
    return #self.phases
end

function ECProject:getProgress()
    local completedPhases = self.currentPhaseIndex - 1
    for i = 1, #self.phases do
        if self.phases[i].completed then
            completedPhases = i
        end
    end
    return completedPhases / #self.phases
end

function ECProject:getRemainingMaterialBudget()
    local remainingPhases = #self.phases - (self.currentPhaseIndex - 1)
    local remainingMaterialCost = math.floor(self.materialBudget / #self.phases) * remainingPhases
    return math.max(0, remainingMaterialCost - self.materialSuppliedValue)
end

function ECProject:trimMaterials()
    local remainingBudget = self:getRemainingMaterialBudget()
    if remainingBudget <= 0 then
        for _, mat in ipairs(self.materials) do
            mat.amount = mat.delivered
        end
        return
    end

    for _, mat in ipairs(self.materials) do
        local remaining = mat.amount - mat.delivered
        if remaining > 0 then
            local fillType = g_fillTypeManager:getFillTypeByIndex(mat.fillTypeIndex)
            local pricePerUnit = (fillType ~= nil) and (fillType.pricePerLiter or 0) or 0
            if pricePerUnit > 0 then
                local maxAffordable = math.floor(remainingBudget / pricePerUnit)
                local cap = mat.delivered + math.min(remaining, maxAffordable)
                mat.amount = math.max(mat.delivered, cap)
            end
        end
    end
end

function ECProject:getCostForPhase(phaseIndex)
    if self.phases[phaseIndex] == nil then
        return 0
    end
    if self.phases[phaseIndex].completed then
        return 0
    end

    local materialPerPhase = math.floor(self.materialBudget / #self.phases)
    local creditUsedBefore = materialPerPhase * (phaseIndex - 1)
    local creditAvailable = math.max(0, self.materialSuppliedValue - creditUsedBefore)
    local creditForPhase = math.min(creditAvailable, materialPerPhase)
    local materialCharge = math.max(0, materialPerPhase - creditForPhase)

    return self.labourPerPhase + materialCharge
end

function ECProject:getPhaseCost()
    return self:getCostForPhase(self.currentPhaseIndex)
end

function ECProject:getTotalRemainingCost()
    local total = 0
    for i = self.currentPhaseIndex, #self.phases do
        total = total + self:getCostForPhase(i)
    end
    return total
end

function ECProject:getStoreItemName()
    local storeItem = g_storeManager:getItemByXMLFilename(self.storeItemXml)
    if storeItem ~= nil then
        return storeItem.name or "Unknown"
    end
    return "Unknown"
end

function ECProject:saveToXML(xmlFile, key)
    setXMLInt(xmlFile, key .. "#id", self.id)
    setXMLInt(xmlFile, key .. "#farmId", self.farmId)
    setXMLString(xmlFile, key .. "#storeItemXml", self.storeItemXml)
    setXMLFloat(xmlFile, key .. "#posX", self.position[1])
    setXMLFloat(xmlFile, key .. "#posY", self.position[2])
    setXMLFloat(xmlFile, key .. "#posZ", self.position[3])
    setXMLFloat(xmlFile, key .. "#rotX", self.rotation[1])
    setXMLFloat(xmlFile, key .. "#rotY", self.rotation[2])
    setXMLFloat(xmlFile, key .. "#rotZ", self.rotation[3])
    setXMLFloat(xmlFile, key .. "#totalPrice", self.totalPrice)
    setXMLFloat(xmlFile, key .. "#depositAmount", self.depositAmount)
    setXMLFloat(xmlFile, key .. "#totalPaid", self.totalPaid)
    setXMLFloat(xmlFile, key .. "#displacementCosts", self.displacementCosts)
    setXMLString(xmlFile, key .. "#mode", self.mode)
    setXMLInt(xmlFile, key .. "#currentPhase", self.currentPhaseIndex)
    setXMLBool(xmlFile, key .. "#completed", self.completed)
    setXMLInt(xmlFile, key .. "#startPeriod", self.startPeriod or 1)
    setXMLInt(xmlFile, key .. "#startYear", self.startYear or 1)
    setXMLFloat(xmlFile, key .. "#labourPerPhase", self.labourPerPhase)
    setXMLFloat(xmlFile, key .. "#materialBudget", self.materialBudget)
    setXMLFloat(xmlFile, key .. "#materialSuppliedValue", self.materialSuppliedValue)

    if self.footprint.sizeX ~= nil then
        setXMLFloat(xmlFile, key .. ".footprint#sizeX", self.footprint.sizeX)
        setXMLFloat(xmlFile, key .. ".footprint#sizeZ", self.footprint.sizeZ)
        setXMLFloat(xmlFile, key .. ".footprint#centerX", self.footprint.centerX or 0)
        setXMLFloat(xmlFile, key .. ".footprint#centerZ", self.footprint.centerZ or 0)
        setXMLFloat(xmlFile, key .. ".footprint#rotY", self.footprint.rotY or 0)
    end

    for ci, config in pairs(self.configurations) do
        local configKey = string.format("%s.configurations.config(%d)", key, ci - 1)
        setXMLString(configKey .. "#name", ci)
        setXMLInt(configKey .. "#value", config)
    end

    for pi, phase in ipairs(self.phases) do
        local phaseKey = string.format("%s.phases.phase(%d)", key, pi - 1)
        setXMLBool(xmlFile, phaseKey .. "#completed", phase.completed)
    end

    for mi, mat in ipairs(self.materials) do
        local matKey = string.format("%s.materials.material(%d)", key, mi - 1)
        setXMLString(xmlFile, matKey .. "#fillType", mat.fillTypeName)
        setXMLFloat(xmlFile, matKey .. "#amount", mat.amount)
        setXMLFloat(xmlFile, matKey .. "#delivered", mat.delivered)
    end
end

function ECProject.loadFromXML(xmlFile, key)
    local id = getXMLInt(xmlFile, key .. "#id")
    if id == nil then
        return nil
    end

    local project = setmetatable({}, ECProject_mt)
    project.id = id
    project.farmId = getXMLInt(xmlFile, key .. "#farmId") or 1
    project.storeItemXml = getXMLString(xmlFile, key .. "#storeItemXml") or ""
    project.position = {
        getXMLFloat(xmlFile, key .. "#posX") or 0,
        getXMLFloat(xmlFile, key .. "#posY") or 0,
        getXMLFloat(xmlFile, key .. "#posZ") or 0,
    }
    project.rotation = {
        getXMLFloat(xmlFile, key .. "#rotX") or 0,
        getXMLFloat(xmlFile, key .. "#rotY") or 0,
        getXMLFloat(xmlFile, key .. "#rotZ") or 0,
    }
    project.totalPrice = getXMLFloat(xmlFile, key .. "#totalPrice") or 0
    project.depositAmount = getXMLFloat(xmlFile, key .. "#depositAmount") or 0
    project.totalPaid = getXMLFloat(xmlFile, key .. "#totalPaid") or 0
    project.displacementCosts = getXMLFloat(xmlFile, key .. "#displacementCosts") or 0
    project.mode = getXMLString(xmlFile, key .. "#mode") or ECConfig.DEFAULT_MODE
    project.currentPhaseIndex = getXMLInt(xmlFile, key .. "#currentPhase") or 1
    project.completed = getXMLBool(xmlFile, key .. "#completed") or false
    project.startPeriod = getXMLInt(xmlFile, key .. "#startPeriod") or 1
    project.startYear = getXMLInt(xmlFile, key .. "#startYear") or 1
    project.fencePlaceableId = nil
    project.activatable = nil
    project.storage = nil
    project.unloadingStation = nil
    project.labourPerPhase = getXMLFloat(xmlFile, key .. "#labourPerPhase") or 0
    project.materialBudget = getXMLFloat(xmlFile, key .. "#materialBudget") or 0
    project.materialSuppliedValue = getXMLFloat(xmlFile, key .. "#materialSuppliedValue") or 0

    project.footprint = {}
    if hasXMLProperty(xmlFile, key .. ".footprint") then
        project.footprint.sizeX = getXMLFloat(xmlFile, key .. ".footprint#sizeX") or 10
        project.footprint.sizeZ = getXMLFloat(xmlFile, key .. ".footprint#sizeZ") or 10
        project.footprint.centerX = getXMLFloat(xmlFile, key .. ".footprint#centerX") or 0
        project.footprint.centerZ = getXMLFloat(xmlFile, key .. ".footprint#centerZ") or 0
        project.footprint.rotY = getXMLFloat(xmlFile, key .. ".footprint#rotY") or 0
    end

    project.configurations = {}
    local ci = 0
    while true do
        local configKey = string.format("%s.configurations.config(%d)", key, ci)
        if not hasXMLProperty(xmlFile, configKey) then
            break
        end
        local name = getXMLString(xmlFile, configKey .. "#name")
        local value = getXMLInt(xmlFile, configKey .. "#value")
        if name ~= nil and value ~= nil then
            project.configurations[name] = value
        end
        ci = ci + 1
    end

    project.configurationData = {}

    project.phases = {}
    local pi = 0
    while true do
        local phaseKey = string.format("%s.phases.phase(%d)", key, pi)
        if not hasXMLProperty(xmlFile, phaseKey) then
            break
        end
        table.insert(project.phases, {
            completed = getXMLBool(xmlFile, phaseKey .. "#completed") or false,
        })
        pi = pi + 1
    end

    project.materials = {}
    local mi = 0
    while true do
        local matKey = string.format("%s.materials.material(%d)", key, mi)
        if not hasXMLProperty(xmlFile, matKey) then
            break
        end
        local fillTypeName = getXMLString(xmlFile, matKey .. "#fillType")
        local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
        if fillTypeIndex ~= nil then
            table.insert(project.materials, {
                fillTypeIndex = fillTypeIndex,
                fillTypeName = fillTypeName,
                amount = getXMLFloat(xmlFile, matKey .. "#amount") or 0,
                delivered = getXMLFloat(xmlFile, matKey .. "#delivered") or 0,
            })
        end
        mi = mi + 1
    end

    return project
end

function ECProject:writeStream(streamId)
    streamWriteInt32(streamId, self.id)
    streamWriteInt32(streamId, self.farmId)
    streamWriteString(streamId, self.storeItemXml)
    streamWriteFloat32(streamId, self.position[1])
    streamWriteFloat32(streamId, self.position[2])
    streamWriteFloat32(streamId, self.position[3])
    streamWriteFloat32(streamId, self.rotation[1])
    streamWriteFloat32(streamId, self.rotation[2])
    streamWriteFloat32(streamId, self.rotation[3])
    streamWriteFloat32(streamId, self.totalPrice)
    streamWriteFloat32(streamId, self.depositAmount)
    streamWriteFloat32(streamId, self.totalPaid)
    streamWriteFloat32(streamId, self.displacementCosts)
    streamWriteString(streamId, self.mode)
    streamWriteInt32(streamId, self.currentPhaseIndex)
    streamWriteBool(streamId, self.completed)
    streamWriteInt32(streamId, self.startPeriod or 1)
    streamWriteInt32(streamId, self.startYear or 1)
    streamWriteFloat32(streamId, self.labourPerPhase)
    streamWriteFloat32(streamId, self.materialBudget)
    streamWriteFloat32(streamId, self.materialSuppliedValue)

    streamWriteBool(streamId, self.footprint.sizeX ~= nil)
    if self.footprint.sizeX ~= nil then
        streamWriteFloat32(streamId, self.footprint.sizeX)
        streamWriteFloat32(streamId, self.footprint.sizeZ)
        streamWriteFloat32(streamId, self.footprint.centerX or 0)
        streamWriteFloat32(streamId, self.footprint.centerZ or 0)
        streamWriteFloat32(streamId, self.footprint.rotY or 0)
    end

    streamWriteInt32(streamId, #self.phases)
    for _, phase in ipairs(self.phases) do
        streamWriteBool(streamId, phase.completed)
    end

    streamWriteInt32(streamId, #self.materials)
    for _, mat in ipairs(self.materials) do
        streamWriteString(streamId, mat.fillTypeName)
        streamWriteFloat32(streamId, mat.amount)
        streamWriteFloat32(streamId, mat.delivered)
    end
end

function ECProject.readStream(streamId)
    local project = setmetatable({}, ECProject_mt)

    project.id = streamReadInt32(streamId)
    project.farmId = streamReadInt32(streamId)
    project.storeItemXml = streamReadString(streamId)
    project.position = {
        streamReadFloat32(streamId),
        streamReadFloat32(streamId),
        streamReadFloat32(streamId),
    }
    project.rotation = {
        streamReadFloat32(streamId),
        streamReadFloat32(streamId),
        streamReadFloat32(streamId),
    }
    project.totalPrice = streamReadFloat32(streamId)
    project.depositAmount = streamReadFloat32(streamId)
    project.totalPaid = streamReadFloat32(streamId)
    project.displacementCosts = streamReadFloat32(streamId)
    project.mode = streamReadString(streamId)
    project.currentPhaseIndex = streamReadInt32(streamId)
    project.completed = streamReadBool(streamId)
    project.startPeriod = streamReadInt32(streamId)
    project.startYear = streamReadInt32(streamId)
    project.labourPerPhase = streamReadFloat32(streamId)
    project.materialBudget = streamReadFloat32(streamId)
    project.materialSuppliedValue = streamReadFloat32(streamId)
    project.fencePlaceableId = nil
    project.activatable = nil
    project.storage = nil
    project.unloadingStation = nil
    project.configurations = {}
    project.configurationData = {}

    project.footprint = {}
    local hasFootprint = streamReadBool(streamId)
    if hasFootprint then
        project.footprint.sizeX = streamReadFloat32(streamId)
        project.footprint.sizeZ = streamReadFloat32(streamId)
        project.footprint.centerX = streamReadFloat32(streamId)
        project.footprint.centerZ = streamReadFloat32(streamId)
        project.footprint.rotY = streamReadFloat32(streamId)
    end

    local numPhases = streamReadInt32(streamId)
    project.phases = {}
    for _ = 1, numPhases do
        table.insert(project.phases, {
            completed = streamReadBool(streamId),
        })
    end

    local numMaterials = streamReadInt32(streamId)
    project.materials = {}
    for _ = 1, numMaterials do
        local fillTypeName = streamReadString(streamId)
        local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
        table.insert(project.materials, {
            fillTypeIndex = fillTypeIndex,
            fillTypeName = fillTypeName,
            amount = streamReadFloat32(streamId),
            delivered = streamReadFloat32(streamId),
        })
    end

    return project
end
