fx_version 'cerulean'
game 'gta5'
-- Startup order hint:
-- ensure NativeUI26
-- ensure vehiclemanager

name 'vehiclemanager'
author 'eddlm'
description 'Standalone vehicle manager menu built on NativeUI26 with PerformanceTuning integration.'
version '0.1.0'

lua54 'yes'

dependency 'NativeUI26'

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
    'client/vehiclemanager.lua'
}
