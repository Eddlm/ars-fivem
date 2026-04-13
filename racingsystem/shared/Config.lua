RacingSystem = RacingSystem or {}

RacingSystem.Config = {
    -- convar candidate: rs_checkpoint_draw_distance — lower on low-end servers to reduce draw calls; raise for long straights
    checkpointDrawDistanceMeters = 250.0,
    markerTypeId = 1,
    visualCheckpointRadiusScale = 2.0,
    checkpointRadiusMinMeters = 2.0,
    checkpointRadiusMaxMeters = 40.0,
    minLapCount = 1,
    -- convar candidate: rs_max_lap_count — lets admins cap race length server-wide without a file edit
    maxLapCount = 10,
    -- convar candidate: rs_player_multiple_races — useful for event servers where multiple concurrent races are desired
    playerCanInvokeMultipleRaces = false,
    -- convar candidate: rs_owner_can_kill_race — toggle per-server without touching the file; often needed in moderated event sessions
    raceOwnerCanKillOwnedRace = false,
    -- convar candidate: rs_countdown_seconds — event organizers often want a shorter or longer countdown depending on session type
    countdownMs = 5000,
    debugLogging = true,
    adminAce = "racingsystem.admin",
    -- convar candidate: rs_late_join_limit_percent — allows real-time tuning of how open races stay to new joiners during a session
    lateJoinProgressLimitPercent = 50,

    advanced = {
        client = {
            checkpointRadiusStepMeters = 1.0,
            editorPitchUpControlId = 111,
            editorPitchDownControlId = 112,
            checkpointPassArmDistance = 30.0,
            checkpointPassReleaseThreshold = 0.75,
            checkpointRecoveryPassMaxMph = 5.0,
            checkpointRecoveryForwardVelocityRatioMax = 0.66,
            checkpointSoftPowerPenaltyMultiplier = 0.05,
            checkpointDebugTextDistanceMeters = 300.0,
            leaderboardClientTiebreakEnabled = false,
            checkpointRuntimeZOffsetMeters = -2.0,
            maxFuturePreviewCheckpoints = 3,
            cornerConeModel = 'prop_roadcone01a',
            cornerConeSpawnHeightOffset = 4.0,
            cornerConeMinLineClearanceMeters = 10.0,
            markerTaxonomy = {
                routeCheckpointTypeId = nil,
                routeChevronTypeId = 20,
                startLineIdleTypeId = 4,
                startLineIdleColor = { r = 255, g = 255, b = 255, a = 0 },
                futureCheckpointBlipSprite = 1,
                startLineBlipSprite = 38,
            },
            extraPrintLevel = 0,
        },
        server = {
            ugcFetchRetryCooldownMs = 700,
            gtaoCheckpointRadiusScale = 1.0,
            pointToPointAutodetectDistanceMeters = 500.0,
            extraPrintLevel = 0,
        },
        menu = {
            title = 'Race Control',
            subtitle = '~b~RACINGSYSTEM',
            x = 20,
            checkpointWidthOptions = { 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 18.0, 20.0, 24.0, 28.0, 32.0, 40.0 },
            extraPrintLevel = 0,
        },
    },

}
