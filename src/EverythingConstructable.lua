EverythingConstructable = {}
EverythingConstructable.dir = g_currentModDirectory
EverythingConstructable.modName = g_currentModName

function EverythingConstructable:loadMap()
    g_currentMission.ecProjectManager = ECProjectManager.new()
    g_currentMission.ecProjectManager:init()

    HusbandryFenceExtension.init()

    g_gui:loadProfiles(EverythingConstructable.dir .. "src/gui/guiProfiles.xml")
    ECConstructionDialog.register()
    ECSettings.addSettingsToMenu()

    self:loadFromXMLFile()

    if g_addCheatCommands and g_currentMission:getIsServer() then
        addConsoleCommand("ecFinishPhase", "Advance current phase for a project (id)", "consoleFinishPhase", self)
        addConsoleCommand("ecListProjects", "List all active construction projects", "consoleListProjects", self)
        addConsoleCommand("ecGroundTypes", "List available ground types and terrain layers", "consoleGroundTypes", self)
    end
end

function EverythingConstructable:onStartMission()
    if not g_currentMission:getIsServer() then
        return
    end

    for _, project in pairs(g_currentMission.ecProjectManager.projects) do
        if not project.completed then
            ECFenceBuilder.buildFence(project)
            if project.currentPhaseIndex >= 2 then
                ECFenceBuilder.buildInnerFence(project)
            end
            ECSiteDecorator.decorate(project)
            g_currentMission.ecProjectManager:setupClientProject(project)
        end
    end
end

function EverythingConstructable:delete()
    if g_currentMission.ecProjectManager ~= nil then
        g_currentMission.ecProjectManager:delete()
        g_currentMission.ecProjectManager = nil
    end

    removeConsoleCommand("ecFinishPhase")
    removeConsoleCommand("ecListProjects")
end

function EverythingConstructable:loadFromXMLFile()
    if not g_currentMission:getIsServer() then
        return
    end

    local savePath = g_currentMission.missionInfo.savegameDirectory
    if savePath == nil then
        savePath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_currentMission.missionInfo.savegameIndex)
    end
    savePath = savePath .. "/"

    local filePath = savePath .. "EverythingConstructable.xml"
    if not fileExists(filePath) then
        return
    end

    local xmlFile = loadXMLFile("EverythingConstructable", filePath)
    if xmlFile == 0 then
        return
    end

    local constructionEnabled = getXMLBool(xmlFile, "EverythingConstructable.settings#constructionEnabled")
    if constructionEnabled ~= nil then
        ECSettings.current.constructionEnabled = constructionEnabled
    end

    g_currentMission.ecProjectManager:loadFromXMLFile(xmlFile)
    delete(xmlFile)
end

function EverythingConstructable:saveToXmlFile()
    if not g_currentMission:getIsServer() then
        return
    end

    local savePath = g_currentMission.missionInfo.savegameDirectory .. "/"
    local xmlFile = createXMLFile("EverythingConstructable", savePath .. "EverythingConstructable.xml", "EverythingConstructable")
    if xmlFile == 0 then
        return
    end

    setXMLBool(xmlFile, "EverythingConstructable.settings#constructionEnabled", ECSettings.current.constructionEnabled)

    g_currentMission.ecProjectManager:saveToXMLFile(xmlFile)
    saveXMLFile(xmlFile)
    delete(xmlFile)
end

function EverythingConstructable:sendInitialClientState(connection, user, farm)
    connection:sendEvent(ECSettingsEvent.new())
    connection:sendEvent(ECInitialClientStateEvent.new())
end

function EverythingConstructable:consoleFinishPhase(projectId)
    if not g_currentMission:getIsServer() then
        return "Only available on server"
    end

    projectId = tonumber(projectId)
    if projectId == nil then
        return "Usage: ecFinishPhase <projectId>"
    end

    local manager = g_currentMission.ecProjectManager
    local project = manager:getProjectById(projectId)
    if project == nil then
        return "Project not found: " .. projectId
    end

    if project.completed then
        return "Project already completed"
    end

    local phase = project:getCurrentPhase()
    if phase ~= nil then
        phase.completed = true
    end

    if project.currentPhaseIndex >= project:getNumPhases() then
        manager:completeProject(project)
        return "Project completed: " .. project:getStoreItemName()
    else
        project.currentPhaseIndex = project.currentPhaseIndex + 1
        if project.currentPhaseIndex >= 2 and project.innerFenceSegments == nil then
            ECFenceBuilder.buildInnerFence(project)
        end
        ECSiteDecorator.decorate(project)
        g_server:broadcastEvent(ECAdvancePhaseEvent.new(project.id, project.currentPhaseIndex, project.totalPaid))
        return string.format("Advanced to phase %d/%d", project.currentPhaseIndex, project:getNumPhases())
    end
end

function EverythingConstructable:consoleListProjects()
    local manager = g_currentMission.ecProjectManager
    if manager == nil then
        return "No project manager"
    end

    local count = 0
    for _, project in pairs(manager.projects) do
        local status = project.completed and "COMPLETED" or
            (project.paused and "PAUSED" or "ACTIVE")
        print(string.format("  [%d] %s - Phase %d/%d - Mode: %s - Status: %s - Paid: %d/%d",
            project.id,
            project:getStoreItemName(),
            project.currentPhaseIndex,
            project:getNumPhases(),
            project.mode,
            status,
            project.totalPaid,
            project.totalPrice
        ))
        count = count + 1
    end

    return string.format("%d projects found", count)
end

function EverythingConstructable:consoleGroundTypes()
    if g_groundTypeManager == nil then
        return "No ground type manager"
    end

    print("Ground type mappings:")
    for typeName, mapping in pairs(g_groundTypeManager.groundTypeMappings) do
        local layerIndex = g_groundTypeManager:getTerrainLayerByType(typeName)
        print(string.format("  %s -> layer '%s' -> index %s", typeName, tostring(mapping.layerName), tostring(layerIndex)))
    end

    if g_groundTypeManager.terrainLayerMapping ~= nil then
        print("Terrain layers:")
        for layerName, index in pairs(g_groundTypeManager.terrainLayerMapping) do
            print(string.format("  [%d] %s", index, layerName))
        end
    end

    return "Done"
end

FSBaseMission.onStartMission = Utils.appendedFunction(FSBaseMission.onStartMission, function(...)
    EverythingConstructable:onStartMission()
end)

FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, function(...)
    EverythingConstructable:saveToXmlFile()
end)

FSBaseMission.sendInitialClientState = Utils.appendedFunction(FSBaseMission.sendInitialClientState, function(self, connection, user, farm)
    EverythingConstructable:sendInitialClientState(connection, user, farm)
end)

addModEventListener(EverythingConstructable)
