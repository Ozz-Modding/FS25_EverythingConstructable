ECFenceBuilder = {}

function ECFenceBuilder.getFenceStoreItem()
    local fenceXml = EverythingConstructable.dir .. ECConfig.FENCE_XML
    local storeItem = g_storeManager:getItemByXMLFilename(fenceXml)
    return storeItem
end

function ECFenceBuilder.getPanelLength(segmentId)
    if ECFenceBuilder.panelLengths == nil then
        ECFenceBuilder.panelLengths = {}
        local xmlPath = EverythingConstructable.dir .. ECConfig.FENCE_XML
        local xmlFile = loadXMLFile("ecFenceTemp", xmlPath)
        if xmlFile ~= nil and xmlFile ~= 0 then
            local i = 0
            while true do
                local segKey = string.format("placeable.fence.segment(%d)", i)
                if not hasXMLProperty(xmlFile, segKey) then
                    break
                end
                local id = getXMLString(xmlFile, segKey .. "#id")
                local length = getXMLFloat(xmlFile, segKey .. ".panels.panel(0)#length")
                if id ~= nil and length ~= nil then
                    ECFenceBuilder.panelLengths[id] = length
                end
                i = i + 1
            end
            delete(xmlFile)
        end
    end
    return ECFenceBuilder.panelLengths[segmentId] or 3.6
end

function ECFenceBuilder.snapToPanel(halfDist, panelLength)
    local panels = math.max(1, math.floor((halfDist * 2) / panelLength))
    return (panels * panelLength) / 2
end

function ECFenceBuilder.findTemplateBySegmentId(fenceObj, segmentId)
    local templates = fenceObj:getSegmentTemplates()
    if templates == nil or #templates == 0 then
        return nil
    end
    for _, templateId in ipairs(templates) do
        if templateId == segmentId then
            return templateId
        end
    end
    return templates[1]
end

function ECFenceBuilder.buildFence(project)
    if project == nil or project.footprint == nil then
        return
    end

    local corners = ECFenceBuilder.calculateCorners(project)
    if corners == nil then
        return
    end

    project.fenceCorners = corners

    local storeItem = ECFenceBuilder.getFenceStoreItem()
    if storeItem == nil then
        print("EverythingConstructable: Fence store item not found")
        return
    end

    local xmlFilename = storeItem.xmlFilename
    local existingFence = g_currentMission.placeableSystem:getExistingPlaceableByXMLFilename(xmlFilename)

    if existingFence ~= nil then
        ECFenceBuilder.addSegmentsToFence(existingFence, project, corners)
    else
        ECFenceBuilder.createSingleton(storeItem, project, corners)
    end
end

function ECFenceBuilder.addSegmentsToFence(fence, project, corners)
    local segments = {}

    if fence.spec_fence ~= nil then
        for i = 1, 4 do
            local nextI = (i % 4) + 1
            local x1, z1 = corners[i][1], corners[i][2]
            local x2, z2 = corners[nextI][1], corners[nextI][2]
            local renderFirst = (i == 1)
            local renderLast = (i == 4)
            local segment = fence:createSegment(x1, z1, x2, z2, renderFirst, nil)
            segment.renderLast = renderLast
            fence:addSegment(segment, true)
            table.insert(segments, segment)
        end
        project.fencePlaceable = fence
        project.fenceSegments = segments
        print(string.format("EverythingConstructable: Added 4 fence segments (PlaceableFence) for project %d", project.id))

    elseif fence.spec_newFence ~= nil then
        local fenceObj = fence:getFence()
        if fenceObj == nil then
            print("EverythingConstructable: getFence() returned nil")
            return
        end

        local templateId = ECFenceBuilder.findTemplateBySegmentId(fenceObj, ECConfig.FENCE_SEGMENT_ID)
        if templateId == nil then
            print("EverythingConstructable: No segment templates found")
            return
        end

        for i = 1, 4 do
            local nextI = (i % 4) + 1
            local x1, z1 = corners[i][1], corners[i][2]
            local x2, z2 = corners[nextI][1], corners[nextI][2]

            if ECConfig.FENCE_OUTER_REVERSE_WINDING then
                x1, z1, x2, z2 = x2, z2, x1, z1
            end

            local segment = fenceObj:createNewSegment(templateId)
            if segment ~= nil then
                local y1 = getTerrainHeightAtWorldPos(g_terrainNode, x1, 0, z1)
                local y2 = getTerrainHeightAtWorldPos(g_terrainNode, x2, 0, z2)
                segment:setStartPos(x1, y1, z1)
                segment:setEndPos(x2, y2, z2)
                segment:updateMeshes(true, false)

                if segment.actualEndX ~= nil then
                    segment.endPosX = segment.actualEndX
                    segment.endPosY = segment.actualEndY
                    segment.endPosZ = segment.actualEndZ
                    addToPhysics(segment.root)
                    fenceObj:addSegment(segment)
                    segment:setCollisionAreaDirty()
                    segment.notYetFinalized = nil
                else
                    print(string.format("EverythingConstructable: Segment %d has no actualEndX after updateMeshes", i))
                end

                table.insert(segments, segment)
            end
        end
        project.fencePlaceable = fence
        project.fenceSegments = segments
        print(string.format("EverythingConstructable: Added %d fence segments (NewFence) for project %d", #segments, project.id))
    else
        print("EverythingConstructable: Fence placeable has neither spec_fence nor spec_newFence")
    end
end

function ECFenceBuilder.createSingleton(storeItem, project, corners)
    local buyData = BuyPlaceableData.new()
    buyData:setStoreItem(storeItem)
    buyData:setPosition(0, PlacementUtil.NETHER_HEIGHT - 1, 0)
    buyData:setRotation(0, 0, 0)
    buyData:setConfigurations({})
    buyData:setOwnerFarmId(project.farmId)
    buyData:setDisplacementCosts(0)
    buyData:setModifyTerrain(false)
    buyData:setIsFreeOfCharge(true)

    buyData:buy(function(_, placeable, loadingState)
        if loadingState ~= PlaceableLoadingState.OK then
            print("EverythingConstructable: Failed to create fence singleton, state: " .. tostring(loadingState))
            return
        end

        local existingFence = g_currentMission.placeableSystem:getExistingPlaceableByXMLFilename(storeItem.xmlFilename)
        if existingFence ~= nil then
            ECFenceBuilder.addSegmentsToFence(existingFence, project, corners)
        else
            print("EverythingConstructable: Fence singleton created but not found in system")
        end
    end, nil, {})
end

function ECFenceBuilder.buildInnerFence(project)
    if project == nil or project.footprint == nil then
        return
    end

    if project.innerFenceSegments ~= nil then
        return
    end

    local corners = ECFenceBuilder.calculateInnerCorners(project)
    if corners == nil then
        return
    end

    project.innerFenceCorners = corners

    local storeItem = ECFenceBuilder.getFenceStoreItem()
    if storeItem == nil then
        print("EverythingConstructable: Inner fence store item not found")
        return
    end

    local xmlFilename = storeItem.xmlFilename
    local existingFence = g_currentMission.placeableSystem:getExistingPlaceableByXMLFilename(xmlFilename)

    if existingFence ~= nil then
        ECFenceBuilder.addInnerSegmentsToFence(existingFence, project, corners)
    else
        ECFenceBuilder.createInnerSingleton(storeItem, project, corners)
    end
end

function ECFenceBuilder.addInnerSegmentsToFence(fence, project, corners)
    local segments = {}

    if fence.spec_fence ~= nil then
        for i = 1, 4 do
            local nextI = (i % 4) + 1
            local x1, z1 = corners[i][1], corners[i][2]
            local x2, z2 = corners[nextI][1], corners[nextI][2]
            local renderFirst = (i == 1)
            local renderLast = (i == 4)
            local segment = fence:createSegment(x1, z1, x2, z2, renderFirst, nil)
            segment.renderLast = renderLast
            fence:addSegment(segment, true)
            table.insert(segments, segment)
        end
        project.innerFencePlaceable = fence
        project.innerFenceSegments = segments

    elseif fence.spec_newFence ~= nil then
        local fenceObj = fence:getFence()
        if fenceObj == nil then
            return
        end

        local templateId = ECFenceBuilder.findTemplateBySegmentId(fenceObj, ECConfig.FENCE_INNER_SEGMENT_ID)
        if templateId == nil then
            return
        end

        for i = 1, 4 do
            local nextI = (i % 4) + 1
            local x1, z1 = corners[i][1], corners[i][2]
            local x2, z2 = corners[nextI][1], corners[nextI][2]

            if ECConfig.FENCE_INNER_REVERSE_WINDING then
                x1, z1, x2, z2 = x2, z2, x1, z1
            end

            local segment = fenceObj:createNewSegment(templateId)
            if segment ~= nil then
                local y1 = getTerrainHeightAtWorldPos(g_terrainNode, x1, 0, z1)
                local y2 = getTerrainHeightAtWorldPos(g_terrainNode, x2, 0, z2)
                segment:setStartPos(x1, y1, z1)
                segment:setEndPos(x2, y2, z2)
                segment:updateMeshes(true, false)

                if segment.actualEndX ~= nil then
                    segment.endPosX = segment.actualEndX
                    segment.endPosY = segment.actualEndY
                    segment.endPosZ = segment.actualEndZ
                    addToPhysics(segment.root)
                    fenceObj:addSegment(segment)
                    segment:setCollisionAreaDirty()
                    segment.notYetFinalized = nil
                end

                table.insert(segments, segment)
            end
        end
        project.innerFencePlaceable = fence
        project.innerFenceSegments = segments
    end
end

function ECFenceBuilder.createInnerSingleton(storeItem, project, corners)
    local buyData = BuyPlaceableData.new()
    buyData:setStoreItem(storeItem)
    buyData:setPosition(0, PlacementUtil.NETHER_HEIGHT - 1, 0)
    buyData:setRotation(0, 0, 0)
    buyData:setConfigurations({})
    buyData:setOwnerFarmId(project.farmId)
    buyData:setDisplacementCosts(0)
    buyData:setModifyTerrain(false)
    buyData:setIsFreeOfCharge(true)

    buyData:buy(function(_, placeable, loadingState)
        if loadingState ~= PlaceableLoadingState.OK then
            return
        end

        local existingFence = g_currentMission.placeableSystem:getExistingPlaceableByXMLFilename(storeItem.xmlFilename)
        if existingFence ~= nil then
            ECFenceBuilder.addInnerSegmentsToFence(existingFence, project, corners)
        end
    end, nil, {})
end

function ECFenceBuilder.removeInnerFence(project)
    if project == nil then
        return
    end

    if project.innerFenceSegments ~= nil and project.innerFencePlaceable ~= nil then
        local fence = project.innerFencePlaceable
        if fence.spec_fence ~= nil then
            for i = #project.innerFenceSegments, 1, -1 do
                fence:deleteSegment(project.innerFenceSegments[i])
            end
        elseif fence.spec_newFence ~= nil then
            local fenceObj = fence:getFence()
            if fenceObj ~= nil then
                for i = #project.innerFenceSegments, 1, -1 do
                    fenceObj:removeSegment(project.innerFenceSegments[i])
                    project.innerFenceSegments[i]:delete()
                end
            end
        end
    end

    project.innerFenceSegments = nil
    project.innerFencePlaceable = nil
    project.innerFenceCorners = nil
end

function ECFenceBuilder.calculateInnerCorners(project)
    local pos = project.position
    local fp = project.footprint
    local panelLength = ECFenceBuilder.getPanelLength(ECConfig.FENCE_INNER_SEGMENT_ID)
    local offset = ECConfig.FENCE_INNER_OFFSET
    local rawHalfX = math.max(0, (fp.sizeX or 10) * 0.5 - offset)
    local rawHalfZ = math.max(0, (fp.sizeZ or 10) * 0.5 - offset)
    local halfX = ECFenceBuilder.snapToPanel(rawHalfX, panelLength)
    local halfZ = ECFenceBuilder.snapToPanel(rawHalfZ, panelLength)
    local rotY = fp.rotY or 0

    local dirX, dirZ = MathUtil.getDirectionFromYRotation(rotY)
    local sideX, _, sideZ = MathUtil.crossProduct(0, 1, 0, dirX, 0, dirZ)

    local cx = pos[1] + dirX * (fp.centerZ or 0) + sideX * (fp.centerX or 0)
    local cz = pos[3] + dirZ * (fp.centerZ or 0) + sideZ * (fp.centerX or 0)

    if halfX < panelLength * 0.5 or halfZ < panelLength * 0.5 then
        return nil
    end

    return {
        {cx - sideX * halfX - dirX * halfZ, cz - sideZ * halfX - dirZ * halfZ},
        {cx + sideX * halfX - dirX * halfZ, cz + sideZ * halfX - dirZ * halfZ},
        {cx + sideX * halfX + dirX * halfZ, cz + sideZ * halfX + dirZ * halfZ},
        {cx - sideX * halfX + dirX * halfZ, cz - sideZ * halfX + dirZ * halfZ},
    }
end

function ECFenceBuilder.removeFence(project)
    if project == nil then
        return
    end

    ECFenceBuilder.removeInnerFence(project)

    if project.fenceSegments ~= nil and project.fencePlaceable ~= nil then
        local fence = project.fencePlaceable
        if fence.spec_fence ~= nil then
            for i = #project.fenceSegments, 1, -1 do
                fence:deleteSegment(project.fenceSegments[i])
            end
        elseif fence.spec_newFence ~= nil then
            local fenceObj = fence:getFence()
            if fenceObj ~= nil then
                for i = #project.fenceSegments, 1, -1 do
                    fenceObj:removeSegment(project.fenceSegments[i])
                    project.fenceSegments[i]:delete()
                end
            end
        end
    end

    project.fenceSegments = nil
    project.fencePlaceable = nil
    project.fenceCorners = nil
end

function ECFenceBuilder.calculateCorners(project)
    local pos = project.position
    local fp = project.footprint
    local panelLength = ECFenceBuilder.getPanelLength(ECConfig.FENCE_SEGMENT_ID)
    local halfX = ECFenceBuilder.snapToPanel((fp.sizeX or 10) * 0.5, panelLength)
    local halfZ = ECFenceBuilder.snapToPanel((fp.sizeZ or 10) * 0.5, panelLength)
    local rotY = fp.rotY or 0

    local dirX, dirZ = MathUtil.getDirectionFromYRotation(rotY)
    local sideX, _, sideZ = MathUtil.crossProduct(0, 1, 0, dirX, 0, dirZ)

    local cx = pos[1] + dirX * (fp.centerZ or 0) + sideX * (fp.centerX or 0)
    local cz = pos[3] + dirZ * (fp.centerZ or 0) + sideZ * (fp.centerX or 0)

    return {
        {cx - sideX * halfX - dirX * halfZ, cz - sideZ * halfX - dirZ * halfZ},
        {cx + sideX * halfX - dirX * halfZ, cz + sideZ * halfX - dirZ * halfZ},
        {cx + sideX * halfX + dirX * halfZ, cz + sideZ * halfX + dirZ * halfZ},
        {cx - sideX * halfX + dirX * halfZ, cz - sideZ * halfX + dirZ * halfZ},
    }
end
