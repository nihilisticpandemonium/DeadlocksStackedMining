local stackSize = settings.startup["deadlock-stack-size"].value
if settings.startup["ky-overwrite-deadlock-stack-size"] == true then
	stackSize = settings.startup["ky-mining-stack-size"].value
end

-- create a stacked version of the ResourceEntity with the given oreName
local function createStackedOre(oreName)
	log("debug2.1: Creating stacked ore for " .. oreName)
	
    local stackedName = "stacked-" .. oreName
    local ore = table.deepcopy(data.raw["resource"][oreName])
    
    ore.localised_name = {"entity-name.stacked-ore",{"entity-name." .. oreName}}
    ore.minable.mining_time = ore.minable.mining_time * stackSize
    
    -- check if the stacked version of the ore item exists, otherwise create it
    if data.raw["item"][oreName] then 
        if not data.raw["item"]["deadlock-stack-" .. oreName] then
            log("debug: Creating stacked version of the item " .. oreName)
            deadlock.add_stack(oreName)
        end
    end

    -- replace every result of minable with their stacked version
    if ore.minable.results then
        log("debug2.2: minable of " .. oreName .. " before overwrite:\n" .. serpent.block(ore.minable))
        local tempResults = {}
        for _,result in pairs(ore.minable.results) do
            if result.name then
                if data.raw["item"]["deadlock-stack-" .. result.name] then
                    result.name = "deadlock-stack-" .. result.name
                    table.insert(tempResults, result)
                else
                    log("debug: result of " .. result.name .. "does not have a stacked version")
                end
            else
                log("debug: break")
                break   -- is this necessary?
            end
        end
        ore.minable.results = tempResults
    elseif ore.minable.result then
        log("debug2.3: minable of " .. oreName .. " before overwrite:\n" .. serpent.block(ore.minable))
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

    log("debug2.4: minable of deadlock-stack-" .. oreName .. ": " .. serpent.block(ore.minable))
    
    ore.name = stackedName
    ore.autoplace = nil
    
	return ore
end


for _,resource in pairs(data.raw["resource"]) do
    log("debug1: start creation of stacked ore for " .. resource.name)

    if resource.category == nil or resource.category == "basic-solid" then   
        data:extend({
            createStackedOre(resource.name)
        })
        log("debug3: finished creation of stacked ore for " .. resource.name)
    elseif resource.category == "basic-fluid" then
        -- to-do: else for fluids like oil, supporting pressurized fluids
        log("debug4: to-do: compressed version of fluid " .. resource.name)
    end

end
