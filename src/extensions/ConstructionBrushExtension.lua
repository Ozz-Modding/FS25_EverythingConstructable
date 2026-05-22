ConstructionBrushExtension = {}

ConstructionBrushPlaceable.updatePlaceablePosition = Utils.overwrittenFunction(
    ConstructionBrushPlaceable.updatePlaceablePosition,
    function(self, superFunc)
        if not ECSettings.current.constructionEnabled then
            superFunc(self)
            return
        end

        if self.placeable == nil or self.storeItem == nil then
            superFunc(self)
            return
        end

        if not ECConfig.shouldApplyConstruction(self.storeItem, self.placeable) then
            superFunc(self)
            return
        end

        local originalSetMessage = self.cursor.setMessage
        self.cursor.setMessage = function(cursor, _message)
            local price = self:getPrice()
            local months = ECConfig.getMonthsForPrice(price)
            local deposit = ECConfig.getDepositAmount(price)
            local symbol = g_i18n:getCurrencySymbol(true)
            local amount = g_i18n:formatNumber(deposit, 0)
            local initial = g_i18n:getText("ec_brush_initial")
            local duration = g_i18n:getText("ec_brush_duration")
            local monthsText = string.format(g_i18n:getText("ec_brush_months"), months)
            local text = symbol .. amount .. " " .. initial .. " | " .. duration .. " " .. monthsText
            originalSetMessage(cursor, text)
        end

        superFunc(self)

        self.cursor.setMessage = originalSetMessage
    end
)
