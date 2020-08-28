-- the vanilla default fluid capacity of an electric mining drill
local requireFluidCapacity = 200   

-- checks if fluid capacity of miner is high enough to start a mining operation twice (to have a bit of a buffer)
for _,resource in pairs(data.raw["resource"]) do 
    if resource.minable.required_fluid and data.raw["fluid"][resource.minable.required_fluid] then
        if resource.minable.fluid_amount * 2 > requireFluidCapacity then
            requireFluidCapacity = resource.minable.fluid_amount * 2
            log("debug update-miner: requireFluidCapacity updated to " .. requireFluidCapacity .. " because of " .. resource.name)
        end
    end
end

-- increase the fluid capacity of all mining drills in case theirs is smaller than requireFluidCapacity
for _,miner in pairs(data.raw["mining-drill"]) do
    if miner.input_fluid_box then
        log("debug update-miner: input_fluid_box of " .. miner.name .. " before overwrite:\n" .. serpent.block(miner.input_fluid_box))
        if (miner.input_fluid_box.height or 1) * (miner.input_fluid_box.base_area or 1) * 100 < requireFluidCapacity then
            miner.input_fluid_box.base_area = requireFluidCapacity / (100 * (miner.input_fluid_box.height or 1))
            log("debug update-miner: UPDATED input_fluid_box of " .. miner.name .. " after overwrite:\n" .. serpent.block(miner.input_fluid_box))
        end    
    end
end


