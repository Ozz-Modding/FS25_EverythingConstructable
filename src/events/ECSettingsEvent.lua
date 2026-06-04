ECSettingsEvent = {}
local ECSettingsEvent_mt = Class(ECSettingsEvent, Event)
InitEventClass(ECSettingsEvent, "ECSettingsEvent")

function ECSettingsEvent.emptyNew()
    return Event.new(ECSettingsEvent_mt)
end

local WEIGHT_KEYS = {
    "resourceWeight_BOARDS",
    "resourceWeight_PLANKS",
    "resourceWeight_WOODBEAM",
    "resourceWeight_CEMENT",
    "resourceWeight_PREFABWALL",
    "resourceWeight_CEMENTBRICKS",
    "resourceWeight_ROOFPLATES",
}

function ECSettingsEvent.new()
    local self = ECSettingsEvent.emptyNew()
    self.constructionEnabled = ECSettings.current.constructionEnabled
    self.labourFraction = ECSettings.current.labourFraction
    self.materialSupplyBonus = ECSettings.current.materialSupplyBonus
    self.resourceWeights = {}
    for _, key in ipairs(WEIGHT_KEYS) do
        self.resourceWeights[key] = ECSettings.current[key]
    end
    return self
end

function ECSettingsEvent:readStream(streamId, connection)
    self.constructionEnabled = streamReadBool(streamId)
    self.labourFraction = streamReadFloat32(streamId)
    self.materialSupplyBonus = streamReadFloat32(streamId)
    self.resourceWeights = {}
    for _, key in ipairs(WEIGHT_KEYS) do
        self.resourceWeights[key] = streamReadInt32(streamId)
    end

    ECSettings.current.constructionEnabled = self.constructionEnabled
    ECSettings.current.labourFraction = self.labourFraction
    ECSettings.current.materialSupplyBonus = self.materialSupplyBonus
    for _, key in ipairs(WEIGHT_KEYS) do
        ECSettings.current[key] = self.resourceWeights[key]
    end

    if not connection:getIsServer() then
        g_server:broadcastEvent(ECSettingsEvent.new())
    else
        self:updateMenuState()
    end
end

function ECSettingsEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.constructionEnabled)
    streamWriteFloat32(streamId, self.labourFraction)
    streamWriteFloat32(streamId, self.materialSupplyBonus)
    for _, key in ipairs(WEIGHT_KEYS) do
        streamWriteInt32(streamId, self.resourceWeights[key] or 0)
    end
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
