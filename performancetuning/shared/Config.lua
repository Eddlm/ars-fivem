PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.Config = PerformanceTuning.Config or {}
local Config = PerformanceTuning.Config

Config.sliderRanges = {
    nitrousShotStrength = { min = 1.0, max = 2.0, step = 0.2 },
    suspensionRaise = { min = -0.300, max = 0.300, step = 0.010 },
}

-- convar candidate: pt_nitrous_base_duration_ms — event admins may want to tune burst length for balance without a file redeploy
Config.nitrous = {
    baseDurationMs = 4000,
    nativePowerMultiplier = 0.5,
}

-- This piece of madness is used to scale raw stats like 
-- grip or speed into reasonable PI numbers for each of the PI categories.
Config.performancePiDistribution = {
    power = 3000, -- 0.3G * 3000 = 900 PI
    topSpeed = 12.5, -- 100mph * 12.5 = 1250 PI
    grip = 600, -- 2G * 600 = 1200 PI
    brake = 400, -- 0.5G * 400 = 200 PI
}

-- Bars consider these stats as the maximum and they are filled at these points.
-- Adjust for your overall car stats on your server, so they make sense.
-- convar candidates: pt_bar_target_top_speed_mph, pt_bar_target_grip_g
-- Different servers run different car sets; adjusting these makes the bars visually meaningful for the actual fleet
Config.performanceBarFillTargets = {
    power = 1.0, --Gs
    topSpeedMph = 250.0, --MPH
    grip = 3.5, --Gs
    brake = 3.5, --Gs
}

-- Models how the upgrades work and apply.
-- Target means offset above baseline for the stat. Power can be upgraded up to 0.1G above stock, for example.
Config.performanceModel = {
    power = {
        target = 0.1,
        transmission = {
            powerBonusPerUpgrade = 0.01,
        },
        nitrous = {
            powerBarFillPerNitroLevel = 2,
        },
    },
    topSpeed = {
        target = 50, --Soon to be deprecated. TopSpeed now adjusts to accomodate the upgraded power.
    },
    grip = {
        target = 0.5, -- Upgrades target this, multiplier by the quality. Then the offset below applies.
        qualityLadder = {
            low_end = 0.25,
            mid_end = 0.5,
            high_end = 0.75,
            top_end = 1.0, 
        },
        compoundRoadOffset = {
            road = 0.0,
            rally = -0.15, -- Non road tires intend to have less base grip but retain more grip off the road.
            offroad = -0.30,
        },
    },
    brake = {
        target = 0.25,
    },
    handbrake = {
        target = 1.0,
    },
}

-- convar candidates: pt_nearby_panels_enabled, pt_nearby_panels_distance, pt_nearby_panels_max
-- Panels are a significant per-frame draw cost; admins on busy servers may want to disable or limit them at runtime
Config.performanceNearbyPanels = {
    enabled = true,
    maxDistanceMeters = 30.0,
    maxPanels = 6,
}



Config.packDefinitions = {
    suspension = {
        { id = 'stock', label = 'Stock', enabled = true, description = 'Keeps the vehicle on its original suspension setup.' },
        { id = 'sport', label = 'Medium', enabled = true, description = 'All-rounder, decent stiffness without grip spikes or heavy bodyroll.', values = { fSuspensionForce = 3.0, fSuspensionReboundDamp = 2.0 } },
        { id = 'race', label = 'Hard', enabled = true, description = 'Les weight transfer, higher grip on compression, but very on-off behavior.', values = { fSuspensionForce = 4.0, fSuspensionReboundDamp = 2.0 } },
        { id = 'rally', label = 'Soft', enabled = true, description = 'Softer overall experience, more lean, slower. No grip spikes.', values = { fSuspensionForce = 2.0, fSuspensionCompDamp = 3.0 } },
    },
        transmission = {
            { id = 'stock', label = 'Stock', enabled = true, description = 'Keeps the original gearing and shift behavior.' },
            { id = 'tuned', label = 'Fluid Change', enabled = true, description = 'A lttle maintenance improves shit times and power delivery to something decent.', gearCountOffset = 0, clutchRateOffset = 2.0 },
            { id = 'street', label = 'Clutch Disc Swap', enabled = true, description = 'Noticeably sharpens shifts, less hang time means more time on power.', gearCountOffset = 0, clutchRateOffset = 4.0 },
            { id = 'pro', label = 'Pressure Plate Swap', enabled = true, description = 'Further increases clutch response and shift speed.', gearCountOffset = 0, clutchRateOffset = 6.0 },
            { id = 'race', label = 'Gearbox Swap', enabled = true, description = 'Now this is podracing.', gearCountOffset = 1, clutchRateOffset = 8.0 },
            { id = 'race_gearbox', label = 'Race Gearbox', enabled = true, description = 'Maximum gearing and the quickest shift response in this set.', gearCountOffset = 3, clutchRateOffset = 10.0 },
        },
    engine = {
        { id = 'stock', label = 'Stock', enabled = true, description = 'No changes.' },
        { id = 'stage_1', label = 'Stage 1', enabled = true, description = 'A few tweaks here and there end in a small, but noticeable power and top speed rise.' },
        { id = 'stage_2', label = 'Stage 2', enabled = true, description = 'Proper upgrades to the power and top end.' },
        { id = 'stage_3', label = 'Stage 3', enabled = true, description = 'Strongest you can go without going to Hao\'s.' },
        { id = 'hsw_special', label = 'HSW Special', enabled = true, description = 'Absolute best this engine can do with upgrades.' },
    },
    tires = {
        { id = 'stock', label = 'Stock', enabled = true, description = 'Keeps the original compound and grip envelope.' },
        { id = 'street', label = 'Street', enabled = true, description = 'Mild grip upgrade with balanced street manners.', gripBarProgressRatio = 0.80, compoundLossMultiplier = 0.8, tractionLossMultiplier = 1.30 },
        { id = 'sport', label = 'Sport', enabled = true, description = 'Sharper on-road grip with a more performance-oriented compound.', gripBarProgressRatio = 0.85, compoundLossMultiplier = 0.8, tractionLossMultiplier = 1.60 },
        { id = 'rally', label = 'Offroad', enabled = true, description = 'Better loose-surface traction and lower low-speed traction loss.', gripBarProgressRatio = 0.90, compoundLossMultiplier = 0.8, tractionLossMultiplier = 0.5, lowSpeedLossMultiplier = 0.5 },
        { id = 'race', label = 'Race Hard', enabled = true, description = 'High grip for fast dry running with firmer breakaway behavior.', gripBarProgressRatio = 0.95, compoundLossMultiplier = 0.8, tractionLossMultiplier = 1.90 },
        { id = 'race_soft', label = 'Race Soft', enabled = true, description = 'Maximum grip target in the tire set for the strongest road hold.', gripBarProgressRatio = 1.0, compoundLossMultiplier = 0.8, tractionLossMultiplier = 2.20 },
    },
    brakes = {
        { id = 'stock', label = 'Stock', enabled = true, description = 'Keep this one close to Grip levels.' },
        { id = 'level_1', label = 'Level 1', enabled = true, description = 'Keep this one close to Grip levels.' },
        { id = 'level_2', label = 'Level 2', enabled = true, description = 'Keep this one close to Grip levels.' },
        { id = 'level_3', label = 'Level 3', enabled = true, description = 'Keep this one close to Grip levels.' },
        { id = 'level_4', label = 'Level 4', enabled = true, description = 'Keep this one close to Grip levels.' },
    },
    handbrakes = {
        { id = 'stock', label = 'Stock', enabled = true, description = 'Keep this one close to Grip levels.' },
        { id = 'level_1', label = 'Level 1', enabled = true, description = 'Keep this one close to Grip levels.' },
        { id = 'level_2', label = 'Level 2', enabled = true, description = 'Keep this one close to Grip levels.' },
        { id = 'level_3', label = 'Level 3', enabled = true, description = 'Keep this one close to Grip levels.' },
        { id = 'level_4', label = 'Level 4', enabled = true, description = 'Keep this one close to Grip levels.' },
    },
    nitrous = {
        { id = 'stock', label = 'Stock', enabled = true, description = 'No nitrous boost is available.' },
        { id = 'level_1', label = 'Level 1', enabled = true, description = 'Light nitrous shot for a modest acceleration burst.', powerMultiplier = 0.5 },
        { id = 'level_2', label = 'Level 2', enabled = true, description = 'Balanced nitrous setup with a stronger burst.', powerMultiplier = 1.0 },
        { id = 'level_3', label = 'Level 3', enabled = true, description = 'High-output nitrous shot with a clear increase in shove.', powerMultiplier = 1.5 },
        { id = 'level_4', label = 'Level 4', enabled = true, description = 'Maximum nitrous strength in the current pack lineup.', powerMultiplier = 2.0 },
    },
}
 
Config.advanced = {
    panel = {
        sharedPanelHeightUnits = 0.15,
        sharedPanelBaseScale = 0.95,
        sharedPanelMinScale = 0.72,
        sharedPanelAlpha = 168,
        sharedPanelFillAlpha = 204,
        sharedPanelHeaderHeightRatio = 0.15,
        sharedPanelTextBaseHeightUnits = 0.20,
        sharedPanelWidthUnits = 0.1875,
        defaultPanelHeightUnits = 0.0874,
        primaryPanelLeftMargin = 0.014,
        menuPanelGapX = 0.018,
        stackedPanelGapY = 0.0032,
        defaultMenuLeftPx = 20.0,
        defaultMenuWidthPx = 431.0,
        panelDrawRequestStaleMs = 1000,
        mainPanelYOffset = -0.01,
    },
    tuning = {
        transmissionPowerBonusPerUpgrade = 0.01,
    },
}

