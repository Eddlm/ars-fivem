Config = {}

-- Camera hold timing.
Config.ToggleHoldMs = 1000
Config.LookBackControl = 79 -- INPUT_VEH_LOOK_BEHIND

Config.VirtualMirror = {
    enabled = true,
    centerX = 0.5,
    centerY = 0.08,
    width = 0.315,
    height = 0.08,
    horizontalFovDegrees = 90.0,
    verticalFovDegrees = 15.0,
    trackingHorizontalPaddingDegrees = 90.0,
    vehiclePollRadius = 200.0,
    roundRobinChecksPerSecond = 100,
    maxTrackedVehicles = 24,
    frameThickness = 0.006,
    frameColor = { r = 20, g = 20, b = 20, a = 230 },
    fillColor = { r = 65, g = 75, b = 90, a = 120 },
    dotSize = 0.007,
    dotSizeNearMultiplier = 7.5,
    dotScaleExponent = 4.0,
    dotSeparationFalloffExponent = 22.0,
    dotWidthScale = 0.65,
    dotClipPaddingPixels = 4.0,
    dotTextureDict = 'mpinventory',
    dotTextureName = 'in_world_circle',
    dotColor = { r = 255, g = 220, b = 80, a = 235 },
    dotRearColor = { r = 255, g = 70, b = 60, a = 235 }
}

-- Smooth follow camera tuning.
Config.FollowCam = {
    acceleration = 10.0,
    damping = 2.0,
    catchupFactor = 10.0,
    initialSpawnDistance = 3.5,
    minimumBubblePadding = 1.0,
    minimumBubbleEscapeSpeed = 6.0,
    speedMatchDistance = 4.0,
    rotationAcceleration = 1800.0,
    rotationDamping = 8.0,
    rotationSmoothing = 30.0,
    followDistancePadding = 0.1,
    trailingDistanceByViewMode = {
        [0] = 0.25,
        [1] = 1.25,
        [2] = 2.25
    },
    heightOffsetByViewMode = {
        [0] = 0.5,
        [1] = 1.3,
        [2] = 2.1
    },
    viewModePadding = {
        [0] = 0.25,
        [1] = 0.5,
        [2] = 0.75
    },
    heightAboveVehicle = 2.0,
    focusHeight = 0.85,
    velocityLookAhead = 0.5,
    maxLookAhead = 3.0,
    hoodViewMode = 4,
    flipAngularVelocityX = 1.5,
    uprightThreshold = 0.2,
    uprightRecoveryThreshold = 0.9,
    defaultFov = 60.0,
    minFov = 20.0,
    maxFov = 90.0
}

-- Hood camera attachment tuning.
Config.HoodCam = {
    forwardOffset = -2,
    upOffset = 0.08,
    rotationX = -10.0,
    rotationY = 0.0,
    rotationZ = 0.0,
    scanHeight = 2.5,
    scanStep = 0.2,
    scanMaxAhead = 3.5,
    hoodNormalDotThreshold = 0.94
}
