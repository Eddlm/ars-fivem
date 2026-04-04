-- Resource manifest for the performancetuning client/server module set.
fx_version 'cerulean'
game 'gta5'
-- Startup order hint:
-- ensure ScaleformUI_Assets
-- ensure ScaleformUI_Lua
-- ensure performancetuning

author 'Eddlm'
description 'Live vehicle handling read/write helpers for player vehicles'
version '0.0.1'

dependency 'ScaleformUI_Assets'
dependency 'ScaleformUI_Lua'

shared_script 'shared.lua'

client_scripts {
    '@ScaleformUI_Lua/ScaleformUI.lua',
    'material_tyre_grip.lua',
    'definitions.lua',
    'configruntime.lua',
    'client.lua',
    'handlingmanager.lua',
    'vehiclemanager.lua',
    'tuningpackmanager.lua',
    'surfacegrip.lua',
    'menusliders.lua',
    'performancepanel.lua',
    'runtimebindings.lua',
    'nitrous.lua',
    'syncorchestrator.lua',
    'scaleformui_menus.lua'
}
server_scripts {
    'UpdateNotifier.lua',
    'server.lua'
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
