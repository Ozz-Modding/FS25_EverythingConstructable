ECConstructionDialog = {}
local ECConstructionDialog_mt = Class(ECConstructionDialog, MessageDialog)

function ECConstructionDialog.new()
    local self = MessageDialog.new(nil, ECConstructionDialog_mt, g_messageCenter, g_i18n, g_inputBinding)
    self.project = nil
    return self
end

function ECConstructionDialog.register()
    local dialog = ECConstructionDialog.new()
    g_gui:loadGui(EverythingConstructable.dir .. "src/gui/ECConstructionDialog.xml", "ECConstructionDialog", dialog)
end

function ECConstructionDialog.show(project)
    local dialog = g_gui.guis["ECConstructionDialog"]
    if dialog == nil then
        return
    end
    local ctrl = dialog.target
    ctrl.project = project
    g_gui:showDialog("ECConstructionDialog")
end

function ECConstructionDialog:onCreate()
end

function ECConstructionDialog:onOpen()
    ECConstructionDialog:superClass().onOpen(self)
    self:updateDisplay()
end

function ECConstructionDialog:onClose()
    ECConstructionDialog:superClass().onClose(self)
    self.project = nil
end

function ECConstructionDialog:updateDisplay()
    if self.project == nil then
        return
    end

    local project = self.project

    if self.buildingNameText ~= nil then
        self.buildingNameText:setText(project:getStoreItemName())
    end

    if self.phaseText ~= nil then
        self.phaseText:setText(g_i18n:getText("ec_phase"):format(project.currentPhaseIndex, project:getNumPhases()))
    end

    if self.modeText ~= nil then
        local modeKey = project.mode == ECProject.MODE_AUTOMATIC and "ec_mode_automatic" or "ec_mode_paused"
        self.modeText:setText(g_i18n:getText(modeKey))
    end

    if self.totalPaidText ~= nil then
        self.totalPaidText:setText(g_i18n:formatMoney(project.totalPaid, 0, true, true))
    end

    if self.totalRemainingText ~= nil then
        self.totalRemainingText:setText(g_i18n:formatMoney(project:getTotalRemainingCost(), 0, true, true))
    end

    if self.labourCostText ~= nil then
        self.labourCostText:setText(g_i18n:formatMoney(project.labourPerPhase, 0, true, true))
    end

    if self.materialSavedText ~= nil then
        self.materialSavedText:setText(g_i18n:formatMoney(project.materialSuppliedValue, 0, true, true))
    end

    if self.phaseCostsText ~= nil then
        local parts = {}
        for i = 1, project:getNumPhases() do
            local cost = project:getCostForPhase(i)
            local label = string.format("%d: %s", i, g_i18n:formatMoney(cost, 0, true, true))
            table.insert(parts, label)
        end
        self.phaseCostsText:setText(table.concat(parts, "   "))
    end

    if self.statusText ~= nil then
        local statusKey = project.mode == ECProject.MODE_PAUSED and "ec_status_paused" or "ec_status_active"
        self.statusText:setText(g_i18n:getText(statusKey))
    end

    if self.switchModeButton ~= nil then
        local buttonKey = project.mode == ECProject.MODE_AUTOMATIC and "ec_pauseProject" or "ec_continueProject"
        self.switchModeButton:setText(g_i18n:getText(buttonKey))
    end

    self:updateMaterialList()
end

function ECConstructionDialog:updateMaterialList()
    if self.project == nil then
        return
    end

    local slot = 1
    for _, mat in ipairs(self.project.materials) do
        if slot > 6 then
            break
        end
        if mat.amount > mat.delivered then
            local fillType = g_fillTypeManager:getFillTypeByIndex(mat.fillTypeIndex)
            if fillType ~= nil then
                local nameEl = self["matName" .. slot]
                local amountEl = self["matAmount" .. slot]
                if nameEl ~= nil then
                    nameEl:setText(fillType.title)
                end
                if amountEl ~= nil then
                    amountEl:setText(string.format("%s / %s",
                        g_i18n:formatVolume(mat.delivered),
                        g_i18n:formatVolume(mat.amount)))
                end
                slot = slot + 1
            end
        end
    end

    if slot == 1 then
        local nameEl = self["matName1"]
        if nameEl ~= nil then
            nameEl:setText(g_i18n:getText("ec_allMaterialsSupplied"))
        end
        slot = 2
    end

    for i = slot, 6 do
        local nameEl = self["matName" .. i]
        local amountEl = self["matAmount" .. i]
        if nameEl ~= nil then
            nameEl:setText("")
        end
        if amountEl ~= nil then
            amountEl:setText("")
        end
    end
end

function ECConstructionDialog:onClickSwitchMode()
    if self.project == nil or self.project.completed then
        return
    end

    local newMode
    if self.project.mode == ECProject.MODE_AUTOMATIC then
        newMode = ECProject.MODE_PAUSED
    else
        newMode = ECProject.MODE_AUTOMATIC
    end

    if g_currentMission:getIsServer() then
        g_currentMission.ecProjectManager:setProjectMode(self.project.id, newMode)
        g_server:broadcastEvent(ECSetModeEvent.new(self.project.id, newMode))
    else
        g_client:getServerConnection():sendEvent(ECSetModeEvent.new(self.project.id, newMode))
    end

    self.project.mode = newMode
    self:updateDisplay()
end

function ECConstructionDialog:onClickCancel()
    if self.project == nil or self.project.completed then
        return
    end

    local refundPct = math.floor(ECConfig.CANCELLATION_REFUND_FRACTION * 100)
    local confirmText = g_i18n:getText("ec_cancelConfirm"):format(refundPct)

    YesNoDialog.show(ECConstructionDialog.onCancelConfirmed, self, confirmText,
        g_i18n:getText("ec_cancel"))
end

function ECConstructionDialog:onCancelConfirmed(yes)
    if not yes or self.project == nil then
        return
    end

    if g_currentMission:getIsServer() then
        g_currentMission.ecProjectManager:cancelProject(self.project.id)
    else
        g_client:getServerConnection():sendEvent(ECCancelProjectEvent.new(self.project.id, 0))
    end

    ECConstructionDialog:superClass().close(self)
end

function ECConstructionDialog:onClickClose()
    ECConstructionDialog:superClass().close(self)
end
