-- Declares the full user-facing shared configuration surface for performancetuning.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.Config = PerformanceTuning.Config or {}

local Config = PerformanceTuning.Config

Config.sliderRanges = {
    nitrousShotStrength = { min = 1.0, max = 2.0, step = 0.2 },
    suspensionRaise = { min = -0.300, max = 0.300, step = 0.010 },
}

Config.nitrous = {
    baseDurationMs = 4000,
    nativePowerMultiplier = 0.5,
}

Config.performancePiDistribution = {
    power = 3000, --1G = 125PI
    topSpeed = 20, --100mph = 250PI
    grip = 1, --1G = 125PI
    brake = 1, --1G = 100PI
}

Config.performanceBarFillTargets = {
    power = 1.0,
    topSpeedMph = 250.0,
    grip = 3.5,
    brake = 3.5,
}

-- Unified PI bar tuning surface. Legacy keys are still supported as fallback.
Config.performanceBars = {
    -- absolute_benchmark: fixed global targets (legacy behavior)
    -- vehicle_relative: shows how maxed-out this specific vehicle is
    displayMode = 'vehicle_relative',
    power = {
        target = 0.1,
        transmission = {
            powerBonusPerUpgrade = 0.01,
        },
        nitrous = {
            powerBarFillPerNitroLevel = 5,
        },
    },
    topSpeed = {
        target = 50,
    },
    grip = {
        target = 0.5,
        qualityLadder = {
            low_end = 0.25,
            mid_end = 0.5,
            high_end = 0.75,
            top_end = 1.0,
        },
        -- Literal fTractionCurveMax offsets from the Road-equivalent target.
        compoundRoadOffset = {
            road = 0.0,
            rally = -0.15, -- Mixed
            offroad = -0.30,
        },
    },
    brake = {
        target = 0.25,
    },
}

Config.performanceNearbyPanels = {
    enabled = true,
    maxDistanceMeters = 30.0,
    maxPanels = 6,
}

Config.packDefinitions = {
    suspension = {
        { id = 'stock', label = 'Stock', enabled = true, description = 'Keeps the vehicle on its original suspension setup.' },
        { id = 'sport', label = 'Medium', enabled = true, description = 'Brings softer cars up to a medium suspension force and rebound baseline.', minimums = { fSuspensionForce = 3.0, fSuspensionReboundDamp = 2.5 } },
        { id = 'race', label = 'Hard', enabled = true, description = 'Brings the suspension up to a firmer track-focused force and rebound baseline.', minimums = { fSuspensionForce = 4.0, fSuspensionReboundDamp = 3.5 } },
        { id = 'rally', label = 'Soft', enabled = true, description = 'Uses a softer off-road-biased damping setup for extra compliance.', values = { fSuspensionForce = 2.0, fSuspensionCompDamp = 3.0 } },
    },
    transmission = {
        { id = 'stock', label = 'Stock', enabled = true, description = 'Keeps the original gearing and shift behavior.' },
        { id = 'tuned', label = 'Fluid change', enabled = true, description = 'Slightly improves shift speed without changing gearing.', gearCountOffset = 0, clutchRateOffset = 2.0 },
        { id = 'street', label = 'clutch disc swap', enabled = true, description = 'Noticeably sharpens shifts for street driving.', gearCountOffset = 0, clutchRateOffset = 4.0 },
        { id = 'pro', label = 'pressure plate swap', enabled = true, description = 'Further increases clutch response and shift speed.', gearCountOffset = 0, clutchRateOffset = 6.0 },
        { id = 'race', label = 'gearbox swap', enabled = true, description = 'Adds a gear and delivers aggressive shift response.', gearCountOffset = 1, clutchRateOffset = 8.0 },
        { id = 'race_gearbox', label = 'Race gearbox', enabled = true, description = 'Maximum gearing and the quickest shift response in this set.', gearCountOffset = 2, clutchRateOffset = 10.0 },
    },
    engine = {
        { id = 'stock', label = 'Stock', enabled = true, description = 'Keeps the original engine power and top speed balance.' },
        { id = 'stage_1', label = 'Stage 1', enabled = true, description = 'Small power increase for a mild street upgrade.' },
        { id = 'stage_2', label = 'Stage 2', enabled = true, description = 'Moderate increase in acceleration and top-end potential.' },
        { id = 'stage_3', label = 'Stage 3', enabled = true, description = 'Strong engine tune with a clear step up in output.' },
        { id = 'hsw_special', label = 'HSW Special', enabled = true, description = 'Highest non-swap power step in the standard upgrade path.' },
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
    nitrous = {
        { id = 'stock', label = 'Stock', enabled = true, description = 'No nitrous boost is available.' },
        { id = 'level_1', label = 'Level 1', enabled = true, description = 'Light nitrous shot for a modest acceleration burst.', powerMultiplier = 0.5 },
        { id = 'level_2', label = 'Level 2', enabled = true, description = 'Balanced nitrous setup with a stronger burst.', powerMultiplier = 1.0 },
        { id = 'level_3', label = 'Level 3', enabled = true, description = 'High-output nitrous shot with a clear increase in shove.', powerMultiplier = 1.5 },
        { id = 'level_4', label = 'Level 4', enabled = true, description = 'Maximum nitrous strength in the current pack lineup.', powerMultiplier = 2.0 },
    },
}

Config.engineSwaps = {
    { id = 'KANJOSJ', label = 'Kanjo SJ Swap', enabled = true, description = 'Uses Kanjo SJ engine values and audio for a full swap.', swapModel = 'KANJOSJ' },
    { id = 'TYRUS', label = 'Tyrus Swap', enabled = true, description = 'Uses Tyrus engine values and audio for a full swap.', swapModel = 'TYRUS' },
    { id = 'TAIPAN', label = 'Taipan Swap', enabled = true, description = 'Uses Taipan engine values and audio for a full swap.', swapModel = 'TAIPAN' },
}
