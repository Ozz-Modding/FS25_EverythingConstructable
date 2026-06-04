ECSettings = {}
ECSettings.CONTROLS = {}

ECSettings.menuItems = {
    'constructionEnabled',
    'labourFraction',
    'materialSupplyBonus',
    'resourceWeight_BOARDS',
    'resourceWeight_PLANKS',
    'resourceWeight_WOODBEAM',
    'resourceWeight_CEMENT',
    'resourceWeight_PREFABWALL',
    'resourceWeight_CEMENTBRICKS',
    'resourceWeight_ROOFPLATES',
}

ECSettings.multiplayerPermissions = {
    'ecSettings'
}

Farm.PERMISSION['EC_SETTINGS'] = "ecSettings"
table.insert(Farm.PERMISSIONS, Farm.PERMISSION.EC_SETTINGS)

ECSettings.SETTINGS = {}

ECSettings.SETTINGS.constructionEnabled = {
    ['default'] = 2,
    ['serverOnly'] = true,
    ['permission'] = 'ecSettings',
    ['values'] = { false, true },
    ['strings'] = {
        g_i18n:getText("ec_setting_disabled"),
        g_i18n:getText("ec_setting_enabled")
    }
}

ECSettings.SETTINGS.materialSupplyBonus = {
    ['default'] = 2,
    ['serverOnly'] = true,
    ['permission'] = 'ecSettings',
    ['values'] = { 0, 0.02, 0.05, 0.10 },
    ['strings'] = { "0%", "2%", "5%", "10%" }
}

ECSettings.SETTINGS.labourFraction = {
    ['default'] = 6,
    ['serverOnly'] = true,
    ['permission'] = 'ecSettings',
    ['values'] = { 0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75 },
    ['strings'] = { "25%", "30%", "35%", "40%", "45%", "50%", "55%", "60%", "65%", "70%", "75%" }
}

local WEIGHT_VALUES = { 0, 1, 2, 3, 4, 5 }
local WEIGHT_STRINGS = { "0", "1", "2", "3", "4", "5" }

ECSettings.SETTINGS.resourceWeight_BOARDS = {
    ['default'] = 6, -- 5
    ['serverOnly'] = true,
    ['permission'] = 'ecSettings',
    ['values'] = WEIGHT_VALUES,
    ['strings'] = WEIGHT_STRINGS,
}

ECSettings.SETTINGS.resourceWeight_PLANKS = {
    ['default'] = 5, -- 4
    ['serverOnly'] = true,
    ['permission'] = 'ecSettings',
    ['values'] = WEIGHT_VALUES,
    ['strings'] = WEIGHT_STRINGS,
}

ECSettings.SETTINGS.resourceWeight_WOODBEAM = {
    ['default'] = 4, -- 3
    ['serverOnly'] = true,
    ['permission'] = 'ecSettings',
    ['values'] = WEIGHT_VALUES,
    ['strings'] = WEIGHT_STRINGS,
}

ECSettings.SETTINGS.resourceWeight_CEMENT = {
    ['default'] = 3, -- 2
    ['serverOnly'] = true,
    ['permission'] = 'ecSettings',
    ['values'] = WEIGHT_VALUES,
    ['strings'] = WEIGHT_STRINGS,
}

ECSettings.SETTINGS.resourceWeight_PREFABWALL = {
    ['default'] = 2, -- 1
    ['serverOnly'] = true,
    ['permission'] = 'ecSettings',
    ['values'] = WEIGHT_VALUES,
    ['strings'] = WEIGHT_STRINGS,
}

ECSettings.SETTINGS.resourceWeight_CEMENTBRICKS = {
    ['default'] = 2, -- 1
    ['serverOnly'] = true,
    ['permission'] = 'ecSettings',
    ['values'] = WEIGHT_VALUES,
    ['strings'] = WEIGHT_STRINGS,
}

ECSettings.SETTINGS.resourceWeight_ROOFPLATES = {
    ['default'] = 2, -- 1
    ['serverOnly'] = true,
    ['permission'] = 'ecSettings',
    ['values'] = WEIGHT_VALUES,
    ['strings'] = WEIGHT_STRINGS,
}

ECSettings.current = {
    constructionEnabled = true,
    labourFraction = 0.50,
    materialSupplyBonus = 0.02,
    resourceWeight_BOARDS = 5,
    resourceWeight_PLANKS = 4,
    resourceWeight_WOODBEAM = 3,
    resourceWeight_CEMENT = 2,
    resourceWeight_PREFABWALL = 1,
    resourceWeight_CEMENTBRICKS = 1,
    resourceWeight_ROOFPLATES = 1,
}

function ECSettings.getValue(id)
    return ECSettings.current[id]
end

function ECSettings.getStateIndex(id, value)
    local value = value or ECSettings.current[id]
    local values = ECSettings.SETTINGS[id].values
    if type(value) == 'number' then
        local index = ECSettings.SETTINGS[id].default
        local initialdiff = math.huge
        for i, v in pairs(values) do
            local currentdiff = math.abs(v - value)
            if currentdiff < initialdiff then
                initialdiff = currentdiff
                index = i
            end
        end
        return index
    else
        for i, v in pairs(values) do
            if value == v then
                return i
            end
        end
    end
    return ECSettings.SETTINGS[id].default
end

ECSettingsControls = {}
function ECSettingsControls.onMenuOptionChanged(self, state, menuOption)
    local id = menuOption.id
    local setting = ECSettings.SETTINGS
    local value = setting[id].values[state]

    if value ~= nil then
        ECSettings.current[id] = value
    end

    g_client:getServerConnection():sendEvent(ECSettingsEvent.new())
end

local function updateFocusIds(element)
    if not element then
        return
    end
    element.focusId = FocusManager:serveAutoFocusId()
    for _, child in pairs(element.elements) do
        updateFocusIds(child)
    end
end

function ECSettings.addSettingsToMenu()
    local inGameMenu = g_gui.screenControllers[InGameMenu]
    local settingsPage = inGameMenu.pageSettings
    ECSettingsControls.name = settingsPage.name

    function ECSettings.addMultiMenuOption(id)
        local callback = "onMenuOptionChanged"
        local i18n_title = "setting_ec_" .. id
        local i18n_tooltip = "setting_ec_" .. id .. "_tooltip"
        local options = ECSettings.SETTINGS[id].strings

        local originalBox = settingsPage.multiVolumeVoiceBox

        local menuOptionBox = originalBox:clone(settingsPage.gameSettingsLayout)
        menuOptionBox.id = id .. "box"

        local menuMultiOption = menuOptionBox.elements[1]
        menuMultiOption.id = id
        menuMultiOption.target = ECSettingsControls

        menuMultiOption:setCallback("onClickCallback", callback)
        menuMultiOption:setDisabled(false)

        local toolTip = menuMultiOption.elements[1]
        toolTip:setText(g_i18n:getText(i18n_tooltip))

        local setting = menuOptionBox.elements[2]
        setting:setText(g_i18n:getText(i18n_title))

        menuMultiOption:setTexts({ table.unpack(options) })
        menuMultiOption:setState(ECSettings.getStateIndex(id))

        ECSettings.CONTROLS[id] = menuMultiOption

        updateFocusIds(menuOptionBox)
        table.insert(settingsPage.controlsList, menuOptionBox)
        return menuOptionBox
    end

    local sectionTitle = nil
    for _, elem in ipairs(settingsPage.gameSettingsLayout.elements) do
        if elem.name == "sectionHeader" then
            sectionTitle = elem:clone(settingsPage.gameSettingsLayout)
            break
        end
    end

    if sectionTitle then
        sectionTitle:setText(g_i18n:getText("setting_ec_section"))
    else
        sectionTitle = TextElement.new()
        sectionTitle:applyProfile("fs25_settingsSectionHeader", true)
        sectionTitle:setText(g_i18n:getText("setting_ec_section"))
        sectionTitle.name = "sectionHeader"
        settingsPage.gameSettingsLayout:addElement(sectionTitle)
    end
    sectionTitle.focusId = FocusManager:serveAutoFocusId()
    table.insert(settingsPage.controlsList, sectionTitle)
    ECSettings.CONTROLS[sectionTitle.name] = sectionTitle

    for _, id in pairs(ECSettings.menuItems) do
        ECSettings.addMultiMenuOption(id)
    end

    settingsPage.gameSettingsLayout:invalidateLayout()

    -- MULTIPLAYER PERMISSIONS
    local multiplayerPage = inGameMenu.pageMultiplayer

    function ECSettings.addMultiplayerPermission(id)
        local newPermissionName = id .. 'PermissionCheckbox'
        local i18n_title = "permission_ec_" .. id

        local original = multiplayerPage.cutTreesPermissionCheckbox.parent
        local newPermissionRow = original:clone(multiplayerPage.permissionsBox)

        local newPermissionCheckbox = newPermissionRow.elements[1]
        newPermissionCheckbox.id = newPermissionName

        local newPermissionLabel = newPermissionRow.elements[2]
        newPermissionLabel:setText(g_i18n:getText(i18n_title))

        table.insert(multiplayerPage.permissionRow, newPermissionRow)

        multiplayerPage.controlIDs[newPermissionName] = true
        multiplayerPage.permissionCheckboxes[id] = newPermissionCheckbox
        multiplayerPage.checkboxPermissions[newPermissionCheckbox] = id
    end

    for _, id in pairs(ECSettings.multiplayerPermissions) do
        ECSettings.addMultiplayerPermission(id)
    end

    -- ENABLE/DISABLE OPTIONS FOR CLIENTS
    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
        local isAdmin = g_currentMission:getIsServer() or g_currentMission.isMasterUser

        for _, id in pairs(ECSettings.menuItems) do
            local menuOption = ECSettings.CONTROLS[id]
            menuOption:setState(ECSettings.getStateIndex(id))

            if ECSettings.SETTINGS[id].serverOnly and g_server == nil then
                menuOption:setDisabled(not isAdmin)
            else
                local permission = ECSettings.SETTINGS[id].permission
                local hasPermission = g_currentMission:getHasPlayerPermission(permission)
                local canChange = isAdmin or hasPermission or false
                menuOption:setDisabled(not canChange)
            end
        end
    end)
end

FocusManager.setGui = Utils.appendedFunction(FocusManager.setGui, function(_, gui)
    if gui == "ingameMenuSettings" then
        for _, control in pairs(ECSettings.CONTROLS) do
            if not control.focusId or not FocusManager.currentFocusData.idToElementMapping[control.focusId] then
                if not FocusManager:loadElementFromCustomValues(control, nil, nil, false, false) then
                    print(
                        "Could not register control %s with the focus manager. Selecting the control might be bugged",
                        control.id or control.name or control.focusId)
                end
            end
        end
        local settingsPage = g_gui.screenControllers[InGameMenu].pageSettings
        settingsPage.gameSettingsLayout:invalidateLayout()
    end
end)
