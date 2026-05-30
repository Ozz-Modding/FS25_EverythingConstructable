ECSiteDecorator = {}
ECSiteDecorator.sizeCache = {}
ECSiteDecorator.modDir = g_currentModDirectory

function ECSiteDecorator.resolveI3dPath(deco)
    if deco.modLocal then
        return ECSiteDecorator.modDir .. deco.i3d
    end
    return deco.i3d
end

function ECSiteDecorator.getDecoSize(deco)
    if deco.width ~= nil and deco.depth ~= nil then
        local buf = ECConfig.SITE_DECORATION_SIZE_BUFFER * 2
        return deco.width + buf, deco.depth + buf
    end

    local i3dPath = ECSiteDecorator.resolveI3dPath(deco)

    local cached = ECSiteDecorator.sizeCache[i3dPath]
    if cached ~= nil then
        local buf = ECConfig.SITE_DECORATION_SIZE_BUFFER * 2
        return cached.width + buf, cached.depth + buf
    end

    local i3dRoot, sharedLoadRequestId = g_i3DManager:loadSharedI3DFile(i3dPath, false, false)
    if i3dRoot == nil or i3dRoot == 0 then
        ECSiteDecorator.sizeCache[i3dPath] = { width = 2, depth = 2 }
        return 2, 2
    end

    local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
    local numChildren = getNumOfChildren(i3dRoot)
    if numChildren > 0 then
        for i = 0, numChildren - 1 do
            local child = getChildAt(i3dRoot, i)
            local x, _, z = getTranslation(child)
            minX = math.min(minX, x)
            maxX = math.max(maxX, x)
            minZ = math.min(minZ, z)
            maxZ = math.max(maxZ, z)
        end
    end

    if minX == math.huge then
        minX, maxX, minZ, maxZ = -1, 1, -1, 1
    end

    local rawWidth = math.max(1, maxX - minX)
    local rawDepth = math.max(1, maxZ - minZ)

    g_i3DManager:releaseSharedI3DFile(sharedLoadRequestId)

    ECSiteDecorator.sizeCache[i3dPath] = { width = rawWidth, depth = rawDepth }

    local buf = ECConfig.SITE_DECORATION_SIZE_BUFFER * 2
    return rawWidth + buf, rawDepth + buf
end

function ECSiteDecorator.decorate(project)
    if project == nil or project.footprint == nil then
        return
    end

    ECSiteDecorator.removeDecorations(project)

    local area = ECSiteDecorator.getPlacementArea(project)
    if area == nil then
        return
    end

    ECSiteVehicles.spawnVehicles(project)
    ECSiteDecorator.startSound(project, area)

    if #ECConfig.SITE_DECORATIONS == 0 then
        return
    end

    local nodes = ECSiteDecorator.fillArea(area, project)
    project.decorationNodes = nodes
end

function ECSiteDecorator.getPlacementArea(project)
    local fp = project.footprint
    local pos = project.position
    local rotY = fp.rotY or 0

    local dirX, dirZ = MathUtil.getDirectionFromYRotation(rotY)
    local sideX, _, sideZ = MathUtil.crossProduct(0, 1, 0, dirX, 0, dirZ)

    local cx = pos[1] + dirX * (fp.centerZ or 0) + sideX * (fp.centerX or 0)
    local cz = pos[3] + dirZ * (fp.centerZ or 0) + sideZ * (fp.centerX or 0)

    local outerHalfX, outerHalfZ
    if project.fenceCorners ~= nil then
        local c1 = project.fenceCorners[1]
        local c3 = project.fenceCorners[3]
        local dx = (c3[1] - c1[1]) * sideX + (c3[2] - c1[2]) * sideZ
        local dz = (c3[1] - c1[1]) * dirX + (c3[2] - c1[2]) * dirZ
        outerHalfX = math.abs(dx) * 0.5
        outerHalfZ = math.abs(dz) * 0.5
    else
        outerHalfX = (fp.sizeX or 10) * 0.5
        outerHalfZ = (fp.sizeZ or 10) * 0.5
    end

    local innerHalfX, innerHalfZ
    if project.currentPhaseIndex >= 2 and project.innerFenceCorners ~= nil then
        local c1 = project.innerFenceCorners[1]
        local c3 = project.innerFenceCorners[3]
        local dx = (c3[1] - c1[1]) * sideX + (c3[2] - c1[2]) * sideZ
        local dz = (c3[1] - c1[1]) * dirX + (c3[2] - c1[2]) * dirZ
        innerHalfX = math.abs(dx) * 0.5
        innerHalfZ = math.abs(dz) * 0.5
    else
        innerHalfX = nil
        innerHalfZ = nil
    end

    if outerHalfX < 1 or outerHalfZ < 1 then
        return nil
    end

    return {
        cx = cx,
        cz = cz,
        halfX = outerHalfX,
        halfZ = outerHalfZ,
        innerHalfX = innerHalfX,
        innerHalfZ = innerHalfZ,
        dirX = dirX,
        dirZ = dirZ,
        sideX = sideX,
        sideZ = sideZ,
        rotY = rotY,
    }
end

function ECSiteDecorator.straddlesInnerFence(area, localX, localZ, halfW, halfD)
    if area.innerHalfX == nil then
        return false
    end
    local minX = localX - halfW
    local maxX = localX + halfW
    local minZ = localZ - halfD
    local maxZ = localZ + halfD
    local fullyInside = minX >= -area.innerHalfX and maxX <= area.innerHalfX
                    and minZ >= -area.innerHalfZ and maxZ <= area.innerHalfZ
    local fullyOutside = maxX <= -area.innerHalfX or minX >= area.innerHalfX
                      or maxZ <= -area.innerHalfZ or minZ >= area.innerHalfZ
    return not fullyInside and not fullyOutside
end

function ECSiteDecorator.fillArea(area, project)
    local cellSize = ECConfig.SITE_DECORATION_CELL_SIZE
    local gridW = math.floor((area.halfX * 2) / cellSize)
    local gridH = math.floor((area.halfZ * 2) / cellSize)

    if gridW < 1 or gridH < 1 then
        return {}
    end

    local vehicleGrid, vGridW, vGridH = ECSiteVehicles.getOccupiedGrid(project)
    local grid = {}
    for r = 1, gridH do
        grid[r] = {}
        for c = 1, gridW do
            if vehicleGrid ~= nil and vGridW == gridW and vGridH == gridH and vehicleGrid[r] ~= nil then
                grid[r][c] = vehicleGrid[r][c] or false
            else
                grid[r][c] = false
            end
        end
    end

    local nodes = {}
    local decorations = ECConfig.SITE_DECORATIONS
    local attempts = gridW * gridH * ECConfig.SITE_DECORATION_ATTEMPT_MULTIPLIER
    local placedCounts = {}
    local placedPositions = {}
    local clusterChance = ECConfig.SITE_DECORATION_CLUSTER_CHANCE
    local clusterRadius = ECConfig.SITE_DECORATION_CLUSTER_RADIUS

    local priorityItems = {}
    for decoIndex, deco in ipairs(decorations) do
        if deco.priority ~= nil then
            table.insert(priorityItems, { index = decoIndex, priority = deco.priority })
        end
    end
    table.sort(priorityItems, function(a, b) return a.priority < b.priority end)

    for _, item in ipairs(priorityItems) do
        local decoIndex = item.index
        local deco = decorations[decoIndex]
        local maxCount = deco.max or 1

        for _ = 1, attempts do
            if (placedCounts[decoIndex] or 0) >= maxCount then
                break
            end

            local decoW, decoD = ECSiteDecorator.getDecoSize(deco)
            local rotation = math.random(0, 3)
            local w, d
            if rotation % 2 == 0 then
                w = decoW
                d = decoD
            else
                w = decoD
                d = decoW
            end

            local cellsW = math.ceil(w / cellSize)
            local cellsD = math.ceil(d / cellSize)

            if cellsW > gridW or cellsD > gridH then
                break
            end

            local col = math.random(1, gridW - cellsW + 1)
            local row = math.random(1, gridH - cellsD + 1)

            if not ECSiteDecorator.canPlace(grid, row, col, cellsD, cellsW) then
                continue
            end

            local localX = ((col - 1 + cellsW * 0.5) * cellSize) - area.halfX
            local localZ = ((row - 1 + cellsD * 0.5) * cellSize) - area.halfZ

            if ECSiteDecorator.straddlesInnerFence(area, localX, localZ, w * 0.5, d * 0.5) then
                continue
            end

            ECSiteDecorator.markCells(grid, row, col, cellsD, cellsW)

            local wx = area.cx + area.sideX * localX + area.dirX * localZ
            local wz = area.cz + area.sideZ * localX + area.dirZ * localZ
            local wy = getTerrainHeightAtWorldPos(g_terrainNode, wx, 0, wz)

            local itemRotY = area.rotY + rotation * math.pi * 0.5

            local node = ECSiteDecorator.placeDecoration(ECSiteDecorator.resolveI3dPath(deco), wx, wy, wz, itemRotY)
            if node ~= nil then
                table.insert(nodes, node)
                placedCounts[decoIndex] = (placedCounts[decoIndex] or 0) + 1
                table.insert(placedPositions, { col = col, row = row })
            end
        end
    end

    for _ = 1, attempts do
        local decoIndex = math.random(1, #decorations)
        local deco = decorations[decoIndex]

        if deco.max ~= nil and (placedCounts[decoIndex] or 0) >= deco.max then
            continue
        end

        local decoW, decoD = ECSiteDecorator.getDecoSize(deco)
        local rotation = math.random(0, 3)
        local w, d
        if rotation % 2 == 0 then
            w = decoW
            d = decoD
        else
            w = decoD
            d = decoW
        end

        local cellsW = math.ceil(w / cellSize)
        local cellsD = math.ceil(d / cellSize)

        if cellsW > gridW or cellsD > gridH then
            continue
        end

        local col, row
        if #placedPositions > 0 and math.random() < clusterChance then
            local anchor = placedPositions[math.random(1, #placedPositions)]
            col = anchor.col + math.random(-clusterRadius, clusterRadius)
            row = anchor.row + math.random(-clusterRadius, clusterRadius)
            col = math.max(1, math.min(col, gridW - cellsW + 1))
            row = math.max(1, math.min(row, gridH - cellsD + 1))
        else
            col = math.random(1, gridW - cellsW + 1)
            row = math.random(1, gridH - cellsD + 1)
        end

        if not ECSiteDecorator.canPlace(grid, row, col, cellsD, cellsW) then
            continue
        end

        local jitterX = (math.random() - 0.5) * cellSize * 0.5
        local jitterZ = (math.random() - 0.5) * cellSize * 0.5
        local localX = ((col - 1 + cellsW * 0.5) * cellSize) - area.halfX + jitterX
        local localZ = ((row - 1 + cellsD * 0.5) * cellSize) - area.halfZ + jitterZ

        if ECSiteDecorator.straddlesInnerFence(area, localX, localZ, w * 0.5, d * 0.5) then
            continue
        end

        ECSiteDecorator.markCells(grid, row, col, cellsD, cellsW)

        local wx = area.cx + area.sideX * localX + area.dirX * localZ
        local wz = area.cz + area.sideZ * localX + area.dirZ * localZ
        local wy = getTerrainHeightAtWorldPos(g_terrainNode, wx, 0, wz)

        local itemRotY = area.rotY + rotation * math.pi * 0.5

        local node = ECSiteDecorator.placeDecoration(ECSiteDecorator.resolveI3dPath(deco), wx, wy, wz, itemRotY)
        if node ~= nil then
            table.insert(nodes, node)
            placedCounts[decoIndex] = (placedCounts[decoIndex] or 0) + 1
            table.insert(placedPositions, { col = col, row = row })
        end
    end

    return nodes
end

function ECSiteDecorator.canPlace(grid, row, col, rows, cols)
    for r = row, row + rows - 1 do
        for c = col, col + cols - 1 do
            if grid[r][c] then
                return false
            end
        end
    end
    return true
end

function ECSiteDecorator.markCells(grid, row, col, rows, cols)
    for r = row, row + rows - 1 do
        for c = col, col + cols - 1 do
            grid[r][c] = true
        end
    end
end

function ECSiteDecorator.placeDecoration(i3dPath, wx, wy, wz, rotY)
    local i3dRoot, sharedLoadRequestId, failedReason = g_i3DManager:loadSharedI3DFile(i3dPath, false, false)
    if i3dRoot == nil or i3dRoot == 0 then
        print("EverythingConstructable: Failed to load decoration i3d: " .. tostring(i3dPath) .. " reason: " .. tostring(failedReason))
        return nil
    end

    local node = createTransformGroup("ecDecoration")
    link(getRootNode(), node)

    local clone = clone(i3dRoot, false, false, false)
    link(node, clone)

    setWorldTranslation(node, wx, wy, wz)
    setWorldRotation(node, 0, rotY, 0)

    g_i3DManager:releaseSharedI3DFile(sharedLoadRequestId)

    return node
end

function ECSiteDecorator.startSound(project, area)
    ECSiteDecorator.stopSound(project)

    local soundFile = ECSiteDecorator.modDir .. ECConfig.SITE_SOUND_FILE
    local wy = getTerrainHeightAtWorldPos(g_terrainNode, area.cx, 0, area.cz)

    local soundNode = createTransformGroup("ecSiteSound")
    link(getRootNode(), soundNode)
    setTranslation(soundNode, area.cx, wy + 1, area.cz)

    local innerRadius = math.max(area.halfX * 2, area.halfZ * 2) + ECConfig.SITE_SOUND_INNER_RADIUS_PADDING
    local outerRadius = innerRadius + ECConfig.SITE_SOUND_OUTER_RADIUS_PADDING
    local audioSource = createAudioSource("ec_construction_bg", soundFile, outerRadius, innerRadius, ECConfig.SITE_SOUND_VOLUME, 0)
    link(soundNode, audioSource)

    local sample = getAudioSourceSample(audioSource)
    playSample(sample, 0, ECConfig.SITE_SOUND_VOLUME, 0, 0, 0)

    project.soundNode = soundNode
    project.soundAudioSource = audioSource
    project.soundSample = sample
end

function ECSiteDecorator.stopSound(project)
    if project == nil then
        return
    end

    if project.soundSample ~= nil then
        stopSample(project.soundSample, 0, 0)
        project.soundSample = nil
    end

    if project.soundAudioSource ~= nil and entityExists(project.soundAudioSource) then
        delete(project.soundAudioSource)
        project.soundAudioSource = nil
    end

    if project.soundNode ~= nil and entityExists(project.soundNode) then
        delete(project.soundNode)
        project.soundNode = nil
    end
end

function ECSiteDecorator.removeDecorations(project)
    if project == nil then
        return
    end

    ECSiteDecorator.stopSound(project)

    if project.decorationNodes == nil then
        return
    end

    for _, node in ipairs(project.decorationNodes) do
        if node ~= nil and entityExists(node) then
            delete(node)
        end
    end

    project.decorationNodes = nil
end
