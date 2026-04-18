ECConstructionActivatable = {}
local ECConstructionActivatable_mt = Class(ECConstructionActivatable)

ECConstructionActivatable.ACTIVATION_DISTANCE = 8

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
    local dx = px - self.project.position[1]
    local dz = pz - self.project.position[3]
    return MathUtil.vector2Length(dx, dz) <= ECConstructionActivatable.ACTIVATION_DISTANCE
end

function ECConstructionActivatable:getDistance(x, y, z)
    if self.project == nil then
        return math.huge
    end
    return MathUtil.vector2Length(x - self.project.position[1], z - self.project.position[3])
end

function ECConstructionActivatable:run()
    if self.project == nil then
        return
    end
    ECConstructionDialog.show(self.project)
end

function ECConstructionActivatable:activate() end
function ECConstructionActivatable:deactivate() end
