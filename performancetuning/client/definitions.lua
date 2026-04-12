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
        handbrakeForce = 'fHandBrakeForce',
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
    PerformanceTuning.Definitions.handlingFields.brakes.handbrakeForce,
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
    performancePiDistribution = {},
    performancePiMultipliers = {},
    performanceBarFillTargets = {},
    performanceNearbyPanels = {},
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
