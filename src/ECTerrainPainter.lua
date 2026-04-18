ECTerrainPainter = {}

function ECTerrainPainter.clearFootprint(project)
    if project == nil or project.footprint == nil then
        return
    end
    if not g_currentMission:getIsServer() then
        return
    end

    local pos = project.position
    local fp = project.footprint
    local halfX = (fp.sizeX or 10) * 0.5
    local halfZ = (fp.sizeZ or 10) * 0.5
    local rotY = fp.rotY or 0

    local dirX, dirZ = MathUtil.getDirectionFromYRotation(rotY)
    local sideX, _, sideZ = MathUtil.crossProduct(0, 1, 0, dirX, 0, dirZ)

    local cx = pos[1] + dirX * (fp.centerZ or 0) + sideX * (fp.centerX or 0)
    local cz = pos[3] + dirZ * (fp.centerZ or 0) + sideZ * (fp.centerX or 0)

    local x = cx - sideX * halfX - dirX * halfZ
    local z = cz - sideZ * halfX - dirZ * halfZ

    local x1 = cx + sideX * halfX - dirX * halfZ
    local z1 = cz + sideZ * halfX - dirZ * halfZ

    local x2 = cx - sideX * halfX + dirX * halfZ
    local z2 = cz - sideZ * halfX + dirZ * halfZ

    FSDensityMapUtil.removeFieldArea(x, z, x1, z1, x2, z2, false)
    FSDensityMapUtil.removeWeedArea(x, z, x1, z1, x2, z2)
    FSDensityMapUtil.removeStoneArea(x, z, x1, z1, x2, z2)
    FSDensityMapUtil.eraseTireTrack(x, z, x1, z1, x2, z2)
    FSDensityMapUtil.clearDecoArea(x, z, x1, z1, x2, z2)
    DensityMapHeightUtil.clearArea(x, z, x1, z1, x2, z2)
end
