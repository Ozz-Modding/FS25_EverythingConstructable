ECConfig = {}

ECConfig.DURATION_THRESHOLDS = {
    { maxPrice = 10000, months = 1 },
    { maxPrice = 50000, months = 2 },
    { maxPrice = 100000, months = 3 },
    { maxPrice = 250000, months = 4 },
    { maxPrice = 500000, months = 6 },
    { maxPrice = 1000000, months = 9 },
    { maxPrice = math.huge, months = 12 },
}

ECConfig.DEPOSIT_FRACTION = 0.10
ECConfig.LABOUR_FRACTION = 0.32
ECConfig.MATERIAL_FRACTION = 0.68

ECConfig.RESOURCE_WEIGHTS = {
    { fillType = "BOARDS", weight = 5 },
    { fillType = "PLANKS", weight = 4 },
    { fillType = "WOODBEAM", weight = 3 },
    { fillType = "CEMENT", weight = 2 },
    { fillType = "PREFABWALL", weight = 1 },
    { fillType = "CEMENTBRICKS", weight = 1 },
    { fillType = "ROOFPLATES", weight = 1 },
}

ECConfig.DEFAULT_MODE = "automatic"

ECConfig.FENCE_XML = "data/placeables/brandless/fences/US/fence07/fenceMetal07.xml"
ECConfig.FENCE_INNER_XML = "data/placeables/brandless/fences/US/fence04/fence04.xml"

ECConfig.GROUND_TYPE = "asphalt"

ECConfig.MIN_PRICE_FOR_CONSTRUCTION = 5000

ECConfig.OVERRIDE_EXISTING_CONSTRUCTIBLES = false

ECConfig.CANCELLATION_REFUND_FRACTION = 0.20
ECConfig.CANCELLATION_MATERIAL_REFUND_FRACTION = 0.35

ECConfig.FENCE_PADDING = 2
ECConfig.FENCE_INNER_OFFSET = 2

ECConfig.ACTIVATABLE_BUFFER = 3

function ECConfig.getMonthsForPrice(price)
    for _, threshold in ipairs(ECConfig.DURATION_THRESHOLDS) do
        if price <= threshold.maxPrice then
            return threshold.months
        end
    end
    return 12
end

function ECConfig.getDepositAmount(totalPrice)
    return math.floor(totalPrice * ECConfig.DEPOSIT_FRACTION)
end

function ECConfig.getLabourCost(totalPrice)
    return math.floor(totalPrice * ECConfig.LABOUR_FRACTION)
end

function ECConfig.getMaterialBudget(totalPrice)
    return math.floor(totalPrice * ECConfig.MATERIAL_FRACTION)
end

function ECConfig.getLabourPerPhase(totalPrice, numPhases)
    return math.floor(ECConfig.getLabourCost(totalPrice) / numPhases)
end

function ECConfig.getMaterialPerPhase(totalPrice, numPhases)
    return math.floor(ECConfig.getMaterialBudget(totalPrice) / numPhases)
end

function ECConfig.generateMaterialList(materialBudget)
    local validResources = {}
    local totalWeight = 0

    for _, entry in ipairs(ECConfig.RESOURCE_WEIGHTS) do
        local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(entry.fillType)
        if fillTypeIndex ~= nil then
            local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
            if fillType ~= nil and (fillType.pricePerLiter or 0) > 0 then
                table.insert(validResources, {
                    fillTypeIndex = fillTypeIndex,
                    fillTypeName = entry.fillType,
                    weight = entry.weight,
                    pricePerLiter = fillType.pricePerLiter,
                })
                totalWeight = totalWeight + entry.weight
            end
        end
    end

    if totalWeight == 0 or #validResources == 0 then
        return {}
    end

    local materials = {}
    for _, res in ipairs(validResources) do
        local share = (res.weight / totalWeight) * materialBudget
        local amount = math.max(1, math.floor(share / res.pricePerLiter))
        table.insert(materials, {
            fillTypeIndex = res.fillTypeIndex,
            fillTypeName = res.fillTypeName,
            amount = amount,
            delivered = 0,
        })
    end

    return materials
end

function ECConfig.shouldApplyConstruction(storeItem, placeable)
    if storeItem == nil then
        return false
    end

    local price = storeItem.price or 0
    if price < ECConfig.MIN_PRICE_FOR_CONSTRUCTION then
        return false
    end

    if not ECConfig.OVERRIDE_EXISTING_CONSTRUCTIBLES then
        if placeable ~= nil and placeable.spec_constructible ~= nil then
            return false
        end
    end

    if placeable ~= nil and placeable.spec_fence ~= nil then
        return false
    end

    return true
end
