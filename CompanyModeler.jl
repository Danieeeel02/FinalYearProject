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

    # A random amount of delay rate will be assigned to each manufacturing unit to simulate
    # the presence of delays between shippings in a supply chain and to study its effects 
    # to the chain.
    shippingDelayRate :: Float64

    # A random defect rate will be assigned to each manufacturer to ensure that the simulation
    # reflects a real-life supply chain. The defect rate determines the percentage of the 
    # components which will need to be discarded due to them being faulty.
    defectRate :: Float64

    # The amount of input resources a manufacturing unit can store within its warehouse after 
    # receiving inputs from other connected companies.
    inputStorageSize :: Int

    # The amount of manufactured outputs a manufacturing unit can store within its warehouse after 
    # being processed by the unit itself.
    outputStorageSize :: Int

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
                # Checking if there is enough storage to store the newly manufactured goods. Else, the production 
                # of new components will be halted.
                if (length(unit.outputLocation.resources) + unit.productionSize <= unit.outputStorageSize)    

                    # The code can only handles manufacturing units with up to 4 inputs needed because this 
                    # portion of the code has to hard-coded. What is done here is basically the code is checking
                    # if a unit's input unit (or its storage) has got enough resources to manufacture its outputs.
                    # If yes, the needed components will be claimed and used for the manufacturing process.
                    if length(inputsNeededPairs) == 1
                        success, claimed = @claim(process, (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[1][1].name, 
                                            inputsNeededPairs[1][2])))
                        println("[PRE-PROCESSING RESOURCE CLAIM] $(inputsNeededPairs[1][2]) units of $(inputsNeededPairs[1][1].name) have been claimed from $(unit.inputLocation.name)" *
                                " to $(unit.outputLocation.name).\n")

                    elseif length(inputsNeededPairs) == 2
                        success, claimed = @claim(process, (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[1][1].name, 
                                            inputsNeededPairs[1][2])) && 
                                            (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[2][1].name, 
                                            inputsNeededPairs[2][2])))
                        println("[PRE-PROCESSING RESOURCE CLAIM] $(inputsNeededPairs[1][2]) units of $(inputsNeededPairs[1][1].name) and $(inputsNeededPairs[2][2]) units of $(inputsNeededPairs[2][1].name) " *
                                "have been claimed from $(unit.inputLocation.name) to $(unit.outputLocation.name).\n")

                    elseif length(inputsNeededPairs) == 3
                        success, claimed = @claim(process, (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[1][1].name, 
                                                            inputsNeededPairs[1][2])) && 
                                                        (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[2][1].name, 
                                                            inputsNeededPairs[2][2])) &&
                                                        (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[3][1].name, 
                                                            inputsNeededPairs[3][2])))
                        println("[PRE-PROCESSING RESOURCE CLAIM] $(inputsNeededPairs[1][2]) units of $(inputsNeededPairs[1][1].name), $(inputsNeededPairs[2][2]) units of $(inputsNeededPairs[2][1].name) " * 
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
                        println("[PRE-PROCESSING RESOURCE CLAIM]$(inputsNeededPairs[1][2]) units of $(inputsNeededPairs[1][1].name), $(inputsNeededPairs[2][2]) units of $(inputsNeededPairs[2][1].name), " * 
                                "$(inputsNeededPairs[3][2]) units of $(inputsNeededPairs[3][1].name), and $(inputsNeededPairs[4][2]) units of $(inputsNeededPairs[4][1].name) " *
                                "have been claimed from $(unit.inputLocation.name) to $(unit.outputLocation.name).\n")

                    end
                
                end

            catch
                # An error is thrown if a manufacturing unit needs more than 4 inputs.
                println("The unit has too many input dependencies. This simulation only supports up to 4 inputs for a unit.") 
            end

            if (success)
                # Converting the claimed components into a list before removing them. The reason why
                # the components are removed is to show that the components have been used up to 
                # manufacture the outputs for the unit.
                production_inputs = SysModels.flatten(claimed)
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
                        println("[POST-PROCESSING] $(length(outputs)) units of $(component_name) have been added to $(unit.outputLocation.name).")
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
        # the manufacturer has enough outputs to be shipped i.e. availableOutput >= shippingSize.
        while true
            for receiver in receivingUnits
                components_shipped = 0
                success = false
                claimed = 0

                # Checking if storage is available to store shipped goods. If not, shipping will not be done.
                if (length(receiver.inputLocation.resources) + shipping.batchSize <= receiver.inputStorageSize)

                    # Some components will be defective after being shipped. The value of defect components
                    # will be ceil-ed to only deal with integers.
                    components_shipped = ceil(Int, shipping.batchSize * (1.0 - shipping.supplier.defectRate))

                    # We need to firstly check whether the output location of the sender has got enough 
                    # outputs to be sent to the connected units. The "success" variable checks for whether 
                    # the current resources in the output location of the supplier is enough to be shipped 
                    # to the other connected units.
                    success, claimed = @claim(process, (shipping.supplier.outputLocation, 
                                        SysModels.find(r -> typeof(r) == Component && r.name == shipping.componentShipped.name,
                                        components_shipped)))
                    println("[SHIPPING CLAIM] $(components_shipped) units of $(shipping.componentShipped.name) claimed from $(shipping.supplier.outputLocation.name) to " *
                            "$(receiver.inputLocation.name).")

                end

                if (success)

                    # Simulating random delays within the shipping of resources using random numbers. 
                    random_number = rand()
                    if (random_number > shipping.supplier.shippingDelayRate)
                        # Delayed time will be in seconds (a float) and can be converted to hours.
                        shippingTimeDelayed = shipping.receivers[receiver] * random_number
                        hold(process, shippingTimeDelayed)
                        println("[SHIPPING DELAY] The shipping process from $(shipping.supplier.outputLocation.name) to $(receiver.inputLocation.name) has been delayed by " *  
                        "$(shippingTimeDelayed/(60*60)) hours.")
                        
                    end

                    # Convert a tree into a list for easy list comprehension.
                    claimed_outputs = SysModels.flatten(claimed)

                    # Wait for some time before all the resources can be shipped completely to the receiving unit.
                    # After the holding period is finished, we move all the claimed resources from the manufacturer
                    # to the input location of the receiving unit. Then, the process releases the moved resources
                    # so that these resources can then be used by other processes.
                    hold(process, shipping.receivers[receiver])
                    move(process, claimed_outputs, shipping.supplier.outputLocation, receiver.inputLocation)
                    release(process, receiver.inputLocation, claimed_outputs)

                    println("[SHIPPING] $(components_shipped) units of $(shipping.componentShipped.name) have been shipped from " * 
                            "$(shipping.supplier.outputLocation.name) to $(receiver.inputLocation.name).")
                    println("")

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
                componentsToBeCreated = 20000
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


#=

#Initialising the locations for outputs and inputs of all the units.
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
company1 = ManufacturingUnit(a_input, a_output, Dict(componentList[1] => 550), 6.0hours, 350, rand(), rand(), 20000, 15000, true)
company2 = ManufacturingUnit(b_input, b_output, Dict(componentList[1] => 450), 10.0hours, 1000, rand(), rand(), 19000, 20000, false)

# Huge output and output storage sizes for units in the final position of the supply chain because they indicate
# the finished products ready for shipping to customers.
company3 = ManufacturingUnit(c_input, c_output, Dict(componentList[1] => 500, componentList[2] => 1000), 
                            2.5hours, 500, rand(), rand(), 50000, 5000000, false)

# Shipping time is different for each company but shipping size is always the same for each 
# manufacturer.
shipping1 = Shipping(company1, Dict(company2 => 2.5hours, company3 => 1.7hours), 2500, component_a)
shipping2 = Shipping(company2, Dict(company3 => 3.0hours), 1800, component_b)

companyList = [company1, company2, company3]
shippingList = [shipping1, shipping2]

model = createModel(companyList, shippingList, componentList)
simulation = Simulation(model)
SysModels.start(simulation)
# Simulation time can be adjusted as desired.
SysModels.run(simulation, 10000hours)

# ISSUES:
## DELAYS IN Shipping / PROBLEMS IN MANFACTURING (DONEEE!!!)
## DEFECT RATE (DONE!!!!!)
## STORAGE SIZE (IF STORAGE SIZE EXCEEDED - MIGHT NEED TO HOLD) (DONEEE!!!!!)
## 

=#

## *****CHOOSING TWO OR MORE SUPPLIERS
## INPUT = STORAGE LOCATION