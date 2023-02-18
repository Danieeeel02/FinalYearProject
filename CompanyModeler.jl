using SysModels

# Production time will be in weeks, so needs to be converted to hours using this variable.
const hoursInAWeek = 24hours * 7

# Each manufacturing unit will be producing different components which will be supplied to other companies.
# They will also need different components from other units to produce their output.
mutable struct Component <: Resource
    # Name of the component
    name :: String

    # We specify the manufacturing using the name attribute of the location class.
    inputLocation :: Location 
end

mutable struct ManufacturingUnit
    # Input and output locations for each manufacturing unit. The input location will deal
    # with the receiving of shipping from other units and the output location will deal with
    # the action of shipping from one unit to another.
    inputLocation :: Location
    outputLocation :: Location

    # Every unit will need inputs from other companies to manufacture new outputs. 
    inputsNeeded :: Dict{Component, Int}
    
    # Production time here will be defined in weeks. Every time one unit of production
    # time is completed, the number of components produced will be as defined by the 
    # productionSize attribute below.
    productionTime :: Float64

    # Production size is the number of resources produced each time one production time is
    # complete and the number will keep on accumulating if none of the resources is being
    # used for shipping or product manufacturing.
    productionSize :: Int

end

mutable struct Shipping
    # This variable holds the data on the list of manufacturing units to which the current 
    # unit will be sending their components to. For each receiving company, a data on how
    # long the shipping will take is also included in this variable.
    # Note: Float64 here represents the shipping time, and this varies from one unit to another.
    inputAndOutputs :: Dict{ManufacturingUnit, Dict{ManufacturingUnit, Float64}}

    # The number of components that has to be produced before any shipping from the 
    # company can start. The batch size for every supplying manufacturer is the same 
    # regardless of where they will be senfing their components to.
    batchSize :: Int

end

# different resources for diff units. eg: produce keyboards, screens, motherboard
# add = after running model
# distrib = before running model
##############################

function createModel(manufacturingUnits :: Array{ManufacturingUnit}, shippingList :: Array{Shipping},
    componentList :: Array{Component})
    
    # Linking both the input and output locations for every manufacturing unit
    for unit in manufacturingUnits
        link(unit.inputLocation, unit.outputLocation)
        println("$(unit.inputLocation.name) and $(unit.outputLocation.name) linked successfully.")
    end

    # Using all the data from the shippingList to link all the units, which have supply dependencies on
    # each other. Components can only be shipped between linked manufacturing units.
    for shipping in shippingList
        # Key here refers to the supplying companies and it will be linked to all the units 
        # that it supplies resources to.
        for key in keys(shipping.inputAndOutputs)
            connectedUnits = keys(shipping.inputAndOutputs[key])
            for unit in connectedUnits
                link(key.outputLocation, unit.inputLocation)
                println("$(key.outputLocation.name) and $(unit.inputLocation.name) linked successfully.")
            end
        end
    end

    # This process of manufacturing will run forever in the background as long as the simulation is running.
    # If there is not enough materials to manufacture, the process would be stopped for as long as the 
    # shipping of the resources will take.
    function processResources(process :: Process, unit :: ManufacturingUnit)
        # At this starting stage, the manufacturing unit does not have any outputs yet. So they would
        # have to use the initial resources that they have to start producing outputs.
        for component in componentList
            
            if component.inputLocation == unit.inputLocation
                for _ in 1 : unit.productionSize
                    new_component = Component(component.name, component.inputLocation)
                    add(process, unit.inputLocation, new_component)
                end
                println("$(unit.productionSize) $(component.name) added to $(unit.inputLocation.name)")
                println("")
            end
        end

        while true
            # Needed here is a pair{Component, num_of_components_needed}
            inputsNeededPairs = unit.inputsNeeded |> collect
            success = false
            claimed = 0
            try
                # Lengths of the inputs needed - has to be manually coded.
                if length(inputsNeededPairs) == 1
                    success, claimed = @claim(process, (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[1][1].name, inputsNeededPairs[1][2])))
                    println("unit(1 input) -> ", unit.inputLocation.name)
                    println("$(inputsNeededPairs[1][2]) units of $(inputsNeededPairs[1][1].name) have been claimed from $(unit.inputLocation.name)\n")

                elseif length(inputsNeededPairs) == 2
                    success, claimed = @claim(process, (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[1][1].name, inputsNeededPairs[1][2])) && 
                                                       (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[2][1].name, inputsNeededPairs[2][2])))
                    println("unit(2 inputs) -> ", unit.inputLocation.name)
                    println("$(inputsNeededPairs[1][2]) units of $(inputsNeededPairs[1][1].name) and $(inputsNeededPairs[2][2]) units of $(inputsNeededPairs[2][1].name) / 
                            have been claimed from $(unit.inputLocation.name)\n")

                elseif length(inputsNeededPairs) == 3
                    success, claimed = @claim(process, (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[1][1].name, inputsNeededPairs[1][2])) && 
                                                       (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[2][1].name, inputsNeededPairs[2][2])) &&
                                                       (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[3][1].name, inputsNeededPairs[3][2])))
                    println("unit(2 inputs) -> ", unit.inputLocation.name)
                    println("$(inputsNeededPairs[1][2]) units of $(inputsNeededPairs[1][1].name), $(inputsNeededPairs[2][2]) units of $(inputsNeededPairs[2][1].name) / 
                            and $(inputsNeededPairs[3][2]) units of $(inputsNeededPairs[3][1].name) have been claimed from $(unit.inputLocation.name)\n")
                end
            catch
                #println("Error occured") ## error....
            end
            
            if (success)
                #println("CLAIM STATUS: ", success)
                production_inputs = flatten(claimed)
                remove(process, production_inputs, unit.inputLocation)

                ##Next, you want to create the output resources.

                outputs = Component[]

                # Finding from the components list, which component is actually produced by the current
                # manufacturing unit.
                for component in componentList
                    if component.inputLocation == unit.inputLocation
                        for _ in 1 : unit.productionSize
                            new_component = Component(component.name, component.inputLocation)
                            push!(outputs, new_component)
                        end
                    end
                end  

                hold(process, unit.productionTime * hoursInAWeek)

                for output in outputs
                    add(process, unit.outputLocation, output)
                end
            end
        end
    end

    #=
        
            #= NOT NEEDED!

            # Checking if there is enough resources to manufacture the output. If yes, the resources 
            # available will be reduced accordingly to produce a set amount of outputs.
            if resourceChecker
                println("$(unit.location.name) output before is " * string(unit.availableOutput))
                

                for key in keys(unit.inputResourcesAvailable)
                    unit.inputResourcesAvailable[key] = availableResources - inputNeeded
                end

                hold(process, unit.productionTime * hoursInAWeek)
                unit.availableOutput += unit.productionSize
            ####Should be creating a new output resource in the output location
                println("$(unit.location.name) output after is " * string(unit.availableOutput))
                println("$(unit.location.name) has just produced $(unit.productionSize) units.")
                println("")
            else 
                # If resources are insufficient for manufacturing, the manufacturer would have to wait as
                # long as the longest time for any of its resources to be shipped to it. This is to ensure
                # that it has got enough resources for the process. 
                longestShippingTime = 0

                for shipping in shippingList
                    receivingUnits = values(shipping.inputAndOutputs)
                    for receiver in receivingUnits
                        if haskey(receiver, unit)
                            time = receiver[unit]
                            if time > longestShippingTime
                                longestShippingTime = time
                            end
                        end
                    end
                end

                hold(process, longestShippingTime * hoursInAWeek)
                println("For unit $(unit.location.name), operation is held for $(longestShippingTime) weeks. \
                $(unit.location.name) does not have enough resources for manufacturing.")
            end

            =#

        end
    end
=#

#=

    # Shipping process method. Continuous process just like creating outputs.
    function moveResources(process :: Process, shipping :: Shipping)

        # NOTE: Shipping will involve many receiving manufacturing units.
        # The sender here is the origin of the shipping for the resources. Receivers are the unit(s)
        # which will need input resources from the sender.
        sender = collect(keys(shipping.inputAndOutputs))[1]
        receiversDict = shipping.inputAndOutputs[sender]
        receivers = collect(keys(receiversDict))

        # The shipping process will continue for as long as the simulation is going on provided that
        # the manufacturer has enough outputs to be shipped ie availableOutput > shippingSize.
        while true
            for receiver in receivers
                shippingTimeToReceiver = receiversDict[receiver]

                # Finding the component associated with the manufacturing company.
                index = findfirst(x -> x.manufacturer == sender.location.name, componentList)
                manufacturedComponent = componentList[index]

                if sender.availableOutput >= shipping.batchSize
                    println("$(receiver.location.name) $(manufacturedComponent) before is " * 
                    string(receiver.inputResourcesAvailable[manufacturedComponent]))
                    sender.availableOutput -= shipping.batchSize
                    
                    # Resources are first taken away, and after the processing time, will the available output increase.
                    hold(process, shippingTimeToReceiver * hoursInAWeek)
                    receiver.inputResourcesAvailable[manufacturedComponent] += shipping.batchSize

                    println("$(sender.location.name) shipped $(shipping.batchSize) units of \
                    $(manufacturedComponent) to $(receiver.location.name).")
                    println("$(receiver.location.name) $(manufacturedComponent) after is " * 
                    string(receiver.inputResourcesAvailable[manufacturedComponent]))

                else
                    hold(process, sender.productionTime * hoursInAWeek)
                    println("$(sender.location.name) does not have enough outputs yet to ship to $(receiver.location.name).")

                end

                println("")
                
            end
        end

        #=
        resourcesNeeded = 0
        receiver = shipping.outputTo
        receiverNeededInput = receiver.inputsNeeded # type is tuple of locations

        for input in receiverNeededInput
            if input[1].name == shipping.inputFrom.location.name
                resourcesNeeded = input[2]
            end
        end

        while shipping.inputFrom.availableResources < resourcesNeeded
            hold(process, shipping.inputFrom.productionTime)
            shipping.inputFrom.availableResources += shipping.inputFrom.productionSize
            println("Holding shipping from unit $(shipping.inputFrom.location.name) \
            to $(shipping.outputTo.location.name) for \
            $(shipping.inputFrom.productionTime) weeks. Now the supplier has \
            $(shipping.inputFrom.availableResources) units.")
        end 

        success, claimed = @claim(process, (shipping.inputFrom.location, Widget))
        widgets = flatten(claimed)
        move(process, widgets, shipping.inputFrom.location, shipping.outputTo.location)
        release(process, shipping.outputTo.location, widgets)
        
        println("Resources moved from $(shipping.inputFrom.location.name) to \
        $(shipping.outputTo.location.name).")
        =#
    end

#=    
    function processResources(process :: Process, unit :: ManufacturingUnit) 
        # Still needs to be improved. We need to check that each manufacturing unit
        # has all the required supplied before processing to create the output
        # Has to deal with the production of output.
        #=
        if !isempty(unit.inputsNeeded)
            
            if unit.availableResources > unit.inputsNeeded[1][2]
                unit.availableResources -= unit.inputsNeeded[1][2]
                hold(process, unit.productionTime)
                println("Since $unit does not have enough resources for manufacturing goods, 
                the process has been halted for $(unit.productionTime).")
            end
        end
        =#


    end

    # Shipping the resources from one unit to another
    function shipResources(process :: Process)
        
    end

    # Creating the processes to move supplies from one manufacturer to another.

    # to do:
    # for loop here for each unit, create a process for each one
    # put push in each loop, order doesnt matter just initially.
    # processes run in parallel to each other.
    # add print statements.

    =#
=#
    # To start all the processes for each manufacturing unit.
    model = Model()
    for unit in manufacturingUnits
        # The first parameter of the Process struct initialisation is the name of process.
        creatingProcess = Process("Create Output", process -> processResources(process, unit))
        push!(model.env_processes, creatingProcess)

        println("Processes started for $(unit.inputLocation.name).")

       
        #=
        for shipping in shippingList
            # Only add the shipping process for the manufacturing units if the shipping originates from
            # the company.
            if collect(keys(shipping.inputAndOutputs))[1] == unit
                # The moveResources method above will deal with the shipping to various different companies
                # as listed in the dictionary.
                shippingProcess = Process("Shipping Resource", process -> moveResources(process, shipping))
                push!(model.env_processes, shippingProcess)
            end
        end
        =#
        
#=        
        processingProcess = Process("Processing Resource", process -> processResources(process, unit))
        push!(model.env_processes, processingProcess)
        # Pushing all the processes involved for each manufacturing unit.
        =#

    end

    println("\n#################  SUPPLY CHAIN SIMULATION STARTS  ###################\n")

    return model

end


# Initialising the locations for outputs and inputs of all the units
a_output = Location("A_output")
b_output = Location("B_output")
c_output = Location("C_output")

a_input = Location("A_input")
b_input = Location("B_input")
c_input = Location("C_input")

# Every company starts out with 0 resource available
componentList = [Component("Wood", a_input), Component("Metal", b_input), Component("Plastic", c_input)]

# We consider that every company start with no available output and no available resources to start
# manufacturing their products.
company1 = ManufacturingUnit(a_input, a_output, Dict(componentList[1] => 150), 6.0, 350)
company2 = ManufacturingUnit(b_input, b_output, Dict(componentList[3] => 50), 10.0, 1000)
company3 = ManufacturingUnit(c_input, c_output, Dict(componentList[1] => 100, componentList[2] => 50), 2.5, 500)

# Shipping time is different for each company but shipping size is always the same for each 
# manufacturer.
shipping1 = Shipping(Dict(company1 => Dict(company1 => 2.0, company2 => 5.5, company3 => 10.0)), 500)
shipping2 = Shipping(Dict(company2 => Dict(company3 => 7.0)), 1200)
#shipping3 = Shipping(Dict(company1 => Dict(company1 => 2.0)), 600)

companyList = [company1, company2, company3]
shippingList = [shipping1, shipping2]

model = createModel(companyList, shippingList, componentList)
simulation = Simulation(model)
SysModels.start(simulation)
# 5000 hours is approximately 208.33 days.
SysModels.run(simulation, 2500hours)
