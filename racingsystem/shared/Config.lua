RacingSystem = RacingSystem or {}

RacingSystem.Config = {
    checkpointDrawDistanceMeters = 250.0,
    markerTypeId = 1,
    visualCheckpointRadiusScale = 2.0,
    checkpointRadiusMinMeters = 2.0,
    checkpointRadiusMaxMeters = 40.0,
    minLapCount = 1,
    maxLapCount = 10,
    playerCanInvokeMultipleRaces = false,
    raceOwnerCanKillOwnedRace = false,
    countdownMs = 5000,
    adminAce = "racingsystem.admin",
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
            checkpointSoftPowerPenaltyMultiplier = -20.0,
            leaderboardClientTiebreakEnabled = false,
            checkpointRuntimeZOffsetMeters = -2.0,
            maxFuturePreviewCheckpoints = 3,
            markerTaxonomy = {
                routeCheckpointTypeId = nil,
                routeChevronTypeId = 20,
                startLineIdleTypeId = 4,
                startLineIdleColor = { r = 255, g = 255, b = 255, a = 0 },
                startLineBlipSprite = 38,
            },
            extraPrintLevel = 0,
        },
        server = {
            ugcFetchRetryCooldownMs = 700,
            ugcFetchTotalTimeoutMs = 30000,
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
