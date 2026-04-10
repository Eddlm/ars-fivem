-- Nitrous shot execution has moved to performancetuning/nitrous.lua.
-- These stubs exist so customphysics/client.lua can still call .reset() and .update() without errors.
CustomPhysicsNitrous = CustomPhysicsNitrous or {}

function CustomPhysicsNitrous.reset() end
function CustomPhysicsNitrous.update() end
function CustomPhysicsNitrous.executeShot() end
function CustomPhysicsNitrous.getDebugSnapshot() return {} end
