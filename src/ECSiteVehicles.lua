ECSiteVehicles = {}
ECSiteVehicles.TERRAIN_OFFSET = 0.5
ECSiteVehicles.pendingRestrictions = {}
ECSiteVehicles.pendingObjectIds = {}
ECSiteVehicles.retryTimer = 0
ECSiteVehicles.RETRY_INTERVAL = 200

function ECSiteVehicles.spawnVehicles(project)
    if not g_currentMission:getIsServer() then
        return
    end

    if project == nil or project.footprint == nil then
        return
    end

    if #ECConfig.SITE_VEHICLES == 0 then
        return
    end

    ECSiteVehicles.removeVehicles(project)

    local area = ECSiteDecorator.getPlacementArea(project)
    if area == nil then
        return
    end

    local cellSize = ECConfig.SITE_DECORATION_CELL_SIZE
    local gridW = math.floor((area.halfX * 2) / cellSize)
    local gridH = math.floor((area.halfZ * 2) / cellSize)

    if gridW < 1 or gridH < 1 then
        return
    end

    local grid = project.vehicleGrid
    if grid == nil then
        grid = {}
        for r = 1, gridH do
            grid[r] = {}
            for c = 1, gridW do
                grid[r][c] = false
            end
        end
    end

    project.siteVehicles = project.siteVehicles or {}
    project.vehicleGrid = grid
    project.vehicleGridW = gridW
    project.vehicleGridH = gridH

    local vehicleIndex = math.random(1, #ECConfig.SITE_VEHICLES)
    local vehicleDef = ECConfig.SITE_VEHICLES[vehicleIndex]

    local storeItem = g_storeManager:getItemByXMLFilename(vehicleDef.xmlFilename)
    if storeItem == nil then
        print("EverythingConstructable: Site vehicle store item not found: " .. tostring(vehicleDef.xmlFilename))
        return
    end

    local sizeValues = StoreItemUtil.getSizeValues(vehicleDef.xmlFilename, "vehicle", storeItem.rotation or 0, nil)
    local width = (sizeValues.width or 3) + 1
    local length = (sizeValues.length or 6) + 1

    local cellsW = math.ceil(width / cellSize)
    local cellsD = math.ceil(length / cellSize)

    if cellsW > gridW or cellsD > gridH then
        return
    end

    local col, row = ECSiteVehicles.findPlacement(grid, gridW, gridH, cellsW, cellsD, area)
    if col == nil then
        return
    end

    ECSiteDecorator.markCells(grid, row, col, cellsD, cellsW)

    local localX = ((col - 1 + cellsW * 0.5) * cellSize) - area.halfX
    local localZ = ((row - 1 + cellsD * 0.5) * cellSize) - area.halfZ

    local wx = area.cx + area.sideX * localX + area.dirX * localZ
    local wz = area.cz + area.sideZ * localX + area.dirZ * localZ

    local yaw = area.rotY + math.random(0, 3) * math.pi * 0.5

    local data = VehicleLoadingData.new()
    data:setStoreItem(storeItem)
    data:setPosition(wx, nil, wz, ECSiteVehicles.TERRAIN_OFFSET)
    data:setRotation(0, yaw, 0)
    data:setIgnoreShopOffset(true)
    data:setPropertyState(VehiclePropertyState.OWNED)
    data:setOwnerFarmId(0)

    data:load(ECSiteVehicles.onVehicleLoaded, ECSiteVehicles, { project = project })
end

function ECSiteVehicles.findPlacement(grid, gridW, gridH, cellsW, cellsD, area)
    local maxAttempts = 50
    for _ = 1, maxAttempts do
        local col = math.random(1, gridW - cellsW + 1)
        local row = math.random(1, gridH - cellsD + 1)

        if ECSiteDecorator.canPlace(grid, row, col, cellsD, cellsW) then
            local localX = ((col - 1 + cellsW * 0.5) * ECConfig.SITE_DECORATION_CELL_SIZE) - area.halfX
            local localZ = ((row - 1 + cellsD * 0.5) * ECConfig.SITE_DECORATION_CELL_SIZE) - area.halfZ

            if not ECSiteDecorator.straddlesInnerFence(area, localX, localZ, cellsW * ECConfig.SITE_DECORATION_CELL_SIZE * 0.5, cellsD * ECConfig.SITE_DECORATION_CELL_SIZE * 0.5) then
                return col, row
            end
        end
    end
    return nil, nil
end

function ECSiteVehicles:onVehicleLoaded(loadedVehicles, loadState, args)
    if loadState ~= VehicleLoadingState.OK then
        if loadedVehicles ~= nil then
            for _, v in ipairs(loadedVehicles) do
                v:delete()
            end
        end
        return
    end

    local project = args.project
    if project == nil or project.completed then
        if loadedVehicles ~= nil then
            for _, v in ipairs(loadedVehicles) do
                v:delete()
            end
        end
        return
    end

    project.siteVehicles = project.siteVehicles or {}

    for _, vehicle in ipairs(loadedVehicles) do
        table.insert(project.siteVehicles, vehicle)

        if not ECSiteVehicles.applyRestrictions(vehicle) then
            table.insert(ECSiteVehicles.pendingRestrictions, vehicle)
        end

        if g_server ~= nil then
            local objectId = NetworkUtil.getObjectId(vehicle)
            if objectId ~= nil then
                g_server:broadcastEvent(ECSiteVehicleEvent.new(objectId))
            end
        end
    end
end

function ECSiteVehicles.applyRestrictions(vehicle)
    if vehicle.spec_drivable == nil then
        return false
    end

    local ok = pcall(vehicle.registerPlayerVehicleControlAllowedFunction,
        vehicle, vehicle, function() return false, nil end)
    if not ok then
        return false
    end

    if vehicle.setIsTabbable ~= nil then
        vehicle:setIsTabbable(false)
    end

    return true
end

function ECSiteVehicles.update(dt)
    if #ECSiteVehicles.pendingRestrictions == 0 and #ECSiteVehicles.pendingObjectIds == 0 then
        return
    end

    ECSiteVehicles.retryTimer = ECSiteVehicles.retryTimer - dt
    if ECSiteVehicles.retryTimer > 0 then
        return
    end
    ECSiteVehicles.retryTimer = ECSiteVehicles.RETRY_INTERVAL

    local i = #ECSiteVehicles.pendingObjectIds
    while i >= 1 do
        local objectId = ECSiteVehicles.pendingObjectIds[i]
        local vehicle = NetworkUtil.getObject(objectId)
        if vehicle ~= nil then
            table.remove(ECSiteVehicles.pendingObjectIds, i)
            if not ECSiteVehicles.applyRestrictions(vehicle) then
                table.insert(ECSiteVehicles.pendingRestrictions, vehicle)
            end
        end
        i = i - 1
    end

    i = #ECSiteVehicles.pendingRestrictions
    while i >= 1 do
        local vehicle = ECSiteVehicles.pendingRestrictions[i]
        if vehicle == nil or vehicle.isDeleted then
            table.remove(ECSiteVehicles.pendingRestrictions, i)
        elseif ECSiteVehicles.applyRestrictions(vehicle) then
            table.remove(ECSiteVehicles.pendingRestrictions, i)
        end
        i = i - 1
    end
end

function ECSiteVehicles.removeVehicles(project)
    if project == nil or project.siteVehicles == nil then
        return
    end

    for _, vehicle in ipairs(project.siteVehicles) do
        if vehicle ~= nil then
            vehicle:delete()
        end
    end

    project.siteVehicles = nil
    project.vehicleGrid = nil
    project.vehicleGridW = nil
    project.vehicleGridH = nil
end

function ECSiteVehicles.getOccupiedGrid(project)
    return project.vehicleGrid, project.vehicleGridW, project.vehicleGridH
end
