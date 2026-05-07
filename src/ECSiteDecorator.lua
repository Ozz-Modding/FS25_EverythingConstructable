ECSiteDecorator = {}

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

    local halfX, halfZ
    if project.currentPhaseIndex >= 2 then
        local offset = ECConfig.FENCE_INNER_OFFSET
        halfX = math.max(0, (fp.sizeX or 10) * 0.5 - offset)
        halfZ = math.max(0, (fp.sizeZ or 10) * 0.5 - offset)
    else
        halfX = (fp.sizeX or 10) * 0.5
        halfZ = (fp.sizeZ or 10) * 0.5
    end

    if halfX < 1 or halfZ < 1 then
        return nil
    end

    local dirX, dirZ = MathUtil.getDirectionFromYRotation(rotY)
    local sideX, _, sideZ = MathUtil.crossProduct(0, 1, 0, dirX, 0, dirZ)

    local cx = pos[1] + dirX * (fp.centerZ or 0) + sideX * (fp.centerX or 0)
    local cz = pos[3] + dirZ * (fp.centerZ or 0) + sideZ * (fp.centerX or 0)

    return {
        cx = cx,
        cz = cz,
        halfX = halfX,
        halfZ = halfZ,
        dirX = dirX,
        dirZ = dirZ,
        sideX = sideX,
        sideZ = sideZ,
        rotY = rotY,
    }
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

    for _ = 1, attempts do
        local decoIndex = math.random(1, #decorations)
        local deco = decorations[decoIndex]

        local rotation = math.random(0, 3)
        local w, d
        if rotation % 2 == 0 then
            w = deco.width
            d = deco.depth
        else
            w = deco.depth
            d = deco.width
        end

        local cellsW = math.ceil(w / cellSize)
        local cellsD = math.ceil(d / cellSize)

        if cellsW <= gridW and cellsD <= gridH then
            local col = math.random(1, gridW - cellsW + 1)
            local row = math.random(1, gridH - cellsD + 1)

            if ECSiteDecorator.canPlace(grid, row, col, cellsD, cellsW) then
                ECSiteDecorator.markCells(grid, row, col, cellsD, cellsW)

                local localX = ((col - 1 + cellsW * 0.5) * cellSize) - area.halfX
                local localZ = ((row - 1 + cellsD * 0.5) * cellSize) - area.halfZ

                local wx = area.cx + area.sideX * localX + area.dirX * localZ
                local wz = area.cz + area.sideZ * localX + area.dirZ * localZ
                local wy = getTerrainHeightAtWorldPos(g_terrainNode, wx, 0, wz)

                local itemRotY = area.rotY + rotation * math.pi * 0.5

                local node = ECSiteDecorator.placeDecoration(deco.i3d, wx, wy, wz, itemRotY)
                if node ~= nil then
                    table.insert(nodes, node)
                end
            end
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
