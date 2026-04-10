-- Applies tuning packs and tweak values to vehicles and synchronized tune state.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.TuningPackManager = PerformanceTuning.TuningPackManager or {}

local TuningPackManager = PerformanceTuning.TuningPackManager
local TIRE_COMPOUND_CATEGORY_OPTIONS = {
    { id = 'stock', label = 'Stock', description = 'Factory. Quality has no effect.' },
    { id = 'road', label = 'Road', description = "Tarmac focused, don't go off the road." },
    { id = 'rally', label = 'Mixed', description = 'Compromise between tarmac grip and offroad grip loss.' },
    { id = 'offroad', label = 'Offroad', description = 'Least griploss offroad, not much grip on tarmac.' },
}
local TIRE_COMPOUND_QUALITY_OPTIONS = {
    { id = 'low_end', label = 'Low-End', description = 'Entry-level compound quality.' },
    { id = 'mid_end', label = 'Mid-End', description = 'Balanced compound quality.' },
    { id = 'high_end', label = 'High-End', description = 'Highest compound quality.' },
    { id = 'top_end', label = 'Top-End', description = 'Ultimate compound quality.' },
}
local TIRE_COMPOUND_TUNING_MATRIX = {
    -- Matrix is intentionally sparse so we can scale from 3x1 to 3x3 progressively.
    road = {
        low_end = {
            gripBarProgressRatio = 0.60,
            tractionLossMultiplier = 1.3,
        },
        mid_end = {
            gripBarProgressRatio = 0.7333333333,
            tractionLossMultiplier = 1.6,
        },
        high_end = {
            gripBarProgressRatio = 0.8666666667,
            tractionLossMultiplier = 1.9,
        },
        top_end = {
            gripBarProgressRatio = 1.00,
            tractionLossMultiplier = 2.2,
        },
    },
    rally = {
        low_end = {
            gripBarProgressRatio = 0.58,
            tractionLossMultiplier = 0.726,
        },
        mid_end = {
            gripBarProgressRatio = 0.68,
            tractionLossMultiplier = 0.52272,
        },
        high_end = {
            gripBarProgressRatio = 0.78,
            tractionLossMultiplier = 0.373745,
        },
        top_end = {
            gripBarProgressRatio = 0.88,
            tractionLossMultiplier = 0.265646,
        },
    },
    offroad = {
        low_end = {
            gripBarProgressRatio = 0.58,
            tractionLossMultiplier = 0.363,
        },
        mid_end = {
            gripBarProgressRatio = 0.6533333333,
            tractionLossMultiplier = 0.13068,
        },
        high_end = {
            gripBarProgressRatio = 0.7266666667,
            tractionLossMultiplier = 0.046718,
        },
        top_end = {
            gripBarProgressRatio = 0.8,
            tractionLossMultiplier = 0.016603,
        },
    },
}
local TIRE_PACK_ID_BY_CATEGORY_AND_QUALITY = {
    road = {
        low_end = 'street',
        mid_end = 'sport',
        high_end = 'race_soft',
        top_end = 'race_soft',
    },
    rally = {
        low_end = 'street',
        mid_end = 'sport',
        high_end = 'race_soft',
        top_end = 'race_soft',
    },
    offroad = {
        low_end = 'street',
        mid_end = 'sport',
        high_end = 'race_soft',
        top_end = 'race_soft',
    },
}

local function isUnavailableTirePackForGrip(pack, baseTireMax, isFiniteNumber, performance)
    if type(pack) ~= 'table' or pack.enabled == false then
        return true
    end

    if pack.id == 'stock' or pack.id == 'rally' or not isFiniteNumber(baseTireMax) or pack.gripBarProgressRatio == nil then
        return false
    end

    local gripBarProgressRatio = math.max(0.0, math.min(1.0, tonumber(pack.gripBarProgressRatio) or 0.0))
    local targetGripValue = (gripBarProgressRatio * performance.barSegmentCount) / performance.gripBarScaleFactor
    return targetGripValue < baseTireMax
end

local function buildPackOptions(packs, selectedId)
    local options = {}

    for index, pack in ipairs(packs or {}) do
        options[index] = {
            index = index,
            id = pack.id,
            label = pack.label,
            description = pack.description,
            selected = pack.id == selectedId,
            enabled = pack.enabled ~= false,
        }
    end

    return options
end

local function getPackLabel(packs, packId, fallback)
    for _, pack in ipairs(packs or {}) do
        if pack.id == packId then
            return pack.label
        end
    end

    return fallback or 'Stock'
end

local function getEngineCombinedPacks()
    local internals = PerformanceTuning._internals or {}
    local combined = {}
    local enginePacks = internals.ENGINE_PACKS or {}
    local engineSwaps = internals.ENGINE_SWAPS or {}

    for index = 1, #enginePacks do
        local pack = enginePacks[index]
        if type(pack) == 'table' then
            combined[#combined + 1] = pack
        end
    end
    for index = 1, #engineSwaps do
        local swap = engineSwaps[index]
        if type(swap) == 'table' then
            combined[#combined + 1] = swap
        end
    end

    return combined
end

local function getBaseEnginePackId()
    local internals = PerformanceTuning._internals or {}
    local enginePacks = internals.ENGINE_PACKS or {}
    local firstPack = enginePacks[1]
    local firstPackId = type(firstPack) == 'table' and firstPack.id or nil
    if type(firstPackId) == 'string' and firstPackId ~= '' then
        return firstPackId
    end
    return 'stock'
end

local function isBaseEnginePackId(packId)
    return tostring(packId or '') == tostring(getBaseEnginePackId())
end

local function getBaseBrakePackId()
    local internals = PerformanceTuning._internals or {}
    local brakePacks = internals.BRAKE_PACKS or {}
    local firstPack = brakePacks[1]
    local firstPackId = type(firstPack) == 'table' and firstPack.id or nil
    if type(firstPackId) == 'string' and firstPackId ~= '' then
        return firstPackId
    end
    return 'stock'
end

local function isBaseBrakePackId(packId)
    return tostring(packId or '') == tostring(getBaseBrakePackId())
end

local function getBrakeUpgradeProgress(selectedPackId)
    local packs = PerformanceTuning._internals.BRAKE_PACKS or {}
    local selectedId = tostring(selectedPackId or '')
    local totalUpgrades = 0
    local selectedLevel = 0

    for index, pack in ipairs(packs) do
        local isEligible = type(pack) == 'table' and pack.enabled ~= false
        if isEligible then
            if index > 1 then
                totalUpgrades = totalUpgrades + 1
                if pack.id == selectedId then
                    selectedLevel = totalUpgrades
                end
            elseif pack.id == selectedId then
                selectedLevel = 0
            end
        end
    end

    return selectedLevel, totalUpgrades
end

function TuningPackManager.normalizeEnginePackId(packId)
    local normalized = tostring(packId or getBaseEnginePackId())
    local basePackId = getBaseEnginePackId()
    if normalized == '' then
        return basePackId
    end

    if normalized:lower() == 'stock' then
        return basePackId
    end

    if normalized:sub(-5):lower() == '_swap' then
        normalized = normalized:sub(1, -6)
    end

    local upperModel = normalized:upper()
    local internals = PerformanceTuning._internals or {}
    for _, swap in ipairs(internals.ENGINE_SWAPS or {}) do
        local swapId = tostring((type(swap) == 'table' and swap.id) or ''):upper()
        if swapId ~= '' and swapId == upperModel then
            return swap.id
        end
    end

    return normalized
end

function TuningPackManager.normalizeSuspensionPackId(packId)
    if packId == 'street' then
        return 'sport'
    end

    return packId or 'stock'
end

function TuningPackManager.buildSuspensionPackOptions(selectedPackId)
    return buildPackOptions(PerformanceTuning._internals.SUSPENSION_PACKS, TuningPackManager.normalizeSuspensionPackId(selectedPackId))
end

function TuningPackManager.getSuspensionPackLabel(packId)
    return getPackLabel(PerformanceTuning._internals.SUSPENSION_PACKS, TuningPackManager.normalizeSuspensionPackId(packId), 'Stock')
end

function TuningPackManager.buildTransmissionPackOptions(selectedPackId)
    return buildPackOptions(PerformanceTuning._internals.TRANSMISSION_PACKS, selectedPackId)
end

function TuningPackManager.getTransmissionPackLabel(packId)
    return getPackLabel(PerformanceTuning._internals.TRANSMISSION_PACKS, packId, 'Stock')
end

function TuningPackManager.buildEnginePackOptions(selectedPackId)
    return buildPackOptions(getEngineCombinedPacks(), TuningPackManager.normalizeEnginePackId(selectedPackId))
end

function TuningPackManager.getEnginePackLabel(packId)
    return getPackLabel(getEngineCombinedPacks(), TuningPackManager.normalizeEnginePackId(packId), 'Stock')
end

function TuningPackManager.buildTireCompoundPackOptions(selectedPackId, baseTireMax)
    local packs = PerformanceTuning._internals.TIRE_COMPOUND_PACKS
    local performance = PerformanceTuning._internals.Performance
    local isFiniteNumber = PerformanceTuning._internals.isFiniteNumber
    local options = {}

    for index, pack in ipairs(packs) do
        local enabled = type(pack) == 'table' and pack.enabled ~= false
        if enabled and isUnavailableTirePackForGrip(pack, baseTireMax, isFiniteNumber, performance) then
            enabled = false
        end

        options[index] = {
            index = index,
            id = pack.id,
            label = pack.label,
            description = pack.description,
            selected = pack.id == selectedPackId,
            enabled = enabled,
        }
    end

    return options
end

function TuningPackManager.normalizeTireCompoundCategory(categoryId)
    local normalized = tostring(categoryId or 'stock'):lower()
    if normalized == 'stock' then
        return 'stock'
    end
    if normalized == 'rally' then
        return 'rally'
    end
    if normalized == 'offroad' or normalized == 'off_road' then
        return 'offroad'
    end
    if normalized == 'road' then
        return 'road'
    end
    return 'stock'
end

function TuningPackManager.normalizeTireCompoundQuality(qualityId)
    local normalized = tostring(qualityId or 'mid_end'):lower()
    if normalized == 'stock' then
        return 'mid_end'
    end
    if normalized == 'low_end' or normalized == 'low' then
        return 'low_end'
    end
    if normalized == 'high_end' or normalized == 'high' then
        return 'high_end'
    end
    if normalized == 'top_end' or normalized == 'top-end' or normalized == 'top' then
        return 'top_end'
    end
    if normalized == 'mid_end' or normalized == 'mid' then
        return 'mid_end'
    end
    return 'mid_end'
end

function TuningPackManager.buildTireCompoundCategoryOptions(selectedCategoryId)
    return buildPackOptions(TIRE_COMPOUND_CATEGORY_OPTIONS, TuningPackManager.normalizeTireCompoundCategory(selectedCategoryId))
end

function TuningPackManager.buildTireCompoundQualityOptions(selectedQualityId)
    return buildPackOptions(TIRE_COMPOUND_QUALITY_OPTIONS, TuningPackManager.normalizeTireCompoundQuality(selectedQualityId))
end

function TuningPackManager.getTireCompoundCategoryLabel(categoryId)
    return getPackLabel(TIRE_COMPOUND_CATEGORY_OPTIONS, TuningPackManager.normalizeTireCompoundCategory(categoryId), 'Stock')
end

function TuningPackManager.getTireCompoundQualityLabel(qualityId)
    return getPackLabel(TIRE_COMPOUND_QUALITY_OPTIONS, TuningPackManager.normalizeTireCompoundQuality(qualityId), 'Mid-End')
end

function TuningPackManager.resolveTireCompoundPackId(categoryId, qualityId)
    local normalizedCategory = TuningPackManager.normalizeTireCompoundCategory(categoryId)
    local normalizedQuality = TuningPackManager.normalizeTireCompoundQuality(qualityId)
    if normalizedCategory == 'stock' then
        return 'stock'
    end
    local categoryMap = TIRE_PACK_ID_BY_CATEGORY_AND_QUALITY[normalizedCategory] or TIRE_PACK_ID_BY_CATEGORY_AND_QUALITY.road
    local packId = categoryMap and categoryMap[normalizedQuality] or nil
    return packId or 'stock'
end

local function getTireCompoundTuningProfile(categoryId, qualityId)
    local normalizedCategory = TuningPackManager.normalizeTireCompoundCategory(categoryId)
    local normalizedQuality = TuningPackManager.normalizeTireCompoundQuality(qualityId)
    local categoryProfiles = TIRE_COMPOUND_TUNING_MATRIX[normalizedCategory]
    if type(categoryProfiles) ~= 'table' then
        return nil
    end

    local qualityProfile = categoryProfiles[normalizedQuality]
    if type(qualityProfile) ~= 'table' then
        return nil
    end

    return qualityProfile
end

local function getLowSpeedLossMultiplierForQuality(qualityId)
    local normalizedQuality = TuningPackManager.normalizeTireCompoundQuality(qualityId)
    if normalizedQuality == 'low_end' then
        return 0.8
    end
    if normalizedQuality == 'mid_end' then
        return 0.6
    end
    if normalizedQuality == 'high_end' then
        return 0.4
    end
    if normalizedQuality == 'top_end' then
        return 0.2
    end
    return nil
end

local function getRelativeGripTargetValue(baseGrip, categoryId, qualityId)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    local performanceModel = runtimeConfig.performanceModel or runtimeConfig.performanceBars or {}
    local gripConfig = performanceModel.grip or {}
    local qualityLadder = gripConfig.qualityLadder or {}
    local compoundRoadOffset = gripConfig.compoundRoadOffset or {}

    local resolvedBaseGrip = tonumber(baseGrip) or 0.0
    if resolvedBaseGrip <= 0.0 then
        return 0.0
    end

    local normalizedCategory = TuningPackManager.normalizeTireCompoundCategory(categoryId)
    local normalizedQuality = TuningPackManager.normalizeTireCompoundQuality(qualityId)
    local qualityOffset = tonumber(qualityLadder[normalizedQuality]) or 0.0
    local roadQualityTarget = resolvedBaseGrip + qualityOffset
    local compoundOffset = tonumber(compoundRoadOffset[normalizedCategory]) or 0.0
    return math.max(0.1, roadQualityTarget + compoundOffset)
end

function TuningPackManager.inferTireCompoundQualityFromPackId(packId)
    local normalized = tostring(packId or ''):lower()
    if normalized == 'street' then
        return 'low_end'
    end
    if normalized == 'sport' or normalized == 'rally' then
        return 'mid_end'
    end
    if normalized == 'race' or normalized == 'race_soft' then
        return 'high_end'
    end
    return nil
end

function TuningPackManager.getTireCompoundPackLabel(packId)
    return getPackLabel(PerformanceTuning._internals.TIRE_COMPOUND_PACKS, packId, 'Stock')
end

function TuningPackManager.buildBrakePackOptions(selectedPackId)
    return buildPackOptions(PerformanceTuning._internals.BRAKE_PACKS, selectedPackId)
end

function TuningPackManager.getBrakePackLabel(packId)
    return getPackLabel(PerformanceTuning._internals.BRAKE_PACKS, packId, 'Stock')
end

function TuningPackManager.buildNitrousPackOptions(selectedPackId)
    return buildPackOptions(PerformanceTuning._internals.NITROUS_PACKS, selectedPackId)
end

function TuningPackManager.getNitrousPackLabel(packId)
    return getPackLabel(PerformanceTuning._internals.NITROUS_PACKS, packId, 'Stock')
end

TuningPackManager.buildNitroPackOptions = TuningPackManager.buildNitrousPackOptions
TuningPackManager.getNitroPackLabel = TuningPackManager.getNitrousPackLabel

function TuningPackManager.getContextDetails(bucket, context)
    local internals = PerformanceTuning._internals
    if context == 'engine' then
        return {
            key = 'engine',
            title = 'ENGINE',
            fieldName = table.concat(internals.ENGINE_FIELDS, ', '),
            currentValue = TuningPackManager.getEnginePackLabel(bucket.enginePack),
            currentStep = bucket.enginePack,
            optionType = 'pack',
            options = TuningPackManager.buildEnginePackOptions(bucket.enginePack),
        }
    end

    if context == 'transmission' then
        return {
            key = 'transmission',
            title = 'TRANSMISSION',
            fieldName = table.concat(internals.TRANSMISSION_FIELDS, ', '),
            currentValue = TuningPackManager.getTransmissionPackLabel(bucket.transmissionPack),
            currentStep = bucket.transmissionPack,
            optionType = 'pack',
            options = TuningPackManager.buildTransmissionPackOptions(bucket.transmissionPack),
        }
    end

    if context == 'suspension' then
        return {
            key = 'suspension',
            title = 'SUSPENSION',
            fieldName = table.concat(internals.SUSPENSION_FIELDS, ', '),
            currentValue = TuningPackManager.getSuspensionPackLabel(bucket.suspensionPack),
            currentStep = bucket.suspensionPack,
            optionType = 'pack',
            options = TuningPackManager.buildSuspensionPackOptions(bucket.suspensionPack),
        }
    end

    if context == 'tires' then
        return {
            key = 'tires',
            title = 'TIRE COMPOUND',
            fieldName = table.concat(internals.TIRE_FIELDS, ', '),
            currentValue = TuningPackManager.getTireCompoundPackLabel(bucket.tireCompoundPack),
            currentStep = bucket.tireCompoundPack,
            optionType = 'pack',
            options = TuningPackManager.buildTireCompoundPackOptions(bucket.tireCompoundPack, bucket.baseTires and bucket.baseTires[internals.TIRE_MAX_FIELD]),
        }
    end

    if context == 'tireCompoundCategory' then
        return {
            key = 'tireCompoundCategory',
            title = 'TIRE COMPOUND CATEGORY',
            fieldName = 'Compound category',
            currentValue = TuningPackManager.getTireCompoundCategoryLabel(bucket.tireCompoundCategory),
            currentStep = TuningPackManager.normalizeTireCompoundCategory(bucket.tireCompoundCategory),
            optionType = 'pack',
            options = TuningPackManager.buildTireCompoundCategoryOptions(bucket.tireCompoundCategory),
        }
    end

    if context == 'tireCompoundQuality' then
        return {
            key = 'tireCompoundQuality',
            title = 'TIRE COMPOUND QUALITY',
            fieldName = 'Compound quality',
            currentValue = TuningPackManager.getTireCompoundQualityLabel(bucket.tireCompoundQuality),
            currentStep = TuningPackManager.normalizeTireCompoundQuality(bucket.tireCompoundQuality),
            optionType = 'pack',
            options = TuningPackManager.buildTireCompoundQualityOptions(bucket.tireCompoundQuality),
        }
    end

    if context == 'brakes' then
        return {
            key = 'brakes',
            title = 'BRAKES',
            fieldName = table.concat(internals.BRAKE_FIELDS, ', '),
            currentValue = TuningPackManager.getBrakePackLabel(bucket.brakePack),
            currentStep = bucket.brakePack,
            optionType = 'pack',
            options = TuningPackManager.buildBrakePackOptions(bucket.brakePack),
        }
    end

    if context == 'nitrous' or context == 'nitro' then
        return {
            key = 'nitrous',
            title = 'NITROUS',
            fieldName = 'Nitrous level',
            currentValue = TuningPackManager.getNitrousPackLabel(bucket.nitrousLevel),
            currentStep = bucket.nitrousLevel,
            optionType = 'pack',
            options = TuningPackManager.buildNitrousPackOptions(bucket.nitrousLevel),
        }
    end

    return {
        key = 'engine',
        title = 'ENGINE',
        fieldName = table.concat(internals.ENGINE_FIELDS, ', '),
        currentValue = TuningPackManager.getEnginePackLabel(bucket.enginePack),
        currentStep = bucket.enginePack,
        optionType = 'pack',
        options = TuningPackManager.buildEnginePackOptions(bucket.enginePack),
    }
end

function TuningPackManager.applyEngineAudioProfile(vehicle, audioName)
    if not PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) then
        return false
    end

    if type(audioName) ~= 'string' or audioName == '' then
        return false
    end

    ForceVehicleEngineAudio(vehicle, audioName)
    return true
end

function TuningPackManager.resolveEngineSwapValues(modelName)
    local normalizedName = tostring(modelName or ''):upper()
    local cache = PerformanceTuning._state.cachedEngineSwapValuesByModel
    local powerField = PerformanceTuning._internals.POWER_FIELD
    local topSpeedField = PerformanceTuning._internals.TOP_SPEED_FIELD
    local dragField = PerformanceTuning._internals.DRAG_FIELD
    local readHandlingValue = PerformanceTuning.HandlingManager.readHandlingValue
    if normalizedName == '' then
        return nil, 'Missing swap model name.'
    end

    if cache[normalizedName] then
        return cache[normalizedName]
    end

    local modelHash = GetHashKey(normalizedName)
    if modelHash == 0 or not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
        return nil, ('Swap model "%s" is invalid.'):format(normalizedName)
    end

    RequestModel(modelHash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(modelHash) do
        Wait(0)
        if GetGameTimer() >= deadline then
            return nil, ('Swap model "%s" failed to load.'):format(normalizedName)
        end
    end

    local tempVehicle = CreateVehicle(modelHash, 0.0, 0.0, -200.0, 0.0, false, false)
    if not PerformanceTuning.VehicleManager.isVehicleEntityValid(tempVehicle) then
        SetModelAsNoLongerNeeded(modelHash)
        return nil, ('Swap model "%s" could not be created.'):format(normalizedName)
    end

    local values = {
        [powerField] = readHandlingValue(tempVehicle, 'float', powerField),
        [topSpeedField] = readHandlingValue(tempVehicle, 'float', topSpeedField),
    }
    if dragField then
        values[dragField] = readHandlingValue(tempVehicle, 'float', dragField)
    end

    DeleteEntity(tempVehicle)
    SetModelAsNoLongerNeeded(modelHash)
    cache[normalizedName] = values
    return values
end

local TuningConfig = ((((PerformanceTuning or {}).Config or {}).advanced or {}).tuning or {})
local TRANSMISSION_POWER_BONUS_PER_UPGRADE = tonumber(TuningConfig.transmissionPowerBonusPerUpgrade) or 0.01

local function ensureDriveForceOffsets(bucket)
    local offsets = bucket.driveForceOffsets
    if type(offsets) ~= 'table' then
        offsets = {}
        bucket.driveForceOffsets = offsets
    end

    return offsets
end

local function getTotalDriveForceOffsets(bucket)
    local offsets = ensureDriveForceOffsets(bucket)
    local total = 0.0

    for _, value in pairs(offsets) do
        total = total + (tonumber(value) or 0.0)
    end

    return total
end

local function setDriveForceOffset(bucket, key, value)
    local offsets = ensureDriveForceOffsets(bucket)
    offsets[key] = tonumber(value) or 0.0
end

local function getTransmissionUpgradeIndexForPack(packId)
    local packs = PerformanceTuning._internals.TRANSMISSION_PACKS or {}
    local selectedPackId = tostring(packId or 'stock')
    local upgradeIndex = 0

    for _, pack in ipairs(packs) do
        if pack.id ~= 'stock' and pack.enabled ~= false then
            upgradeIndex = upgradeIndex + 1
            if pack.id == selectedPackId then
                return upgradeIndex
            end
        end
    end

    return 0
end

local function getTransmissionPowerBonusForPack(packId)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    local configuredBonus = tonumber((((((runtimeConfig.performanceModel or runtimeConfig.performanceBars or {}).power or {}).transmission or {}).powerBonusPerUpgrade)))
    local perUpgradeBonus = configuredBonus
    if perUpgradeBonus == nil then
        perUpgradeBonus = TRANSMISSION_POWER_BONUS_PER_UPGRADE
    end
    if perUpgradeBonus < 0.0 then
        perUpgradeBonus = TRANSMISSION_POWER_BONUS_PER_UPGRADE
    end

    return getTransmissionUpgradeIndexForPack(packId) * perUpgradeBonus
end

local function getEngineUpgradeProgress(selectedPackId)
    local packs = PerformanceTuning._internals.ENGINE_PACKS or {}
    local selectedId = tostring(selectedPackId or '')
    local totalUpgrades = 0
    local selectedLevel = 0

    for index, pack in ipairs(packs) do
        local isEligible = type(pack) == 'table'
            and pack.enabled ~= false
            and not pack.swapModel
        if isEligible then
            if index > 1 then
                totalUpgrades = totalUpgrades + 1
                if pack.id == selectedId then
                    selectedLevel = totalUpgrades
                end
            elseif pack.id == selectedId then
                selectedLevel = 0
            end
        end
    end

    return selectedLevel, totalUpgrades
end

local roundToThreeDecimals = PerformanceTuning.VehicleManager.roundToThreeDecimals

local function applyComposedDriveForce(vehicle, bucket, options)
    options = options or {}
    local internals = PerformanceTuning._internals
    local powerField = internals.POWER_FIELD
    local topSpeedField = internals.TOP_SPEED_FIELD
    if not powerField or powerField == '' then
        return true
    end

    local readHandlingValue = PerformanceTuning.HandlingManager.readHandlingValue
    local writeHandlingValue = PerformanceTuning.HandlingManager.writeHandlingValue
    local rememberOriginalValue = PerformanceTuning.HandlingManager.rememberOriginalValue
    local formatHandlingValue = PerformanceTuning.HandlingManager.formatHandlingValue
    local currentPower = tonumber(readHandlingValue(vehicle, 'float', powerField)) or 0.0
    local currentTopSpeed = (topSpeedField and topSpeedField ~= '') and (tonumber(readHandlingValue(vehicle, 'float', topSpeedField)) or 0.0) or 0.0
    local existingOffsetsTotal = getTotalDriveForceOffsets(bucket)
    local baselinePower = tonumber(options.engineBaselinePower)
    local baselineTopSpeed = tonumber(options.engineBaselineTopSpeed)

    if baselinePower == nil then
        baselinePower = currentPower - existingOffsetsTotal
    end
    if not internals.isFiniteNumber(baselinePower) then
        baselinePower = currentPower
    end
    if baselineTopSpeed == nil then
        if baselinePower > 0.0 and currentPower > 0.0 then
            baselineTopSpeed = currentTopSpeed * (baselinePower / currentPower)
        else
            baselineTopSpeed = currentTopSpeed
        end
    end
    if not internals.isFiniteNumber(baselineTopSpeed) then
        baselineTopSpeed = currentTopSpeed
    end

    setDriveForceOffset(bucket, 'transmission', getTransmissionPowerBonusForPack(bucket.transmissionPack or 'stock'))
    local offsetsTotal = getTotalDriveForceOffsets(bucket)
    local targetPower = baselinePower + offsetsTotal
    local powerChanged = math.abs(targetPower - currentPower) > 0.000001

    rememberOriginalValue(vehicle, powerField, 'float')
    writeHandlingValue(vehicle, 'float', powerField, targetPower)
    if not options.skipLog then
        internals.logInfo(('Composed %s: %s -> %s (engine base: %.4f, total offsets: +%.3f)'):format(
            powerField,
            formatHandlingValue(currentPower, 'float'),
            formatHandlingValue(targetPower, 'float'),
            baselinePower,
            offsetsTotal
        ))
    end

    if topSpeedField and topSpeedField ~= '' then
        local targetTopSpeed = baselineTopSpeed
        if baselinePower > 0.0 and targetPower > 0.0 then
            targetTopSpeed = baselineTopSpeed * (targetPower / baselinePower)
        end
        local topSpeedChanged = math.abs(targetTopSpeed - currentTopSpeed) > 0.000001
        rememberOriginalValue(vehicle, topSpeedField, 'float')
        writeHandlingValue(vehicle, 'float', topSpeedField, targetTopSpeed)
        if not options.skipLog then
            internals.logInfo(('Composed %s: %s -> %s (power ratio: %.4f)'):format(
                topSpeedField,
                formatHandlingValue(currentTopSpeed, 'float'),
                formatHandlingValue(targetTopSpeed, 'float'),
                (baselinePower > 0.0) and (targetPower / baselinePower) or 1.0
            ))
        end

        if (powerChanged or topSpeedChanged) and type(internals.requestDragRebalance) == 'function' then
            internals.requestDragRebalance(vehicle, {
                skipSync = true,
                skipRefresh = true,
            })
        end
    elseif powerChanged and type(internals.requestDragRebalance) == 'function' then
        internals.requestDragRebalance(vehicle, 0, {
            skipSync = true,
            skipRefresh = true,
        })
    end

    return true
end

local function applySimpleFloatTweak(vehicle, fieldName, value, clampFn, bucketField, logLabel, options)
    options = options or {}
    local readHandlingValue = PerformanceTuning.HandlingManager.readHandlingValue
    local writeHandlingValue = PerformanceTuning.HandlingManager.writeHandlingValue
    local rememberOriginalValue = PerformanceTuning.HandlingManager.rememberOriginalValue
    local formatHandlingValue = PerformanceTuning.HandlingManager.formatHandlingValue
    local refreshVehicleAfterHandlingChange = PerformanceTuning._internals.refreshVehicleAfterHandlingChange
    local vehicleManager = PerformanceTuning.VehicleManager
    local bucket = vehicleManager.ensureTuningState(vehicle)
    local currentValue = readHandlingValue(vehicle, 'float', fieldName)
    local resolvedValue = roundToThreeDecimals(clampFn(value), currentValue)

    rememberOriginalValue(vehicle, fieldName, 'float')
    writeHandlingValue(vehicle, 'float', fieldName, resolvedValue)
    if not options.skipLog then
        PerformanceTuning._internals.logInfo(('%s %s: %s -> %s (tweak)'):format(logLabel, fieldName, formatHandlingValue(currentValue, 'float'), formatHandlingValue(resolvedValue, 'float')))
    end

    bucket[bucketField] = resolvedValue
    if not options.skipRefresh then
        refreshVehicleAfterHandlingChange(vehicle)
    end
    vehicleManager.syncVehicleHandlingState(vehicle)
    return true, resolvedValue
end

local function computeUpperLimitNearSuspensionRaise(baseUpperLimit, baseRaise, targetRaise)
    local resolvedBaseUpperLimit = tonumber(baseUpperLimit) or 0.0
    local resolvedBaseRaise = tonumber(baseRaise) or 0.0
    local resolvedTargetRaise = tonumber(targetRaise) or resolvedBaseRaise
    local leftRaise = resolvedBaseRaise - (resolvedBaseUpperLimit * 0.5)
    if resolvedTargetRaise >= resolvedBaseRaise then
        return resolvedBaseUpperLimit
    end

    local span = resolvedBaseRaise - leftRaise
    if span <= 0.000001 then
        return resolvedBaseUpperLimit
    end

    local progress = (resolvedTargetRaise - leftRaise) / span
    if progress < 0.0 then
        progress = 0.0
    end
    if progress > 1.0 then
        progress = 1.0
    end

    return (resolvedBaseUpperLimit * 0.5) + ((resolvedBaseUpperLimit - (resolvedBaseUpperLimit * 0.5)) * progress)
end

local function computeLowerLimitNearSuspensionRaise(baseUpperLimit, baseLowerLimit, baseRaise, targetRaise)
    local resolvedBaseUpperLimit = tonumber(baseUpperLimit) or 0.0
    local resolvedBaseLowerLimit = tonumber(baseLowerLimit) or -0.1
    local resolvedBaseRaise = tonumber(baseRaise) or 0.0
    local resolvedTargetRaise = tonumber(targetRaise) or resolvedBaseRaise
    local sliderMax = math.min(resolvedBaseRaise + 0.2, 0.3)
    local sliderMin = resolvedBaseRaise - (resolvedBaseUpperLimit * 0.5)
    local resolvedLowerLimit = resolvedBaseLowerLimit
    local leftLowerLimit = -0.05
    local rightLowerLimit = resolvedBaseLowerLimit

    if resolvedTargetRaise <= resolvedBaseRaise then
        local leftSpan = resolvedBaseRaise - sliderMin
        local leftProgress = 0.0
        if leftSpan > 0.000001 then
            leftProgress = (resolvedTargetRaise - sliderMin) / leftSpan
        end
        if leftProgress < 0.0 then
            leftProgress = 0.0
        end
        if leftProgress > 1.0 then
            leftProgress = 1.0
        end
        resolvedLowerLimit = leftLowerLimit + ((resolvedBaseLowerLimit - leftLowerLimit) * leftProgress)
    else
        local rightSpan = sliderMax - resolvedBaseRaise
        local rightProgress = 0.0
        if rightSpan > 0.000001 then
            rightProgress = (resolvedTargetRaise - resolvedBaseRaise) / rightSpan
        end
        if rightProgress < 0.0 then
            rightProgress = 0.0
        end
        if rightProgress > 1.0 then
            rightProgress = 1.0
        end
        resolvedLowerLimit = resolvedBaseLowerLimit + ((rightLowerLimit - resolvedBaseLowerLimit) * rightProgress)
    end

    local clampHigh = -0.01
    local clampLow = math.min(resolvedBaseLowerLimit, clampHigh)
    if resolvedLowerLimit > clampHigh then
        resolvedLowerLimit = clampHigh
    end
    if resolvedLowerLimit < clampLow then
        resolvedLowerLimit = clampLow
    end

    return resolvedLowerLimit
end

function TuningPackManager.applySuspensionRaiseLimitAdjustments(vehicle, targetRaise)
    local vehicleManager = PerformanceTuning.VehicleManager
    local handlingManager = PerformanceTuning.HandlingManager
    local bucket = vehicleManager.ensureTuningState(vehicle)
    local resolvedUpperLimit = computeUpperLimitNearSuspensionRaise(
        bucket.baseSuspension and bucket.baseSuspension.fSuspensionUpperLimit,
        bucket.baseSuspension and bucket.baseSuspension.fSuspensionRaise,
        targetRaise
    )
    local resolvedLowerLimit = computeLowerLimitNearSuspensionRaise(
        bucket.baseSuspension and bucket.baseSuspension.fSuspensionUpperLimit,
        bucket.baseSuspension and bucket.baseSuspension.fSuspensionLowerLimit,
        bucket.baseSuspension and bucket.baseSuspension.fSuspensionRaise,
        targetRaise
    )

    handlingManager.rememberOriginalValue(vehicle, 'fSuspensionUpperLimit', 'float')
    handlingManager.writeHandlingValue(vehicle, 'float', 'fSuspensionUpperLimit', resolvedUpperLimit)
    handlingManager.rememberOriginalValue(vehicle, 'fSuspensionLowerLimit', 'float')
    handlingManager.writeHandlingValue(vehicle, 'float', 'fSuspensionLowerLimit', resolvedLowerLimit)
    return resolvedUpperLimit, resolvedLowerLimit
end

function TuningPackManager.applyAntirollForceTweak(vehicle, value, options)
    return applySimpleFloatTweak(vehicle, PerformanceTuning._internals.ANTIROLL_FORCE_FIELD, value, PerformanceTuning._internals.clampAntirollForceValue, 'antirollForce', 'Anti-roll', options)
end

function TuningPackManager.applyBrakeBiasFrontTweak(vehicle, value, options)
    return applySimpleFloatTweak(vehicle, PerformanceTuning._internals.BRAKE_BIAS_FRONT_FIELD, value, PerformanceTuning._internals.clampBrakeBiasFrontValue, 'brakeBiasFront', 'Brakes', options)
end

function TuningPackManager.applyGripBiasFrontTweak(vehicle, value, options)
    return applySimpleFloatTweak(vehicle, PerformanceTuning._internals.TIRE_BIAS_FRONT_FIELD, value, PerformanceTuning._internals.clampGripBiasFrontValue, 'gripBiasFront', 'Tires', options)
end

function TuningPackManager.applyAntirollBiasFrontTweak(vehicle, value, options)
    return applySimpleFloatTweak(vehicle, PerformanceTuning._internals.ANTIROLL_BIAS_FRONT_FIELD, value, PerformanceTuning._internals.clampAntirollBiasFrontValue, 'antirollBiasFront', 'Anti-roll', options)
end

function TuningPackManager.applySuspensionBiasFrontTweak(vehicle, value, options)
    return applySimpleFloatTweak(vehicle, PerformanceTuning._internals.SUSPENSION_BIAS_FRONT_FIELD, value, PerformanceTuning._internals.clampSuspensionBiasFrontValue, 'suspensionBiasFront', 'Suspension', options)
end

function TuningPackManager.applySuspensionRaiseTweak(vehicle, value, options)
    options = options or {}
    local bucket = PerformanceTuning.VehicleManager.ensureTuningState(vehicle)
    local currentValue = PerformanceTuning.HandlingManager.readHandlingValue(vehicle, 'float', 'fSuspensionRaise')
    local resolvedValue = roundToThreeDecimals(PerformanceTuning._internals.clampSuspensionRaiseValue(value), currentValue)
    local baseUpperLimit = bucket.baseSuspension and tonumber(bucket.baseSuspension.fSuspensionUpperLimit) or 0.0
    local baseRaise = bucket.baseSuspension and tonumber(bucket.baseSuspension.fSuspensionRaise) or 0.0
    local raiseLeftLimit = baseRaise - (baseUpperLimit * 0.5)
    local raiseRightLimit = math.min(baseRaise + 0.2, 0.3)
    if resolvedValue < raiseLeftLimit then
        return false, 'Suspension raise cannot go past the precomputed left range.'
    end
    if resolvedValue > raiseRightLimit then
        return false, 'Suspension raise cannot go past the precomputed right range.'
    end

    local targetUpperLimit = computeUpperLimitNearSuspensionRaise(baseUpperLimit, baseRaise, resolvedValue)
    if targetUpperLimit < 0.0 then
        return false, 'Suspension upper limit cannot go below 0.0.'
    end

    PerformanceTuning.HandlingManager.rememberOriginalValue(vehicle, 'fSuspensionRaise', 'float')
    PerformanceTuning.HandlingManager.writeHandlingValue(vehicle, 'float', 'fSuspensionRaise', resolvedValue)
    TuningPackManager.applySuspensionRaiseLimitAdjustments(vehicle, resolvedValue)
    if not options.skipLog then
        PerformanceTuning._internals.logInfo(('Suspension %s: %s -> %s (tweak)'):format('fSuspensionRaise', PerformanceTuning.HandlingManager.formatHandlingValue(currentValue, 'float'), PerformanceTuning.HandlingManager.formatHandlingValue(resolvedValue, 'float')))
    end

    bucket.suspensionRaise = resolvedValue
    if not options.skipRefresh then
        PerformanceTuning._internals.refreshVehicleAfterHandlingChange(vehicle)
    end
    PerformanceTuning.VehicleManager.syncVehicleHandlingState(vehicle)
    return true, resolvedValue
end

function TuningPackManager.applyNitroShotStrengthTweak(vehicle, value, options)
    options = options or {}
    local bucket = PerformanceTuning.VehicleManager.ensureTuningState(vehicle)
    local resolvedValue = roundToThreeDecimals(PerformanceTuning._internals.clampNitroShotStrength(value), 1.0)
    bucket.nitrousShotStrength = resolvedValue
    bucket.nitrousDurationMs = math.max(250, math.floor(PerformanceTuning._internals.NitrousConfig.baseDurationMs / resolvedValue))

    if not options.skipRefresh then
        PerformanceTuning._internals.refreshVehicleAfterHandlingChange(vehicle)
    end
    PerformanceTuning.VehicleManager.syncVehicleHandlingState(vehicle)
    return true, resolvedValue
end

function TuningPackManager.normalizeSteeringLockMode(mode)
    local normalized = tostring(mode or 'stock'):lower()
    if normalized == 'stock' or normalized == 'none' then
        return 'stock'
    end

    if normalized == 'balanced' or normalized == 'balance' then
        normalized = '1.0'
    elseif normalized == 'aggro' or normalized == 'aggressive' then
        normalized = '1.2'
    elseif normalized == 'very_aggro' or normalized == 'very_aggressive' or normalized == 'extreme_aggressive' then
        normalized = '1.4'
    elseif normalized == 'very_smooth' or normalized == 'extreme_smooth' or normalized == 'very_soft' then
        normalized = '0.6'
    elseif normalized == 'sooth' or normalized == 'smooth' then
        normalized = '0.8'
    end

    local numeric = tonumber(normalized)
    if numeric == nil then
        local percentValue = normalized:match('^(%-?%d+%.?%d*)%%$')
        if percentValue ~= nil then
            numeric = tonumber(percentValue) / 100.0
        end
    end

    if numeric == nil then
        return 'stock'
    end

    return ('%.1f'):format(numeric)
end

function TuningPackManager.getSteeringLockModeFactor(mode)
    local normalized = TuningPackManager.normalizeSteeringLockMode(mode)
    if normalized == 'stock' then
        return nil
    end

    local numeric = tonumber(normalized)
    if numeric == nil then
        return nil
    end
    return numeric
end

function TuningPackManager.applySteeringLockModeTweak(vehicle, mode, options)
    options = options or {}
    local internals = PerformanceTuning._internals
    local handlingManager = PerformanceTuning.HandlingManager
    local vehicleManager = PerformanceTuning.VehicleManager
    local steeringLockField = internals.STEERING_LOCK_FIELD
    local bucket = vehicleManager.ensureTuningState(vehicle)
    local normalizedMode = TuningPackManager.normalizeSteeringLockMode(mode)

    bucket.steeringLockMode = normalizedMode

    if normalizedMode == 'stock' and steeringLockField and steeringLockField ~= '' then
        local baseSteeringLock = tonumber(bucket.baseSteeringLock)
        if baseSteeringLock == nil then
            baseSteeringLock = tonumber(handlingManager.readHandlingValue(vehicle, 'float', steeringLockField)) or 0.0
            bucket.baseSteeringLock = baseSteeringLock
        end

        handlingManager.rememberOriginalValue(vehicle, steeringLockField, 'float')
        handlingManager.writeHandlingValue(vehicle, 'float', steeringLockField, baseSteeringLock)
    end

    if not options.skipRefresh then
        internals.refreshVehicleAfterHandlingChange(vehicle)
    end
    vehicleManager.syncVehicleHandlingState(vehicle)
    return true, normalizedMode
end

function TuningPackManager.applySuspensionPack(vehicle, packId, options)
    options = options or {}
    local packs = PerformanceTuning._internals.SUSPENSION_PACKS
    local readHandlingValue = PerformanceTuning.HandlingManager.readHandlingValue
    local writeHandlingValue = PerformanceTuning.HandlingManager.writeHandlingValue
    local rememberOriginalValue = PerformanceTuning.HandlingManager.rememberOriginalValue
    local formatHandlingValue = PerformanceTuning.HandlingManager.formatHandlingValue
    local logInfo = PerformanceTuning._internals.logInfo
    local refreshVehicleAfterHandlingChange = PerformanceTuning._internals.refreshVehicleAfterHandlingChange
    local vehicleManager = PerformanceTuning.VehicleManager
    local normalizeSuspensionPackId = PerformanceTuning._internals.normalizeSuspensionPackId
    local isFiniteNumber = PerformanceTuning._internals.isFiniteNumber
    local bucket = vehicleManager.ensureTuningState(vehicle)
    local selectedPack
    local fieldNames = PerformanceTuning._internals.SUSPENSION_FIELDS

    packId = normalizeSuspensionPackId(packId)
    for _, pack in ipairs(packs) do
        if pack.id == packId then
            selectedPack = pack
            break
        end
    end

    if not selectedPack then
        return false, 'Unknown suspension pack.'
    end

    if selectedPack.enabled == false then
        return false, ('Suspension pack "%s" is not available yet.'):format(selectedPack.label)
    end

    for _, fieldName in ipairs(fieldNames) do
        if fieldName ~= 'fSuspensionRaise' then
            local currentValue = readHandlingValue(vehicle, 'float', fieldName)
            local value = bucket.baseSuspension[fieldName]

            if selectedPack.id ~= 'stock' then
                if type(selectedPack.values) == 'table' and selectedPack.values[fieldName] ~= nil then
                    value = selectedPack.values[fieldName]
                elseif type(selectedPack.minimums) == 'table' and selectedPack.minimums[fieldName] ~= nil then
                    value = math.max(value, selectedPack.minimums[fieldName])
                elseif type(selectedPack.offsets) == 'table' and selectedPack.offsets[fieldName] ~= nil then
                    value = value + selectedPack.offsets[fieldName]
                end

                if fieldName == 'fSuspensionCompDamp' and selectedPack.computeCompDampFromRebound then
                    local reboundValue = value
                    if type(selectedPack.values) == 'table' and selectedPack.values.fSuspensionReboundDamp ~= nil then
                        reboundValue = selectedPack.values.fSuspensionReboundDamp
                    elseif type(selectedPack.minimums) == 'table' and selectedPack.minimums.fSuspensionReboundDamp ~= nil then
                        reboundValue = math.max(bucket.baseSuspension.fSuspensionReboundDamp, selectedPack.minimums.fSuspensionReboundDamp)
                    elseif type(selectedPack.offsets) == 'table' and selectedPack.offsets.fSuspensionReboundDamp ~= nil then
                        reboundValue = bucket.baseSuspension.fSuspensionReboundDamp + selectedPack.offsets.fSuspensionReboundDamp
                    end
                    value = reboundValue
                end

                if type(selectedPack.lowerBounds) == 'table' and selectedPack.lowerBounds[fieldName] ~= nil then
                    value = math.max(value, selectedPack.lowerBounds[fieldName])
                end
            end

            if not isFiniteNumber(value) then
                return false, ('Suspension pack "%s" has an invalid value for %s.'):format(selectedPack.label, fieldName)
            end

            rememberOriginalValue(vehicle, fieldName, 'float')
            writeHandlingValue(vehicle, 'float', fieldName, value)
            if not options.skipLog then
                logInfo(('Suspension %s: %s -> %s (pack: %s)'):format(fieldName, formatHandlingValue(currentValue, 'float'), formatHandlingValue(value, 'float'), selectedPack.label))
            end
        end
    end

    bucket.suspensionPack = selectedPack.id
    if not options.skipRefresh then
        refreshVehicleAfterHandlingChange(vehicle)
    end
    vehicleManager.syncVehicleHandlingState(vehicle)
    return true, selectedPack.label
end

function TuningPackManager.applyTransmissionPack(vehicle, packId, options)
    options = options or {}
    local packs = PerformanceTuning._internals.TRANSMISSION_PACKS
    local readHandlingValue = PerformanceTuning.HandlingManager.readHandlingValue
    local writeHandlingValue = PerformanceTuning.HandlingManager.writeHandlingValue
    local rememberOriginalValue = PerformanceTuning.HandlingManager.rememberOriginalValue
    local formatHandlingValue = PerformanceTuning.HandlingManager.formatHandlingValue
    local logInfo = PerformanceTuning._internals.logInfo
    local refreshVehicleAfterHandlingChange = PerformanceTuning._internals.refreshVehicleAfterHandlingChange
    local vehicleManager = PerformanceTuning.VehicleManager
    local gearField = PerformanceTuning._internals.GEAR_FIELD
    local maxUpgradedGears = 6
    local bucket = vehicleManager.ensureTuningState(vehicle)
    local selectedPack

    for _, pack in ipairs(packs) do
        if pack.id == packId then
            selectedPack = pack
            break
        end
    end

    if not selectedPack then
        return false, 'Unknown transmission pack.'
    end

    if selectedPack.enabled == false then
        return false, ('Transmission pack "%s" is not available yet.'):format(selectedPack.label)
    end

    for _, fieldName in ipairs(PerformanceTuning._internals.TRANSMISSION_FIELDS) do
        local fieldType = fieldName == gearField and 'int' or 'float'
        local currentValue = readHandlingValue(vehicle, fieldType, fieldName)
        local value = bucket.baseTransmission[fieldName]

        if selectedPack.id ~= 'stock' then
            if fieldName == gearField then
                value = value + (selectedPack.gearCountOffset or 0)
                if value > maxUpgradedGears then
                    value = maxUpgradedGears
                end
            else
                value = value + (selectedPack.clutchRateOffset or 0.0)
            end
        end

        rememberOriginalValue(vehicle, fieldName, fieldType)
        writeHandlingValue(vehicle, fieldType, fieldName, value)
        if not options.skipLog then
            logInfo(('Transmission %s: %s -> %s (pack: %s)'):format(fieldName, formatHandlingValue(currentValue, fieldType), formatHandlingValue(value, fieldType), selectedPack.label))
        end
    end

    bucket.transmissionPack = selectedPack.id
    applyComposedDriveForce(vehicle, bucket, {
        skipLog = options.skipLog == true,
    })
    if not options.skipRefresh then
        refreshVehicleAfterHandlingChange(vehicle)
    end
    vehicleManager.syncVehicleHandlingState(vehicle)
    return true, selectedPack.label
end

function TuningPackManager.applyEnginePack(vehicle, packId, options)
    options = options or {}
    local internals = PerformanceTuning._internals
    local refreshVehicleAfterHandlingChange = internals.refreshVehicleAfterHandlingChange
    local vehicleManager = PerformanceTuning.VehicleManager
    local bucket = vehicleManager.ensureTuningState(vehicle)
    local selectedPack
    local previousPackWasSwap = false
    local appliedEngineBasePower = tonumber(bucket.baseEngine[internals.POWER_FIELD]) or 0.0
    local appliedEngineBaseTopSpeed = tonumber(bucket.baseEngine[internals.TOP_SPEED_FIELD]) or 0.0
    local normalizedPackId = TuningPackManager.normalizeEnginePackId(packId)
    local normalizedCurrentEnginePack = TuningPackManager.normalizeEnginePackId(bucket.enginePack)
    local engineCombinedPacks = getEngineCombinedPacks()
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    local configuredBars = runtimeConfig.performanceModel or runtimeConfig.performanceBars or {}
    local configuredPowerBar = configuredBars.power or {}
    local performance = internals.Performance or {}
    local configuredPowerTarget = tonumber(configuredPowerBar.target)
        or tonumber((runtimeConfig.performanceBarFillTargets or {}).power)
        or (((performance.barSegmentCount or 20) / math.max(0.0001, tonumber(performance.powerBarScaleFactor) or 1.0)))
        or 0.60

    for _, pack in ipairs(engineCombinedPacks) do
        local resolvedSwapModel = tostring(pack.swapModel or pack.id or ''):upper()
        local isSwapPack = resolvedSwapModel ~= '' and not isBaseEnginePackId(pack.id) and type(pack.swapModel) == 'string'
        if pack.id == normalizedPackId then
            selectedPack = pack
        end

        if pack.id == normalizedCurrentEnginePack and isSwapPack then
            previousPackWasSwap = true
        end
    end

    if not selectedPack then
        return false, 'Unknown engine pack.'
    end

    if selectedPack.enabled == false then
        return false, ('Engine pack "%s" is not available yet.'):format(selectedPack.label)
    end

    local swapValues = nil
    local targetAudioName = nil
    local selectedSwapModel = tostring(selectedPack.swapModel or selectedPack.id or ''):upper()
    local selectedPackIsBase = isBaseEnginePackId(selectedPack.id)
    local selectedPackIsSwap = selectedSwapModel ~= '' and not selectedPackIsBase and type(selectedPack.swapModel) == 'string'
    if selectedPackIsSwap then
        local resolvedSwapValues, errorMessage = TuningPackManager.resolveEngineSwapValues(selectedSwapModel)
        if not resolvedSwapValues then
            return false, errorMessage
        end
        swapValues = resolvedSwapValues
        targetAudioName = selectedSwapModel
    elseif previousPackWasSwap then
        targetAudioName = internals.getVehicleModelAudioName(vehicle)
    end

    local stockBasePower = tonumber(bucket.baseEngine[internals.POWER_FIELD]) or 0.0
    local stockBaseTopSpeed = tonumber(bucket.baseEngine[internals.TOP_SPEED_FIELD]) or 0.0
    if not selectedPackIsBase then
        if swapValues then
            appliedEngineBasePower = tonumber(swapValues[internals.POWER_FIELD]) or stockBasePower
            local swapTopSpeed = tonumber(swapValues[internals.TOP_SPEED_FIELD])
            if swapTopSpeed ~= nil and swapTopSpeed > 0.0 then
                appliedEngineBaseTopSpeed = swapTopSpeed
            elseif stockBasePower > 0.0 and appliedEngineBasePower > 0.0 then
                appliedEngineBaseTopSpeed = stockBaseTopSpeed * (appliedEngineBasePower / stockBasePower)
            else
                appliedEngineBaseTopSpeed = stockBaseTopSpeed
            end
        else
            local selectedLevel, maxLevel = getEngineUpgradeProgress(selectedPack.id)
            local powerTarget = configuredPowerTarget
            if powerTarget <= 0.0 then
                powerTarget = 0.60
            end
            if selectedLevel > 0 and maxLevel > 0 and stockBasePower > 0.0 then
                local progress = selectedLevel / maxLevel
                appliedEngineBasePower = stockBasePower + (powerTarget * progress)
            else
                appliedEngineBasePower = stockBasePower
            end
            if stockBasePower > 0.0 and appliedEngineBasePower > 0.0 then
                appliedEngineBaseTopSpeed = stockBaseTopSpeed * (appliedEngineBasePower / stockBasePower)
            else
                appliedEngineBaseTopSpeed = stockBaseTopSpeed
            end
        end
    end

    if targetAudioName then
        TuningPackManager.applyEngineAudioProfile(vehicle, targetAudioName)
    end

    if not options.skipLog then
        internals.logInfo(('Engine baseline composed (pack: %s): power=%.4f, topSpeed=%.4f'):format(
            selectedPack.label,
            tonumber(appliedEngineBasePower) or 0.0,
            tonumber(appliedEngineBaseTopSpeed) or 0.0
        ))
    end

    bucket.enginePack = TuningPackManager.normalizeEnginePackId(selectedPack.id)
    applyComposedDriveForce(vehicle, bucket, {
        skipLog = options.skipLog == true,
        engineBaselinePower = appliedEngineBasePower,
        engineBaselineTopSpeed = appliedEngineBaseTopSpeed,
    })
    if not options.skipRefresh then
        refreshVehicleAfterHandlingChange(vehicle)
    end
    vehicleManager.syncVehicleHandlingState(vehicle)
    return true, selectedPack.label
end

function TuningPackManager.applyTireCompoundPack(vehicle, packId, options)
    options = options or {}
    local internals = PerformanceTuning._internals
    local readHandlingValue = PerformanceTuning.HandlingManager.readHandlingValue
    local writeHandlingValue = PerformanceTuning.HandlingManager.writeHandlingValue
    local rememberOriginalValue = PerformanceTuning.HandlingManager.rememberOriginalValue
    local formatHandlingValue = PerformanceTuning.HandlingManager.formatHandlingValue
    local isFiniteNumber = internals.isFiniteNumber
    local refreshVehicleAfterHandlingChange = internals.refreshVehicleAfterHandlingChange
    local vehicleManager = PerformanceTuning.VehicleManager
    local bucket = vehicleManager.ensureTuningState(vehicle)
    local selectedPack
    local normalizedCategory = TuningPackManager.normalizeTireCompoundCategory(bucket.tireCompoundCategory)
    local normalizedQuality = TuningPackManager.normalizeTireCompoundQuality(bucket.tireCompoundQuality)

    for _, pack in ipairs(internals.TIRE_COMPOUND_PACKS) do
        if pack.id == packId then
            selectedPack = pack
            break
        end
    end

    if not selectedPack then
        return false, 'Unknown tire compound pack.'
    end

    if selectedPack.enabled == false then
        return false, ('Tire compound pack "%s" is not available yet.'):format(selectedPack.label)
    end

    local effectiveCategory = normalizedCategory
    local effectiveQuality = normalizedQuality
    if selectedPack.id == 'stock' then
        effectiveCategory = 'stock'
    else
        if effectiveCategory == 'stock' then
            effectiveCategory = 'road'
        end
    end
    local shouldApplyCompoundProfile = effectiveCategory ~= 'stock'
    local qualityProfile = shouldApplyCompoundProfile and getTireCompoundTuningProfile(effectiveCategory, effectiveQuality) or nil
    local qualityLowSpeedLossMultiplier = shouldApplyCompoundProfile and getLowSpeedLossMultiplierForQuality(effectiveQuality) or nil

    local resolvedValues = {}
    local effectiveCompoundLossMultiplier = tonumber(selectedPack.compoundLossMultiplier) or 1.0
    local targetGripValue = nil

    if shouldApplyCompoundProfile then
        targetGripValue = getRelativeGripTargetValue(
            bucket.baseTires[internals.TIRE_MAX_FIELD],
            effectiveCategory,
            effectiveQuality
        )
    end

    for _, fieldName in ipairs(internals.TIRE_FIELDS) do
        local value = bucket.baseTires[fieldName]

        if shouldApplyCompoundProfile then
            if fieldName == internals.TIRE_MAX_FIELD then
                value = targetGripValue or value
            elseif fieldName == 'fTractionCurveMin' then
                value = (targetGripValue and (targetGripValue * 0.9)) or value
            elseif fieldName == 'fTractionLossMult' then
                local tractionLossMultiplier = tonumber(selectedPack.tractionLossMultiplier) or effectiveCompoundLossMultiplier
                if type(qualityProfile) == 'table' and qualityProfile.tractionLossMultiplier ~= nil then
                    tractionLossMultiplier = tonumber(qualityProfile.tractionLossMultiplier) or tractionLossMultiplier
                end
                value = bucket.baseTires[fieldName] * tractionLossMultiplier
                value = math.max(0.0, value)
            elseif fieldName == 'fLowSpeedTractionLossMult' then
                if qualityLowSpeedLossMultiplier ~= nil then
                    value = bucket.baseTires[fieldName] * qualityLowSpeedLossMultiplier
                    value = math.max(0.0, value)
                elseif type(qualityProfile) == 'table' and qualityProfile.lowSpeedLossMultiplier ~= nil then
                    value = bucket.baseTires[fieldName] * (tonumber(qualityProfile.lowSpeedLossMultiplier) or 1.0)
                    value = math.max(0.0, value)
                else
                    value = bucket.baseTires[fieldName] * (tonumber(selectedPack.lowSpeedLossMultiplier) or effectiveCompoundLossMultiplier)
                    value = math.max(0.0, value)
                end
            elseif fieldName == 'fTractionCurveLateral' then
                value = bucket.baseTires[fieldName]
            end
        end

        resolvedValues[fieldName] = value
    end

    bucket.tireCompoundCategory = effectiveCategory
    bucket.tireCompoundQuality = effectiveQuality
    for _, fieldName in ipairs(internals.TIRE_FIELDS) do
        local currentValue = readHandlingValue(vehicle, 'float', fieldName)
        local value = resolvedValues[fieldName]

        if not isFiniteNumber(value) then
            return false, ('Tire compound pack "%s" has an invalid value for %s.'):format(selectedPack.label, fieldName)
        end

        rememberOriginalValue(vehicle, fieldName, 'float')
        writeHandlingValue(vehicle, 'float', fieldName, value)
        if not options.skipLog then
            internals.logInfo(('Tires %s: %s -> %s (pack: %s)'):format(fieldName, formatHandlingValue(currentValue, 'float'), formatHandlingValue(value, 'float'), selectedPack.label))
        end
    end

    bucket.tireCompoundPack = selectedPack.id
    if not options.skipRefresh then
        refreshVehicleAfterHandlingChange(vehicle)
    end
    vehicleManager.syncVehicleHandlingState(vehicle)
    return true, selectedPack.label
end

function TuningPackManager.applyTireCompoundCategory(vehicle, categoryId, options)
    options = options or {}
    local vehicleManager = PerformanceTuning.VehicleManager
    local bucket = vehicleManager.ensureTuningState(vehicle)
    bucket.tireCompoundCategory = TuningPackManager.normalizeTireCompoundCategory(categoryId)
    if bucket.tireCompoundQuality == nil then
        bucket.tireCompoundQuality = 'mid_end'
    end

    local packId = 'stock'
    if bucket.tireCompoundCategory ~= 'stock' then
        packId = TuningPackManager.resolveTireCompoundPackId(bucket.tireCompoundCategory, bucket.tireCompoundQuality)
    else
        bucket.tireCompoundPack = 'stock'
    end
    local ok, result = TuningPackManager.applyTireCompoundPack(vehicle, packId, options)
    if not ok then
        return false, result
    end

    return true, TuningPackManager.getTireCompoundCategoryLabel(bucket.tireCompoundCategory)
end

function TuningPackManager.applyTireCompoundQuality(vehicle, qualityId, options)
    options = options or {}
    local vehicleManager = PerformanceTuning.VehicleManager
    local bucket = vehicleManager.ensureTuningState(vehicle)
    bucket.tireCompoundQuality = TuningPackManager.normalizeTireCompoundQuality(qualityId)
    if bucket.tireCompoundCategory == nil then
        bucket.tireCompoundCategory = 'road'
    end

    local packId = 'stock'
    if bucket.tireCompoundCategory ~= 'stock' then
        packId = TuningPackManager.resolveTireCompoundPackId(bucket.tireCompoundCategory, bucket.tireCompoundQuality)
    else
        bucket.tireCompoundPack = 'stock'
    end
    local ok, result = TuningPackManager.applyTireCompoundPack(vehicle, packId, options)
    if not ok then
        return false, result
    end

    return true, TuningPackManager.getTireCompoundQualityLabel(bucket.tireCompoundQuality)
end

function TuningPackManager.applyBrakePack(vehicle, packId, options)
    options = options or {}
    local internals = PerformanceTuning._internals
    local readHandlingValue = PerformanceTuning.HandlingManager.readHandlingValue
    local writeHandlingValue = PerformanceTuning.HandlingManager.writeHandlingValue
    local rememberOriginalValue = PerformanceTuning.HandlingManager.rememberOriginalValue
    local formatHandlingValue = PerformanceTuning.HandlingManager.formatHandlingValue
    local refreshVehicleAfterHandlingChange = internals.refreshVehicleAfterHandlingChange
    local vehicleManager = PerformanceTuning.VehicleManager
    local bucket = vehicleManager.ensureTuningState(vehicle)
    local selectedPack
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    local configuredBars = runtimeConfig.performanceModel or runtimeConfig.performanceBars or {}
    local configuredBrakeBar = configuredBars.brake or {}
    local configuredBrakeTarget = tonumber(configuredBrakeBar.target) or 0.60

    for _, pack in ipairs(internals.BRAKE_PACKS) do
        if pack.id == packId then
            selectedPack = pack
            break
        end
    end

    if not selectedPack then
        return false, 'Unknown brake pack.'
    end

    if selectedPack.enabled == false then
        return false, ('Brake pack "%s" is not available yet.'):format(selectedPack.label)
    end

    local currentValue = readHandlingValue(vehicle, 'float', internals.BRAKE_FORCE_FIELD)
    local value = bucket.baseBrakes[internals.BRAKE_FORCE_FIELD]
    local selectedPackIsBase = isBaseBrakePackId(selectedPack.id)

    if not selectedPackIsBase then
        local baseBrakeForce = tonumber(bucket.baseBrakes[internals.BRAKE_FORCE_FIELD]) or 0.0
        local upgradeIndex, upgradeCount = getBrakeUpgradeProgress(selectedPack.id)

        if upgradeIndex > 0 and upgradeCount > 0 then
            local progress = upgradeIndex / upgradeCount
            local targetBrakeForce = baseBrakeForce + math.max(0.0, configuredBrakeTarget)
            value = baseBrakeForce + ((targetBrakeForce - baseBrakeForce) * progress)
        end
    end

    rememberOriginalValue(vehicle, internals.BRAKE_FORCE_FIELD, 'float')
    writeHandlingValue(vehicle, 'float', internals.BRAKE_FORCE_FIELD, value)
    if not options.skipLog then
        internals.logInfo(('Brakes %s: %s -> %s (pack: %s)'):format(internals.BRAKE_FORCE_FIELD, formatHandlingValue(currentValue, 'float'), formatHandlingValue(value, 'float'), selectedPack.label))
    end

    bucket.brakePack = selectedPack.id
    if not options.skipRefresh then
        refreshVehicleAfterHandlingChange(vehicle)
    end
    vehicleManager.syncVehicleHandlingState(vehicle)
    return true, selectedPack.label
end

function TuningPackManager.applyNitrousPack(vehicle, packId, options)
    options = options or {}
    local internals = PerformanceTuning._internals
    local vehicleManager = PerformanceTuning.VehicleManager
    local bucket = vehicleManager.ensureTuningState(vehicle)
    local selectedPack

    for _, pack in ipairs(internals.NITROUS_PACKS) do
        if pack.id == packId then
            selectedPack = pack
            break
        end
    end

    if not selectedPack then
        return false, 'Unknown nitrous level.'
    end

    if selectedPack.enabled == false then
        return false, ('Nitrous level "%s" is not available yet.'):format(selectedPack.label)
    end

    bucket.nitrousLevel = selectedPack.id
    local selectedMultiplier = tonumber(selectedPack.powerMultiplier) or 0.0
    if selectedMultiplier <= 0.0 then
        bucket.nitrousAvailableCharge = 0.0
        bucket.nitrousActiveUntil = 0
        bucket.nitrousDurationMs = internals.NitrousConfig.baseDurationMs
        bucket.nitrousAvailableNotified = true
        internals.clearCustomPhysicsNitrousShot(vehicle)
    else
        if options.preserveCharge then
            bucket.nitrousAvailableCharge = math.min(1.0, math.max(0.0, tonumber(bucket.nitrousAvailableCharge) or 1.0))
            bucket.nitrousAvailableNotified = bucket.nitrousAvailableCharge >= 1.0
        else
            bucket.nitrousAvailableCharge = 1.0
            bucket.nitrousAvailableNotified = true
        end
        if not options.preserveCharge then
            bucket.nitrousActiveUntil = 0
        end
        bucket.nitrousDurationMs = math.max(250, math.floor(internals.NitrousConfig.baseDurationMs / (bucket.nitrousShotStrength or 1.0)))
    end

    if not options.skipRefresh then
        internals.refreshVehicleAfterHandlingChange(vehicle)
    end
    vehicleManager.syncVehicleHandlingState(vehicle)
    return true, selectedPack.label
end

TuningPackManager.applyNitroPack = TuningPackManager.applyNitrousPack

function TuningPackManager.applySynchronizedTuneState(vehicle, state, options)
    options = options or {}
    local internals = PerformanceTuning._internals

    if not PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) then
        return false
    end

    local bucket = PerformanceTuning.VehicleManager.ensureTuningState(vehicle)
    bucket.enginePack = TuningPackManager.normalizeEnginePackId(state.enginePack or getBaseEnginePackId())
    bucket.transmissionPack = state.transmissionPack or 'stock'
    bucket.suspensionPack = internals.normalizeSuspensionPackId(state.suspensionPack)
    bucket.tireCompoundCategory = TuningPackManager.normalizeTireCompoundCategory(state.tireCompoundCategory)
    bucket.tireCompoundQuality = TuningPackManager.normalizeTireCompoundQuality(state.tireCompoundQuality)
    if type(state.tireCompoundPack) == 'string' and state.tireCompoundPack ~= '' then
        bucket.tireCompoundPack = state.tireCompoundPack
        if bucket.tireCompoundPack == 'stock' then
            bucket.tireCompoundCategory = 'stock'
        else
            if bucket.tireCompoundCategory == 'stock' then
                bucket.tireCompoundCategory = 'road'
            end
        end
    else
        bucket.tireCompoundPack = TuningPackManager.resolveTireCompoundPackId(bucket.tireCompoundCategory, bucket.tireCompoundQuality)
    end
    bucket.brakePack = state.brakePack or getBaseBrakePackId()
    bucket.nitrousLevel = state.nitrousLevel or 'stock'
    bucket.steeringLockMode = TuningPackManager.normalizeSteeringLockMode(state.steeringLockMode)
    bucket.revLimiterEnabled = state.revLimiterEnabled == true
    bucket.nitrousDurationMs = math.max(250, math.floor(tonumber(state.nitrousDurationMs) or bucket.nitrousDurationMs or internals.NitrousConfig.baseDurationMs))
    bucket.nitrousShotStrength = internals.clampNitroShotStrength(state.nitrousShotStrength or bucket.nitrousShotStrength or 1.0)
    bucket.antirollForce = internals.clampAntirollForceValue(state.antirollForce or bucket.baseAntiroll[internals.ANTIROLL_FORCE_FIELD] or 0.0)
    bucket.brakeBiasFront = internals.clampBrakeBiasFrontValue(state.brakeBiasFront or bucket.baseBrakes[internals.BRAKE_BIAS_FRONT_FIELD] or 0.5)
    bucket.gripBiasFront = internals.clampGripBiasFrontValue(state.gripBiasFront or bucket.baseTires[internals.TIRE_BIAS_FRONT_FIELD] or 0.5)
    bucket.antirollBiasFront = internals.clampAntirollBiasFrontValue(state.antirollBiasFront or bucket.baseAntiroll[internals.ANTIROLL_BIAS_FRONT_FIELD] or 0.5)
    bucket.suspensionRaise = internals.clampSuspensionRaiseValue(state.suspensionRaise or bucket.baseSuspension.fSuspensionRaise or 0.0)
    bucket.suspensionBiasFront = internals.clampSuspensionBiasFrontValue(state.suspensionBiasFront or bucket.baseSuspension[internals.SUSPENSION_BIAS_FRONT_FIELD] or 0.5)

    local sharedOptions = {
        skipRefresh = true,
        skipLog = options.skipLog == true,
        preserveCharge = true,
    }

    if not select(1, TuningPackManager.applyEnginePack(vehicle, bucket.enginePack, sharedOptions)) then return false end
    if not select(1, TuningPackManager.applyTransmissionPack(vehicle, bucket.transmissionPack, sharedOptions)) then return false end
    if not select(1, TuningPackManager.applySuspensionPack(vehicle, bucket.suspensionPack, sharedOptions)) then return false end
    if not select(1, TuningPackManager.applyTireCompoundPack(vehicle, bucket.tireCompoundPack, sharedOptions)) then return false end
    if not select(1, TuningPackManager.applyBrakePack(vehicle, bucket.brakePack, sharedOptions)) then return false end
    if not select(1, TuningPackManager.applyNitrousPack(vehicle, bucket.nitrousLevel or 'stock', sharedOptions)) then return false end
    if not select(1, TuningPackManager.applySteeringLockModeTweak(vehicle, bucket.steeringLockMode or 'stock', sharedOptions)) then return false end
    if not select(1, TuningPackManager.applyNitroShotStrengthTweak(vehicle, bucket.nitrousShotStrength or 1.0, sharedOptions)) then return false end
    if not select(1, TuningPackManager.applyAntirollForceTweak(vehicle, bucket.antirollForce, sharedOptions)) then return false end
    if not select(1, TuningPackManager.applyBrakeBiasFrontTweak(vehicle, bucket.brakeBiasFront, sharedOptions)) then return false end
    if not select(1, TuningPackManager.applyGripBiasFrontTweak(vehicle, bucket.gripBiasFront, sharedOptions)) then return false end
    if not select(1, TuningPackManager.applyAntirollBiasFrontTweak(vehicle, bucket.antirollBiasFront, sharedOptions)) then return false end
    if not select(1, TuningPackManager.applySuspensionRaiseTweak(vehicle, bucket.suspensionRaise, sharedOptions)) then return false end
    if not select(1, TuningPackManager.applySuspensionBiasFrontTweak(vehicle, bucket.suspensionBiasFront, sharedOptions)) then return false end

    internals.refreshVehicleAfterHandlingChange(vehicle)
    PerformanceTuning.VehicleManager.setLastAppliedTuneState(vehicle, PerformanceTuning.VehicleManager.serializeTuneState(bucket))
    return true
end

function TuningPackManager.applyTunePackForContext(vehicle, context, packId)
    if context == 'engine' then return TuningPackManager.applyEnginePack(vehicle, packId or getBaseEnginePackId()) end
    if context == 'transmission' then return TuningPackManager.applyTransmissionPack(vehicle, packId or 'stock') end
    if context == 'suspension' then return TuningPackManager.applySuspensionPack(vehicle, packId or 'stock') end
    if context == 'tires' then return TuningPackManager.applyTireCompoundPack(vehicle, packId or 'stock') end
    if context == 'tireCompoundCategory' then return TuningPackManager.applyTireCompoundCategory(vehicle, packId or 'stock') end
    if context == 'tireCompoundQuality' then return TuningPackManager.applyTireCompoundQuality(vehicle, packId or 'mid_end') end
    if context == 'brakes' then return TuningPackManager.applyBrakePack(vehicle, packId or getBaseBrakePackId()) end
    if context == 'nitrous' or context == 'nitro' then return TuningPackManager.applyNitrousPack(vehicle, packId or 'stock') end
    return false, 'Unsupported tuning context.'
end
