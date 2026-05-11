ECSettingsEvent = {}
local ECSettingsEvent_mt = Class(ECSettingsEvent, Event)
InitEventClass(ECSettingsEvent, "ECSettingsEvent")

function ECSettingsEvent.emptyNew()
    return Event.new(ECSettingsEvent_mt)
end

function ECSettingsEvent.new()
    local self = ECSettingsEvent.emptyNew()
    self.constructionEnabled = ECSettings.current.constructionEnabled
    return self
end

function ECSettingsEvent:readStream(streamId, connection)
    self.constructionEnabled = streamReadBool(streamId)

    if not connection:getIsServer() then
        ECSettings.current.constructionEnabled = self.constructionEnabled
        g_server:broadcastEvent(ECSettingsEvent.new())
    else
        ECSettings.current.constructionEnabled = self.constructionEnabled
        self:updateMenuState()
    end
end

function ECSettingsEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.constructionEnabled)
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
