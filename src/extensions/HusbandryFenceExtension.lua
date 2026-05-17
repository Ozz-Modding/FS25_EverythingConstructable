HusbandryFenceExtension = {}
HusbandryFenceExtension.pendingPlaceables = {}

function HusbandryFenceExtension.init()
    if ConstructionBrushHusbandry ~= nil then
        ConstructionBrushHusbandry.onCustomizableFenceFinished = Utils.appendedFunction(
            ConstructionBrushHusbandry.onCustomizableFenceFinished,
            HusbandryFenceExtension.onClientFenceFlowFinished
        )
    end
end

function HusbandryFenceExtension.markForConversion(placeable, buyData)
    if placeable == nil then
        return
    end
    local id = NetworkUtil.getObjectId(placeable)
    if id == nil then
        return
    end

    local pending = {
        placeable = placeable,
        storeItem = buyData.storeItem,
        price = buyData.price,
        displacementCosts = buyData.displacementCosts or 0,
        farmId = buyData.ownerFarmId,
        position = {buyData.position[1], buyData.position[2], buyData.position[3]},
        rotation = {buyData.rotation[1], buyData.rotation[2], buyData.rotation[3]},
        configurations = {},
    }

    if buyData.configurations ~= nil then
        for k, v in pairs(buyData.configurations) do
            pending.configurations[k] = v
        end
    end

    HusbandryFenceExtension.pendingPlaceables[id] = pending

    local hasMeadow = placeable.getCanCreateMeadow ~= nil and placeable:getCanCreateMeadow()
    if hasMeadow then
        local originalCreateMeadow = placeable.createMeadow
        placeable.createMeadow = function(self, doCreateMeadow, noEventSend)
            originalCreateMeadow(self, doCreateMeadow, noEventSend)
            local objId = NetworkUtil.getObjectId(self)
            if objId ~= nil and HusbandryFenceExtension.pendingPlaceables[objId] ~= nil then
                HusbandryFenceExtension.pendingPlaceables[objId] = nil
                pending.createMeadow = doCreateMeadow or false
                HusbandryFenceExtension.convertToProject(pending)
            end
        end
    end
end

function HusbandryFenceExtension.onClientFenceFlowFinished(self, placeable)
    if placeable == nil then
        return
    end

    local hasMeadow = placeable.getCanCreateMeadow ~= nil and placeable:getCanCreateMeadow()
    if hasMeadow then
        return
    end

    if g_server ~= nil then
        HusbandryFenceExtension.onConvertRequested(placeable, false)
    else
        g_client:getServerConnection():sendEvent(ECHusbandryConvertEvent.new(placeable, false))
    end
end

function HusbandryFenceExtension.onConvertRequested(placeable, createMeadow)
    if placeable == nil or placeable.isDeleted then
        return
    end
    local id = NetworkUtil.getObjectId(placeable)
    if id == nil then
        return
    end
    local pending = HusbandryFenceExtension.pendingPlaceables[id]
    if pending == nil then
        return
    end
    HusbandryFenceExtension.pendingPlaceables[id] = nil
    pending.createMeadow = createMeadow or false
    HusbandryFenceExtension.convertToProject(pending)
end

function HusbandryFenceExtension.saveFenceData(pending, placeable)
    local spec = placeable.spec_husbandryFence
    if spec == nil or spec.fence == nil then
        return
    end
    pending.fenceSegments = {}
    for _, segment in ipairs(spec.fence:getSegments()) do
        local sx, sy, sz = segment:getStartPos()
        local ex, ey, ez = segment:getEndPos()
        table.insert(pending.fenceSegments, {
            startPos = {sx, sy, sz},
            endPos = {ex, ey, ez},
            isCustomizable = segment.husbandryFenceIsCustomizable or false,
            isDefaultSegment = segment.husbandryFenceIsDefaultSegment or false,
            templateId = segment.templateId,
            isReversed = segment.isReversed,
        })
    end
end

function HusbandryFenceExtension.convertToProject(pending)
    local placeable = pending.placeable
    if placeable == nil or placeable.isDeleted then
        return
    end

    HusbandryFenceExtension.saveFenceData(pending, placeable)

    local footprint = BuyPlaceableDataExtension.extractFootprint(placeable, pending.position, pending.rotation)

    placeable:delete()

    local manager = g_currentMission.ecProjectManager
    if manager == nil then
        return
    end

    local project = manager:createProject(
        pending.farmId, pending.storeItem.xmlFilename,
        pending.position, pending.rotation,
        pending.configurations, {}, pending.price, pending.displacementCosts, footprint
    )

    project.husbandryFenceData = pending.fenceSegments
    project.husbandryMeadow = pending.createMeadow or false

    ECFenceBuilder.buildFence(project)
    ECFenceBuilder.buildPastureFence(project)
    ECSiteDecorator.decorate(project)
    ECTerrainPainter.clearFootprint(project)

    g_server:broadcastEvent(ECCreateProjectEvent.new(project))
end
