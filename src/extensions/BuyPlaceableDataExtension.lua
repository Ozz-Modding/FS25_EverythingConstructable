BuyPlaceableDataExtension = {}

BuyPlaceableData.onBought = Utils.overwrittenFunction(BuyPlaceableData.onBought, function(self, superFunc, placeable, loadingState, args)
    if loadingState ~= PlaceableLoadingState.OK then
        superFunc(self, placeable, loadingState, args)
        return
    end

    if not ECSettings.current.constructionEnabled then
        superFunc(self, placeable, loadingState, args)
        return
    end

    if not ECConfig.shouldApplyConstruction(self.storeItem, placeable) then
        superFunc(self, placeable, loadingState, args)
        return
    end

    local isHusbandryBrush = self.storeItem.brush ~= nil and self.storeItem.brush.type == "husbandry"
    if placeable.spec_husbandryFence ~= nil and isHusbandryBrush and g_currentMission:getIsServer() then
        local deposit = ECConfig.getDepositAmount(self.price)
        local displacementCosts = self.displacementCosts or 0
        if not self.isFreeOfCharge then
            g_currentMission:addMoney(-(deposit + displacementCosts), self.ownerFarmId, MoneyType.SHOP_PROPERTY_BUY, true, true)
        end
        placeable:finalizePlacement()
        placeable:onBuy()
        HusbandryFenceExtension.markForConversion(placeable, self)
        if args.callback ~= nil then
            args.callback(args.callbackTarget, placeable, PlaceableLoadingState.OK, args.callbackArguments)
        end
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

    if args.callback ~= nil then
        args.callback(args.callbackTarget, placeable, PlaceableLoadingState.OK, args.callbackArguments)
    end

    placeable:delete()

    ECFenceBuilder.shrinkFootprintToAvoidCollisions(footprint, position, rotation)

    local manager = g_currentMission.ecProjectManager
    if manager ~= nil and g_currentMission:getIsServer() then
        local project = manager:createProject(
            farmId, storeItemXml, position, rotation,
            configurations, {}, totalPrice, displacementCosts, footprint
        )

        ECFenceBuilder.buildFence(project)
        ECSiteDecorator.decorate(project)
        ECTerrainPainter.clearFootprint(project)

        local deposit = project.depositAmount + displacementCosts
        g_currentMission:addMoney(-deposit, farmId, MoneyType.SHOP_PROPERTY_BUY, true, true)

        g_server:broadcastEvent(ECCreateProjectEvent.new(project))
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

    local areas = BuyPlaceableDataExtension.getParallelogramAreas(placeable)
    if areas ~= nil then
        BuyPlaceableDataExtension.footprintFromParallelogramAreas(areas, placeable.rootNode, footprint)
    elseif placeable.spec_placement ~= nil and placeable.spec_placement.testAreas ~= nil then
        BuyPlaceableDataExtension.footprintFromTestAreas(placeable.spec_placement.testAreas, footprint)
    end

    return footprint
end

function BuyPlaceableDataExtension.getParallelogramAreas(placeable)
    if placeable.spec_clearAreas ~= nil and placeable.spec_clearAreas.areas ~= nil and #placeable.spec_clearAreas.areas > 0 then
        return placeable.spec_clearAreas.areas
    end

    if placeable.spec_leveling ~= nil and placeable.spec_leveling.levelAreas ~= nil and #placeable.spec_leveling.levelAreas > 0 then
        return placeable.spec_leveling.levelAreas
    end

    return nil
end

function BuyPlaceableDataExtension.footprintFromParallelogramAreas(areas, rootNode, footprint)
    local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge

    for _, area in ipairs(areas) do
        local startNode = area.start or area.startNode
        local widthNode = area.width or area.widthNode
        local heightNode = area.height or area.heightNode

        if startNode ~= nil and widthNode ~= nil and heightNode ~= nil then
            local sx, _, sz = localToLocal(startNode, rootNode, 0, 0, 0)
            local wx, _, wz = localToLocal(widthNode, rootNode, 0, 0, 0)
            local hx, _, hz = localToLocal(heightNode, rootNode, 0, 0, 0)

            local corners = {
                {sx, sz},
                {wx, wz},
                {hx, hz},
                {wx + hx - sx, wz + hz - sz},
            }

            for _, c in ipairs(corners) do
                minX = math.min(minX, c[1])
                maxX = math.max(maxX, c[1])
                minZ = math.min(minZ, c[2])
                maxZ = math.max(maxZ, c[2])
            end
        end
    end

    if minX < math.huge then
        footprint.sizeX = (maxX - minX) + ECConfig.FENCE_PADDING * 2
        footprint.sizeZ = (maxZ - minZ) + ECConfig.FENCE_PADDING * 2
        footprint.centerX = (minX + maxX) * 0.5
        footprint.centerZ = (minZ + maxZ) * 0.5
    end
end

function BuyPlaceableDataExtension.footprintFromTestAreas(testAreas, footprint)
    local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge

    for _, area in ipairs(testAreas) do
        if area.size ~= nil then
            local halfX = (area.size.x or 5) * 0.5
            local halfZ = (area.size.z or 5) * 0.5
            local cx = area.center ~= nil and area.center.x or 0
            local cz = area.center ~= nil and area.center.z or 0
            local rotOffset = area.rotYOffset or 0

            if math.abs(rotOffset) < 0.001 then
                minX = math.min(minX, cx - halfX)
                maxX = math.max(maxX, cx + halfX)
                minZ = math.min(minZ, cz - halfZ)
                maxZ = math.max(maxZ, cz + halfZ)
            else
                local cosR = math.cos(rotOffset)
                local sinR = math.sin(rotOffset)
                local corners = {
                    {-halfX, -halfZ},
                    { halfX, -halfZ},
                    { halfX,  halfZ},
                    {-halfX,  halfZ},
                }
                for _, c in ipairs(corners) do
                    local rx = c[1] * cosR - c[2] * sinR + cx
                    local rz = c[1] * sinR + c[2] * cosR + cz
                    minX = math.min(minX, rx)
                    maxX = math.max(maxX, rx)
                    minZ = math.min(minZ, rz)
                    maxZ = math.max(maxZ, rz)
                end
            end
        end
    end

    if minX < math.huge then
        footprint.sizeX = (maxX - minX) + ECConfig.FENCE_PADDING * 2
        footprint.sizeZ = (maxZ - minZ) + ECConfig.FENCE_PADDING * 2
        footprint.centerX = (minX + maxX) * 0.5
        footprint.centerZ = (minZ + maxZ) * 0.5
    end
end
