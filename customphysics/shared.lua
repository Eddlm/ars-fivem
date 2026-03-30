CustomPhysics = CustomPhysics or {}

CustomPhysics.Config = {
    -- Wheelies
    nativeWheeliesDisabled = true,
    customWheelieEnabled = true,    
    wheeliesMuscleOnly = true,
    customWheelieForce = 0.4, -- TO DO - Consider making the wheelie force dependent on true acceleration, not wheel acceleration.
    customWheelieFrontOffset = 2,
    customWheelieArmSpeedThreshold = 1.0,

-- Rollovers
rolloversEnabled = true,

    -- Offroad speed 
    offroadBoostEnabled = true,
    offroadMaxMultiplier = 5.0,
    offroadFallStep = 100.0,
    offroadRampStep = 2.0,

    -- Fallback value in case the car does not get a rev limiter state bag from performancetuning.
    fallbackRevLimiterEnabled = false,
    
    -- Anti kerb and suspension boost
    suspensionBoostPenaltyStrength = 5.0,

    -- Powerslides
    slideAngleStepDegrees = 20.0,
    slideMaxMultiplier = 5.0,
    slideSpeedThreshold = 3.0,    

    materialTyreDragByIndex = {
        [0] = -0.15,
        [1] = -0.10,
        [2] = -0.10,
        [4] = -0.10,
        [5] = -0.10,
        [7] = -0.12,
        [8] = -0.10,
        [9] = -0.15,
        [10] = -0.20,
        [11] = -0.15,
        [12] = -0.13,
        [13] = -0.15,
        [14] = -0.15,
        [15] = -0.10,
        [16] = -0.15,
        [17] = -0.15,
        [18] = 0.115,
        [19] = 0.08,
        [20] = 0.13,
        [21] = 0.06,
        [22] = 0.06,
        [23] = 0.115,
        [24] = 0.13,
        [27] = 0.06,
        [28] = 0.02,
        [29] = 0.15,
        [31] = 0.04,
        [32] = 0.06,
        [33] = 0.04,
        [34] = 0.04,
        [35] = 0.03,
        [36] = 0.02,
        [37] = 0.05,
        [38] = 0.07,
        [39] = 0.06,
        [40] = 0.10,
        [41] = 0.07,
        [42] = 0.07,
        [43] = 0.08,
        [44] = 0.02,
        [45] = 0.03,
        [46] = 0.03,
        [47] = 0.02,
        [48] = 0.01,
        [49] = 0.02,
    },
}
