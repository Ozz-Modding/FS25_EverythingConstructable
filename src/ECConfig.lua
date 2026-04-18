ECConfig = {}

ECConfig.DURATION_THRESHOLDS = {
    {maxPrice = 10000,   months = 1},
    {maxPrice = 50000,   months = 2},
    {maxPrice = 100000,  months = 3},
    {maxPrice = 250000,  months = 4},
    {maxPrice = 500000,  months = 6},
    {maxPrice = 1000000, months = 9},
    {maxPrice = math.huge, months = 12},
}

ECConfig.DEPOSIT_FRACTION = 0.10

ECConfig.RESOURCE_SCALE_PER_10K = {
    {fillType = "WOODBEAM",   amount = 500},
    {fillType = "PLANKS",     amount = 400},
    {fillType = "CEMENT",     amount = 300},
    {fillType = "PREFABWALL", amount = 200},
}

ECConfig.RESOURCE_DISCOUNT_FACTOR = 0.5

ECConfig.DEFAULT_MODE = "automatic"

ECConfig.FENCE_XML = "data/placeables/brandless/fences/US/fence07/fenceMetal07.xml"

ECConfig.GROUND_TYPE = "asphalt"

ECConfig.MIN_PRICE_FOR_CONSTRUCTION = 5000

ECConfig.OVERRIDE_EXISTING_CONSTRUCTIBLES = false

ECConfig.CANCELLATION_REFUND_FRACTION = 0.50

ECConfig.FENCE_PADDING = 2

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

function ECConfig.getResourcesForPhase(totalPrice, numPhases)
    local pricePerPhase = totalPrice / numPhases
    local scaleFactor = pricePerPhase / 10000
    local resources = {}

    for _, template in ipairs(ECConfig.RESOURCE_SCALE_PER_10K) do
        local fillType = g_fillTypeManager:getFillTypeIndexByName(template.fillType)
        if fillType ~= nil then
            table.insert(resources, {
                fillTypeIndex = fillType,
                fillTypeName = template.fillType,
                amount = math.max(1, math.floor(template.amount * scaleFactor)),
                delivered = 0,
            })
        end
    end

    return resources
end

function ECConfig.getPhaseCost(totalPrice, numPhases, depositAmount)
    local remainingCost = totalPrice - depositAmount
    return math.floor(remainingCost / numPhases)
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
