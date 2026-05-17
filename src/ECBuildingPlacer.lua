ECBuildingPlacer = {}

function ECBuildingPlacer.placeBuilding(project, callback)
    if project == nil then
        if callback ~= nil then
            callback(false)
        end
        return
    end

    local storeItem = g_storeManager:getItemByXMLFilename(project.storeItemXml)
    if storeItem == nil then
        print("EverythingConstructable: Store item not found: " .. tostring(project.storeItemXml))
        if callback ~= nil then
            callback(false)
        end
        return
    end

    local loadingData = PlaceableLoadingData.new()
    loadingData:setStoreItem(storeItem)
    loadingData:setConfigurations(project.configurations or {})
    loadingData:setOwnerFarmId(project.farmId)
    loadingData:setPosition(project.position[1], project.position[2], project.position[3])
    loadingData:setRotation(project.rotation[1], project.rotation[2], project.rotation[3])

    loadingData:load(function(_, placeable, loadingState)
        if loadingState ~= PlaceableLoadingState.OK or placeable == nil then
            print("EverythingConstructable: Failed to load placeable, state: " .. tostring(loadingState))
            if callback ~= nil then
                callback(false)
            end
            return
        end

        placeable:finalizePlacement()
        placeable:onBuy()

        ECBuildingPlacer.restoreHusbandryFence(project, placeable)

        print(string.format("EverythingConstructable: Building placed for project %d: %s",
            project.id, project:getStoreItemName()))

        if callback ~= nil then
            callback(true)
        end
    end, nil)
end

function ECBuildingPlacer.restoreHusbandryFence(project, placeable)
    if project.husbandryFenceData == nil then
        return
    end

    local spec = placeable.spec_husbandryFence
    if spec == nil or spec.fence == nil then
        return
    end

    for _, segment in ipairs_reverse(spec.fence:getSegments()) do
        spec.fence:removeSegment(segment)
        segment:delete()
    end

    if spec.previewSegments ~= nil then
        spec.previewSegments = {}
    end

    for _, segData in ipairs(project.husbandryFenceData) do
        local templateId = segData.templateId
        if templateId == nil then
            templateId = spec.fenceSegmentsData[1] and spec.fenceSegmentsData[1].segmentId
        end
        if templateId ~= nil then
            local segment = spec.fence:createNewSegment(templateId)
            if segment ~= nil then
                segment:setStartPos(segData.startPos[1], segData.startPos[2], segData.startPos[3])
                segment:setEndPos(segData.endPos[1], segData.endPos[2], segData.endPos[3])
                if segData.isReversed and segment.setIsReversed ~= nil then
                    segment:setIsReversed(segData.isReversed)
                end
                segment.husbandryFenceIsCustomizable = segData.isCustomizable
                segment.husbandryFenceIsDefaultSegment = segData.isDefaultSegment
                segment:updateMeshes(true, false)
                segment:finalize()
            end
        end
    end

    spec.fence:finalize()
    placeable:finalizeHusbandryFence()

    if project.husbandryMeadow and placeable.createMeadow ~= nil then
        placeable:createMeadow(true)
    end
end
