ECBuildingPlacer = {}

function ECBuildingPlacer.placeBuilding(project, callback)
    if project == nil then
        if callback ~= nil then
            callback(false)
        end
        return
    end

    local storeItem = g_storeManager:getItemByXMLFilename(project.storeItemXml)
    if storeItem == nil then
        print("EverythingConstructable: Store item not found: " .. tostring(project.storeItemXml))
        if callback ~= nil then
            callback(false)
        end
        return
    end

    local loadingData = PlaceableLoadingData.new()
    loadingData:setStoreItem(storeItem)
    loadingData:setConfigurations(project.configurations or {})
    loadingData:setOwnerFarmId(project.farmId)
    loadingData:setPosition(project.position[1], project.position[2], project.position[3])
    loadingData:setRotation(project.rotation[1], project.rotation[2], project.rotation[3])

    loadingData:load(function(_, placeable, loadingState)
        if loadingState ~= PlaceableLoadingState.OK or placeable == nil then
            print("EverythingConstructable: Failed to load placeable, state: " .. tostring(loadingState))
            if callback ~= nil then
                callback(false)
            end
            return
        end

        placeable:finalizePlacement()
        placeable:onBuy()

        print(string.format("EverythingConstructable: Building placed for project %d: %s",
            project.id, project:getStoreItemName()))

        if callback ~= nil then
            callback(true)
        end
    end, nil)
end
