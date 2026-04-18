BuyPlaceableDataExtension = {}

BuyPlaceableData.onBought = Utils.overwrittenFunction(BuyPlaceableData.onBought, function(self, superFunc, placeable, loadingState, args)
    if loadingState ~= PlaceableLoadingState.OK then
        superFunc(self, placeable, loadingState, args)
        return
    end

    if not ECConfig.shouldApplyConstruction(self.storeItem, placeable) then
        superFunc(self, placeable, loadingState, args)
        return
    end

    local footprint = BuyPlaceableDataExtension.extractFootprint(placeable, self.position, self.rotation)

    local storeItemXml = self.storeItem.xmlFilename
    local position = {self.position[1], self.position[2], self.position[3]}
    local rotation = {self.rotation[1], self.rotation[2], self.rotation[3]}
    local totalPrice = self.price
    local displacementCosts = self.displacementCosts or 0
    local farmId = self.ownerFarmId
    local configurations = {}
    if self.configurations ~= nil then
        for k, v in pairs(self.configurations) do
            configurations[k] = v
        end
    end

    placeable:delete()

    local manager = g_currentMission.ecProjectManager
    if manager ~= nil and g_currentMission:getIsServer() then
        local project = manager:createProject(
            farmId, storeItemXml, position, rotation,
            configurations, {}, totalPrice, displacementCosts, footprint
        )

        ECFenceBuilder.buildFence(project)
        ECTerrainPainter.clearFootprint(project)

        local deposit = project.depositAmount + displacementCosts
        g_currentMission:addMoney(-deposit, farmId, MoneyType.SHOP_PROPERTY_BUY, true, true)

        g_server:broadcastEvent(ECCreateProjectEvent.new(project))
    end

    if args.callback ~= nil then
        args.callback(args.callbackTarget, nil, PlaceableLoadingState.OK, args.callbackArguments)
    end
end)

function BuyPlaceableDataExtension.extractFootprint(placeable, position, rotation)
    local footprint = {
        sizeX = 10,
        sizeZ = 10,
        centerX = 0,
        centerZ = 0,
        rotY = rotation[2] or 0,
    }

    if placeable.spec_placement ~= nil and placeable.spec_placement.testAreas ~= nil then
        local testAreas = placeable.spec_placement.testAreas
        local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge

        for _, area in ipairs(testAreas) do
            if area.size ~= nil then
                local halfX = (area.size.x or 5) * 0.5
                local halfZ = (area.size.z or 5) * 0.5
                local cx = area.center ~= nil and area.center.x or 0
                local cz = area.center ~= nil and area.center.z or 0

                minX = math.min(minX, cx - halfX)
                maxX = math.max(maxX, cx + halfX)
                minZ = math.min(minZ, cz - halfZ)
                maxZ = math.max(maxZ, cz + halfZ)
            end
        end

        if minX < math.huge then
            footprint.sizeX = (maxX - minX) + ECConfig.FENCE_PADDING * 2
            footprint.sizeZ = (maxZ - minZ) + ECConfig.FENCE_PADDING * 2
            footprint.centerX = (minX + maxX) * 0.5
            footprint.centerZ = (minZ + maxZ) * 0.5
        end
    end

    return footprint
end
