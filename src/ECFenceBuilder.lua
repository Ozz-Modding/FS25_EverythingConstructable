ECFenceBuilder = {}

-- panel04 outer TG contains two sub-panels (panel04 at Z=3.6, panel04a at Z=7.2).
-- We clone the first child (index 0) to get a single panel mesh.
-- panel07 and panel12 are single-panel TGs with mesh directly as children.
-- All are placed via setWorldTranslation so local offsets don't affect world position.
ECFenceBuilder.PANEL_NODE_NAME = {
    outer   = "panel04",   -- clone child 0 of this group
    inner   = "panel07",   -- clone group directly
    pasture = "panel12",   -- clone group directly
}
ECFenceBuilder.PANEL_LENGTH = {
    outer   = 3.6,
    inner   = 3.604,
    pasture = 2.17,
}
ECFenceBuilder.FENCE_I3D = "assets/fence/Fence01.i3d"

-- ─── panel placement ──────────────────────────────────────────────────────────

function ECFenceBuilder.loadFenceI3D()
    local path = EverythingConstructable.dir .. ECFenceBuilder.FENCE_I3D
    local root, sharedId = g_i3DManager:loadSharedI3DFile(path, false, false)
    if root == nil or root == 0 then
        return nil, nil
    end
    return root, sharedId
end

function ECFenceBuilder.placePanels(corners, nodeName, panelLength, useFirstChild)
    local root, sharedId = ECFenceBuilder.loadFenceI3D()
    if root == nil then return {} end

    local panelGroup = getChild(root, nodeName)
    if panelGroup == nil or panelGroup == 0 then
        g_i3DManager:releaseSharedI3DFile(sharedId)
        return {}
    end
    -- For panel04: clone child 0 (single-panel sub-TG) to avoid the 2-panel template
    local sourceNode = useFirstChild and getChildAt(panelGroup, 0) or panelGroup

    local nodes = {}

    for i = 1, 4 do
        local nextI = (i % 4) + 1
        local x1, z1 = corners[i][1], corners[i][2]
        local x2, z2 = corners[nextI][1], corners[nextI][2]
        local dx, dz = x2 - x1, z2 - z1
        local dist = math.sqrt(dx * dx + dz * dz)
        local rotY = math.atan2(dx, dz)
        local numPanels = math.max(1, math.floor(dist / panelLength + 0.5))

        for p = 0, numPanels - 1 do
            local t = p / numPanels
            local wx = x1 + dx * t
            local wz = z1 + dz * t
            local wy = getTerrainHeightAtWorldPos(g_terrainNode, wx, 0, wz)

            local c = clone(sourceNode, false, false, false)
            link(getRootNode(), c)
            setWorldTranslation(c, wx, wy, wz)
            setWorldRotation(c, 0, rotY, 0)
            setVisibility(c, true)
            addToPhysics(c)
            table.insert(nodes, c)
        end
    end

    g_i3DManager:releaseSharedI3DFile(sharedId)
    return nodes
end

function ECFenceBuilder.deleteNodes(nodeList)
    if nodeList == nil then return end
    for _, node in ipairs(nodeList) do
        if node ~= nil and entityExists(node) then
            removeFromPhysics(node)
            delete(node)
        end
    end
end

-- ─── outer fence ─────────────────────────────────────────────────────────────

function ECFenceBuilder.buildFence(project)
    if project == nil or project.footprint == nil then return end

    local corners = ECFenceBuilder.calculateCorners(project)
    if corners == nil then return end

    project.fenceCorners = corners
    project.fencePanelNodes = ECFenceBuilder.placePanels(
        corners, ECFenceBuilder.PANEL_NODE_NAME.outer, ECFenceBuilder.PANEL_LENGTH.outer, true)
    ECFenceBuilder.placeFenceSigns(project)
end

function ECFenceBuilder.removeFence(project)
    if project == nil then return end

    ECFenceBuilder.removeFenceSigns(project)
    ECFenceBuilder.removeInnerFence(project)
    ECFenceBuilder.removePastureFence(project)

    ECFenceBuilder.deleteNodes(project.fencePanelNodes)
    project.fencePanelNodes = nil
    project.fenceCorners = nil
end

-- ─── inner fence ─────────────────────────────────────────────────────────────

function ECFenceBuilder.buildInnerFence(project)
    if project == nil or project.footprint == nil then return end
    if project.innerFencePanelNodes ~= nil then return end

    local corners = ECFenceBuilder.calculateInnerCorners(project)
    if corners == nil then return end

    project.innerFenceCorners = corners
    project.innerFencePanelNodes = ECFenceBuilder.placePanels(
        corners, ECFenceBuilder.PANEL_NODE_NAME.inner, ECFenceBuilder.PANEL_LENGTH.inner, false)
end

function ECFenceBuilder.removeInnerFence(project)
    if project == nil then return end

    ECFenceBuilder.deleteNodes(project.innerFencePanelNodes)
    project.innerFencePanelNodes = nil
    project.innerFenceCorners = nil
end

-- ─── pasture fence ───────────────────────────────────────────────────────────

function ECFenceBuilder.buildPastureFence(project)
    if project == nil or project.husbandryFenceData == nil then return end

    local siteCorners = ECFenceBuilder.calculateCorners(project)
    if siteCorners == nil then return end

    local root, sharedId = ECFenceBuilder.loadFenceI3D()
    if root == nil then return end

    local nodeName = ECFenceBuilder.PANEL_NODE_NAME.pasture
    local panelLength = ECFenceBuilder.PANEL_LENGTH.pasture
    local sourceNode = getChild(root, nodeName)
    local pieces = ECFenceBuilder.subdivideFenceData(project.husbandryFenceData, panelLength)
    local nodes = {}

    if sourceNode ~= nil and sourceNode ~= 0 then
        for _, piece in ipairs(pieces) do
            if not ECFenceBuilder.segmentInsideSite(piece.sx, piece.sz, piece.ex, piece.ez, siteCorners) then
                local dx = piece.ex - piece.sx
                local dz = piece.ez - piece.sz
                local wx = piece.sx
                local wz = piece.sz
                local wy = getTerrainHeightAtWorldPos(g_terrainNode, wx, 0, wz)
                local rotY = math.atan2(dx, dz)

                local c = clone(sourceNode, false, false, false)
                link(getRootNode(), c)
                setWorldTranslation(c, wx, wy, wz)
                setWorldRotation(c, 0, rotY, 0)
                setVisibility(c, true)
                table.insert(nodes, c)
            end
        end
    end

    g_i3DManager:releaseSharedI3DFile(sharedId)

    if #nodes > 0 then
        project.pasturePanelNodes = nodes
    end
end

function ECFenceBuilder.removePastureFence(project)
    if project == nil then return end

    ECFenceBuilder.deleteNodes(project.pasturePanelNodes)
    project.pasturePanelNodes = nil
end

-- ─── fence signs ─────────────────────────────────────────────────────────────

function ECFenceBuilder.placeFenceSigns(project)
    if project == nil or project.fenceCorners == nil then return end

    ECFenceBuilder.removeFenceSigns(project)

    local i3dPath = ECSiteDecorator.modDir .. ECConfig.FENCE_SIGN_I3D
    local height = ECConfig.FENCE_SIGN_HEIGHT
    local interval = ECConfig.FENCE_SIGN_PANEL_INTERVAL
    local panelLength = ECFenceBuilder.PANEL_LENGTH.outer
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
    if i3dRoot == nil or i3dRoot == 0 then return nil end

    local node = createTransformGroup("ecFenceSign")
    link(getRootNode(), node)
    local c = clone(i3dRoot, false, false, false)
    link(node, c)
    setWorldTranslation(node, wx, wy, wz)
    setWorldRotation(node, 0, rotY, 0)
    g_i3DManager:releaseSharedI3DFile(sharedLoadRequestId)
    return node
end

function ECFenceBuilder.removeFenceSigns(project)
    if project == nil or project.fenceSignNodes == nil then return end

    ECFenceBuilder.deleteNodes(project.fenceSignNodes)
    project.fenceSignNodes = nil
end

-- ─── geometry helpers ─────────────────────────────────────────────────────────

function ECFenceBuilder.snapToPanel(halfDist, panelLength)
    local panels = math.max(1, math.floor((halfDist * 2) / panelLength))
    return (panels * panelLength) / 2
end

function ECFenceBuilder.calculateCorners(project)
    local pos = project.position
    local fp = project.footprint
    local panelLength = ECFenceBuilder.PANEL_LENGTH.outer
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

function ECFenceBuilder.calculateInnerCorners(project)
    local pos = project.position
    local fp = project.footprint
    local panelLength = ECFenceBuilder.PANEL_LENGTH.inner
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

-- ─── pasture helpers ─────────────────────────────────────────────────────────

function ECFenceBuilder.subdivideFenceData(fenceData, panelLength)
    local pieces = {}
    for _, segData in ipairs(fenceData) do
        local sx, sz = segData.startPos[1], segData.startPos[3]
        local ex, ez = segData.endPos[1], segData.endPos[3]
        local dx = ex - sx
        local dz = ez - sz
        local dist = math.sqrt(dx * dx + dz * dz)
        if dist >= 0.1 then
            local ux = dx / dist
            local uz = dz / dist
            local numPanels = math.max(1, math.floor(dist / panelLength + 0.5))
            for i = 0, numPanels - 1 do
                table.insert(pieces, {
                    sx = sx + ux * panelLength * i,
                    sz = sz + uz * panelLength * i,
                    ex = sx + ux * panelLength * (i + 1),
                    ez = sz + uz * panelLength * (i + 1),
                })
            end
        end
    end
    return pieces
end

function ECFenceBuilder.segmentInsideSite(sx, sz, ex, ez, corners)
    if ECFenceBuilder.pointInsideQuad(sx, sz, corners) then return true end
    if ECFenceBuilder.pointInsideQuad(ex, ez, corners) then return true end
    local midX = (sx + ex) * 0.5
    local midZ = (sz + ez) * 0.5
    if ECFenceBuilder.pointInsideQuad(midX, midZ, corners) then return true end
    for i = 1, 4 do
        local nextI = (i % 4) + 1
        local ax, az = corners[i][1], corners[i][2]
        local bx, bz = corners[nextI][1], corners[nextI][2]
        if ECFenceBuilder.linesIntersect(sx, sz, ex, ez, ax, az, bx, bz) then return true end
    end
    return false
end

function ECFenceBuilder.linesIntersect(ax, az, bx, bz, cx, cz, dx, dz)
    local d1 = (dx - cx) * (az - cz) - (dz - cz) * (ax - cx)
    local d2 = (dx - cx) * (bz - cz) - (dz - cz) * (bx - cx)
    local d3 = (bx - ax) * (cz - az) - (bz - az) * (cx - ax)
    local d4 = (bx - ax) * (dz - az) - (bz - az) * (dx - ax)
    return d1 * d2 < 0 and d3 * d4 < 0
end

function ECFenceBuilder.pointInsideQuad(px, pz, corners)
    for i = 1, 4 do
        local nextI = (i % 4) + 1
        local ax, az = corners[i][1], corners[i][2]
        local bx, bz = corners[nextI][1], corners[nextI][2]
        if (bx - ax) * (pz - az) - (bz - az) * (px - ax) < -0.5 then
            return false
        end
    end
    return true
end
