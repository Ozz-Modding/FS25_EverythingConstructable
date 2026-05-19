ECHusbandryConvertEvent = {}
local ECHusbandryConvertEvent_mt = Class(ECHusbandryConvertEvent, Event)
InitEventClass(ECHusbandryConvertEvent, "ECHusbandryConvertEvent")

function ECHusbandryConvertEvent.emptyNew()
    return Event.new(ECHusbandryConvertEvent_mt)
end

function ECHusbandryConvertEvent.new(placeable, createMeadow)
    local self = ECHusbandryConvertEvent.emptyNew()
    self.placeable = placeable
    self.createMeadow = createMeadow or false
    return self
end

function ECHusbandryConvertEvent:readStream(streamId, connection)
    self.placeable = NetworkUtil.readNodeObject(streamId)
    self.createMeadow = streamReadBool(streamId)
    self:run(connection)
end

function ECHusbandryConvertEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.placeable)
    streamWriteBool(streamId, self.createMeadow)
end

function ECHusbandryConvertEvent:run(connection)
    if self.placeable == nil then
        return
    end
    if connection:getIsServer() then
        return
    end
    HusbandryFenceExtension.onConvertRequested(self.placeable, self.createMeadow)
end
