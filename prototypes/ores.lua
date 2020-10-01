local function starts_with(str, start)
    return str:sub(1, #start) == start
end

-- safely get the value of a setting
local function getSettingValue(optionName)
    if settings["startup"] and settings["startup"][optionName] and settings["startup"][optionName].value then
        return settings["startup"][optionName].value
    end
    return false
end

-- get the stack size from Deadlock's Stacking settings or from this mod if the option is enabled
local stackSize
if getSettingValue("kyth-overwrite-deadlock-stack-size") == "disabled" then
    stackSize = tonumber(getSettingValue("deadlock-stack-size"))
else
    stackSize = tonumber(getSettingValue("kyth-overwrite-deadlock-stack-size"))
end

---------------------------------------------------------------------------------------------------

-- check if the stacked version of the item with the given name exists and in case it does not, create it
-- returns true when an item was created or if it already exists, otherwise false
local function createStackedVersion(name)
    local base = data.raw["item"][name] or data.raw["tool"][name]
    if base then
        local item_type = data.raw["item"][name] and "item" or "tool"
        if data.raw[item_type]["deadlock-stack-" .. name] then
            return true
        else
            deadlock.add_stack(name, nil, nil, nil, item_type)
            log("Created stacked version of the item " .. name .. ", because it was missing. It is advised to install a mod that adds support for the mod that this item is from in case you did not already")
            return true
        end
    else
        log("Error in createStackedVersion(): the item " .. name .. " does not exist")
        return false
    end
end

-- create a stacked version of the ResourceEntity with the given oreName
local function createStackedOre(oreName)
    local stackedName = "stacked-" .. oreName
    local ore = table.deepcopy(data.raw["resource"][oreName])

    -- generate a dynamic localized name for the stacked version of the ore
    ore.localised_name = {"entity-name.stacked-ore", {"entity-name." .. oreName}}

    -- replace every result of minable with their stacked version
    if ore.minable.results then
        local tempResults = {}
        for _, result in pairs(ore.minable.results) do
            if result.name then
                if createStackedVersion(result.name) then
                    result.name = "deadlock-stack-" .. result.name
                    table.insert(tempResults, result)
                else
                    log("Error in createStackedOre() for " .. result.name)
                end
            elseif result[1] then
                if createStackedVersion(result[1]) then
                    result[1] = "deadlock-stack-" .. result[1]
                    table.insert(tempResults, result)
                else
                    log("Error in createStackedOre() for " .. result[1] .. " with [1]")
                end
            else
                log("Something went wrong during the replacing of minable.results")
                break -- probably not necessary?
            end
        end
        ore.minable.results = tempResults
    elseif ore.minable.result then
        if createStackedVersion(ore.minable.result) then
            ore.minable.results = {
                {
                    amount_max = ore.minable.count or 1,
                    amount_min = ore.minable.count or 1,
                    name = "deadlock-stack-" .. ore.minable.result,
                    probability = 1,
                    type = "item"
                }
            }
            ore.minable.result = nil
            ore.minable.count = nil
        else
            log("Error in createStackedOre() for " .. result.name)
        end
    end

    ore.name = stackedName

    -- adjust the amount of fluid required for mining (to keep it the same overall)
    if ore.minable.required_fluid and ore.minable.fluid_amount and ore.minable.fluid_amount > 0 then
        ore.minable.fluid_amount = ore.minable.fluid_amount * stackSize
    end
    -- same for mining time
    ore.minable.mining_time = ore.minable.mining_time * stackSize

    -- the ore should never occur naturally
    ore.autoplace = nil

    -- if the ore is infinite, increase the infinite_depletion_amount accordingly
    if ore.infinite then
        ore.infinite_depletion_amount = (ore.infinite_depletion_amount or 1) * stackSize
    end

    -- option in the settings to adjust the graphics of ores
    if getSettingValue("kyth-adjust-stage-counts") and ore.stage_counts then
        for i, stage in ipairs(ore.stage_counts) do
            ore.stage_counts[i] = math.ceil(stage / stackSize)
        end
    end

    return ore
end

-- create a high pressure version of the ResourceEntity with the given fluidName (Support for Pressurized fluids)
local function createCompressedFluidResource(fluidName)
    local compressedName = "high-pressure-" .. fluidName
    local fluidResource = table.deepcopy(data.raw["resource"][fluidName])

    -- generate a dynamic localized name for the stacked version of the ore
    fluidResource.localised_name = {"entity-name.high-pressure-fluid-resource", {"entity-name." .. fluidName}}

    -- replace the mining result with the high pressure version
    if fluidResource.minable.results then
        if fluidResource.minable.results[1].name then
            fluidResource.minable.results[1].name = "high-pressure-" .. fluidResource.minable.results[1].name
        elseif fluidResource.minable.results[1][1] then
            fluidResource.minable.results[1][1] = "high-pressure-" .. fluidResource.minable.results[1][1]
        end
    elseif ore.minable.result then
        if fluidResource.minable.result.name then
            fluidResource.minable.result.name = "high-pressure-" .. fluidResource.minable.result.name
        elseif fluidResource.minable.result[1] then
            fluidResource.minable.result[1] = "high-pressure-" .. fluidResource.minable.result[1]
        end
    end

    fluidResource.name = compressedName

    -- adjust the mining time (to keep it the same overall)
    fluidResource.minable.mining_time = fluidResource.minable.mining_time * getSettingValue("fluid-compression-rate")

    -- the ResourceEntity should never occur naturally
    fluidResource.autoplace = nil

    -- if the ResourceEntity is infinite, increase the infinite_depletion_amount accordingly
    if fluidResource.infinite then
        fluidResource.infinite_depletion_amount = (fluidResource.infinite_depletion_amount or 1) * getSettingValue("fluid-compression-rate")
    end

    return fluidResource
end

---------------------------------------------------------------------------------------------------

-- try to create stacked versions for all resources in the resource table
local resourceTable = {}
for _, resource in pairs(data.raw["resource"]) do
    if not starts_with(resource.name, "stacked") then
        if resource.category == nil or resource.category == "basic-solid" or resource.category == "kr-quarry" then
            -- Support for Pressurized fluids
            -- check if nil because in that case at the end of the data stage the value would be set to the default, which is "basic-solid"
            table.insert(resourceTable, createStackedOre(resource.name))
            log("Sucessfully created the ResourceEntity for the stacked ore version of " .. resource.name)
        elseif mods["CompressedFluids"] and (resource.category == "basic-fluid" or resource.category == "oil" or resource.category == "angels-fissure") then
            -- check if a high pressure version fluid exists that corresponds to the mining result of a resource
            if (resource.minable.result and (data.raw.fluid["high-pressure-" .. (resource.minable.result.name or resource.minable.result[1])])) or (resource.minable.results and (data.raw.fluid["high-pressure-" .. (resource.minable.results[1].name or resource.minable.results[1][1])])) then
                table.insert(resourceTable, createCompressedFluidResource(resource.name))
                log("Sucessfully created the ResourceEntity for the high pressure version of " .. resource.name)
            end
        else
            log("Skipping the resource " .. resource.name .. " because it is neither basic-solid, kr-quarry nor basic-fluid. Feel free to contact the mod author if you feel like the resource " .. resource.name .. " should be supported")
        end
    end
end

for _, resource in pairs(resourceTable) do
    data:extend({resource})
end
