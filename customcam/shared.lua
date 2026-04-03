CustomCam = CustomCam or {}
CustomCam.Config = {}

-- Camera hold timing.
CustomCam.Config.toggleHoldMs = 1000
CustomCam.Config.showControlHints = true

CustomCam.Config.Controls = {
    toggleControlId = 0, -- INPUT_NEXT_CAMERA
    lookBackControlId = 79, -- INPUT_VEH_LOOK_BEHIND
}

CustomCam.Config.Debug = {
    command = "customcamdebug",
}

CustomCam.Config.VirtualMirror = {
    enabled = true,
    centerXNormalized = 0.5,
    centerYNormalized = 0.08,
    widthNormalized = 0.315,
    heightNormalized = 0.08,
}

-- Smooth follow camera tuning.
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
