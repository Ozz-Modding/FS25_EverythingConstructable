ECConfig = {}

ECConfig.DURATION_THRESHOLDS = {
    { maxPrice = 10000, months = 1 },
    { maxPrice = 50000, months = 2 },
    { maxPrice = 100000, months = 3 },
    { maxPrice = 250000, months = 4 },
    { maxPrice = 500000, months = 6 },
    { maxPrice = 1000000, months = 7 },
    { maxPrice = math.huge, months = 8 },
}

ECConfig.DEPOSIT_FRACTION = 0.10

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

ECConfig.FENCE_XML = "assets/fence/ec_fence.xml"
ECConfig.FENCE_SEGMENT_ID = "panel04"
ECConfig.FENCE_INNER_SEGMENT_ID = "panel07"

ECConfig.GROUND_TYPE = "asphalt"

ECConfig.MIN_PRICE_FOR_CONSTRUCTION = 5000

ECConfig.OVERRIDE_EXISTING_CONSTRUCTIBLES = false

ECConfig.CANCELLATION_REFUND_FRACTION = 0.20
ECConfig.CANCELLATION_MATERIAL_REFUND_FRACTION = 0.35

ECConfig.FENCE_OUTER_REVERSE_WINDING = false
ECConfig.FENCE_INNER_REVERSE_WINDING = true

ECConfig.FENCE_PADDING = 2
ECConfig.FENCE_INNER_OFFSET = 2
ECConfig.FENCE_PASTURE_SEGMENT_ID = "panel12"

ECConfig.ACTIVATABLE_BUFFER = 3

ECConfig.FENCE_SIGN_I3D = "assets/sitesafety/i3ds/WarningSign1024.i3d"
ECConfig.FENCE_SIGN_HEIGHT = 1.25
ECConfig.FENCE_SIGN_PANEL_INTERVAL = 3

ECConfig.SITE_DECORATION_CELL_SIZE = 1
ECConfig.SITE_DECORATION_SIZE_BUFFER = 0.5
ECConfig.SITE_DECORATION_CLUSTER_CHANCE = 0.6
ECConfig.SITE_DECORATION_CLUSTER_RADIUS = 3
ECConfig.SITE_DECORATION_ATTEMPT_MULTIPLIER = 5
ECConfig.SITE_DECORATIONS = {
    { i3d = "data/maps/mapEU/textures/props/boots.i3d", max = 1 },
    { i3d = "data/maps/mapEU/textures/props/cementMixer01.i3d", max = 1 },
    { i3d = "data/maps/mapEU/textures/props/lockedContainer01.i3d", max = 1 },
    { i3d = "data/maps/mapEU/textures/props/sawhorse.i3d", max = 1, width = 3, depth = 2 },
    { i3d = "data/maps/mapEU/textures/props/stepStool.i3d", max = 1 },
    { i3d = "data/maps/mapEU/textures/props/wheelBarrow.i3d", max = 1 },
    { i3d = "data/maps/mapEU/textures/props/workBench01.i3d", max = 1 },
    { i3d = "data/placeables/brandless/decoration/boardStacks/boardStackSmall.i3d", max = 4, width = 5, depth = 2 },
    { i3d = "data/placeables/brandless/decoration/palletTruck/palletTruck.i3d", max = 1, width = 4, depth = 2 },
    { i3d = "data/placeables/brandless/decoration/garbageContainers/barrel01.i3d", max = 2 },
    { i3d = "data/placeables/brandless/decoration/garbageContainers/barrel02.i3d", max = 2 },
    { i3d = "data/placeables/brandless/decoration/garbageContainers/barrel03.i3d", max = 2 },
    { i3d = "data/placeables/brandless/decoration/garbageContainers/barrel04.i3d", max = 2 },
    { i3d = "data/placeables/brandless/decoration/garbageContainers/trashcan01.i3d", max = 2 },
    { i3d = "data/placeables/brandless/decoration/benches/bench02.i3d", max = 2 },
    { i3d = "data/placeables/brandless/decoration/garbageContainers/garbageContainers.i3d", max = 1 },
    { i3d = "data/placeables/mapAS/farmShacksAS/shackContainer01.i3d", max = 1, width = 9, depth = 6, priority = 1 },
    { i3d = "assets/fence/sign01.i3d", modLocal = true, max = 1 },
    { i3d = "assets/fence/sign02.i3d", modLocal = true, max = 1, width = 4, depth = 3 },
}

ECConfig.EASTER_EGG_SOUND_DIR = "assets/sounds/easter_eggs/"
ECConfig.EASTER_EGG_CHANCE = 0.50
ECConfig.EASTER_EGG_COOLDOWN = 5000

ECConfig.SITE_SOUND_FILE = "assets/sounds/background.ogg"
ECConfig.SITE_SOUND_INNER_RADIUS_PADDING = 4
ECConfig.SITE_SOUND_OUTER_RADIUS_PADDING = 20
ECConfig.SITE_SOUND_VOLUME = 0.2

ECConfig.SITE_VEHICLES = {
    { xmlFilename = "data/vehicles/jungheinrich/efgS50S/efgS50S.xml" },
    { xmlFilename = "data/vehicles/jcb/series547/series547.xml" }
}

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
    local labourFraction = ECSettings.getValue('labourFraction')
    return math.floor(totalPrice * labourFraction) - ECConfig.getDepositAmount(totalPrice)
end

function ECConfig.getMaterialBudget(totalPrice)
    local labourFraction = ECSettings.getValue('labourFraction')
    return totalPrice - math.floor(totalPrice * labourFraction)
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
            pricePerLiter = res.pricePerLiter,
        })
    end

    local supplyBonus = ECSettings.getValue('materialSupplyBonus')
    if supplyBonus > 0 then
        local discountRemaining = materialBudget * supplyBonus

        table.sort(materials, function(a, b) return a.pricePerLiter > b.pricePerLiter end)

        for _, mat in ipairs(materials) do
            if discountRemaining <= 0 then
                break
            end
            local unitsToRemove = math.min(mat.amount - 1, math.floor(discountRemaining / mat.pricePerLiter))
            mat.amount = mat.amount - unitsToRemove
            discountRemaining = discountRemaining - (unitsToRemove * mat.pricePerLiter)
        end
    end

    for _, mat in ipairs(materials) do
        mat.pricePerLiter = nil
    end

    return materials
end

function ECConfig.shouldApplyConstruction(storeItem, placeable)
    if storeItem == nil then
        return false
    end

    local price = storeItem.price or 0
    if price <= ECConfig.MIN_PRICE_FOR_CONSTRUCTION then
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
