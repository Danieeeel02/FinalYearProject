using SysModels

# Each manufacturing unit will be producing different components which will be supplied to other companies.
# They will also need different components from other units to produce their output.
mutable struct Component <: Resource
    # Name of the component
    name :: String

    # Specifying the location where a component will be manufactured
    inputLocation :: Location 
end

mutable struct ManufacturingUnit
    # Input and output locations for each manufacturing unit. The input location will deal
    # with the receiving of shipping from other units and the output location will deal with
    # the action of shipping from one unit to another.
    inputLocation :: Location
    outputLocation :: Location

    # Every unit will need inputs from other companies to manufacture new outputs and 
    # this is captured in this dictionary.
    inputsNeeded :: Dict{Component, Int}
    
    # Production time is the time taken for a particular unit to manufacture a stock
    # determined by the production size variable.
    productionTime :: Float64

    # Production size is the number of resources produced every one unit of production time 
    # and the available resources will keep on accumulating if none of the resources is being
    # used for shipping or product manufacturing.
    productionSize :: Int

    # Checking if a unit is on the top of the supply chain because if so, it is assumed that
    # the unit has a lot of resources to begin with so that the supply chain can start.
    firstUnit :: Bool

end

mutable struct Shipping
    supplier :: ManufacturingUnit 

    # One manufacturing unit may have multiple units connected to it (one or more). Hence, a 
    # dictionary is used to keep track of all the shipping that one unit has to perform. The
    # float64 here represents the shipping time to each of the receiving units.
    receivers :: Dict{ManufacturingUnit, Float64}

    # The number of components that has to be produced before any shipping from the 
    # company can start. The batch size for every supplying manufacturer is the same 
    # regardless of where they will be sending their components to.
    batchSize :: Int

    componentShipped :: Component

end

########################################  CREATE MODEL FUNCTION  ########################################

function createModel(manufacturingUnits :: Array{ManufacturingUnit}, shippingList :: Array{Shipping},
    componentList :: Array{Component})
    
    # Linking both the input and output locations for every manufacturing unit. This is to ensure that
    # a manufacturing unit can transport processed goods within itself.
    println("#################  SETUP: Manufacturing units linking process  #################\n")
    for unit in manufacturingUnits
        link(unit.inputLocation, unit.outputLocation)
        println("$(unit.inputLocation.name) and $(unit.outputLocation.name) linked successfully.")
    end

    # Using all the data from the shippingList to link all the units, which have supply dependencies on
    # each other. Components can only be shipped between linked manufacturing units.
    for shipping in shippingList
        receivingUnits = keys(shipping.receivers)
        for unit in receivingUnits
            link(shipping.supplier.outputLocation, unit.inputLocation)
            println("$(shipping.supplier.outputLocation.name) and $(unit.inputLocation.name) linked successfully.")
        end
    end

    println("")

    # This process of manufacturing will run forever in the background as long as the simulation is running.
    # If there is not enough materials to manufacture, the process would be stopped for as long as the 
    # shipping of the resources will take.
    function processResources(process :: Process, unit :: ManufacturingUnit)
        while true
            # Needed here is a pair{Component, num_of_components_needed}. This pair contains information 
            # about the inputs needed for each manufacturing unit and how much of those inputs are needed
            # to manufacture the unit's output.
            inputsNeededPairs = unit.inputsNeeded |> collect
            success = false
            claimed = 0

            try
                # The code can only handles manufacturing units with up to 4 inputs needed because this 
                # portion of the code has to hard-coded. What is done here is basically the code is checking
                # if a unit's input unit (or its storage) has got enough resources to manufacture its outputs.
                # If yes, the needed components will be claimed and used for the manufacturing process.
                if length(inputsNeededPairs) == 1
                    success, claimed = @claim(process, (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[1][1].name, 
                                        inputsNeededPairs[1][2])))
                    println("unit(1 input) -> ", unit.inputLocation.name)
                    println("$(inputsNeededPairs[1][2]) units of $(inputsNeededPairs[1][1].name) have been claimed from $(unit.inputLocation.name)" *
                            " to $(unit.outputLocation.name).\n")

                elseif length(inputsNeededPairs) == 2
                    success, claimed = @claim(process, (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[1][1].name, 
                                        inputsNeededPairs[1][2])) && 
                                        (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[2][1].name, 
                                        inputsNeededPairs[2][2])))
                    println("unit(2 inputs) -> ", unit.inputLocation.name)
                    println("$(inputsNeededPairs[1][2]) units of $(inputsNeededPairs[1][1].name) and $(inputsNeededPairs[2][2]) units of $(inputsNeededPairs[2][1].name) " *
                            "have been claimed from $(unit.inputLocation.name) to $(unit.outputLocation.name).\n")

                elseif length(inputsNeededPairs) == 3
                    success, claimed = @claim(process, (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[1][1].name, 
                                                        inputsNeededPairs[1][2])) && 
                                                       (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[2][1].name, 
                                                        inputsNeededPairs[2][2])) &&
                                                       (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[3][1].name, 
                                                        inputsNeededPairs[3][2])))
                    println("unit(3 inputs) -> ", unit.inputLocation.name)
                    println("$(inputsNeededPairs[1][2]) units of $(inputsNeededPairs[1][1].name), $(inputsNeededPairs[2][2]) units of $(inputsNeededPairs[2][1].name) " * 
                            "and $(inputsNeededPairs[3][2]) units of $(inputsNeededPairs[3][1].name) have been claimed from $(unit.inputLocation.name) " *
                            "to $(unit.outputLocation.name).\n")

                elseif length(inputsNeededPairs) == 4
                    success, claimed = @claim(process, (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[1][1].name, 
                                                        inputsNeededPairs[1][2])) && 
                                                        (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[2][1].name, 
                                                        inputsNeededPairs[2][2])) &&
                                                        (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[3][1].name, 
                                                        inputsNeededPairs[3][2])) &&
                                                        (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[4][1].name, 
                                                        inputsNeededPairs[4][2])))
                    println("unit(4 inputs) -> ", unit.inputLocation.name)
                    println("$(inputsNeededPairs[1][2]) units of $(inputsNeededPairs[1][1].name), $(inputsNeededPairs[2][2]) units of $(inputsNeededPairs[2][1].name), " * 
                            "$(inputsNeededPairs[3][2]) units of $(inputsNeededPairs[3][1].name), and $(inputsNeededPairs[4][2]) units of $(inputsNeededPairs[4][1].name) " *
                            "have been claimed from $(unit.inputLocation.name) to $(unit.outputLocation.name).\n")

                end
            

            catch
                # An error is thrown if a manufacturing unit needs more than 4 inputs.
                println("The unit has too many input dependencies. This simulation only supports up to 4 inputs for a unit.") 
            end
            
            if (success)
                # Converting the claimed components into a list before removing them. The reason why
                # the components are removed is to show that the components have been used up to 
                # manufacture the outputs for the unit.
                production_inputs = flatten(claimed)
                remove(process, production_inputs, unit.inputLocation)

                outputs = Component[]
                component_name = nothing

                # Finding from the components list, which component is actually produced by the current
                # manufacturing unit. Then, the finished output components will be initialised and added 
                # to the outputs list.
                for component in componentList
                    if component.inputLocation == unit.inputLocation
                        component_name = component.name
                        for _ in 1 : unit.productionSize
                            new_component = Component(component.name, component.inputLocation)
                            push!(outputs, new_component)
                        end
                    end
                end  

                # Holding the process to allow for the manufacturing process of the components.
                hold(process, unit.productionTime)

                count = 1
                for output in outputs
                    # After the components have been added to the outputs list above, each 
                    # components in the outputs list will be added to the unit's output location.
                    # The completed components will be available for shipping to other units.
                    add(process, unit.outputLocation, output)
                    
                    if count == length(outputs)
                        println("$(length(outputs)) units of $(component_name) have been added to $(unit.outputLocation.name).")
                        println("")
                    end
                    count += 1
                    
                end
            end
        end
    end

    # Shipping process function.
    function moveResources(process :: Process, shipping :: Shipping)

        # NOTE: Shipping might involve more than one receiving manufacturing unit.
        # The sender here is the origin of the shipping for the resources. Receivers are the unit(s)
        # which will need input resources from the sender.
        receivingUnits = keys(shipping.receivers)

        # The shipping process will continue for as long as the simulation is going on provided that
        # the manufacturer has enough outputs to be shipped i.e. availableOutput > shippingSize.
        while true
            for receiver in receivingUnits
                success = false
                claimed = 0

                # We need to firstly check whether the output location of the sender has got enough 
                # outputs to be sent to the connected units. The "success" variable checks for whether 
                # the current resources in the output location of the supplier is enough to be shipped 
                # to the other connected units.
                success, claimed = @claim(process, (shipping.supplier.outputLocation, 
                                    SysModels.find(r -> typeof(r) == Component && r.name == shipping.componentShipped.name,
                                    shipping.batchSize)))
                println("success status: ", success)
                println("$(shipping.batchSize) units of $(shipping.componentShipped.name) claimed from $(shipping.supplier.outputLocation.name) to " *
                        "$(receiver.inputLocation.name).")
                
                if (success)
                    # Convert a tree into a list for easy list comprehension.
                    claimed_outputs = flatten(claimed)

                    # Wait for some time before all the resources can be shipped completely to the receiving unit.
                    # After the holding period is finished, we move all the claimed resources from the manufacturer
                    # to the input location of the receiving unit. Then, the process releases the moved resources
                    # so that these resources can then be used by other processes.
                    hold(process, shipping.receivers[receiver])
                    move(process, claimed_outputs, shipping.supplier.outputLocation, receiver.inputLocation)
                    release(process, receiver.inputLocation, claimed_outputs)

                    println("$(shipping.batchSize) units of $(shipping.componentShipped.name) have been shipped from " * 
                            "$(shipping.supplier.outputLocation.name) to $(receiver.inputLocation.name).\n")

                end
            end
        end
    end

    # To start all the processes for each manufacturing unit.
    model = Model()

    println("\n#################  SETUP: Initial resource allocation  #################\n")

    for unit in manufacturingUnits
        # At this starting stage, the manufacturing unit does not have any outputs yet. So they would
        # have to use the initial resources that they have to start producing outputs. We begin the 
        # simulation by firstly initialising the manufacturing units with some pre-existing 
        # resources and that can be seen in the code block below.
        for component in componentList
            componentsToBeCreated = 0
            if component.inputLocation == unit.inputLocation && !unit.firstUnit
                componentsToBeCreated = unit.productionSize
                for count in 1 : componentsToBeCreated
                    # distrib function is used before a process is being run to allocate resources to
                    # a location.
                    new_component = Component(component.name, component.inputLocation)
                    distrib(new_component, unit.inputLocation)

                    if count == componentsToBeCreated
                        println("$(unit.productionSize) $(component.name) added to $(unit.inputLocation.name)")
                        println("")
                    end
                end

            # If the manufacturing unit is at the top of the supply chain, it is assumed that 
            # the unit has a lot of resources to begin with. This is to ensure that the supply
            # chain simulation can be started.
            elseif component.inputLocation == unit.inputLocation && unit.firstUnit
                componentsToBeCreated = 100000
                for count in 1 : componentsToBeCreated
                    # distrib function is used before a process is being run to allocate resources to
                    # a location.
                    new_component = Component(component.name, component.inputLocation)
                    distrib(new_component, unit.inputLocation)

                    if count == componentsToBeCreated
                        println("$(componentsToBeCreated) $(component.name) added to $(unit.inputLocation.name)")
                        println("")
                    end
                end
            end

        end

        # The continuous process of manufacturing is started for each unit.
        creatingProcess = Process("Create Output", process -> processResources(process, unit))
        push!(model.env_processes, creatingProcess)
        println("Process started for $(unit.inputLocation.name).")

    end   

    for shipping in shippingList
        # The moveResources method above will deal with the shipping to various different companies
        # as listed in the dictionary.
        shippingProcess = Process("Shipping Resource", process -> moveResources(process, shipping))
        push!(model.env_processes, shippingProcess)
        println("Shipping process started for $(shipping.supplier.outputLocation.name).")
    end

    println("\n#################  SUPPLY CHAIN SIMULATION STARTS  #################\n")

    return model

end

# Initialising the locations for outputs and inputs of all the units.
a_output = Location("A_output")
b_output = Location("B_output")
c_output = Location("C_output")

a_input = Location("A_input")
b_input = Location("B_input")
c_input = Location("C_input")

# Initialising all the instances of the components that will be needed later on.
component_a = Component("Wood", a_input)
component_b = Component("Metal", b_input)
component_c = Component("Plastic", c_input)

# Initialising the components involved in the supply chain.
componentList = [component_a, component_b, component_c]

# We consider that every company start with no available output and no available resources to start
# manufacturing their products.
company1 = ManufacturingUnit(a_input, a_output, Dict(componentList[1] => 150), 6.0, 350, true)
company2 = ManufacturingUnit(b_input, b_output, Dict(componentList[1] => 50), 10.0, 1000, false)
company3 = ManufacturingUnit(c_input, c_output, Dict(componentList[1] => 100, componentList[2] => 50), 2.5, 500, false)

# Shipping time is different for each company but shipping size is always the same for each 
# manufacturer.
shipping1 = Shipping(company1, Dict(company2 => 5.5hours, company3 => 10.0hours), 500, component_a)
shipping2 = Shipping(company2, Dict(company3 => 7.0hours), 1200, component_b)

companyList = [company1, company2, company3]
shippingList = [shipping1, shipping2]

model = createModel(companyList, shippingList, componentList)
simulation = Simulation(model)
SysModels.start(simulation)
# 5000 hours is approximately 208.33 days.
SysModels.run(simulation, 100hours)

# ISSUES:
## DELAYS IN Shipping / PROBLEMS IN MANFACTURING
## STORAGE SIZE (IF STORAGE SIZE EXCEEDED - MIGHT NEED TO HOLD)
## INPUT = STORAGE LOCATION
