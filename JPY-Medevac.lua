env.info("-------------------*-----------------------")
env.info("------------------***----------------------")
env.info("-----------------*****---------------------")
env.info("------------------***----------------------")
env.info("-------------------*-----------------------")
env.info("      Jarpy SeaSAR MIST Edition            ")
env.info("-------------------*-----------------------")
env.info("------------------***----------------------")
env.info("-----------------*****---------------------")
env.info("------------------***----------------------")
env.info("-------------------*-----------------------")

-- Global data table for this script. Mirrors the "medevac" map in the main
-- MEDEVAC script by ciribob.
JPYMedevac = {}
JPYMedevac.addedTo = {} -- Table of player units that have been set up for JPYMedevac.
JPYMedevac.numberOfRescueZones = 6 -- Total number of rescue zones defined in the map.
JPYMedevac.usedRescueZones = {} -- Map of str->bool saying which zones have been used already.
JPYMedevac.mashCallsign = "Cathedral"


-- A debugging function to create text representations of objects.
local function describe(o)
  if type(o) == 'table' then
    local s = '{ '
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '"'..k..'"' end
      s = s .. '['..k..'] = ' .. describe(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end


-- Write a specially formatted line to the log which will be picked up by the
-- external SRS integration system and transmitted over SRS by text-to-speech.
local function srsTransmit(text)
  env.info("SAY=" .. text)
end


local function useRescueZone(zoneName)
  env.info("Marking rescue zone '" .. zoneName .. "' as used.")
  JPYMedevac.usedRescueZones[zoneName] = true
end


local function resetRescueZones(zoneName)
  env.info("Resetting rescue zones.")
  JPYMedevac.usedRescueZones = {}
end


local function rescueZoneUsed(zoneName)
  if JPYMedevac.usedRescueZones[zoneName] == true then
    return true
  else
    return false
  end
end


local function allRescueZonesUsed(zoneName)
  local counter = 0
  for index, value in pairs(JPYMedevac.usedRescueZones) do
    if value == true then
      counter = counter + 1
    end
  end

  if counter == JPYMedevac.numberOfRescueZones then
    env.info("All rescue zones have been used.")
    return true
  else
    env.info("At least one rescue zone has not been used.")
    return false
  end
end


local function getRandomRescueZone()
  env.info(describe(JPYMedevac.usedRescueZones))

  if allRescueZonesUsed() then
    resetRescueZones()
  end

  local chosenZoneName = nil
  while chosenZoneName == nil do
    local zoneNumber = math.random(JPYMedevac.numberOfRescueZones)
    local zoneName = "rescue_" .. zoneNumber

    if rescueZoneUsed(zoneName) == true then
      env.info("Rescue zone '" .. zoneName .. "' is already used...")
    else
      useRescueZone(zoneName)
      env.info("Selected zone '" .. zoneName .. "' as random rescue zone.")
      chosenZoneName = zoneName
    end
  end
  return chosenZoneName
end


local function splitString(string)
  local sep = "%s"
  local tokens = {}
  for str in string.gmatch(string, "([^"..sep.."]+)") do
    table.insert(tokens, str)
  end
  return tokens
end


-- Like mist.getBRString but returns a two element table of bearing, range.
local function getBR(argMap)
  local BRString = mist.getBRString(argMap)
  local tokens = splitString(BRString)
  return {tokens[1], tokens[3]}
end

-- Takes a percentage chance and a function.
-- Based on the chance, randomly returns either the given function or a dummy
-- function that always returns nil.
--
-- Example: maybe(50, print)("Hello half the time!")
--
-- @param chance number:
-- @param func function:
local function maybe(chance, func)
  local emptyFunc = function(...) return nil end

  if chance >= math.random(100) then
    return func
  else
    return emptyFunc
  end
end


-- Clone the given group (name) to a radius around the given point.
local function cloneGroupNearPoint(sourceGroupName, point, radius, innerRadius)
  local newGroup = mist.teleportToPoint(
    {
      groupName = sourceGroupName,
      point = point,
      action = "clone",
      radius = radius,
      innerRadius = innerRadius,
      disperse = true,
      maxDisp = 50,
    }
  )
  return newGroup
end


-- Given an existing group (name), spawn an active copy of that group into a
-- randomly selected rescue zone and set up the new group as a rescue target.
--
-- Also requires the name of the SAR heli unit that is making the request.
--
-- Chooses a random location within the zone for the exact spawn point.
local function cloneGroupForRescue(sourceGroupName, heliUnitName)
  local zone = getRandomRescueZone()
  local rescuePoint = mist.getRandomPointInZone(zone)

  local rescueGroup = cloneGroupNearPoint(
    sourceGroupName,
    rescuePoint
  )
  medevac.injectWoundedGroup(rescueGroup.name)

  -- Possibly spawn a truck-mounted anti-aircraft gun near the LZ.
  local enemyAA = maybe(30, cloneGroupNearPoint)(
    "hostile-aa-truck-template", rescuePoint, 1000, 300
  )

  -- Spawn up to 3 squads of enemy infantry, possibly with an organic RPG
  -- and/or MANPADS in each squad.
  local squadCount = 0
  local rpgCount = 0
  local manpadsCount = 0
  for squadNumber = 1, 3, 1 do
    local squadPoint = mist.getRandPointInCircle(rescuePoint, 1000, 200)
    local squad = maybe(80, cloneGroupNearPoint)(
      "hostile-infantry-template", squadPoint, 0, 0
    )
    if squad ~= nil then
      squadCount = squadCount + 1
    end


    --- FIXME: no spawning in water!!!!!!!!!!!!!


    -- Add an RPG to the infantry squad?
    if squad ~= nil then
      RPG = maybe(30, cloneGroupNearPoint)(
        "hostile-infantry-rpg-template", squadPoint, 10, 3
      )
    end
    if RPG ~= nil then
      rpgCount = rpgCount + 1
    end

    -- How about a MANPADS? (shudder)
    if squad ~= nil then
      MANPADS = maybe(5, cloneGroupNearPoint)(
        "hostile-infantry-manpads-template", squadPoint, 10, 3
      )
    end
    if MANPADS ~= nil then
      manpadsCount = manpadsCount + 1
    end

  end

  -- Inform the calling heli of the situtation over SRS.
  SRSVectorToRescueGroup(rescueGroup.name, heliUnitName)
  if enemyAA ~= nil then
    srsTransmit("Caution: Enemy Zeus truck spotted.")
  end

  if squadCount == 1 then
    srsTransmit("Enemy infantry reported near LZ.")
  elseif squadCount > 1 then
    srsTransmit("Multiple enemy infantry squads at LZ.")
  end

  if rpgCount > 0 then
    srsTransmit("Be advised. RPG sighted.")
  end

  if manpadsCount > 0 then
    srsTransmit("Manpads reported. Exercise extreme caution.")
  end
end


function SRSVectorToRescueGroup(groupName, heliUnitName)
  local heli = medevac.getSARHeli(heliUnitName)
  if heli == nil then
    return
  end

  local group = Group.getByName(groupName)
  local playerPosition = heli:getPosition().p
  local BR = getBR({
    units = medevac.convertGroupToTable(group),
    ref = playerPosition,
    metric = true,
  })

  -- FIXME: use string.format
  srsTransmit(
    heliUnitName .. ", " .. JPYMedevac.mashCallsign .. ". " ..
    -- "Assist " .. groupName .. ". " ..
    " Fly heading, " .. BR[1] .. ". Distance, " .. BR[2] .. " kilometers."
  )
end

-- Request vector to closest rescue group from the controller.
-- Response comes over SRS radio.
function SRSVectorToClosestRescueGroup(heliUnitName)
  local heli = medevac.getSARHeli(heliUnitName)
  if heli == nil then
    return
  end

  local groupName = medevac.getClosestGroupName(heli)
  if groupName == nil then
    -- FIXME: Use string.format()
    srsTransmit(
      heliUnitName .. ", " .. JPYMedevac.mashCallsign .. ". " ..
      "No active operations."
    )
    return
  end

  SRSVectorToRescueGroup(groupName, heliUnitName)
end

-- A modified version of addMedevacMenuItem.
-- This version injects additional radio menu items that are specific to this
-- script, but sets them up so that they appear under the "MEDEVAC" menu
-- group and look just like the ones from the MEDEVAC script itself.
function addJPYMedevacMenuItems()
  -- Reschedule this very function to run itself again later.
  -- Picks up any new players as they join the server.
  timer.scheduleFunction(addJPYMedevacMenuItems, nil, timer.getTime() + 5)

  for _, _unitName in pairs(medevac.medevacunits) do
      local _unit = medevac.getSARHeli(_unitName)

      if _unit ~= nil and JPYMedevac.addedTo[_unitName] == nil then

        -- Add the command for getting a vector to the nearest resuce group
        -- over SRS radio.
        missionCommands.addCommandForGroup(
          medevac.getGroupId(_unit),
          "Vector to nearest rescue", {"MEDEVAC"},
          SRSVectorToClosestRescueGroup, _unitName
        )

        missionCommands.addCommandForGroup(
          medevac.getGroupId(_unit),
          "Call for SAR tasking", {"MEDEVAC"},
          cloneGroupForRescue,
          "rescue-infantry-template", _unitName
        )

        JPYMedevac.addedTo[_unitName] = true
      end
  end
end

timer.scheduleFunction(addJPYMedevacMenuItems, nil, timer.getTime() + 6)


------ Testing

-- local function testCloneGroupForRescue(sourceGroupName)
--   local rescueGroup = mist.teleportToPoint(
--     {
--       groupName = sourceGroupName,
--       point = mist.getRandomPointInZone('rescue_test'),
--       action = "clone"
--     }
--   )
--   -- env.info(describe(rescueGroup))
--   medevac.injectWoundedGroup(rescueGroup.name)
-- end

-- missionCommands.addCommand(
--   "TEST.",
--   nil,
--   testCloneGroupForRescue,
--   "rescue-infantry-template"
--)
