ECPalletCollector = {}
local ECPalletCollector_mt = Class(ECPalletCollector)

ECPalletCollector.TRIGGER_I3D = g_currentModDirectory .. "assets/palletTrigger.i3d"
ECPalletCollector.TILE_SIZE = 1
ECPalletCollector.TILE_HEIGHT = 2

function ECPalletCollector.new(project)
    local self = setmetatable({}, ECPalletCollector_mt)
    self.project = project
    self.triggers = {}
    self.isDeleted = false
    return self
end

function ECPalletCollector:createTrigger()
    local fp = self.project.footprint
    if fp == nil or fp.sizeX == nil then
        return false
    end

    local pos = self.project.position
    local rotY = fp.rotY or 0
    local dirX, dirZ = MathUtil.getDirectionFromYRotation(rotY)
    local sideX, _, sideZ = MathUtil.crossProduct(0, 1, 0, dirX, 0, dirZ)
    local cx = pos[1] + dirX * (fp.centerZ or 0) + sideX * (fp.centerX or 0)
    local cy = pos[2] + 0.5
    local cz = pos[3] + dirZ * (fp.centerZ or 0) + sideZ * (fp.centerX or 0)

    -- First place the known-working single trigger at center+5 height
    self:placeTriggerAt(cx, pos[2] + 5, cz, rotY)

    -- Then try placing a border at ground level, tight to the fence
    local tileSize = ECPalletCollector.TILE_SIZE
    local halfX, halfZ

    if self.project.fenceCorners ~= nil then
        local c1 = self.project.fenceCorners[1]
        local c3 = self.project.fenceCorners[3]
        local dx = (c3[1] - c1[1]) * sideX + (c3[2] - c1[2]) * sideZ
        local dz = (c3[1] - c1[1]) * dirX + (c3[2] - c1[2]) * dirZ
        halfX = math.abs(dx) * 0.5 + tileSize
        halfZ = math.abs(dz) * 0.5 + tileSize
    else
        halfX = (fp.sizeX + 2) * 0.5
        halfZ = (fp.sizeZ + 2) * 0.5
    end

    local tilesX = math.ceil((halfX * 2) / tileSize)
    local tilesZ = math.ceil((halfZ * 2) / tileSize)

    local tileHeight = ECPalletCollector.TILE_HEIGHT

    for tx = 0, tilesX - 1 do
        for tz = 0, tilesZ - 1 do
            if tx == 0 or tx == tilesX - 1 or tz == 0 or tz == tilesZ - 1 then
                local localX = -halfX + tileSize * 0.5 + tx * tileSize
                local localZ = -halfZ + tileSize * 0.5 + tz * tileSize

                local worldX = cx + sideX * localX + dirX * localZ
                local worldZ = cz + sideZ * localX + dirZ * localZ

                for row = 0, tileHeight - 1 do
                    self:placeTriggerAt(worldX, cy + row, worldZ, rotY)
                end
            end
        end
    end

    print(string.format("ECPalletCollector: placed %d triggers (%d border + 1 center)", #self.triggers, #self.triggers - 1))

    return #self.triggers > 0
end

function ECPalletCollector:placeTriggerAt(wx, wy, wz, rotY)
    local i3dRoot = loadI3DFile(ECPalletCollector.TRIGGER_I3D)
    if i3dRoot == nil or i3dRoot == 0 then
        return
    end

    local triggerNode
    local numChildren = getNumOfChildren(i3dRoot)
    if numChildren > 0 then
        triggerNode = getChildAt(i3dRoot, 0)
    else
        triggerNode = i3dRoot
        i3dRoot = nil
    end

    setWorldTranslation(triggerNode, wx, wy, wz)
    setWorldRotation(triggerNode, 0, rotY, 0)
    addTrigger(triggerNode, "onTriggerCallback", self)

    table.insert(self.triggers, {i3dRoot = i3dRoot, triggerNode = triggerNode})
end

function ECPalletCollector:delete()
    self.isDeleted = true

    for _, t in ipairs(self.triggers) do
        if t.triggerNode ~= nil then
            removeTrigger(t.triggerNode)
        end
        if t.i3dRoot ~= nil then
            delete(t.i3dRoot)
        elseif t.triggerNode ~= nil then
            delete(t.triggerNode)
        end
    end
    self.triggers = {}
end

function ECPalletCollector:onTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
    if self.isDeleted or self.project == nil or self.project.completed then
        return
    end

    if not onEnter then
        return
    end

    if not g_currentMission:getIsServer() then
        return
    end

    local object = g_currentMission:getNodeObject(otherId)
    if object == nil then
        object = g_currentMission:getNodeObject(getParent(otherId))
    end
    if object == nil then
        return
    end

    if object.getFillUnits == nil then
        return
    end

    self:tryAbsorbPallet(object)
end

function ECPalletCollector:tryAbsorbPallet(pallet)
    if pallet.getFillUnitFillLevel == nil or pallet.addFillUnitFillLevel == nil or pallet.getFillUnitFillType == nil then
        return
    end

    local manager = g_currentMission.ecProjectManager
    local fillUnits = pallet:getFillUnits()

    for fillUnitIndex, _ in pairs(fillUnits) do
        local fillTypeIndex = pallet:getFillUnitFillType(fillUnitIndex)
        if fillTypeIndex ~= nil and fillTypeIndex ~= FillType.UNKNOWN then
            local fillLevel = pallet:getFillUnitFillLevel(fillUnitIndex)
            if fillLevel > 0 then
                local needed = self:getNeededAmount(fillTypeIndex)
                if needed > 0 then
                    local toTake = math.min(fillLevel, needed)
                    pallet:addFillUnitFillLevel(pallet:getOwnerFarmId(), fillUnitIndex, -toTake, fillTypeIndex, ToolType.UNDEFINED)

                    local delivered = manager:deliverResource(self.project.id, fillTypeIndex, toTake)
                    if delivered > 0 then
                        g_server:broadcastEvent(ECResourceDeliveredEvent.new(self.project.id, fillTypeIndex, delivered))
                    end

                    local remaining = pallet:getFillUnitFillLevel(fillUnitIndex)
                    if remaining <= 0.001 then
                        pallet:delete()
                        return
                    end
                end
            end
        end
    end
end

function ECPalletCollector:getNeededAmount(fillTypeIndex)
    for _, mat in ipairs(self.project.materials) do
        if mat.fillTypeIndex == fillTypeIndex then
            return mat.amount - mat.delivered
        end
    end
    return 0
end

