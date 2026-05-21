ECSiteVehicleEvent = {}
local ECSiteVehicleEvent_mt = Class(ECSiteVehicleEvent, Event)
InitEventClass(ECSiteVehicleEvent, "ECSiteVehicleEvent")

function ECSiteVehicleEvent.emptyNew()
    return Event.new(ECSiteVehicleEvent_mt)
end

function ECSiteVehicleEvent.new(vehicleObjectId)
    local self = ECSiteVehicleEvent.emptyNew()
    self.vehicleObjectId = vehicleObjectId
    return self
end

function ECSiteVehicleEvent:readStream(streamId, connection)
    self.vehicleObjectId = streamReadInt32(streamId)
    self:run(connection)
end

function ECSiteVehicleEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.vehicleObjectId)
end

function ECSiteVehicleEvent:run(connection)
    if not connection:getIsServer() then
        return
    end

    local vehicle = NetworkUtil.getObject(self.vehicleObjectId)
    if vehicle ~= nil then
        if not ECSiteVehicles.applyRestrictions(vehicle) then
            table.insert(ECSiteVehicles.pendingRestrictions, vehicle)
        end
    else
        table.insert(ECSiteVehicles.pendingObjectIds, self.vehicleObjectId)
    end
end
