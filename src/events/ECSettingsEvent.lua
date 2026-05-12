ECSettingsEvent = {}
local ECSettingsEvent_mt = Class(ECSettingsEvent, Event)
InitEventClass(ECSettingsEvent, "ECSettingsEvent")

function ECSettingsEvent.emptyNew()
    return Event.new(ECSettingsEvent_mt)
end

function ECSettingsEvent.new()
    local self = ECSettingsEvent.emptyNew()
    self.constructionEnabled = ECSettings.current.constructionEnabled
    self.labourFraction = ECSettings.current.labourFraction
    self.materialSupplyBonus = ECSettings.current.materialSupplyBonus
    return self
end

function ECSettingsEvent:readStream(streamId, connection)
    self.constructionEnabled = streamReadBool(streamId)
    self.labourFraction = streamReadFloat32(streamId)
    self.materialSupplyBonus = streamReadFloat32(streamId)

    if not connection:getIsServer() then
        ECSettings.current.constructionEnabled = self.constructionEnabled
        ECSettings.current.labourFraction = self.labourFraction
        ECSettings.current.materialSupplyBonus = self.materialSupplyBonus
        g_server:broadcastEvent(ECSettingsEvent.new())
    else
        ECSettings.current.constructionEnabled = self.constructionEnabled
        ECSettings.current.labourFraction = self.labourFraction
        ECSettings.current.materialSupplyBonus = self.materialSupplyBonus
        self:updateMenuState()
    end
end

function ECSettingsEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.constructionEnabled)
    streamWriteFloat32(streamId, self.labourFraction)
    streamWriteFloat32(streamId, self.materialSupplyBonus)
end

function ECSettingsEvent:updateMenuState()
    for _, id in pairs(ECSettings.menuItems) do
        local menuOption = ECSettings.CONTROLS[id]
        if menuOption ~= nil then
            local currentState = ECSettings.getStateIndex(id)
            if menuOption:getState() ~= currentState then
                menuOption:setState(currentState)
            end
        end
    end
end
