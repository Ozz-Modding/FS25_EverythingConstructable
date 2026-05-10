ECSiteDecorator = {}
ECSiteDecorator.sizeCache = {}

function ECSiteDecorator.getDecoSize(deco)
    if deco.width ~= nil and deco.depth ~= nil then
        local buf = ECConfig.SITE_DECORATION_SIZE_BUFFER * 2
        return deco.width + buf, deco.depth + buf
    end

    local cached = ECSiteDecorator.sizeCache[deco.i3d]
    if cached ~= nil then
        local buf = ECConfig.SITE_DECORATION_SIZE_BUFFER * 2
        return cached.width + buf, cached.depth + buf
    end

    local i3dRoot, sharedLoadRequestId = g_i3DManager:loadSharedI3DFile(deco.i3d, false, false)
    if i3dRoot == nil or i3dRoot == 0 then
        ECSiteDecorator.sizeCache[deco.i3d] = { width = 2, depth = 2 }
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

    ECSiteDecorator.sizeCache[deco.i3d] = { width = rawWidth, depth = rawDepth }

    local buf = ECConfig.SITE_DECORATION_SIZE_BUFFER * 2
    return rawWidth + buf, rawDepth + buf
end

function ECSiteDecorator.decorate(project)
    if project == nil or project.footprint == nil then
        return
    end

    if #ECConfig.SITE_DECORATIONS == 0 then
        return
    end

    ECSiteDecorator.removeDecorations(project)

    local area = ECSiteDecorator.getPlacementArea(project)
    if area == nil then
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

    local grid = {}
    for r = 1, gridH do
        grid[r] = {}
        for c = 1, gridW do
            grid[r][c] = false
        end
    end

    local nodes = {}
    local decorations = ECConfig.SITE_DECORATIONS
    local attempts = gridW * gridH * 2
    local placedCounts = {}

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

        local node = ECSiteDecorator.placeDecoration(deco.i3d, wx, wy, wz, itemRotY)
        if node ~= nil then
            table.insert(nodes, node)
            placedCounts[decoIndex] = (placedCounts[decoIndex] or 0) + 1
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

function ECSiteDecorator.removeDecorations(project)
    if project == nil or project.decorationNodes == nil then
        return
    end

    for _, node in ipairs(project.decorationNodes) do
        if node ~= nil and entityExists(node) then
            delete(node)
        end
    end

    project.decorationNodes = nil
end
