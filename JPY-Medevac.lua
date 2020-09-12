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

JPYMedevac.rescueCallsigns = {
  "Pony",
  "Stubby",
  "Noodles",
  "Duckey",
  "Avalon",
  "Bongo",
  "Hot-Sauce",
  "Cane-Toad",
  "Gumball",
  "Woofer",
}

local function getRandomRescueCallsign()
  local index = math.random(#JPYMedevac.rescueCallsigns)
  local callsign = JPYMedevac.rescueCallsigns[index]
  table.remove(JPYMedevac.rescueCallsigns, index)
  return callsign
end

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

-- Modified version of mist.teleportToPoint that accepts "newGroupName"
-- when cloning a group.
function JPYMedevac.teleportToPoint(vars)
  --log:info(vars)
  local point = vars.point
  local gpName
  if vars.gpName then
    gpName = vars.gpName
  elseif vars.groupName then
    gpName = vars.groupName
  else
    --log:error('Missing field groupName or gpName in variable table')
  end

  local action = vars.action
  local newGroupName = vars.newGroupName

  local disperse = vars.disperse or false
  local maxDisp = vars.maxDisp or 200
  local radius = vars.radius or 0
  local innerRadius = vars.innerRadius

  local route = vars.route
  local dbData = false

  local newGroupData
  if gpName and not vars.groupData then
    if string.lower(action) == 'teleport' or string.lower(action) == 'tele' then
      newGroupData = mist.getCurrentGroupData(gpName)
    elseif string.lower(action) == 'respawn' then
      newGroupData = mist.getGroupData(gpName)
      dbData = true
    elseif string.lower(action) == 'clone' then
      newGroupData = mist.getGroupData(gpName)
      newGroupData.clone = 'order66'
      dbData = true
    else
      action = 'tele'
      newGroupData = mist.getCurrentGroupData(gpName)
    end
  else
    action = 'tele'
    newGroupData = vars.groupData
  end

  --log:info('get Randomized Point')
  local diff = {x = 0, y = 0}
  local newCoord, origCoord
  local validTerrain = {'LAND', 'ROAD', 'SHALLOW_WATER', 'WATER', 'RUNWAY'}
  if string.lower(newGroupData.category) == 'ship' then
    validTerrain = {'SHALLOW_WATER' , 'WATER'}
  elseif string.lower(newGroupData.category) == 'vehicle' then
    validTerrain = {'LAND', 'ROAD'}
  end
  local offsets = {}
  if point and radius >= 0 then
    local valid = false
    for i = 1, 100	do
      newCoord = mist.getRandPointInCircle(point, radius, innerRadius)
      if mist.isTerrainValid(newCoord, validTerrain) then
        origCoord = mist.utils.deepCopy(newCoord)
        diff = {x = (newCoord.x - newGroupData.units[1].x), y = (newCoord.y - newGroupData.units[1].y)}
        valid = true
        break
      end
    end
    if valid == false then
      --log:error('Point supplied in variable table is not a valid coordinate. Valid coords: $1', validTerrain)
      return false
    end
  end

  if not newGroupData.country and mist.DBs.groupsByName[newGroupData.groupName].country then
    newGroupData.country = mist.DBs.groupsByName[newGroupData.groupName].country
  end

  if not newGroupData.category and mist.DBs.groupsByName[newGroupData.groupName].category then
    newGroupData.category = mist.DBs.groupsByName[newGroupData.groupName].category
  end
  --log:info(point)

  for unitNum, unitData in pairs(newGroupData.units) do
    --log:info(unitNum)

    if disperse then
      local unitCoord
      if maxDisp and type(maxDisp) == 'number' and unitNum ~= 1 then
        for i = 1, 100 do
          unitCoord = mist.getRandPointInCircle(origCoord, maxDisp)
          if mist.isTerrainValid(unitCoord, validTerrain) == true then
            --log:warn('Index: $1, Itered: $2. AT: $3', unitNum, i, unitCoord)
            break
          end
        end
      --else
      --newCoord = mist.getRandPointInCircle(zone.point, zone.radius)
      end

      if unitNum == 1 then
        unitCoord = mist.utils.deepCopy(newCoord)
      end

      if unitCoord then
        newGroupData.units[unitNum].x = unitCoord.x
        newGroupData.units[unitNum].y = unitCoord.y
      end
    else -- if not disperse
      newGroupData.units[unitNum].x = unitData.x + diff.x
      newGroupData.units[unitNum].y = unitData.y + diff.y
    end

    if point then
      if (newGroupData.category == 'plane' or newGroupData.category == 'helicopter')	then
        if point.z and point.y > 0 and point.y > land.getHeight({newGroupData.units[unitNum].x, newGroupData.units[unitNum].y}) + 10 then
          newGroupData.units[unitNum].alt = point.y
          --log:info('far enough from ground')
        else
          if newGroupData.category == 'plane' then
            --log:info('setNewAlt')
            newGroupData.units[unitNum].alt = land.getHeight({newGroupData.units[unitNum].x, newGroupData.units[unitNum].y}) + math.random(300, 9000)
          else
            newGroupData.units[unitNum].alt = land.getHeight({newGroupData.units[unitNum].x, newGroupData.units[unitNum].y}) + math.random(200, 3000)
          end
        end
      end
    end
  end

  if newGroupData.start_time then
    newGroupData.startTime = newGroupData.start_time
  end

  if newGroupData.startTime and newGroupData.startTime ~= 0 and dbData == true then
    local timeDif = timer.getAbsTime() - timer.getTime0()
    if timeDif > newGroupData.startTime then
      newGroupData.startTime = 0
    else
      newGroupData.startTime = newGroupData.startTime - timeDif
    end
  end

  if route then
    newGroupData.route = route
  end

  if newGroupName then
    newGroupData.groupName = newGroupName
  end

  --log:info(newGroupData)
  --mist.debug.writeData(mist.utils.serialize,{'teleportToPoint', newGroupData}, 'newGroupData.lua')
  if string.lower(newGroupData.category) == 'static' then
    --log:info(newGroupData)
    return mist.dynAddStatic(newGroupData)
  end
  return mist.dynAdd(newGroupData)
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
local function cloneGroupNearPoint(sourceGroupName, newGroupName, point, radius, innerRadius)
  local newGroup = JPYMedevac.teleportToPoint(
    {
      groupName = sourceGroupName,
      newGroupName = newGroupName,
      point = point,
      action = "clone",
      radius = radius,
      innerRadius = innerRadius,
      disperse = true,
      maxDisp = 10,
    }
  )
  return newGroup
end

local function SRSVectorToGroup(groupName, heliUnitName, preamble)
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
  if preamble == nil then
    preamble = ""
  end

  srsTransmit(
    heliUnitName .. ", " .. JPYMedevac.mashCallsign .. ". " ..
    preamble ..
    " Fly heading, " .. BR[1] .. ". Distance, " .. BR[2] .. " kilometers."
  )
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
    sourceGroupName, getRandomRescueCallsign(),
    rescuePoint
  )
  medevac.injectWoundedGroup(rescueGroup.name)

  local squadCount = 0
  local sawSquadCount = 0
  local rpgSquadCount = 0
  local manpadsSquadCount = 0

  -- Spawn up to 3 squads of enemy riflemen.
  for squadNumber = 1, 3, 1 do
    local squad = maybe(20, cloneGroupNearPoint)(
      "hostile-infantry", nil,
      rescuePoint, 350, 150)
    if squad then
      squadCount = squadCount + 1
    end
  end

  -- Spawn up to 3 squads of enemy infantry with a SAW.
  for squadNumber = 1, 3, 1 do
    local squad = maybe(20, cloneGroupNearPoint)(
      "hostile-infantry-saw", nil,
      rescuePoint, 350, 150)
    if squad then
      sawSquadCount = sawSquadCount + 1
    end
  end

  -- Spawn up to 2 squads of enemy infantry with organic RPG.
  for squadNumber = 1, 2, 1 do
    local rpgSquad = maybe(20, cloneGroupNearPoint)(
      "hostile-infantry-rpg", nil,
      rescuePoint, 350, 150)
    if rpgSquad then
      rpgSquadCount = rpgSquadCount + 1
    end
  end

  -- How about a MANPADS squad? (shudder)
  for squadNumber = 1, 2, 1 do
    local manpadsSquad = maybe(5, cloneGroupNearPoint)(
      "hostile-infantry-manpads", nil,
      rescuePoint, 350, 150)
    if manpadsSquad then
      manpadsSquadCount = manpadsSquadCount + 1
    end
  end

  -- Possibly spawn a truck-mounted anti-aircraft gun.
  local enemyAA = maybe(20, cloneGroupNearPoint)(
    "hostile-aa-truck", nil,
    rescuePoint, 1000, 300
  )

  -- Inform the calling heli of the situtation over SRS.
  SRSVectorToGroup(
    rescueGroup.name, heliUnitName,
    string.format("%s, requests medevac. ", rescueGroup.name))

  if enemyAA ~= nil then
    srsTransmit("Caution: Anti-aircraft truck spotted.")
  end

  if squadCount + sawSquadCount == 1 then
    srsTransmit("Enemy infantry reported.")
  elseif squadCount + sawSquadCount > 1 then
    srsTransmit("Multiple enemy infantry squads in contact.")
  end

  if rpgSquadCount > 0 then
    srsTransmit("Be advised. RPG sighted.")
  end

  if manpadsSquadCount > 0 then
    srsTransmit("Manpads reported. Exercise extreme caution.")
  end
end

-- Request vector to closest rescue group from the controller.
-- Response comes over SRS radio.
local function SRSVectorToClosestRescueGroup(heliUnitName)
  local heli = medevac.getSARHeli(heliUnitName)
  if heli == nil then
    return
  end

  local groupName = medevac.getClosestGroupName(heli)
  if groupName == nil then
    srsTransmit(
      string.format(
        "%s, %s. No active operations.",
        heliUnitName, JPYMedevac.mashCallsign))
    return
  end

  SRSVectorToGroup(
    groupName, heliUnitName,
    string.format("Nearest unit, %s. ", groupName))
end

local function SRSVectorToBlueMash(heliUnitName)
  if medevac.getSARHeli(heliUnitName) == nil then
    return
  end

  SRSVectorToGroup(medevac.bluemash[1], heliUnitName)
end

-- A modified version of addMedevacMenuItem.
-- This version injects additional radio menu items that are specific to this
-- script, but sets them up so that they appear under the "MEDEVAC" menu
-- group and look just like the ones from the MEDEVAC script itself.
local function addJPYMedevacMenuItems()
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
          "Vector to " .. medevac.bluemash[1], {"MEDEVAC"},
          SRSVectorToBlueMash, _unitName
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
