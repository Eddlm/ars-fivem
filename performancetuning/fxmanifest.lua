-- Resource manifest for the performancetuning client/server module set.
fx_version 'cerulean'
game 'gta5'
-- Startup order hint:
-- ensure NativeUI26
-- ensure performancetuning

author 'Eddlm'
description 'Live vehicle handling read/write helpers for player vehicles'
version '0.1.0'

dependency 'NativeUI26'

shared_script 'shared.lua'

client_scripts {
    '@NativeUI26/share/Utils.lua',
    '@NativeUI26/elements/UIResRectangle.lua',
    '@NativeUI26/elements/UIResText.lua',
    '@NativeUI26/elements/Sprite.lua',
    '@NativeUI26/elements/StringMeasurer.lua',
    '@NativeUI26/elements/Badge.lua',
    '@NativeUI26/elements/Colours.lua',
    '@NativeUI26/elements/ColoursPanel.lua',
    '@NativeUI26/items/UIMenuItem.lua',
    '@NativeUI26/items/UIMenuCheckboxItem.lua',
    '@NativeUI26/items/UIMenuListItem.lua',
    '@NativeUI26/items/UIMenuSliderItem.lua',
    '@NativeUI26/items/UIMenuSliderHeritageItem.lua',
    '@NativeUI26/items/UIMenuColouredItem.lua',
    '@NativeUI26/items/UIMenuProgressItem.lua',
    '@NativeUI26/windows/UIMenuHeritageWindow.lua',
    '@NativeUI26/panels/UIMenuGridPanel.lua',
    '@NativeUI26/panels/UIMenuColourPanel.lua',
    '@NativeUI26/panels/UIMenuPercentagePanel.lua',
    '@NativeUI26/base/UIMenu.lua',
    '@NativeUI26/base/MenuPool.lua',
    '@NativeUI26/NativeUI.lua',
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
    'nativeui_menus.lua'
}
server_script 'server.lua'

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
    'OpenPerformanceTuningMenu'
}
