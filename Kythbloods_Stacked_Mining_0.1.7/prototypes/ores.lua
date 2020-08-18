local stackSize = settings.startup["deadlock-stack-size"].value
if settings.startup["ky-overwrite-deadlock-stack-size"] == true then
	stackSize = settings.startup["ky-mining-stack-size"].value
end

-- check if the stacked version of the item with the given name exists and in case it does not, create it
    -- returns true when an item was created or if it already exists, otherwise false
local function createStackedVersion(name)
    if data.raw["item"][name] then 
        if data.raw["item"]["deadlock-stack-" .. name] then
            log("debug createStackedVersion: stacked version of the item " .. name .. " already exists")
            return true
        else
            log("debug createStackedVersion: creating stacked version of the item " .. name)
            deadlock.add_stack(name)
            return true
        end
    else
        log("debug createStackedVersion: the item " .. name .. "does not exist")
        return false
    end
end

-- create a stacked version of the ResourceEntity with the given oreName
local function createStackedOre(oreName)
	log("debug2.1: creating stacked ore for " .. oreName)
	
    local stackedName = "stacked-" .. oreName
    local ore = table.deepcopy(data.raw["resource"][oreName])

    ore.localised_name = {"entity-name.stacked-ore",{"entity-name." .. oreName}}
    
    -- replace every result of minable with their stacked version
    if ore.minable.results then
        log("debug2.2.1: minable of " .. oreName .. " before overwrite:\n" .. serpent.block(ore.minable))
        local tempResults = {}
        for _,result in pairs(ore.minable.results) do
            if result.name then
                if createStackedVersion(result.name) then
                    result.name = "deadlock-stack-" .. result.name
                    table.insert(tempResults, result)
                else
                    log("debug2.2.2: something went wrong with createStackedVersion() for " .. result.name)
                end
            else
                log("debug: break")
                break   -- probably not necessary?
            end
        end
        ore.minable.results = tempResults
    elseif ore.minable.result then
        log("debug2.3.1: minable of " .. oreName .. " before overwrite:\n" .. serpent.block(ore.minable))
        
        if createStackedVersion(ore.minable.result) == false then
            log("debug2.3.2: something went wrong with createStackedVersion() for " .. result.name)
        end
        ore.minable.results = 
        {{
            amount_max = 1,
            amount_min = 1,
            name = "deadlock-stack-" .. ore.minable.result,
            probability = 1,
            type = "item"
        }}
        ore.minable.result=nil
    end

    if ore.minable.required_fluid and data.raw["fluid"][ore.minable.required_fluid] then
        ore.minable.fluid_amount = ore.minable.fluid_amount * stackSize
    end
    ore.minable.mining_time = ore.minable.mining_time * stackSize
    log("debug2.4: minable of deadlock-stack-" .. oreName .. " after overwrite:\n" .. serpent.block(ore.minable))
    
    ore.name = stackedName
    ore.autoplace = nil
    
	return ore
end

local resourceTable = {}
for _,resource in pairs(data.raw["resource"]) do
    log("debug1: start creation of stacked ore for " .. resource.name)

    if resource.category == nil or resource.category == "basic-solid" or resource.category == "kr-quarry" then   
        table.insert(resourceTable, createStackedOre(resource.name))
        log("debug3: finished creation of stacked ore for " .. resource.name)
    elseif resource.category == "basic-fluid" then
        -- to-do: else for fluids like oil, supporting pressurized fluids
        log("debug4: to-do: pressurized version of fluid " .. resource.name)
    else 
        log("debug5: resource " .. resource.name .. " is neither basic-solid nor basic-fluid")
    end

end

for _,resource in pairs(resourceTable) do
    data:extend({resource})
end