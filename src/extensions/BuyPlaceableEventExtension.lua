BuyPlaceableEventExtension = {}

BuyPlaceableEvent.run = Utils.overwrittenFunction(BuyPlaceableEvent.run, function(self, superFunc, connection)
    if connection:getIsServer() then
        superFunc(self, connection)
        return
    end

    if self.buyData == nil or not self.buyData:isValid() then
        superFunc(self, connection)
        return
    end

    if not ECSettings.current.constructionEnabled then
        superFunc(self, connection)
        return
    end

    if not ECConfig.shouldApplyConstruction(self.buyData.storeItem, nil) then
        superFunc(self, connection)
        return
    end

    local depositAmount = ECConfig.getDepositAmount(self.buyData.price)
    local displacementCosts = self.buyData.displacementCosts or 0
    local requiredMoney = depositAmount + displacementCosts

    local farm = g_farmManager:getFarmById(self.buyData.ownerFarmId)
    if farm == nil then
        superFunc(self, connection)
        return
    end

    if not self.buyData.isFreeOfCharge and farm.money < requiredMoney then
        superFunc(self, connection)
        return
    end

    self.buyData:buy(self.onPlaceableBoughtCallback, self, {connection})
end)
