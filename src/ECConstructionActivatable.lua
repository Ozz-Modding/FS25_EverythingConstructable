ECConstructionActivatable = {}
local ECConstructionActivatable_mt = Class(ECConstructionActivatable)

function ECConstructionActivatable.new(project)
    local self = setmetatable({}, ECConstructionActivatable_mt)
    self.project = project
    self.activateText = g_i18n:getText("ec_action_viewConstruction")
    return self
end

function ECConstructionActivatable:getIsActivatable()
    if self.project == nil or self.project.completed then
        return false
    end
    if g_localPlayer == nil or g_localPlayer.rootNode == nil then
        return false
    end
    if g_localPlayer:getCurrentVehicle() ~= nil then
        return false
    end

    local px, _, pz = getWorldTranslation(g_localPlayer.rootNode)
    local inRange = ECConstructionActivatable.isPointInFootprint(self.project, px, pz, ECConfig.ACTIVATABLE_BUFFER)

    if inRange and not self.wasInRange then
        ECPalletCollector.tryPlayEasterEgg(self.project)
    end
    self.wasInRange = inRange

    return inRange
end

function ECConstructionActivatable:getDistance(x, y, z)
    if self.project == nil then
        return math.huge
    end
    local fp = self.project.footprint
    if fp == nil or fp.sizeX == nil then
        return math.huge
    end

    local pos = self.project.position
    local rotY = fp.rotY or 0
    local dirX, dirZ = MathUtil.getDirectionFromYRotation(rotY)
    local sideX, _, sideZ = MathUtil.crossProduct(0, 1, 0, dirX, 0, dirZ)
    local cx = pos[1] + dirX * (fp.centerZ or 0) + sideX * (fp.centerX or 0)
    local cz = pos[3] + dirZ * (fp.centerZ or 0) + sideZ * (fp.centerX or 0)

    return MathUtil.vector2Length(x - cx, z - cz)
end

function ECConstructionActivatable:run()
    if self.project == nil then
        return
    end
    ECConstructionDialog.show(self.project)
end

function ECConstructionActivatable:activate() end
function ECConstructionActivatable:deactivate() end

function ECConstructionActivatable.isPointInFootprint(project, px, pz, buffer)
    local fp = project.footprint
    if fp == nil or fp.sizeX == nil then
        return false
    end

    local pos = project.position
    local rotY = fp.rotY or 0
    local dirX, dirZ = MathUtil.getDirectionFromYRotation(rotY)
    local sideX, _, sideZ = MathUtil.crossProduct(0, 1, 0, dirX, 0, dirZ)
    local cx = pos[1] + dirX * (fp.centerZ or 0) + sideX * (fp.centerX or 0)
    local cz = pos[3] + dirZ * (fp.centerZ or 0) + sideZ * (fp.centerX or 0)

    local dx = px - cx
    local dz = pz - cz
    local localX = dx * sideX + dz * sideZ
    local localZ = dx * dirX + dz * dirZ

    local halfX = fp.sizeX * 0.5 + (buffer or 0)
    local halfZ = fp.sizeZ * 0.5 + (buffer or 0)

    return math.abs(localX) <= halfX and math.abs(localZ) <= halfZ
end
