BuyPlaceableEventExtension = {}

BuyPlaceableEvent.run = Utils.overwrittenFunction(BuyPlaceableEvent.run, function(self, superFunc, connection)
    if connection:getIsServer() then
        superFunc(self, connection)
        return
    end

    local buyData = self.placeableBuyData
    if buyData == nil or not buyData:isValid() then
        superFunc(self, connection)
        return
    end

    if not ECSettings.current.constructionEnabled then
        superFunc(self, connection)
        return
    end

    if not ECConfig.shouldApplyConstruction(buyData.storeItem, nil) then
        superFunc(self, connection)
        return
    end

    local depositAmount = ECConfig.getDepositAmount(buyData.price)
    local displacementCosts = buyData.displacementCosts or 0
    local requiredMoney = depositAmount + displacementCosts

    local farm = g_farmManager:getFarmById(buyData.ownerFarmId)
    if farm == nil then
        superFunc(self, connection)
        return
    end

    if not buyData.isFreeOfCharge and farm.money < requiredMoney then
        connection:sendEvent(BuyPlaceableEvent.newServerToClient(BuyPlaceableEvent.STATE_NOT_ENOUGH_MONEY, buyData))
        return
    end

    buyData:buy(self.onPlaceableBoughtCallback, self, {["connection"] = connection})
end)
