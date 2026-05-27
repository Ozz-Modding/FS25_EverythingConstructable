ECFenceBuilder = {}

function ECFenceBuilder.lockFence(fence)
    if fence == nil or fence.ecFenceLocked then
        return
    end

    fence.getAllowFenceSegmentDeletion = function()
        return false
    end

    fence.canBeSold = function()
        return false, g_i18n:getText("ec_cannotDeleteFence")
    end

    fence.ecFenceLocked = true
end

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
        if ECFenceBuilder.adoptExistingSegments(existingFence, project, corners) then
            ECFenceBuilder.lockFence(existingFence)
            ECFenceBuilder.placeFenceSigns(project)
            return
        end
        ECFenceBuilder.addSegmentsToFence(existingFence, project, corners)
        ECFenceBuilder.placeFenceSigns(project)
    else
        ECFenceBuilder.createSingleton(storeItem, project, corners)
    end
end

function ECFenceBuilder.adoptExistingSegments(fence, project, corners)
    if fence.spec_newFence == nil then
        return false
    end
    local fenceObj = fence:getFence()
    if fenceObj == nil then
        return false
    end

    local adopted = {}
    for i = 1, 4 do
        local nextI = (i % 4) + 1
        local cx1, cz1 = corners[i][1], corners[i][2]
        local cx2, cz2 = corners[nextI][1], corners[nextI][2]

        if ECConfig.FENCE_OUTER_REVERSE_WINDING then
            cx1, cz1, cx2, cz2 = cx2, cz2, cx1, cz1
        end

        for _, segment in ipairs(fenceObj:getSegments()) do
            if not table.hasElement(adopted, segment) then
                local sx, _, sz = segment:getStartPos()
                local ex, _, ez = segment:getEndPos()
                local matchForward = math.abs(sx - cx1) < 0.5 and math.abs(sz - cz1) < 0.5 and
                                     math.abs(ex - cx2) < 0.5 and math.abs(ez - cz2) < 0.5
                local matchReverse = math.abs(sx - cx2) < 0.5 and math.abs(sz - cz2) < 0.5 and
                                     math.abs(ex - cx1) < 0.5 and math.abs(ez - cz1) < 0.5
                if matchForward or matchReverse then
                    table.insert(adopted, segment)
                    break
                end
            end
        end
    end

    if #adopted == 4 then
        project.fencePlaceable = fence
        project.fenceSegments = adopted
        return true
    end
    return false
end

function ECFenceBuilder.addSegmentsToFence(fence, project, corners)
    ECFenceBuilder.lockFence(fence)
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
            ECFenceBuilder.placeFenceSigns(project)
        else
            print("EverythingConstructable: Fence singleton created but not found in system")
        end
    end, nil, {})
end

function ECFenceBuilder.placeFenceSigns(project)
    if project == nil or project.fenceCorners == nil then
        return
    end

    ECFenceBuilder.removeFenceSigns(project)

    local i3dPath = ECSiteDecorator.modDir .. ECConfig.FENCE_SIGN_I3D
    local height = ECConfig.FENCE_SIGN_HEIGHT
    local interval = ECConfig.FENCE_SIGN_PANEL_INTERVAL
    local panelLength = ECFenceBuilder.getPanelLength(ECConfig.FENCE_SEGMENT_ID)
    local corners = project.fenceCorners
    local nodes = {}

    for i = 1, 4 do
        local nextI = (i % 4) + 1
        local x1, z1 = corners[i][1], corners[i][2]
        local x2, z2 = corners[nextI][1], corners[nextI][2]

        local dx = x2 - x1
        local dz = z2 - z1
        local dist = math.sqrt(dx * dx + dz * dz)
        local numPanels = math.max(1, math.floor(dist / panelLength + 0.5))

        local faceRotY = math.atan2(dx, dz)

        for p = 0, numPanels - 1 do
            if p % interval == 0 then
                local t = (p + 0.5) / numPanels
                local wx = x1 + dx * t
                local wz = z1 + dz * t
                local wy = getTerrainHeightAtWorldPos(g_terrainNode, wx, 0, wz) + height

                local node = ECFenceBuilder.placeSignNode(i3dPath, wx, wy, wz, faceRotY)
                if node ~= nil then
                    table.insert(nodes, node)
                end
            end
        end
    end

    project.fenceSignNodes = nodes
end

function ECFenceBuilder.placeSignNode(i3dPath, wx, wy, wz, rotY)
    local i3dRoot, sharedLoadRequestId = g_i3DManager:loadSharedI3DFile(i3dPath, false, false)
    if i3dRoot == nil or i3dRoot == 0 then
        return nil
    end

    local node = createTransformGroup("ecFenceSign")
    link(getRootNode(), node)

    local clone = clone(i3dRoot, false, false, false)
    link(node, clone)

    setWorldTranslation(node, wx, wy, wz)
    setWorldRotation(node, 0, rotY, 0)

    g_i3DManager:releaseSharedI3DFile(sharedLoadRequestId)
    return node
end

function ECFenceBuilder.removeFenceSigns(project)
    if project == nil or project.fenceSignNodes == nil then
        return
    end

    for _, node in ipairs(project.fenceSignNodes) do
        if node ~= nil and entityExists(node) then
            delete(node)
        end
    end

    project.fenceSignNodes = nil
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
        if ECFenceBuilder.adoptExistingInnerSegments(existingFence, project, corners) then
            ECFenceBuilder.lockFence(existingFence)
            return
        end
        ECFenceBuilder.addInnerSegmentsToFence(existingFence, project, corners)
    else
        ECFenceBuilder.createInnerSingleton(storeItem, project, corners)
    end
end

function ECFenceBuilder.adoptExistingInnerSegments(fence, project, corners)
    if fence.spec_newFence == nil then
        return false
    end
    local fenceObj = fence:getFence()
    if fenceObj == nil then
        return false
    end

    local adopted = {}
    for i = 1, 4 do
        local nextI = (i % 4) + 1
        local cx1, cz1 = corners[i][1], corners[i][2]
        local cx2, cz2 = corners[nextI][1], corners[nextI][2]

        if ECConfig.FENCE_INNER_REVERSE_WINDING then
            cx1, cz1, cx2, cz2 = cx2, cz2, cx1, cz1
        end

        for _, segment in ipairs(fenceObj:getSegments()) do
            if not table.hasElement(adopted, segment) then
                local sx, _, sz = segment:getStartPos()
                local ex, _, ez = segment:getEndPos()
                local matchForward = math.abs(sx - cx1) < 0.5 and math.abs(sz - cz1) < 0.5 and
                                     math.abs(ex - cx2) < 0.5 and math.abs(ez - cz2) < 0.5
                local matchReverse = math.abs(sx - cx2) < 0.5 and math.abs(sz - cz2) < 0.5 and
                                     math.abs(ex - cx1) < 0.5 and math.abs(ez - cz1) < 0.5
                if matchForward or matchReverse then
                    table.insert(adopted, segment)
                    break
                end
            end
        end
    end

    if #adopted == 4 then
        project.innerFencePlaceable = fence
        project.innerFenceSegments = adopted
        return true
    end
    return false
end

function ECFenceBuilder.addInnerSegmentsToFence(fence, project, corners)
    ECFenceBuilder.lockFence(fence)
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

    if project.innerFenceSegments == nil or project.innerFencePlaceable == nil then
        local corners = ECFenceBuilder.calculateInnerCorners(project)
        if corners ~= nil then
            local storeItem = ECFenceBuilder.getFenceStoreItem()
            if storeItem ~= nil then
                local fence = g_currentMission.placeableSystem:getExistingPlaceableByXMLFilename(storeItem.xmlFilename)
                if fence ~= nil then
                    ECFenceBuilder.removeSegmentsByCorners(fence, project, corners)
                end
            end
        end
    else
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

    ECFenceBuilder.removeFenceSigns(project)
    ECFenceBuilder.removeInnerFence(project)
    ECFenceBuilder.removePastureFence(project)

    if project.fenceSegments == nil or project.fencePlaceable == nil then
        print(string.format("EverythingConstructable: removeFence - no references for project %d (segments=%s, placeable=%s)",
            project.id, tostring(project.fenceSegments ~= nil), tostring(project.fencePlaceable ~= nil)))

        local storeItem = ECFenceBuilder.getFenceStoreItem()
        if storeItem ~= nil then
            local fence = g_currentMission.placeableSystem:getExistingPlaceableByXMLFilename(storeItem.xmlFilename)
            if fence ~= nil then
                print("EverythingConstructable: removeFence - found fence placeable by filename, attempting corner-based removal")
                ECFenceBuilder.removeSegmentsByCorners(fence, project)
            end
        end
    else
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

function ECFenceBuilder.removeSegmentsByCorners(fence, project, corners)
    if corners == nil then
        corners = ECFenceBuilder.calculateCorners(project)
    end
    if corners == nil then
        return
    end

    local fenceObj = nil
    if fence.spec_newFence ~= nil then
        fenceObj = fence:getFence()
    end
    if fenceObj == nil then
        return
    end

    local toRemove = {}
    for _, segment in ipairs(fenceObj:getSegments()) do
        local sx, _, sz = segment:getStartPos()
        local ex, _, ez = segment:getEndPos()
        for i = 1, 4 do
            local nextI = (i % 4) + 1
            local cx1, cz1 = corners[i][1], corners[i][2]
            local cx2, cz2 = corners[nextI][1], corners[nextI][2]

            local matchForward = math.abs(sx - cx1) < 0.5 and math.abs(sz - cz1) < 0.5 and
                                 math.abs(ex - cx2) < 0.5 and math.abs(ez - cz2) < 0.5
            local matchReverse = math.abs(sx - cx2) < 0.5 and math.abs(sz - cz2) < 0.5 and
                                 math.abs(ex - cx1) < 0.5 and math.abs(ez - cz1) < 0.5

            if matchForward or matchReverse then
                table.insert(toRemove, segment)
                break
            end
        end
    end

    for i = #toRemove, 1, -1 do
        fenceObj:removeSegment(toRemove[i])
        toRemove[i]:delete()
    end

    print(string.format("EverythingConstructable: removeFence - removed %d segments by corner matching for project %d", #toRemove, project.id))
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

function ECFenceBuilder.buildPastureFence(project)
    if project == nil or project.husbandryFenceData == nil then
        return
    end

    local siteCorners = ECFenceBuilder.calculateCorners(project)
    if siteCorners == nil then
        return
    end

    local storeItem = ECFenceBuilder.getFenceStoreItem()
    if storeItem == nil then
        return
    end

    local xmlFilename = storeItem.xmlFilename
    local fence = g_currentMission.placeableSystem:getExistingPlaceableByXMLFilename(xmlFilename)
    if fence == nil or fence.spec_newFence == nil then
        return
    end

    local fenceObj = fence:getFence()
    if fenceObj == nil then
        return
    end

    local templateId = ECFenceBuilder.findTemplateBySegmentId(fenceObj, ECConfig.FENCE_PASTURE_SEGMENT_ID)
    if templateId == nil then
        return
    end

    local panelLength = ECFenceBuilder.getPanelLength(ECConfig.FENCE_PASTURE_SEGMENT_ID)
    local pieces = ECFenceBuilder.subdivideFenceData(project.husbandryFenceData, panelLength)

    local segments = {}
    for _, piece in ipairs(pieces) do
        if not ECFenceBuilder.segmentInsideSite(piece.sx, piece.sz, piece.ex, piece.ez, siteCorners) then
            local segment = fenceObj:createNewSegment(templateId)
            if segment ~= nil then
                local sy = getTerrainHeightAtWorldPos(g_terrainNode, piece.sx, 0, piece.sz)
                local ey = getTerrainHeightAtWorldPos(g_terrainNode, piece.ex, 0, piece.ez)
                segment:setStartPos(piece.sx, sy, piece.sz)
                segment:setEndPos(piece.ex, ey, piece.ez)
                segment:updateMeshes(true, false)

                if segment.actualEndX ~= nil then
                    segment.endPosX = segment.actualEndX
                    segment.endPosY = segment.actualEndY
                    segment.endPosZ = segment.actualEndZ
                    addToPhysics(segment.root)
                    fenceObj:addSegment(segment)
                    segment:setCollisionAreaDirty()
                    segment.notYetFinalized = nil
                    table.insert(segments, segment)
                else
                    segment:delete()
                end
            end
        end
    end

    if #segments > 0 then
        project.pastureFencePlaceable = fence
        project.pastureFenceSegments = segments
    end
end

function ECFenceBuilder.removePastureFence(project)
    if project == nil then
        return
    end

    if project.pastureFenceSegments ~= nil and project.pastureFencePlaceable ~= nil then
        local fence = project.pastureFencePlaceable
        if fence.spec_newFence ~= nil then
            local fenceObj = fence:getFence()
            if fenceObj ~= nil then
                for i = #project.pastureFenceSegments, 1, -1 do
                    fenceObj:removeSegment(project.pastureFenceSegments[i])
                    project.pastureFenceSegments[i]:delete()
                end
            end
        end
        project.pastureFenceSegments = nil
        project.pastureFencePlaceable = nil
        return
    end

    if project.husbandryFenceData == nil then
        return
    end

    local storeItem = ECFenceBuilder.getFenceStoreItem()
    if storeItem == nil then
        return
    end

    local fence = g_currentMission.placeableSystem:getExistingPlaceableByXMLFilename(storeItem.xmlFilename)
    if fence == nil or fence.spec_newFence == nil then
        return
    end

    local fenceObj = fence:getFence()
    if fenceObj == nil then
        return
    end

    local panelLength = ECFenceBuilder.getPanelLength(ECConfig.FENCE_PASTURE_SEGMENT_ID)
    local pieces = ECFenceBuilder.subdivideFenceData(project.husbandryFenceData, panelLength)

    local toRemove = {}
    for _, segment in ipairs(fenceObj:getSegments()) do
        local sx, _, sz = segment:getStartPos()
        local ex, _, ez = segment:getEndPos()
        for _, piece in ipairs(pieces) do
            local matchForward = math.abs(sx - piece.sx) < 0.5 and math.abs(sz - piece.sz) < 0.5 and
                                 math.abs(ex - piece.ex) < 0.5 and math.abs(ez - piece.ez) < 0.5
            local matchReverse = math.abs(sx - piece.ex) < 0.5 and math.abs(sz - piece.ez) < 0.5 and
                                 math.abs(ex - piece.sx) < 0.5 and math.abs(ez - piece.sz) < 0.5
            if matchForward or matchReverse then
                table.insert(toRemove, segment)
                break
            end
        end
    end

    for i = #toRemove, 1, -1 do
        fenceObj:removeSegment(toRemove[i])
        toRemove[i]:delete()
    end
end

function ECFenceBuilder.subdivideFenceData(fenceData, panelLength)
    local pieces = {}
    for _, segData in ipairs(fenceData) do
        local sx, sz = segData.startPos[1], segData.startPos[3]
        local ex, ez = segData.endPos[1], segData.endPos[3]
        local dx = ex - sx
        local dz = ez - sz
        local dist = math.sqrt(dx * dx + dz * dz)

        if dist <= panelLength * 1.05 then
            table.insert(pieces, {sx = sx, sz = sz, ex = ex, ez = ez})
        else
            local numPanels = math.max(1, math.floor(dist / panelLength + 0.5))
            local stepX = dx / numPanels
            local stepZ = dz / numPanels
            for i = 0, numPanels - 1 do
                local px = sx + stepX * i
                local pz = sz + stepZ * i
                local qx = sx + stepX * (i + 1)
                local qz = sz + stepZ * (i + 1)
                table.insert(pieces, {sx = px, sz = pz, ex = qx, ez = qz})
            end
        end
    end
    return pieces
end

function ECFenceBuilder.segmentInsideSite(sx, sz, ex, ez, corners)
    if ECFenceBuilder.pointInsideQuad(sx, sz, corners) then
        return true
    end
    if ECFenceBuilder.pointInsideQuad(ex, ez, corners) then
        return true
    end
    local midX = (sx + ex) * 0.5
    local midZ = (sz + ez) * 0.5
    if ECFenceBuilder.pointInsideQuad(midX, midZ, corners) then
        return true
    end
    for i = 1, 4 do
        local nextI = (i % 4) + 1
        local ax, az = corners[i][1], corners[i][2]
        local bx, bz = corners[nextI][1], corners[nextI][2]
        if ECFenceBuilder.linesIntersect(sx, sz, ex, ez, ax, az, bx, bz) then
            return true
        end
    end
    return false
end

function ECFenceBuilder.linesIntersect(ax, az, bx, bz, cx, cz, dx, dz)
    local d1 = (dx - cx) * (az - cz) - (dz - cz) * (ax - cx)
    local d2 = (dx - cx) * (bz - cz) - (dz - cz) * (bx - cx)
    local d3 = (bx - ax) * (cz - az) - (bz - az) * (cx - ax)
    local d4 = (bx - ax) * (dz - az) - (bz - az) * (dx - ax)
    if d1 * d2 < 0 and d3 * d4 < 0 then
        return true
    end
    return false
end

function ECFenceBuilder.pointInsideQuad(px, pz, corners)
    local inside = true
    for i = 1, 4 do
        local nextI = (i % 4) + 1
        local ax, az = corners[i][1], corners[i][2]
        local bx, bz = corners[nextI][1], corners[nextI][2]
        local cross = (bx - ax) * (pz - az) - (bz - az) * (px - ax)
        if cross < -0.5 then
            inside = false
            break
        end
    end
    return inside
end
