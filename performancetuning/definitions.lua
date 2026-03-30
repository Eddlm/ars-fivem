-- Defines shared static constants, field metadata, and tuning pack data.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.Definitions = PerformanceTuning.Definitions or {}

PerformanceTuning.Definitions.handlingClass = 'CHandlingData'

PerformanceTuning.Definitions.stateBagKeys = {
    tune = 'performancetuning:tuneState',
    handling = 'performancetuning:handlingState',
    pi = 'performancetuning:pi',
}

PerformanceTuning.Definitions.handlingFields = {
    engine = {
        power = 'fInitialDriveForce',
        topSpeed = 'fInitialDriveMaxFlatVel',
        drag = 'fInitialDragCoeff',
    },
    transmission = {
        gear = 'nInitialDriveGears',
        clutchUpshift = 'fClutchChangeRateScaleUpShift',
        clutchDownshift = 'fClutchChangeRateScaleDownShift',
    },
    suspension = {
        biasFront = 'fSuspensionBiasFront',
        raise = 'fSuspensionRaise',
        upperLimit = 'fSuspensionUpperLimit',
        lowerLimit = 'fSuspensionLowerLimit',
        list = {
            'fSuspensionForce',
            'fSuspensionCompDamp',
            'fSuspensionReboundDamp',
            'fSuspensionBiasFront',
            'fSuspensionRaise',
            'fSuspensionUpperLimit',
            'fSuspensionLowerLimit',
        },
    },
    brakes = {
        force = 'fBrakeForce',
        biasFront = 'fBrakeBiasFront',
    },
    antiroll = {
        force = 'fAntiRollBarForce',
        biasFront = 'fAntiRollBarBiasFront',
    },
    tires = {
        max = 'fTractionCurveMax',
        min = 'fTractionCurveMin',
        tractionLoss = 'fTractionLossMult',
        lowSpeedLoss = 'fLowSpeedTractionLossMult',
        lateral = 'fTractionCurveLateral',
        biasFront = 'fTractionBiasFront',
    },
    steering = {
        lock = 'fSteeringLock',
    },
}

PerformanceTuning.Definitions.engineSwapModelName = 'CHAMPION'
PerformanceTuning.Definitions.engineFields = {
    PerformanceTuning.Definitions.handlingFields.engine.power,
    PerformanceTuning.Definitions.handlingFields.engine.topSpeed,
}
PerformanceTuning.Definitions.transmissionFields = {
    PerformanceTuning.Definitions.handlingFields.transmission.gear,
    PerformanceTuning.Definitions.handlingFields.transmission.clutchUpshift,
    PerformanceTuning.Definitions.handlingFields.transmission.clutchDownshift,
}
PerformanceTuning.Definitions.suspensionFields = PerformanceTuning.Definitions.handlingFields.suspension.list
PerformanceTuning.Definitions.brakeFields = {
    PerformanceTuning.Definitions.handlingFields.brakes.force,
    PerformanceTuning.Definitions.handlingFields.brakes.biasFront,
}
PerformanceTuning.Definitions.antirollFields = {
    PerformanceTuning.Definitions.handlingFields.antiroll.force,
    PerformanceTuning.Definitions.handlingFields.antiroll.biasFront,
}
PerformanceTuning.Definitions.tireFields = {
    PerformanceTuning.Definitions.handlingFields.tires.max,
    PerformanceTuning.Definitions.handlingFields.tires.min,
    PerformanceTuning.Definitions.handlingFields.tires.tractionLoss,
    PerformanceTuning.Definitions.handlingFields.tires.lowSpeedLoss,
    PerformanceTuning.Definitions.handlingFields.tires.lateral,
    PerformanceTuning.Definitions.handlingFields.tires.biasFront,
}

PerformanceTuning.Definitions.runtimeConfig = {
    suspensionRaise = {
        maximumLowerLimit = -0.05,
    },
    sliderRanges = {},
    nitrous = {},
    performancePiMultipliers = {
        power = 20,
        topSpeed = 40,
        grip = 20,
        brake = 20,
    },
    performanceNearbyPanels = {
        enabled = true,
        maxDistanceMeters = 30.0,
        maxPanels = 12,
    },
    performancePiClasses = {
        { label = 'S2', minimum = 901 },
        { label = 'S1', minimum = 801 },
        { label = 'A', minimum = 701 },
        { label = 'B', minimum = 601 },
        { label = 'C', minimum = 501 },
        { label = 'D', minimum = 401 },
        { label = 'E', minimum = 0 },
    },
    brakeScaling = {
        barTopValue = 2.5,
        upgradeMultiplierMin = 0.5,
        upgradeMultiplierMax = 2.0,
    },
    nitrousRefill = {
        ptfxAsset = 'veh_xs_vehicle_mods',
        refillIntervalMs = 500,
        refillMaxSpeed = 0.5,
        refillSeconds = 2.0,
    },
}

PerformanceTuning.Definitions.performance = {
    barSegments = 20,
    powerFactor = 33.3333333333,
    topSpeedFactor = 0.0909090909,
    gripFactor = 8.0,
    flatVelToMph = 145.0 / 176.0,
}

PerformanceTuning.Definitions.uiText = {
    menuDescriptions = {
        engine = 'Affects raw acceleration and top speed.',
        transmission = 'Affects shift speed, gear spread, and power delivery between gears.',
        suspension = 'Affects body control, weight transfer, and cornering stability.',
        tires = 'Affects grip level and how traction falls away at the limit.',
        tireCompoundCategory = 'Selects the tire compound family (Road, Rally, Offroad).',
        tireCompoundQuality = 'Selects the tire quality tier (Low-End, Mid-End, High-End).',
        brakes = 'Affects stopping force and braking confidence into corners.',
        nitrous = 'Adds temporary power on demand for stronger acceleration.',
        revLimiter = 'Cuts throttle near redline below top gear when enabled.',
        antirollBars = 'Adjusts roll stiffness to control body lean and responsiveness.',
        nitrousShotStrength = 'Trades nitrous duration for a stronger burst of acceleration.',
        brakeBiasFront = 'Moves braking balance toward the front or rear axle.',
        gripBiasFront = 'Moves front-to-rear traction balance using the handling grip bias field.',
        antirollBiasFront = 'Shifts roll stiffness balance toward the front or rear.',
        suspensionRaise = 'Shows clearance as upper limit minus suspension raise.',
        suspensionBiasFront = 'Moves suspension balance toward the front or rear of the car.',
        steeringLockMode = 'Scales steering lock from traction lateral. Stock keeps original steering lock.',
        piDisplayMode = 'Selects how PI panel targets should be displayed.',
    },
    listOptionDescriptions = {
        revLimiter = {
            [1] = 'Leaves throttle response untouched near redline.',
            [2] = 'Cuts throttle near redline below top gear to help traction and stability.',
        },
        steeringLockMode = {
            [1] = 'Keeps stock steering lock behavior.',
            [2] = 'Balanced steering lock scaling (2.0x traction lateral).',
            [3] = 'Aggro steering lock scaling (2.5x traction lateral).',
            [4] = 'Very aggro steering lock scaling (3.0x traction lateral).',
            [5] = 'Very smooth steering lock scaling (1.0x traction lateral).',
            [6] = 'Smooth steering lock scaling (1.5x traction lateral).',
        },
        piDisplayMode = {
            [1] = 'Display PI for your current car.',
            [2] = 'Display PI targets for nearby tuned cars with PT state.',
            [3] = 'Display PI targets for any nearby cars.',
        },
    },
}

PerformanceTuning.Definitions.packDefinitions = {
    suspension = {
        { id = 'stock', label = 'Stock', enabled = true, description = 'Keeps the vehicle on its original suspension setup.' },
        {
            id = 'sport',
            label = 'Medium',
            enabled = true,
            description = 'Brings softer cars up to a medium suspension force and rebound baseline.',
            minimums = {
                fSuspensionForce = 3.0,
                fSuspensionReboundDamp = 2.5,
            },
        },
        {
            id = 'race',
            label = 'Hard',
            enabled = true,
            description = 'Brings the suspension up to a firmer track-focused force and rebound baseline.',
            minimums = {
                fSuspensionForce = 4.0,
                fSuspensionReboundDamp = 3.5,
            },
        },
        {
            id = 'rally',
            label = 'Soft',
            enabled = true,
            description = 'Uses a softer off-road-biased damping setup for extra compliance.',
            values = {
                fSuspensionForce = 2.0,
                fSuspensionCompDamp = 3.0,
            },
        },
    },
    transmission = {
        { id = 'stock', label = 'Stock', enabled = true, description = 'Keeps the original gearing and shift behavior.' },
        { id = 'tuned', label = 'Fluid change', enabled = true, description = 'Slightly improves shift speed without changing gearing.', gearOffset = 0, clutchOffset = 2.0 },
        { id = 'street', label = 'clutch disc swap', enabled = true, description = 'Noticeably sharpens shifts for street driving.', gearOffset = 0, clutchOffset = 4.0 },
        { id = 'pro', label = 'pressure plate swap', enabled = true, description = 'Further increases clutch response and shift speed.', gearOffset = 0, clutchOffset = 6.0 },
        { id = 'race', label = 'gearbox swap', enabled = true, description = 'Adds a gear and delivers aggressive shift response.', gearOffset = 1, clutchOffset = 8.0 },
        { id = 'race_gearbox', label = 'Race gearbox', enabled = true, description = 'Maximum gearing and the quickest shift response in this set.', gearOffset = 2, clutchOffset = 10.0 },
    },
    engine = {
        { id = 'stock', label = 'Stock', enabled = true, description = 'Keeps the original engine power and top speed balance.' },
        { id = 'stage_1', label = 'Stage 1', enabled = true, description = 'Small power increase for a mild street upgrade.', powerOffset = 0.05 },
        { id = 'stage_2', label = 'Stage 2', enabled = true, description = 'Moderate increase in acceleration and top-end potential.', powerOffset = 0.10 },
        { id = 'stage_3', label = 'Stage 3', enabled = true, description = 'Strong engine tune with a clear step up in output.', powerOffset = 0.15 },
        { id = 'hsw_special', label = 'HSW Special', enabled = true, description = 'Highest non-swap power step in the standard upgrade path.', powerOffset = 0.25 },
        { id = 'kanjosj_swap', label = 'Kanjo SJ Swap', enabled = true, description = 'Uses Kanjo SJ engine values and audio for a full swap.', swapModel = 'KANJOSJ' },
        { id = 'tyrus_swap', label = 'Tyrus Swap', enabled = true, description = 'Uses Tyrus engine values and audio for a full swap.', swapModel = 'TYRUS' },
        { id = 'taipan_swap', label = 'Taipan Swap', enabled = true, description = 'Uses Taipan engine values and audio for a full swap.', swapModel = 'TAIPAN' },
    },
    tires = {
        { id = 'stock', label = 'Stock', enabled = true, description = 'Keeps the original compound and grip envelope.' },
        { id = 'street', label = 'Street', enabled = true, description = 'Mild grip upgrade with balanced street manners.', gripTargetProgress = 0.80, compoundLossMultiplier = 0.8, tractionLossMultiplier = 1.30 },
        { id = 'sport', label = 'Sport', enabled = true, description = 'Sharper on-road grip with a more performance-oriented compound.', gripTargetProgress = 0.85, compoundLossMultiplier = 0.8, tractionLossMultiplier = 1.60 },
        { id = 'rally', label = 'Offroad', enabled = true, description = 'Better loose-surface traction and lower low-speed traction loss.', gripTargetProgress = 0.90, compoundLossMultiplier = 0.8, tractionLossMultiplier = 0.5, lowSpeedLossMultiplier = 0.5 },
        { id = 'race', label = 'Race Hard', enabled = true, description = 'High grip for fast dry running with firmer breakaway behavior.', gripTargetProgress = 0.95, compoundLossMultiplier = 0.8, tractionLossMultiplier = 1.90 },
        { id = 'race_soft', label = 'Race Soft', enabled = true, description = 'Maximum grip target in the tire set for the strongest road hold.', gripTargetProgress = 1.0, compoundLossMultiplier = 0.8, tractionLossMultiplier = 2.20 },
    },
    brakes = {
        { id = 'stock', label = 'Stock', enabled = true, description = 'Keeps the original brake force.' },
        { id = 'level_1', label = 'Level 1', enabled = true, description = 'Small increase in stopping power.', brakeForceOffset = 0.15 },
        { id = 'level_2', label = 'Level 2', enabled = true, description = 'Moderate brake force upgrade for faster stops.', brakeForceOffset = 0.30 },
        { id = 'level_3', label = 'Level 3', enabled = true, description = 'Strong braking upgrade for aggressive driving.', brakeForceOffset = 0.45 },
        { id = 'level_4', label = 'Level 4', enabled = true, description = 'Highest brake force step in the standard set.', brakeForceOffset = 0.60 },
    },
    nitrous = {
        { id = 'stock', label = 'Stock', enabled = true, description = 'No nitrous boost is available.' },
        { id = 'level_1', label = 'Level 1', enabled = true, description = 'Light nitrous shot for a modest acceleration burst.', multiplier = 0.5 },
        { id = 'level_2', label = 'Level 2', enabled = true, description = 'Balanced nitrous setup with a stronger burst.', multiplier = 1.0 },
        { id = 'level_3', label = 'Level 3', enabled = true, description = 'High-output nitrous shot with a clear increase in shove.', multiplier = 1.5 },
        { id = 'level_4', label = 'Level 4', enabled = true, description = 'Maximum nitrous strength in the current pack lineup.', multiplier = 2.0 },
    },
}

PerformanceTuning.Definitions.fieldTypeAliases = {
    number = 'float',
    float = 'float',
    decimal = 'float',
    int = 'int',
    integer = 'int',
    flag = 'int',
    flags = 'int',
    vector = 'vector',
    vec = 'vector',
    vector3 = 'vector',
}

PerformanceTuning.Definitions.knownFieldTypes = {
    vecCentreOfMassOffset = 'vector',
    vecInertiaMultiplier = 'vector',
    nInitialDriveGears = 'int',
    nMonetaryValue = 'int',
    strModelFlags = 'int',
    strHandlingFlags = 'int',
    strDamageFlags = 'int',
    AIHandling = 'int',
}
