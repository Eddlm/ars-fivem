CustomCam = CustomCam or {}
CustomCam.Config = {}

-- Camera hold timing.
-- convar candidate: cc_toggle_hold_ms — players on touch-heavy setups or with accessibility needs may want a shorter or longer hold
CustomCam.Config.toggleHoldMs = 1000
-- convar candidate: cc_show_control_hints — servers with experienced regulars can disable hints to reduce UI clutter
CustomCam.Config.showControlHints = true

CustomCam.Config.Controls = {
    toggleControlId = 0, -- INPUT_NEXT_CAMERA
    lookBackControlId = 79, -- INPUT_VEH_LOOK_BEHIND
}

-- convar candidates: cc_virtual_mirror_enabled, cc_virtual_mirror_width, cc_virtual_mirror_height
-- Mirror is a per-frame render cost; admins may want to disable it globally or let players size it to their resolution
CustomCam.Config.VirtualMirror = {
    enabled = true,
    centerXNormalized = 0.5,
    centerYNormalized = 0.08,
    widthNormalized = 0.315,
    heightNormalized = 0.08,
}

-- Smooth follow camera tuning.
-- convar candidate: cc_followcam_spawn_distance — closer spawn suits tight city driving; farther suits open highway/track sessions
CustomCam.Config.FollowCam = {
    initialSpawnDistanceMeters = 3.5,
    trailingDistanceByViewModeMeters = {
        [0] = 0.25,
        [1] = 1.25,
        [2] = 2.25
    },
    heightOffsetByViewModeMeters = {
        [0] = 0.5,
        [1] = 1.3,
        [2] = 2.1
    },
}

-- Hood camera attachment tuning.
CustomCam.Config.HoodCam = {
    forwardOffsetMeters = -2,
    upOffsetMeters = 0.08,
    rotationXDegrees = -10.0,
}

CustomCam.Config.Advanced = {
    defaultGameplayCamFov = 60.0,
    virtualMirrorHorizontalFovDegrees = 90.0,
    virtualMirrorVerticalFovDegrees = 15.0,
    virtualMirrorTrackingHorizontalPaddingDegrees = 90.0,
    virtualMirrorVehiclePollRadiusMeters = 200.0,
    virtualMirrorMaxTrackedVehicles = 24,
    virtualMirrorFrameThicknessNormalized = 0.006,
    virtualMirrorFrameColor = { r = 20, g = 20, b = 20, a = 230 },
    virtualMirrorFillColor = { r = 65, g = 75, b = 90, a = 120 },
    virtualMirrorDotSizeNormalized = 0.007,
    virtualMirrorDotSizeNearMultiplier = 7.5,
    virtualMirrorDotScaleExponent = 4.0,
    virtualMirrorDotSeparationFalloffExponent = 22.0,
    virtualMirrorDotWidthScale = 0.65,
    virtualMirrorDotClipPaddingPixels = 4.0,
    virtualMirrorDotTextureDict = 'mpinventory',
    virtualMirrorDotTextureName = 'in_world_circle',
    virtualMirrorDotColor = { r = 255, g = 220, b = 80, a = 235 },
    virtualMirrorDotRearColor = { r = 255, g = 70, b = 60, a = 235 },
    followCamMinimumBubblePaddingMeters = 1.0,
    followCamMinimumBubbleEscapeSpeedMetersPerSecond = 6.0,
    followCamSpeedMatchDistanceMeters = 4.0,
    followCamAccelerationFactor = 10.0,
    followCamDampingFactor = 2.0,
    followCamCatchupFactor = 10.0,
    followCamRotationAccelerationDegreesPerSecondSquared = 1800.0,
    followCamRotationDampingFactor = 8.0,
    followCamRotationSmoothingFactor = 30.0,
    followCamViewModePaddingMeters = { [0] = 0.25, [1] = 0.5, [2] = 0.75 },
    followCamFallbackDistancePaddingMeters = 0.1,
    followCamVelocityLookAheadFactor = 0.5,
    followCamHoodViewModeId = 4,
    followCamFlipAngularVelocityXRadiansPerSecond = 1.5,
    followCamUprightThresholdRatio = 0.2,
    followCamUprightRecoveryThresholdRatio = 0.9,
    followCamFocusHeightMeters = 0.85,
    hoodCamScanHeightMeters = 2.5,
    hoodCamScanStepMeters = 0.2,
    hoodCamScanMaxAheadMeters = 3.5,
    hoodCamNormalDotThresholdRatio = 0.94,
    hoodCamRotationYDegrees = 0.0,
    hoodCamRotationZDegrees = 0.0,
    controlHintInitialDelayMs = 30000,
}
