-- Resource manifest for the performancetuning client/server module set.
fx_version 'cerulean'
game 'gta5'
-- Startup order hint:
-- ensure ScaleformUI_Assets
-- ensure ScaleformUI_Lua
-- ensure performancetuning

author 'Eddlm'
description 'Live vehicle handling read/write helpers for player vehicles'
version '0.0.2'

dependency 'ScaleformUI_Assets'
dependency 'ScaleformUI_Lua'

shared_script 'shared/Config.lua'

client_scripts {
    '@ScaleformUI_Lua/ScaleformUI.lua',
    'client/material_tyre_grip.lua',
    'client/definitions.lua',
    'client/configruntime.lua',
    'client/client.lua',
    'client/handlingmanager.lua',
    'client/vehiclemanager.lua',
    'client/tuningpackmanager.lua',
    'client/surfacegrip.lua',
    'client/menusliders.lua',
    'client/performancepanel.lua',
    'client/runtimebindings.lua',
    'client/nitrous.lua',
    'client/syncorchestrator.lua',
    'client/scaleformui_menus.lua'
}
server_scripts {
    'server/UpdateNotifier.lua',
    'server/server.lua'
}

exports {
    'GetCurrentVehicle',
    'GetMaterialTyreGrip',
    'GetHandlingField',
    'SetHandlingField',
    'ResetHandlingField',
    'ResetAllHandling',
    'InferHandlingFieldType',
    'GetPerformancePanelMetrics',
    'DrawPerformanceIndexPanel',
    'DrawPerformanceIndexPanelInstance',
    'SetKeepPersonalPiPanelActive',
    'SetPanelDrawRequest',
    'ClearPanelDrawRequest',
    'OpenPerformanceTuningMenu',
    'GetPiDisplayModeIndex',
    'SetPiDisplayModeIndex',
    'GetPerformanceBarsDisplayMode',
    'SetPerformanceBarsDisplayMode',
    'GetCurrentVehicleRevLimiterEnabled',
    'SetCurrentVehicleRevLimiterEnabled',
    'GetCurrentVehicleSteeringLockMode',
    'SetCurrentVehicleSteeringLockMode'
}
