---@meta
---@diagnostic disable: duplicate-set-field, undefined-doc-name

---@alias Entity integer
---@alias Ped integer
---@alias Player integer
---@alias Vehicle integer
---@alias Object integer
---@alias Blip integer
---@alias Hash integer
---@alias ShapeTestHandle integer

---@class vector2
---@field x number
---@field y number

---@class vector3
---@field x number
---@field y number
---@field z number

---@class vector4
---@field x number
---@field y number
---@field z number
---@field w number

---@param x number
---@param y number
---@return vector2
function vector2(x, y) end

---@param x number
---@param y number
---@param z number
---@return vector3
function vector3(x, y, z) end

---@param x number
---@param y number
---@param z number
---@param w number
---@return vector4
function vector4(x, y, z, w) end

---@class CitizenLib
Citizen = Citizen or {}

---@param handler fun()
function Citizen.CreateThread(handler) end

---@param timeout integer
---@param handler fun()
function Citizen.SetTimeout(timeout, handler) end

---@param timeout integer
function Citizen.Wait(timeout) end

---@param timeoutId integer
function Citizen.ClearTimeout(timeoutId) end

---@param handler fun()
function CreateThread(handler) end

---@param timeout integer
---@param handler fun()
function SetTimeout(timeout, handler) end

---@param timeout integer
function Wait(timeout) end

---@param timeoutId integer
function ClearTimeout(timeoutId) end

---@param eventName string
---@param callback fun(...): any
---@return integer handlerId
function AddEventHandler(eventName, callback) end

---@overload fun(eventName: string)
---@param eventName string
---@param callback? fun(...): any
function RegisterNetEvent(eventName, callback) end

---@param eventName string
---@param ... any
function TriggerEvent(eventName, ...) end

---@param eventName string
---@param ... any
function TriggerServerEvent(eventName, ...) end

---@param eventName string
---@param playerId integer
---@param ... any
function TriggerClientEvent(eventName, playerId, ...) end

---@param commandName string
---@param handler fun(source: integer, args: string[], rawCommand: string)
---@param restricted? boolean
function RegisterCommand(commandName, handler, restricted) end

---@param commandName string
---@param description string
---@param defaultMapper string
---@param defaultParameter string
function RegisterKeyMapping(commandName, description, defaultMapper, defaultParameter) end

---@param callbackType string
---@param callback fun(data: table, cb: fun(response?: any))
function RegisterNUICallback(callbackType, callback) end

---@param exportName string
---@param callback fun(...): any
function exports(exportName, callback) end

---@return string
function GetCurrentResourceName() end

---@return string|nil
function GetInvokingResource() end

---@param resourceName string
---@param key string
---@param index integer
---@return string|nil
function GetResourceMetadata(resourceName, key, index) end

---@param resourceName string
---@return string|nil
function GetResourcePath(resourceName) end

---@param resourceName string
---@param fileName string
---@return string|nil
function LoadResourceFile(resourceName, fileName) end

---@param resourceName string
---@param fileName string
---@param data string
---@param dataLength integer
---@return boolean
function SaveResourceFile(resourceName, fileName, data, dataLength) end

---@param url string
---@param callback fun(statusCode: integer, body: string, headers?: table<string, string>, errorData?: any)
---@param method? string
---@param data? string
---@param headers? table<string, string>
---@param options? table
function PerformHttpRequest(url, callback, method, data, headers, options) end

---@return Player
function PlayerId() end

---@return Ped
function PlayerPedId() end

---@param player Player
---@return integer
function GetPlayerServerId(player) end

---@param serverId integer
---@return Player
function GetPlayerFromServerId(serverId) end

---@param player Player
---@return Ped
function GetPlayerPed(player) end

---@return Player[]
function GetPlayers() end

---@param player Player
---@return string
function GetPlayerName(player) end

---@return integer
function GetGameTimer() end

---@return number
function GetFrameTime() end

---@param entity Entity
---@param alive? boolean
---@return vector3
function GetEntityCoords(entity, alive) end

---@param entity Entity
---@return vector3
function GetEntityVelocity(entity) end

---@param entity Entity
---@return vector3
function GetEntityForwardVector(entity) end

---@param entity Entity
---@return number
function GetEntityHeading(entity) end

---@param entity Entity
---@return number
function GetEntitySpeed(entity) end

---@param entity Entity
---@return boolean
function DoesEntityExist(entity) end

---@param vehicle Vehicle
---@param seatIndex integer
---@param isTaskRunning? boolean
---@return Ped
function GetPedInVehicleSeat(vehicle, seatIndex, isTaskRunning) end

---@param ped Ped
---@param lastVehicle boolean
---@return Vehicle
function GetVehiclePedIsIn(ped, lastVehicle) end

---@param vehicle Vehicle
---@return boolean
function IsVehicleOnAllWheels(vehicle) end

---@param entity Entity
---@param keepTasks? boolean
function ClearPedTasks(entity, keepTasks) end

---@param entity Entity
---@param x number
---@param y number
---@param z number
---@param xAxis? boolean
---@param yAxis? boolean
---@param zAxis? boolean
---@param clearArea? boolean
function SetEntityCoordsNoOffset(entity, x, y, z, xAxis, yAxis, zAxis, clearArea) end

---@param entity Entity
---@param heading number
function SetEntityHeading(entity, heading) end

---@param entity Entity
---@param x number
---@param y number
---@param z number
function SetEntityVelocity(entity, x, y, z) end

---@param entity Entity
---@param toggle boolean
function FreezeEntityPosition(entity, toggle) end

---@param entity Entity
function SetEntityAsNoLongerNeeded(entity) end

---@param entity Entity
---@param otherEntity Entity
---@param thisFrameOnly boolean
function SetEntityNoCollisionEntity(entity, otherEntity, thisFrameOnly) end

---@param entity Entity
---@param lodDistance integer
function SetEntityLodDist(entity, lodDistance) end

---@param entity Entity
---@param pitch number
---@param roll number
---@param yaw number
---@param rotationOrder integer
---@param deadCheck boolean
function SetEntityRotation(entity, pitch, roll, yaw, rotationOrder, deadCheck) end

---@param vehicle Vehicle
---@param multiplier number
function SetVehicleEnginePowerMultiplier(vehicle, multiplier) end

---@param vehicle Vehicle
---@param speed number
function SetVehicleForwardSpeed(vehicle, speed) end

---@param vehicle Vehicle
---@param toggle boolean
function SetVehicleHandbrake(vehicle, toggle) end

---@param vehicle Vehicle
---@param toggle boolean
function SetVehicleUndriveable(vehicle, toggle) end

---@param vehicle Vehicle
---@param toggle boolean
function SetVehicleBrakeLights(vehicle, toggle) end

---@param vehicle Vehicle
---@param toggle boolean
---@param instantly? boolean
---@param disableAutoStart? boolean
function SetVehicleEngineOn(vehicle, toggle, instantly, disableAutoStart) end

---@param vehicle Vehicle
---@return boolean
function SetVehicleOnGroundProperly(vehicle) end

---@param model string|Hash
---@return Hash
function GetHashKey(model) end

---@param model Hash
---@return boolean
function IsModelInCdimage(model) end

---@param model Hash
function RequestModel(model) end

---@param model Hash
---@return boolean
function HasModelLoaded(model) end

---@param model Hash
function SetModelAsNoLongerNeeded(model) end

---@param model Hash
---@param x number
---@param y number
---@param z number
---@param network? boolean
---@param missionEntity? boolean
---@param dynamic? boolean
---@return Object
function CreateObjectNoOffset(model, x, y, z, network, missionEntity, dynamic) end

---@param object Object
---@return boolean
function DeleteObject(object) end

---@param object Object
---@return boolean
function PlaceObjectOnGroundProperly(object) end

---@param object Object
---@param duration number
function SetObjectStuntPropDuration(object, duration) end

---@param object Object
---@param speed number
function SetObjectStuntPropSpeedup(object, speed) end

---@param object Object
---@param textureVariant integer
function SetObjectTextureVariant(object, textureVariant) end

---@param x number
---@param y number
---@param z number
---@param radius number
---@param model Hash
---@param p5 boolean
function CreateModelHide(x, y, z, radius, model, p5) end

---@param x number
---@param y number
---@param z number
---@param radius number
---@param model Hash
---@param p5 boolean
function RemoveModelHide(x, y, z, radius, model, p5) end

---@param type integer
---@param posX number
---@param posY number
---@param posZ number
---@param dirX number
---@param dirY number
---@param dirZ number
---@param rotX number
---@param rotY number
---@param rotZ number
---@param scaleX number
---@param scaleY number
---@param scaleZ number
---@param red integer
---@param green integer
---@param blue integer
---@param alpha integer
---@param bobUpAndDown? boolean
---@param faceCamera? boolean
---@param p19? integer
---@param rotate? boolean
---@param textureDict? string
---@param textureName? string
---@param drawOnEnts? boolean
function DrawMarker(type, posX, posY, posZ, dirX, dirY, dirZ, rotX, rotY, rotZ, scaleX, scaleY, scaleZ, red, green, blue, alpha, bobUpAndDown, faceCamera, p19, rotate, textureDict, textureName, drawOnEnts) end

---@param x number
---@param y number
---@param width number
---@param height number
---@param red integer
---@param green integer
---@param blue integer
---@param alpha integer
function DrawRect(x, y, width, height, red, green, blue, alpha) end

---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@param red integer
---@param green integer
---@param blue integer
---@param alpha integer
function DrawLine(x1, y1, z1, x2, y2, z2, red, green, blue, alpha) end

---@param x number
---@param y number
---@param z number
---@return Blip
function AddBlipForCoord(x, y, z) end

---@param blip Blip
function RemoveBlip(blip) end

---@param blip Blip
---@return boolean
function DoesBlipExist(blip) end

---@param blip Blip
---@param sprite integer
function SetBlipSprite(blip, sprite) end

---@param blip Blip
---@param colour integer
function SetBlipColour(blip, colour) end

---@param blip Blip
---@param scale number
function SetBlipScale(blip, scale) end

---@param blip Blip
---@param display integer
function SetBlipDisplay(blip, display) end

---@param blip Blip
---@param toggle boolean
function SetBlipAsShortRange(blip, toggle) end

---@param blip Blip
---@param x number
---@param y number
---@param z number
function SetBlipCoords(blip, x, y, z) end

---@param textType string
function BeginTextCommandDisplayText(textType) end

---@param textType string
function BeginTextCommandPrint(textType) end

---@param textType string
function BeginTextCommandThefeedPost(textType) end

---@param textType string
function BeginTextCommandSetBlipName(textType) end

---@param text string
function AddTextComponentSubstringPlayerName(text) end

---@param x number
---@param y number
function EndTextCommandDisplayText(x, y) end

---@param duration integer
---@param drawImmediately boolean
function EndTextCommandPrint(duration, drawImmediately) end

---@param blink boolean
---@param showInBrief boolean
function EndTextCommandThefeedPostTicker(blink, showInBrief) end

---@param blip Blip
function EndTextCommandSetBlipName(blip) end

---@param font integer
function SetTextFont(font) end

---@param toggle boolean
function SetTextProportional(toggle) end

---@param scaleX number
---@param scaleY number
function SetTextScale(scaleX, scaleY) end

---@param red integer
---@param green integer
---@param blue integer
---@param alpha integer
function SetTextColour(red, green, blue, alpha) end

---@param shadow integer
---@param r integer
---@param g integer
---@param b integer
---@param a integer
function SetTextDropshadow(shadow, r, g, b, a) end

function SetTextDropShadow() end

---@param depth integer
---@param r integer
---@param g integer
---@param b integer
---@param a integer
function SetTextEdge(depth, r, g, b, a) end

function SetTextOutline() end

---@param centered boolean
function SetTextCentre(centered) end

---@param entryKey string
---@param text string
function AddTextEntry(entryKey, text) end

---@param player Player
---@param toggle boolean
function SetPlayerControl(player, toggle) end

---@param hasFocus boolean
---@param hasCursor boolean
function SetNuiFocus(hasFocus, hasCursor) end

---@param message table
function SendNUIMessage(message) end

---@param url string
---@param defaultText string
---@param maxLength integer
function DisplayOnscreenKeyboard(url, defaultText, maxLength) end

---@return integer
function UpdateOnscreenKeyboard() end

---@return string|nil
function GetOnscreenKeyboardResult() end

---@param entity Entity
function SetFocusEntity(entity) end

---@param x number
---@param y number
---@param z number
---@param offsetX? number
---@param offsetY? number
---@param offsetZ? number
function SetFocusPosAndVel(x, y, z, offsetX, offsetY, offsetZ) end

function ClearFocus() end

---@param x number
---@param y number
---@param z number
---@param x2 number
---@param y2 number
---@param z2 number
---@param traceFlags integer
---@param ignoreEntity Entity
---@param options integer
---@return ShapeTestHandle
function StartExpensiveSynchronousShapeTestLosProbe(x, y, z, x2, y2, z2, traceFlags, ignoreEntity, options) end

---@param shapeTest ShapeTestHandle
---@return integer hitState, boolean didHit, vector3 endCoords, vector3 surfaceNormal, Hash materialHash, Entity entityHit
function GetShapeTestResultIncludingMaterial(shapeTest) end

---@param x number
---@param y number
---@param z number
---@param includeWater? boolean
---@return boolean foundGround, number groundZ
function GetGroundZFor_3dCoord(x, y, z, includeWater) end

---@param deltaX number
---@param deltaY number
---@return number
function GetHeadingFromVector_2d(deltaX, deltaY) end

---@param x number
---@param y number
---@param z number
function RequestCollisionAtCoord(x, y, z) end

---@param fadeTime integer
function DoScreenFadeIn(fadeTime) end

---@param fadeTime integer
function DoScreenFadeOut(fadeTime) end

---@return boolean
function IsScreenFadedIn() end

---@return boolean
function IsScreenFadedOut() end

---@param inputGroup integer
---@param control integer
---@return boolean
function IsControlJustPressed(inputGroup, control) end

---@param inputGroup integer
---@param control integer
---@return boolean
function IsDisabledControlJustPressed(inputGroup, control) end

---@param resourceName string
---@param fileName string
function LoadScriptFile(resourceName, fileName) end

---@type integer
source = source

-- FiveM-specific client natives not present in the GTA native DB

---@param vehicle Vehicle
---@return number
function GetVehicleCurrentRpm(vehicle) end

---@param vehicle Vehicle
---@return integer
function GetVehicleCurrentGear(vehicle) end

---@param vehicle Vehicle
---@return integer
function GetVehicleHighGear(vehicle) end

---@param vehicle Vehicle
---@return number
function GetVehicleClutch(vehicle) end

---@param vehicle Vehicle
---@param handlingClass string
---@param fieldName string
---@return number
function GetVehicleHandlingFloat(vehicle, handlingClass, fieldName) end

---@param vehicle Vehicle
---@param handlingClass string
---@param fieldName string
---@return integer
function GetVehicleHandlingInt(vehicle, handlingClass, fieldName) end

---@param vehicle Vehicle
---@param handlingClass string
---@param fieldName string
---@param value number
function SetVehicleHandlingFloat(vehicle, handlingClass, fieldName, value) end

---@param vehicle Vehicle
---@param handlingClass string
---@param fieldName string
---@param value integer
function SetVehicleHandlingInt(vehicle, handlingClass, fieldName, value) end

---@param vehicle Vehicle
---@param wheelIndex integer
---@return integer
function GetVehicleWheelSurfaceMaterial(vehicle, wheelIndex) end

---@param assetName string
function UseParticleFxAssetNextCall(assetName) end
