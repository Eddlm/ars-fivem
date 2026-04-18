-- Applies tuning packs and tweak values to vehicles and synchronized tune state.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.TuningPackManager = PerformanceTuning.TuningPackManager or {}
local TIRE_COMPOUND_CATEGORY_OPTIONS = {
    { id = 'stock', label = 'Stock' },
    { id = 'road', label = 'Road' },
    { id = 'rally', label = 'Mixed' },
    { id = 'offroad', label = 'Offroad' },
}
local TIRE_COMPOUND_QUALITY_OPTIONS = {
    { id = 'low_end', label = 'Low-End' },
    { id = 'mid_end', label = 'Mid-End' },
    { id = 'high_end', label = 'High-End' },
    { id = 'top_end', label = 'Top-End' },
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

local function getEngineSwapPacks()
    local internals = PerformanceTuning._internals or {}
    if type(internals.getConfiguredEngineSwaps) == 'function' then
        local refreshed = internals.getConfiguredEngineSwaps()
        if type(refreshed) == 'table' then
            internals.ENGINE_SWAPS = refreshed
        end
    end
    return internals.ENGINE_SWAPS or {}
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

local function getBaseHandbrakePackId()
    local internals = PerformanceTuning._internals or {}
    local handbrakePacks = internals.HANDBRAKE_PACKS or {}
    local firstPack = handbrakePacks[1]
    local firstPackId = type(firstPack) == 'table' and firstPack.id or nil
    if type(firstPackId) == 'string' and firstPackId ~= '' then
        return firstPackId
    end
    return 'stock'
end

local function isBaseHandbrakePackId(packId)
    return tostring(packId or '') == tostring(getBaseHandbrakePackId())
end

local function getHandbrakeUpgradeProgress(selectedPackId)
    local packs = PerformanceTuning._internals.HANDBRAKE_PACKS or {}
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

function PerformanceTuning.TuningPackManager.normalizeEnginePackId(packId)
    local normalized = tostring(packId or getBaseEnginePackId())
    local basePackId = getBaseEnginePackId()
    if normalized == '' then
        return basePackId
    end

    if normalized:lower() == 'stock' then
        return basePackId
    end

    local packs = PerformanceTuning._internals.ENGINE_PACKS or {}
    for _, pack in ipairs(packs) do
        if type(pack) == 'table' and tostring(pack.id or '') == normalized then
            return pack.id
        end
    end

    return basePackId
end

function PerformanceTuning.TuningPackManager.normalizeEngineSwapPackId(packId)
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
    for _, swap in ipairs(getEngineSwapPacks()) do
        local swapId = tostring((type(swap) == 'table' and swap.id) or ''):upper()
        if swapId ~= '' and swapId == upperModel then
            return swap.id
        end
    end

    return basePackId
end

function PerformanceTuning.TuningPackManager.normalizeSuspensionPackId(packId)
    if packId == 'street' then
        return 'sport'
    end

    return packId or 'stock'
end

function PerformanceTuning.TuningPackManager.buildSuspensionPackOptions(selectedPackId)
    return buildPackOptions(PerformanceTuning._internals.SUSPENSION_PACKS, PerformanceTuning.TuningPackManager.normalizeSuspensionPackId(selectedPackId))
end

function PerformanceTuning.TuningPackManager.getSuspensionPackLabel(packId)
    return getPackLabel(PerformanceTuning._internals.SUSPENSION_PACKS, PerformanceTuning.TuningPackManager.normalizeSuspensionPackId(packId), 'Stock')
end

function PerformanceTuning.TuningPackManager.buildTransmissionPackOptions(selectedPackId)
    return buildPackOptions(PerformanceTuning._internals.TRANSMISSION_PACKS, selectedPackId)
end

function PerformanceTuning.TuningPackManager.getTransmissionPackLabel(packId)
    return getPackLabel(PerformanceTuning._internals.TRANSMISSION_PACKS, packId, 'Stock')
end

function PerformanceTuning.TuningPackManager.buildEnginePackOptions(selectedPackId)
    return buildPackOptions(PerformanceTuning._internals.ENGINE_PACKS, PerformanceTuning.TuningPackManager.normalizeEnginePackId(selectedPackId))
end

function PerformanceTuning.TuningPackManager.getEnginePackLabel(packId)
    return getPackLabel(PerformanceTuning._internals.ENGINE_PACKS, PerformanceTuning.TuningPackManager.normalizeEnginePackId(packId), 'Stock')
end

function PerformanceTuning.TuningPackManager.buildEngineSwapPackOptions(selectedPackId)
    local options = {}
    local basePackId = getBaseEnginePackId()
    local selectedId = PerformanceTuning.TuningPackManager.normalizeEngineSwapPackId(selectedPackId)
    local baseLabel = PerformanceTuning.TuningPackManager.getEnginePackLabel(basePackId)
    options[1] = {
        index = 1,
        id = basePackId,
        label = baseLabel,
        description = 'Keeps this vehicle on its original engine and audio profile.',
        selected = selectedId == basePackId,
        enabled = true,
    }

    local swaps = getEngineSwapPacks()
    for index = 1, #swaps do
        local swap = swaps[index]
        if type(swap) == 'table' then
            options[#options + 1] = {
                index = #options + 1,
                id = swap.id,
                label = swap.label,
                description = swap.description,
                selected = swap.id == selectedId,
                enabled = swap.enabled ~= false,
            }
        end
    end

    return options
end

function PerformanceTuning.TuningPackManager.getEngineSwapPackLabel(packId)
    local selectedId = PerformanceTuning.TuningPackManager.normalizeEngineSwapPackId(packId)
    local basePackId = getBaseEnginePackId()
    if selectedId == basePackId then
        return PerformanceTuning.TuningPackManager.getEnginePackLabel(basePackId)
    end

    return getPackLabel(getEngineSwapPacks(), selectedId, 'Stock')
end

function PerformanceTuning.TuningPackManager.buildTireCompoundPackOptions(selectedPackId, baseTireMax)
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

function PerformanceTuning.TuningPackManager.normalizeTireCompoundCategory(categoryId)
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

function PerformanceTuning.TuningPackManager.normalizeTireCompoundQuality(qualityId)
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

function PerformanceTuning.TuningPackManager.buildTireCompoundCategoryOptions(selectedCategoryId)
    return buildPackOptions(TIRE_COMPOUND_CATEGORY_OPTIONS, PerformanceTuning.TuningPackManager.normalizeTireCompoundCategory(selectedCategoryId))
end

function PerformanceTuning.TuningPackManager.buildTireCompoundQualityOptions(selectedQualityId)
    return buildPackOptions(TIRE_COMPOUND_QUALITY_OPTIONS, PerformanceTuning.TuningPackManager.normalizeTireCompoundQuality(selectedQualityId))
end

function PerformanceTuning.TuningPackManager.getTireCompoundCategoryLabel(categoryId)
    return getPackLabel(TIRE_COMPOUND_CATEGORY_OPTIONS, PerformanceTuning.TuningPackManager.normalizeTireCompoundCategory(categoryId), 'Stock')
end

function PerformanceTuning.TuningPackManager.getTireCompoundQualityLabel(qualityId)
    return getPackLabel(TIRE_COMPOUND_QUALITY_OPTIONS, PerformanceTuning.TuningPackManager.normalizeTireCompoundQuality(qualityId), 'Mid-End')
end

function PerformanceTuning.TuningPackManager.resolveTireCompoundPackId(categoryId, qualityId)
    local normalizedCategory = PerformanceTuning.TuningPackManager.normalizeTireCompoundCategory(categoryId)
    local normalizedQuality = PerformanceTuning.TuningPackManager.normalizeTireCompoundQuality(qualityId)
    if normalizedCategory == 'stock' then
        return 'stock'
    end
    local categoryMap = TIRE_PACK_ID_BY_CATEGORY_AND_QUALITY[normalizedCategory] or TIRE_PACK_ID_BY_CATEGORY_AND_QUALITY.road
    local packId = categoryMap and categoryMap[normalizedQuality] or nil
    return packId or 'stock'
end

local function getTireCompoundTuningProfile(categoryId, qualityId)
    local normalizedCategory = PerformanceTuning.TuningPackManager.normalizeTireCompoundCategory(categoryId)
    local normalizedQuality = PerformanceTuning.TuningPackManager.normalizeTireCompoundQuality(qualityId)
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
    local normalizedQuality = PerformanceTuning.TuningPackManager.normalizeTireCompoundQuality(qualityId)
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

    local normalizedCategory = PerformanceTuning.TuningPackManager.normalizeTireCompoundCategory(categoryId)
    local normalizedQuality = PerformanceTuning.TuningPackManager.normalizeTireCompoundQuality(qualityId)
    local qualityOffset = tonumber(qualityLadder[normalizedQuality]) or 0.0
    local roadQualityTarget = resolvedBaseGrip + qualityOffset
    local compoundOffset = tonumber(compoundRoadOffset[normalizedCategory]) or 0.0
    return math.max(0.1, roadQualityTarget + compoundOffset)
end

function PerformanceTuning.TuningPackManager.inferTireCompoundQualityFromPackId(packId)
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

function PerformanceTuning.TuningPackManager.getTireCompoundPackLabel(packId)
    return getPackLabel(PerformanceTuning._internals.TIRE_COMPOUND_PACKS, packId, 'Stock')
end

function PerformanceTuning.TuningPackManager.buildBrakePackOptions(selectedPackId)
    return buildPackOptions(PerformanceTuning._internals.BRAKE_PACKS, selectedPackId)
end

function PerformanceTuning.TuningPackManager.getBrakePackLabel(packId)
    return getPackLabel(PerformanceTuning._internals.BRAKE_PACKS, packId, 'Stock')
end

function PerformanceTuning.TuningPackManager.buildHandbrakePackOptions(selectedPackId)
    return buildPackOptions(PerformanceTuning._internals.HANDBRAKE_PACKS, selectedPackId)
end

function PerformanceTuning.TuningPackManager.getHandbrakePackLabel(packId)
    return getPackLabel(PerformanceTuning._internals.HANDBRAKE_PACKS, packId, 'Stock')
end

function PerformanceTuning.TuningPackManager.buildNitrousPackOptions(selectedPackId)
    return buildPackOptions(PerformanceTuning._internals.NITROUS_PACKS, selectedPackId)
end

function PerformanceTuning.TuningPackManager.getNitrousPackLabel(packId)
    return getPackLabel(PerformanceTuning._internals.NITROUS_PACKS, packId, 'Stock')
end

PerformanceTuning.TuningPackManager.buildNitroPackOptions = PerformanceTuning.TuningPackManager.buildNitrousPackOptions
PerformanceTuning.TuningPackManager.getNitroPackLabel = PerformanceTuning.TuningPackManager.getNitrousPackLabel

function PerformanceTuning.TuningPackManager.getContextDetails(bucket, context)
    local internals = PerformanceTuning._internals
    if context == 'engine' then
        return {
            key = 'engine',
            title = 'ENGINE',
            fieldName = table.concat(internals.ENGINE_FIELDS, ', '),
            currentValue = PerformanceTuning.TuningPackManager.getEnginePackLabel(bucket.enginePack),
            currentStep = bucket.enginePack,
            optionType = 'pack',
            options = PerformanceTuning.TuningPackManager.buildEnginePackOptions(bucket.enginePack),
        }
    end

    if context == 'engineSwap' then
        return {
            key = 'engineSwap',
            title = 'ENGINE SWAP',
            fieldName = table.concat(internals.ENGINE_FIELDS, ', '),
            currentValue = PerformanceTuning.TuningPackManager.getEngineSwapPackLabel(bucket.engineSwapPack),
            currentStep = bucket.engineSwapPack,
            optionType = 'pack',
            options = PerformanceTuning.TuningPackManager.buildEngineSwapPackOptions(bucket.engineSwapPack),
        }
    end

    if context == 'transmission' then
        return {
            key = 'transmission',
            title = 'TRANSMISSION',
            fieldName = table.concat(internals.TRANSMISSION_FIELDS, ', '),
            currentValue = PerformanceTuning.TuningPackManager.getTransmissionPackLabel(bucket.transmissionPack),
            currentStep = bucket.transmissionPack,
            optionType = 'pack',
            options = PerformanceTuning.TuningPackManager.buildTransmissionPackOptions(bucket.transmissionPack),
        }
    end

    if context == 'suspension' then
        return {
            key = 'suspension',
            title = 'SUSPENSION',
            fieldName = table.concat(internals.SUSPENSION_FIELDS, ', '),
            currentValue = PerformanceTuning.TuningPackManager.getSuspensionPackLabel(bucket.suspensionPack),
            currentStep = bucket.suspensionPack,
            optionType = 'pack',
            options = PerformanceTuning.TuningPackManager.buildSuspensionPackOptions(bucket.suspensionPack),
        }
    end

    if context == 'tires' then
        return {
            key = 'tires',
            title = 'TIRE COMPOUND',
            fieldName = table.concat(internals.TIRE_FIELDS, ', '),
            currentValue = PerformanceTuning.TuningPackManager.getTireCompoundPackLabel(bucket.tireCompoundPack),
            currentStep = bucket.tireCompoundPack,
            optionType = 'pack',
            options = PerformanceTuning.TuningPackManager.buildTireCompoundPackOptions(bucket.tireCompoundPack, bucket.baseTires and bucket.baseTires[internals.TIRE_MAX_FIELD]),
        }
    end

    if context == 'tireCompoundCategory' then
        return {
            key = 'tireCompoundCategory',
            title = 'TIRE COMPOUND CATEGORY',
            fieldName = 'Compound category',
            currentValue = PerformanceTuning.TuningPackManager.getTireCompoundCategoryLabel(bucket.tireCompoundCategory),
            currentStep = PerformanceTuning.TuningPackManager.normalizeTireCompoundCategory(bucket.tireCompoundCategory),
            optionType = 'pack',
            options = PerformanceTuning.TuningPackManager.buildTireCompoundCategoryOptions(bucket.tireCompoundCategory),
        }
    end

    if context == 'tireCompoundQuality' then
        return {
            key = 'tireCompoundQuality',
            title = 'TIRE COMPOUND QUALITY',
            fieldName = 'Compound quality',
            currentValue = PerformanceTuning.TuningPackManager.getTireCompoundQualityLabel(bucket.tireCompoundQuality),
            currentStep = PerformanceTuning.TuningPackManager.normalizeTireCompoundQuality(bucket.tireCompoundQuality),
            optionType = 'pack',
            options = PerformanceTuning.TuningPackManager.buildTireCompoundQualityOptions(bucket.tireCompoundQuality),
        }
    end

    if context == 'brakes' then
        return {
            key = 'brakes',
            title = 'BRAKES',
            fieldName = table.concat(internals.BRAKE_FIELDS, ', '),
            currentValue = PerformanceTuning.TuningPackManager.getBrakePackLabel(bucket.brakePack),
            currentStep = bucket.brakePack,
            optionType = 'pack',
            options = PerformanceTuning.TuningPackManager.buildBrakePackOptions(bucket.brakePack),
        }
    end

    if context == 'handbrakes' then
        return {
            key = 'handbrakes',
            title = 'HANDBRAKES',
            fieldName = tostring(internals.HANDBRAKE_FORCE_FIELD or 'fHandBrakeForce'),
            currentValue = PerformanceTuning.TuningPackManager.getHandbrakePackLabel(bucket.handbrakePack),
            currentStep = bucket.handbrakePack,
            optionType = 'pack',
            options = PerformanceTuning.TuningPackManager.buildHandbrakePackOptions(bucket.handbrakePack),
        }
    end

    if context == 'nitrous' or context == 'nitro' then
        return {
            key = 'nitrous',
            title = 'NITROUS',
            fieldName = 'Nitrous level',
            currentValue = PerformanceTuning.TuningPackManager.getNitrousPackLabel(bucket.nitrousLevel),
            currentStep = bucket.nitrousLevel,
            optionType = 'pack',
            options = PerformanceTuning.TuningPackManager.buildNitrousPackOptions(bucket.nitrousLevel),
        }
    end

    return {
        key = 'engine',
        title = 'ENGINE',
        fieldName = table.concat(internals.ENGINE_FIELDS, ', '),
        currentValue = PerformanceTuning.TuningPackManager.getEnginePackLabel(bucket.enginePack),
        currentStep = bucket.enginePack,
        optionType = 'pack',
        options = PerformanceTuning.TuningPackManager.buildEnginePackOptions(bucket.enginePack),
    }
end

function PerformanceTuning.TuningPackManager.applyEngineAudioProfile(vehicle, audioName)
    if not PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) then
        return false
    end

    if type(audioName) ~= 'string' or audioName == '' then
        return false
    end

    ForceVehicleEngineAudio(vehicle, audioName)
    return true
end

function PerformanceTuning.TuningPackManager.resolveEngineSwapValues(modelName)
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
    local resolvedValue = PerformanceTuning.VehicleManager.roundToThreeDecimals(clampFn(value), currentValue)

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

function PerformanceTuning.TuningPackManager.applySuspensionRaiseLimitAdjustments(vehicle, targetRaise)
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

function PerformanceTuning.TuningPackManager.applyAntirollForceTweak(vehicle, value, options)
    return applySimpleFloatTweak(vehicle, PerformanceTuning._internals.ANTIROLL_FORCE_FIELD, value, PerformanceTuning._internals.clampAntirollForceValue, 'antirollForce', 'Anti-roll', options)
end

function PerformanceTuning.TuningPackManager.applyBrakeBiasFrontTweak(vehicle, value, options)
    return applySimpleFloatTweak(vehicle, PerformanceTuning._internals.BRAKE_BIAS_FRONT_FIELD, value, PerformanceTuning._internals.clampBrakeBiasFrontValue, 'brakeBiasFront', 'Brakes', options)
end

function PerformanceTuning.TuningPackManager.applyGripBiasFrontTweak(vehicle, value, options)
    return applySimpleFloatTweak(vehicle, PerformanceTuning._internals.TIRE_BIAS_FRONT_FIELD, value, PerformanceTuning._internals.clampGripBiasFrontValue, 'gripBiasFront', 'Tires', options)
end

function PerformanceTuning.TuningPackManager.applyAntirollBiasFrontTweak(vehicle, value, options)
    return applySimpleFloatTweak(vehicle, PerformanceTuning._internals.ANTIROLL_BIAS_FRONT_FIELD, value, PerformanceTuning._internals.clampAntirollBiasFrontValue, 'antirollBiasFront', 'Anti-roll', options)
end

function PerformanceTuning.TuningPackManager.applySuspensionBiasFrontTweak(vehicle, value, options)
    return applySimpleFloatTweak(vehicle, PerformanceTuning._internals.SUSPENSION_BIAS_FRONT_FIELD, value, PerformanceTuning._internals.clampSuspensionBiasFrontValue, 'suspensionBiasFront', 'Suspension', options)
end

function PerformanceTuning.TuningPackManager.applyCgOffsetTweak(vehicle, delta, options)
    options = options or {}
    local bucket = PerformanceTuning.VehicleManager.ensureTuningState(vehicle)
    local base = bucket.baseCgOffset or { x = 0.0, y = 0.0, z = 0.0 }
    local resolvedDelta = PerformanceTuning._internals.clampCgOffsetValue(delta)
    SetCgoffset(vehicle, base.x, base.y + resolvedDelta, base.z)  -- 0xD8FA3908D7B86904 SET_CGOFFSET
    bucket.cgOffsetTweak = resolvedDelta
    if not options.skipRefresh then
        PerformanceTuning._internals.refreshVehicleAfterHandlingChange(vehicle)
    end
    if not options.skipSync then
        PerformanceTuning.VehicleManager.syncVehicleTuneState(vehicle)
    end
    return true, resolvedDelta
end

function PerformanceTuning.TuningPackManager.applySuspensionRaiseTweak(vehicle, value, options)
    options = options or {}
    local bucket = PerformanceTuning.VehicleManager.ensureTuningState(vehicle)
    local currentValue = PerformanceTuning.HandlingManager.readHandlingValue(vehicle, 'float', 'fSuspensionRaise')
    local resolvedValue = PerformanceTuning.VehicleManager.roundToThreeDecimals(PerformanceTuning._internals.clampSuspensionRaiseValue(value), currentValue)
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
    PerformanceTuning.TuningPackManager.applySuspensionRaiseLimitAdjustments(vehicle, resolvedValue)
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

function PerformanceTuning.TuningPackManager.applyNitroShotStrengthTweak(vehicle, value, options)
    options = options or {}
    local bucket = PerformanceTuning.VehicleManager.ensureTuningState(vehicle)
    local resolvedValue = PerformanceTuning.VehicleManager.roundToThreeDecimals(PerformanceTuning._internals.clampNitroShotStrength(value), 1.0)
    bucket.nitrousShotStrength = resolvedValue
    bucket.nitrousDurationMs = math.max(250, math.floor(PerformanceTuning._internals.NitrousConfig.baseDurationMs / resolvedValue))

    if not options.skipRefresh then
        PerformanceTuning._internals.refreshVehicleAfterHandlingChange(vehicle)
    end
    PerformanceTuning.VehicleManager.syncVehicleHandlingState(vehicle)
    return true, resolvedValue
end

function PerformanceTuning.TuningPackManager.normalizeSteeringLockMode(mode)
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

function PerformanceTuning.TuningPackManager.getSteeringLockModeFactor(mode)
    local normalized = PerformanceTuning.TuningPackManager.normalizeSteeringLockMode(mode)
    if normalized == 'stock' then
        return nil
    end

    local numeric = tonumber(normalized)
    if numeric == nil then
        return nil
    end
    return numeric
end

function PerformanceTuning.TuningPackManager.applySteeringLockModeTweak(vehicle, mode, options)
    options = options or {}
    local internals = PerformanceTuning._internals
    local handlingManager = PerformanceTuning.HandlingManager
    local vehicleManager = PerformanceTuning.VehicleManager
    local steeringLockField = internals.STEERING_LOCK_FIELD
    local bucket = vehicleManager.ensureTuningState(vehicle)
    local normalizedMode = PerformanceTuning.TuningPackManager.normalizeSteeringLockMode(mode)

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

function PerformanceTuning.TuningPackManager.applySuspensionPack(vehicle, packId, options)
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

function PerformanceTuning.TuningPackManager.applyTransmissionPack(vehicle, packId, options)
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

local function resolveEngineStagePack(packId)
    local normalizedId = PerformanceTuning.TuningPackManager.normalizeEnginePackId(packId)
    local packs = PerformanceTuning._internals.ENGINE_PACKS or {}
    for _, pack in ipairs(packs) do
        if type(pack) == 'table' and pack.id == normalizedId then
            return pack
        end
    end

    return nil
end

local function resolveEngineSwapPack(packId)
    local normalizedId = PerformanceTuning.TuningPackManager.normalizeEngineSwapPackId(packId)
    local basePackId = getBaseEnginePackId()
    if normalizedId == basePackId then
        return nil
    end

    local swaps = getEngineSwapPacks()
    for _, swap in ipairs(swaps) do
        if type(swap) == 'table' and tostring(swap.id or '') == normalizedId then
            return swap
        end
    end

    return nil
end

local function getConfiguredEnginePowerTarget()
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    local configuredBars = runtimeConfig.performanceModel or runtimeConfig.performanceBars or {}
    local configuredPowerBar = configuredBars.power or {}
    local performance = (PerformanceTuning._internals or {}).Performance or {}
    local configuredPowerTarget = tonumber(configuredPowerBar.target)
        or tonumber((runtimeConfig.performanceBarFillTargets or {}).power)
        or (((performance.barSegmentCount or 20) / math.max(0.0001, tonumber(performance.powerBarScaleFactor) or 1.0)))
        or 0.60
    if configuredPowerTarget <= 0.0 then
        configuredPowerTarget = 0.60
    end

    return configuredPowerTarget
end

local function applySelectedEngineComposition(vehicle, bucket, options)
    options = options or {}
    local internals = PerformanceTuning._internals
    local stockBasePower = tonumber(bucket.baseEngine[internals.POWER_FIELD]) or 0.0
    local stockBaseTopSpeed = tonumber(bucket.baseEngine[internals.TOP_SPEED_FIELD]) or 0.0
    local appliedEngineBasePower = stockBasePower
    local appliedEngineBaseTopSpeed = stockBaseTopSpeed
    local selectedStagePack = resolveEngineStagePack(bucket.enginePack)
    local selectedSwapPack = resolveEngineSwapPack(bucket.engineSwapPack)
    local targetAudioName = nil

    if not selectedStagePack then
        return false, 'Unknown engine pack.'
    end

    if selectedStagePack.enabled == false then
        return false, ('Engine pack "%s" is not available yet.'):format(selectedStagePack.label)
    end

    if selectedSwapPack and selectedSwapPack.enabled == false then
        return false, ('Engine swap "%s" is not available yet.'):format(selectedSwapPack.label)
    end

    if selectedSwapPack then
        local selectedSwapModel = tostring(selectedSwapPack.swapModel or selectedSwapPack.id or ''):upper()
        local resolvedSwapValues, errorMessage = PerformanceTuning.TuningPackManager.resolveEngineSwapValues(selectedSwapModel)
        if not resolvedSwapValues then
            return false, errorMessage
        end

        appliedEngineBasePower = tonumber(resolvedSwapValues[internals.POWER_FIELD]) or stockBasePower
        local swapTopSpeed = tonumber(resolvedSwapValues[internals.TOP_SPEED_FIELD])
        if swapTopSpeed ~= nil and swapTopSpeed > 0.0 then
            appliedEngineBaseTopSpeed = swapTopSpeed
        elseif stockBasePower > 0.0 and appliedEngineBasePower > 0.0 then
            appliedEngineBaseTopSpeed = stockBaseTopSpeed * (appliedEngineBasePower / stockBasePower)
        else
            appliedEngineBaseTopSpeed = stockBaseTopSpeed
        end
        targetAudioName = selectedSwapModel
    else
        targetAudioName = internals.getVehicleModelAudioName(vehicle)
    end

    if not isBaseEnginePackId(selectedStagePack.id) then
        local selectedLevel, maxLevel = getEngineUpgradeProgress(selectedStagePack.id)
        local powerTarget = getConfiguredEnginePowerTarget()
        if selectedLevel > 0 and maxLevel > 0 and appliedEngineBasePower > 0.0 then
            local progress = selectedLevel / maxLevel
            local stagePower = appliedEngineBasePower + (powerTarget * progress)
            if appliedEngineBasePower > 0.0 and stagePower > 0.0 then
                appliedEngineBaseTopSpeed = appliedEngineBaseTopSpeed * (stagePower / appliedEngineBasePower)
            end
            appliedEngineBasePower = stagePower
        end
    end

    if targetAudioName then
        PerformanceTuning.TuningPackManager.applyEngineAudioProfile(vehicle, targetAudioName)
    end

    if not options.skipLog then
        local swapLabel = selectedSwapPack and selectedSwapPack.label or PerformanceTuning.TuningPackManager.getEngineSwapPackLabel(getBaseEnginePackId())
        internals.logInfo(('Engine baseline composed (stage: %s, swap: %s): power=%.4f, topSpeed=%.4f'):format(
            selectedStagePack.label,
            swapLabel,
            tonumber(appliedEngineBasePower) or 0.0,
            tonumber(appliedEngineBaseTopSpeed) or 0.0
        ))
    end

    applyComposedDriveForce(vehicle, bucket, {
        skipLog = options.skipLog == true,
        engineBaselinePower = appliedEngineBasePower,
        engineBaselineTopSpeed = appliedEngineBaseTopSpeed,
    })

    return true
end

function PerformanceTuning.TuningPackManager.applyEnginePack(vehicle, packId, options)
    options = options or {}
    local internals = PerformanceTuning._internals
    local refreshVehicleAfterHandlingChange = internals.refreshVehicleAfterHandlingChange
    local vehicleManager = PerformanceTuning.VehicleManager
    local bucket = vehicleManager.ensureTuningState(vehicle)
    bucket.enginePack = PerformanceTuning.TuningPackManager.normalizeEnginePackId(packId)
    bucket.engineSwapPack = PerformanceTuning.TuningPackManager.normalizeEngineSwapPackId(bucket.engineSwapPack)
    local ok, errorMessage = applySelectedEngineComposition(vehicle, bucket, options)
    if not ok then
        return false, errorMessage
    end

    if not options.skipRefresh then
        refreshVehicleAfterHandlingChange(vehicle)
    end
    vehicleManager.syncVehicleHandlingState(vehicle)
    return true, PerformanceTuning.TuningPackManager.getEnginePackLabel(bucket.enginePack)
end

function PerformanceTuning.TuningPackManager.applyEngineSwapPack(vehicle, packId, options)
    options = options or {}
    local refreshVehicleAfterHandlingChange = (PerformanceTuning._internals or {}).refreshVehicleAfterHandlingChange
    local vehicleManager = PerformanceTuning.VehicleManager
    local bucket = vehicleManager.ensureTuningState(vehicle)
    bucket.enginePack = PerformanceTuning.TuningPackManager.normalizeEnginePackId(bucket.enginePack)
    bucket.engineSwapPack = PerformanceTuning.TuningPackManager.normalizeEngineSwapPackId(packId)
    local ok, errorMessage = applySelectedEngineComposition(vehicle, bucket, options)
    if not ok then
        return false, errorMessage
    end

    if not options.skipRefresh then
        refreshVehicleAfterHandlingChange(vehicle)
    end
    vehicleManager.syncVehicleHandlingState(vehicle)
    return true, PerformanceTuning.TuningPackManager.getEngineSwapPackLabel(bucket.engineSwapPack)
end

function PerformanceTuning.TuningPackManager.applyTireCompoundPack(vehicle, packId, options)
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
    local normalizedCategory = PerformanceTuning.TuningPackManager.normalizeTireCompoundCategory(bucket.tireCompoundCategory)
    local normalizedQuality = PerformanceTuning.TuningPackManager.normalizeTireCompoundQuality(bucket.tireCompoundQuality)

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

function PerformanceTuning.TuningPackManager.applyTireCompoundCategory(vehicle, categoryId, options)
    options = options or {}
    local vehicleManager = PerformanceTuning.VehicleManager
    local bucket = vehicleManager.ensureTuningState(vehicle)
    bucket.tireCompoundCategory = PerformanceTuning.TuningPackManager.normalizeTireCompoundCategory(categoryId)
    if bucket.tireCompoundQuality == nil then
        bucket.tireCompoundQuality = 'mid_end'
    end

    local packId = 'stock'
    if bucket.tireCompoundCategory ~= 'stock' then
        packId = PerformanceTuning.TuningPackManager.resolveTireCompoundPackId(bucket.tireCompoundCategory, bucket.tireCompoundQuality)
    else
        bucket.tireCompoundPack = 'stock'
    end
    local ok, result = PerformanceTuning.TuningPackManager.applyTireCompoundPack(vehicle, packId, options)
    if not ok then
        return false, result
    end

    return true, PerformanceTuning.TuningPackManager.getTireCompoundCategoryLabel(bucket.tireCompoundCategory)
end

function PerformanceTuning.TuningPackManager.applyTireCompoundQuality(vehicle, qualityId, options)
    options = options or {}
    local vehicleManager = PerformanceTuning.VehicleManager
    local bucket = vehicleManager.ensureTuningState(vehicle)
    bucket.tireCompoundQuality = PerformanceTuning.TuningPackManager.normalizeTireCompoundQuality(qualityId)
    if bucket.tireCompoundCategory == nil then
        bucket.tireCompoundCategory = 'road'
    end

    local packId = 'stock'
    if bucket.tireCompoundCategory ~= 'stock' then
        packId = PerformanceTuning.TuningPackManager.resolveTireCompoundPackId(bucket.tireCompoundCategory, bucket.tireCompoundQuality)
    else
        bucket.tireCompoundPack = 'stock'
    end
    local ok, result = PerformanceTuning.TuningPackManager.applyTireCompoundPack(vehicle, packId, options)
    if not ok then
        return false, result
    end

    return true, PerformanceTuning.TuningPackManager.getTireCompoundQualityLabel(bucket.tireCompoundQuality)
end

function PerformanceTuning.TuningPackManager.applyBrakePack(vehicle, packId, options)
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

function PerformanceTuning.TuningPackManager.applyHandbrakePack(vehicle, packId, options)
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

    if type(internals.HANDBRAKE_FORCE_FIELD) ~= 'string' or internals.HANDBRAKE_FORCE_FIELD == '' then
        return false, 'Handbrake field is not configured.'
    end

    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    local configuredBars = runtimeConfig.performanceModel or runtimeConfig.performanceBars or {}
    local configuredHandbrakeBar = configuredBars.handbrake or {}
    local fallbackBrakeBar = configuredBars.brake or {}
    local configuredHandbrakeTarget = tonumber(configuredHandbrakeBar.target)
        or tonumber(fallbackBrakeBar.target)
        or 0.60

    for _, pack in ipairs(internals.HANDBRAKE_PACKS or {}) do
        if pack.id == packId then
            selectedPack = pack
            break
        end
    end

    if not selectedPack then
        return false, 'Unknown handbrake pack.'
    end

    if selectedPack.enabled == false then
        return false, ('Handbrake pack "%s" is not available yet.'):format(selectedPack.label)
    end

    local currentValue = readHandlingValue(vehicle, 'float', internals.HANDBRAKE_FORCE_FIELD)
    local baseHandbrakeForce = tonumber(bucket.baseBrakes[internals.HANDBRAKE_FORCE_FIELD]) or tonumber(currentValue) or 0.0
    local value = baseHandbrakeForce
    local selectedPackIsBase = isBaseHandbrakePackId(selectedPack.id)

    if not selectedPackIsBase then
        local upgradeIndex, upgradeCount = getHandbrakeUpgradeProgress(selectedPack.id)

        if upgradeIndex > 0 and upgradeCount > 0 then
            local progress = upgradeIndex / upgradeCount
            local targetHandbrakeForce = baseHandbrakeForce + math.max(0.0, configuredHandbrakeTarget)
            value = baseHandbrakeForce + ((targetHandbrakeForce - baseHandbrakeForce) * progress)
        end
    end

    rememberOriginalValue(vehicle, internals.HANDBRAKE_FORCE_FIELD, 'float')
    writeHandlingValue(vehicle, 'float', internals.HANDBRAKE_FORCE_FIELD, value)
    if not options.skipLog then
        internals.logInfo(('Handbrakes %s: %s -> %s (pack: %s)'):format(internals.HANDBRAKE_FORCE_FIELD, formatHandlingValue(currentValue, 'float'), formatHandlingValue(value, 'float'), selectedPack.label))
    end

    bucket.handbrakePack = selectedPack.id
    if not options.skipRefresh then
        refreshVehicleAfterHandlingChange(vehicle)
    end
    vehicleManager.syncVehicleHandlingState(vehicle)
    return true, selectedPack.label
end

function PerformanceTuning.TuningPackManager.applyNitrousPack(vehicle, packId, options)
    options = options or {}
    local internals = PerformanceTuning._internals
    local vehicleManager = PerformanceTuning.VehicleManager
    local bucket = vehicleManager.ensureTuningState(vehicle)
    local nitrousConfig = internals.NitrousConfig or {}
    local maxNitrousShots = math.max(1, math.floor(tonumber(nitrousConfig.shotsPerRefill) or 3))
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
        bucket.nitrousAvailableCharge = 0
        bucket.nitrousActiveUntil = 0
        bucket.nitrousCooldownUntil = 0
        bucket.nitrousDurationMs = internals.NitrousConfig.baseDurationMs
        bucket.nitrousAvailableNotified = true
        internals.clearCustomPhysicsNitrousShot(vehicle)
    else
        if options.preserveCharge then
            bucket.nitrousAvailableCharge = math.max(0, math.min(maxNitrousShots, math.floor(tonumber(bucket.nitrousAvailableCharge) or maxNitrousShots)))
            bucket.nitrousCooldownUntil = math.max(0, math.floor(tonumber(bucket.nitrousCooldownUntil) or 0))
            bucket.nitrousAvailableNotified = bucket.nitrousAvailableCharge >= maxNitrousShots
        else
            bucket.nitrousAvailableCharge = maxNitrousShots
            bucket.nitrousAvailableNotified = true
            bucket.nitrousActiveUntil = 0
            bucket.nitrousCooldownUntil = 0
        end
        bucket.nitrousDurationMs = math.max(250, math.floor(internals.NitrousConfig.baseDurationMs / (bucket.nitrousShotStrength or 1.0)))
    end

    if not options.skipRefresh then
        internals.refreshVehicleAfterHandlingChange(vehicle)
    end
    vehicleManager.syncVehicleHandlingState(vehicle)
    return true, selectedPack.label
end

PerformanceTuning.TuningPackManager.applyNitroPack = PerformanceTuning.TuningPackManager.applyNitrousPack

function PerformanceTuning.TuningPackManager.applySynchronizedTuneState(vehicle, state, options)
    options = options or {}
    local internals = PerformanceTuning._internals

    if not PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) then
        return false
    end

    local bucket = PerformanceTuning.VehicleManager.ensureTuningState(vehicle)
    bucket.enginePack = PerformanceTuning.TuningPackManager.normalizeEnginePackId(state.enginePack or getBaseEnginePackId())
    bucket.engineSwapPack = PerformanceTuning.TuningPackManager.normalizeEngineSwapPackId(state.engineSwapPack or getBaseEnginePackId())
    bucket.transmissionPack = state.transmissionPack or 'stock'
    bucket.suspensionPack = internals.normalizeSuspensionPackId(state.suspensionPack)
    bucket.tireCompoundCategory = PerformanceTuning.TuningPackManager.normalizeTireCompoundCategory(state.tireCompoundCategory)
    bucket.tireCompoundQuality = PerformanceTuning.TuningPackManager.normalizeTireCompoundQuality(state.tireCompoundQuality)
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
        bucket.tireCompoundPack = PerformanceTuning.TuningPackManager.resolveTireCompoundPackId(bucket.tireCompoundCategory, bucket.tireCompoundQuality)
    end
    bucket.brakePack = state.brakePack or getBaseBrakePackId()
    bucket.handbrakePack = state.handbrakePack or getBaseHandbrakePackId()
    bucket.nitrousLevel = state.nitrousLevel or 'stock'
    bucket.steeringLockMode = PerformanceTuning.TuningPackManager.normalizeSteeringLockMode(state.steeringLockMode)
    bucket.revLimiterEnabled = state.revLimiterEnabled == true
    bucket.nitrousDurationMs = math.max(250, math.floor(tonumber(state.nitrousDurationMs) or bucket.nitrousDurationMs or internals.NitrousConfig.baseDurationMs))
    bucket.nitrousShotStrength = internals.clampNitroShotStrength(state.nitrousShotStrength or bucket.nitrousShotStrength or 1.0)
    bucket.antirollForce = internals.clampAntirollForceValue(state.antirollForce or bucket.baseAntiroll[internals.ANTIROLL_FORCE_FIELD] or 0.0)
    bucket.brakeBiasFront = internals.clampBrakeBiasFrontValue(state.brakeBiasFront or bucket.baseBrakes[internals.BRAKE_BIAS_FRONT_FIELD] or 0.5)
    bucket.gripBiasFront = internals.clampGripBiasFrontValue(state.gripBiasFront or bucket.baseTires[internals.TIRE_BIAS_FRONT_FIELD] or 0.5)
    bucket.antirollBiasFront = internals.clampAntirollBiasFrontValue(state.antirollBiasFront or bucket.baseAntiroll[internals.ANTIROLL_BIAS_FRONT_FIELD] or 0.5)
    bucket.suspensionRaise = internals.clampSuspensionRaiseValue(state.suspensionRaise or bucket.baseSuspension.fSuspensionRaise or 0.0)
    bucket.suspensionBiasFront = internals.clampSuspensionBiasFrontValue(state.suspensionBiasFront or bucket.baseSuspension[internals.SUSPENSION_BIAS_FRONT_FIELD] or 0.5)
    bucket.cgOffsetTweak = internals.clampCgOffsetValue(state.cgOffsetTweak or 0.0)

    local sharedOptions = {
        skipRefresh = true,
        skipLog = options.skipLog == true,
        preserveCharge = true,
    }

    if not select(1, PerformanceTuning.TuningPackManager.applyEnginePack(vehicle, bucket.enginePack, sharedOptions)) then return false end
    if not select(1, PerformanceTuning.TuningPackManager.applyTransmissionPack(vehicle, bucket.transmissionPack, sharedOptions)) then return false end
    if not select(1, PerformanceTuning.TuningPackManager.applySuspensionPack(vehicle, bucket.suspensionPack, sharedOptions)) then return false end
    if not select(1, PerformanceTuning.TuningPackManager.applyTireCompoundPack(vehicle, bucket.tireCompoundPack, sharedOptions)) then return false end
    if not select(1, PerformanceTuning.TuningPackManager.applyBrakePack(vehicle, bucket.brakePack, sharedOptions)) then return false end
    if not select(1, PerformanceTuning.TuningPackManager.applyHandbrakePack(vehicle, bucket.handbrakePack, sharedOptions)) then return false end
    if not select(1, PerformanceTuning.TuningPackManager.applyNitrousPack(vehicle, bucket.nitrousLevel or 'stock', sharedOptions)) then return false end
    if not select(1, PerformanceTuning.TuningPackManager.applySteeringLockModeTweak(vehicle, bucket.steeringLockMode or 'stock', sharedOptions)) then return false end
    if not select(1, PerformanceTuning.TuningPackManager.applyNitroShotStrengthTweak(vehicle, bucket.nitrousShotStrength or 1.0, sharedOptions)) then return false end
    if not select(1, PerformanceTuning.TuningPackManager.applyAntirollForceTweak(vehicle, bucket.antirollForce, sharedOptions)) then return false end
    if not select(1, PerformanceTuning.TuningPackManager.applyBrakeBiasFrontTweak(vehicle, bucket.brakeBiasFront, sharedOptions)) then return false end
    if not select(1, PerformanceTuning.TuningPackManager.applyGripBiasFrontTweak(vehicle, bucket.gripBiasFront, sharedOptions)) then return false end
    if not select(1, PerformanceTuning.TuningPackManager.applyAntirollBiasFrontTweak(vehicle, bucket.antirollBiasFront, sharedOptions)) then return false end
    if not select(1, PerformanceTuning.TuningPackManager.applySuspensionRaiseTweak(vehicle, bucket.suspensionRaise, sharedOptions)) then return false end
    if not select(1, PerformanceTuning.TuningPackManager.applySuspensionBiasFrontTweak(vehicle, bucket.suspensionBiasFront, sharedOptions)) then return false end
    PerformanceTuning.TuningPackManager.applyCgOffsetTweak(vehicle, bucket.cgOffsetTweak or 0.0, sharedOptions)

    internals.refreshVehicleAfterHandlingChange(vehicle)
    PerformanceTuning.VehicleManager.setLastAppliedTuneState(vehicle, PerformanceTuning.VehicleManager.serializeTuneState(bucket))
    return true
end

function PerformanceTuning.TuningPackManager.applyTunePackForContext(vehicle, context, packId)
    if context == 'engine' then return PerformanceTuning.TuningPackManager.applyEnginePack(vehicle, packId or getBaseEnginePackId()) end
    if context == 'engineSwap' then return PerformanceTuning.TuningPackManager.applyEngineSwapPack(vehicle, packId or getBaseEnginePackId()) end
    if context == 'transmission' then return PerformanceTuning.TuningPackManager.applyTransmissionPack(vehicle, packId or 'stock') end
    if context == 'suspension' then return PerformanceTuning.TuningPackManager.applySuspensionPack(vehicle, packId or 'stock') end
    if context == 'tires' then return PerformanceTuning.TuningPackManager.applyTireCompoundPack(vehicle, packId or 'stock') end
    if context == 'tireCompoundCategory' then return PerformanceTuning.TuningPackManager.applyTireCompoundCategory(vehicle, packId or 'stock') end
    if context == 'tireCompoundQuality' then return PerformanceTuning.TuningPackManager.applyTireCompoundQuality(vehicle, packId or 'mid_end') end
    if context == 'brakes' then return PerformanceTuning.TuningPackManager.applyBrakePack(vehicle, packId or getBaseBrakePackId()) end
    if context == 'handbrakes' then return PerformanceTuning.TuningPackManager.applyHandbrakePack(vehicle, packId or getBaseHandbrakePackId()) end
    if context == 'nitrous' or context == 'nitro' then return PerformanceTuning.TuningPackManager.applyNitrousPack(vehicle, packId or 'stock') end
    return false, 'Unsupported tuning context.'
end




