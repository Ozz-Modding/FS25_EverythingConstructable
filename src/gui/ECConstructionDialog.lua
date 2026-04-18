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
        local modeKey = project.mode == ECProject.MODE_AUTOMATIC and "ec_mode_automatic" or "ec_mode_waitForResources"
        self.modeText:setText(g_i18n:getText(modeKey))
    end

    if self.totalPaidText ~= nil then
        self.totalPaidText:setText(g_i18n:formatMoney(project.totalPaid, 0, true, true))
    end

    if self.remainingText ~= nil then
        local remaining = project.totalPrice - project.totalPaid
        self.remainingText:setText(g_i18n:formatMoney(remaining, 0, true, true))
    end

    if self.phaseCostText ~= nil then
        local effectiveCost = project:getEffectivePhaseCost()
        self.phaseCostText:setText(g_i18n:formatMoney(effectiveCost, 0, true, true))
    end

    if self.statusText ~= nil then
        local statusKey = project.paused and "ec_status_paused" or "ec_status_active"
        self.statusText:setText(g_i18n:getText(statusKey))
    end

    self:updateResourceList()
end

function ECConstructionDialog:updateResourceList()
    if self.resourceList == nil or self.project == nil then
        return
    end

    self.resourceList:deleteListItems()

    local phase = self.project:getCurrentPhase()
    if phase == nil then
        return
    end

    for _, resource in ipairs(phase.resources) do
        local fillType = g_fillTypeManager:getFillTypeByIndex(resource.fillTypeIndex)
        if fillType ~= nil then
            local item = self.resourceList:addItem()
            if item ~= nil then
                local nameElement = item:getDescendantByName("resourceName")
                local amountElement = item:getDescendantByName("resourceAmount")

                if nameElement ~= nil then
                    nameElement:setText(fillType.title)
                end
                if amountElement ~= nil then
                    amountElement:setText(string.format("%s / %s",
                        g_i18n:formatVolume(resource.delivered),
                        g_i18n:formatVolume(resource.amount)))
                end
            end
        end
    end
end

function ECConstructionDialog:onClickSwitchMode()
    if self.project == nil or self.project.completed then
        return
    end

    local newMode
    if self.project.mode == ECProject.MODE_AUTOMATIC then
        newMode = ECProject.MODE_WAIT_FOR_RESOURCES
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
