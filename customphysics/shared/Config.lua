CustomPhysics = CustomPhysics or {}

CustomPhysics.Config = {
    -- Wheelies
    nativeWheeliesDisabled = true,
    -- convar: cp_wheelies_enabled <0|1> — toggle the custom wheelie system server-side without touching this file
    -- convar candidate: cp_wheelies_muscle_only — some servers run mixed car classes and want wheelies available for all RWD vehicles
    wheeliesMuscleOnly = true,

    -- Rollovers
    -- convar candidate: cp_rollovers_enabled — lets admins disable the recovery assist on servers preferring pure simulation
    rolloversEnabled = true,

    -- Offroad speed
    -- convar candidate: cp_offroad_boost_enabled — servers focused on road racing may want to disable this without editing Lua
    offroadBoostEnabled = true,
    -- convar candidate: cp_offroad_max_multiplier — tune the offroad boost ceiling for balance across different terrain servers
    offroadMaxMultiplier = 5.0,


    -- Powerslides
    -- convar candidate: cp_slide_speed_threshold — lower values make slides trigger earlier; useful tuning for different tire/surface setups
    slideAngleStepDegrees = 20.0,
    -- convar candidate: cp_slide_max_multiplier — caps the power boost during slides; competitive servers may want a tighter cap
    slideMaxMultiplier = 5.0,
    slideSpeedThresholdMetersPerSecond = 3.0,
 

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

    advanced = {
        rollovers = {
            startSpeedMs         = 8.94,  -- convar: cp_rollover_start_speed (m/s, default 20 mph)
            keepSpeedMs          = 6.71,  -- convar: cp_rollover_keep_speed  (m/s, default 15 mph)
            angularStartDegrees  = 180.0, -- convar: cp_rollover_start_rot   (deg/s, min rotation to trigger)
            angularKeepDegrees   = 90.0,  -- convar: cp_rollover_keep_rot    (deg/s, min rotation to keep active)
            checkIntervalMs      = 300,
            forceHeightOffset    = 4.0,
            forceMagnitude       = 1.4,
            settleDurationMs     = 500,
            initialForceMultiplier = 3.0,
        },
        wheelies = {
            armSpeedThresholdMetersPerSecond = 1.0,
            forceMultiplier = 0.4,
            frontOffsetLengthMultiplier = 2.0,
        },
    },

}
