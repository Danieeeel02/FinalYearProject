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
    supplier :: ManufacturingUnit

    # One manufacturing unit may have multiple units connected to it (one or more). Hence, a 
    # dictionary is used to keep track of all the shipping that one unit has to perform. The
    # float64 here represents the shipping time to each of the receiving units.
    receivers :: Dict{ManufacturingUnit, Float64}

    # The number of components that has to be produced before any shipping from the 
    # company can start. The batch size for every supplying manufacturer is the same 
    # regardless of where they will be senfing their components to.
    batchSize :: Int

    componentShipped :: Component

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
        receivingUnits = keys(shipping.receivers)
        for unit in receivingUnits
            link(shipping.supplier.outputLocation, unit.inputLocation)
            println("$(shipping.supplier.outputLocation.name) and $(unit.inputLocation.name) linked successfully.")
        end
    end

    # This process of manufacturing will run forever in the background as long as the simulation is running.
    # If there is not enough materials to manufacture, the process would be stopped for as long as the 
    # shipping of the resources will take.
    function processResources(process :: Process, unit :: ManufacturingUnit)
        # At this starting stage, the manufacturing unit does not have any outputs yet. So they would
        # have to use the initial resources that they have to start producing outputs. We begin the 
        # simulation by firstly initialising the manufacturing units with some pre-existing 
        # resources and that can be seen in the code block below.
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
                    success, claimed = @claim(process, (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[1][1].name, 
                                        inputsNeededPairs[1][2])))
                    println("unit(1 input) -> ", unit.inputLocation.name)
                    println("$(inputsNeededPairs[1][2]) units of $(inputsNeededPairs[1][1].name) have been claimed from $(unit.inputLocation.name)\n")

                elseif length(inputsNeededPairs) == 2
                    success, claimed = @claim(process, (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[1][1].name, 
                                        inputsNeededPairs[1][2])) && 
                                        (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[2][1].name, 
                                        inputsNeededPairs[2][2])))
                    println("unit(2 inputs) -> ", unit.inputLocation.name)
                    println("$(inputsNeededPairs[1][2]) units of $(inputsNeededPairs[1][1].name) and $(inputsNeededPairs[2][2]) units of $(inputsNeededPairs[2][1].name) / 
                            have been claimed from $(unit.inputLocation.name)\n")

                elseif length(inputsNeededPairs) == 3
                    success, claimed = @claim(process, (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[1][1].name, 
                                                        inputsNeededPairs[1][2])) && 
                                                       (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[2][1].name, 
                                                        inputsNeededPairs[2][2])) &&
                                                       (unit.inputLocation, SysModels.find(r -> typeof(r) == Component && r.name == inputsNeededPairs[3][1].name, 
                                                        inputsNeededPairs[3][2])))
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


    # Shipping process method. Continuous process just like creating outputs.
    function moveResources(process :: Process, shipping :: Shipping)

        # NOTE: Shipping might involve more than one receiving manufacturing unit.
        # The sender here is the origin of the shipping for the resources. Receivers are the unit(s)
        # which will need input resources from the sender.
        receivingUnits = keys(shipping.receivers)

        # The shipping process will continue for as long as the simulation is going on provided that
        # the manufacturer has enough outputs to be shipped ie availableOutput > shippingSize.
        while true
            for receiver in receivingUnits
                # We need to firstly check whether the output location of the sender has got enough 
                # outputs to be sent to the connected units. 
                println("sender: ", shipping.supplier.outputLocation.name)
                println("receiver", receiver.outputLocation.name, " ", shipping.batchSize)

                # The last variable checks for whether the current resources in the output location of
                # the supplier is enough to be shipped to the other connected units.
                try
                    success, claimed = @claim(process, (shipping.supplier.outputLocation, 
                                        SysModels.find(r -> typeof(r) == Component && r.name == shipping.componentShipped.name, 
                                        shipping.batchSize)))
                catch
                    #println("error occurred")
                end

                

                
                
            












                #=
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
                =#
                
            end
        end
    end

    # To start all the processes for each manufacturing unit.
    model = Model()

    for unit in manufacturingUnits
        # The first parameter of the Process struct initialisation is the name of process.
        creatingProcess = Process("Create Output", process -> processResources(process, unit))
        push!(model.env_processes, creatingProcess)
        println("Process started for $(unit.inputLocation.name).")
    end   

    for shipping in shippingList
        # The moveResources method above will deal with the shipping to various different companies
        # as listed in the dictionary.
        shippingProcess = Process("Shipping Resource", process -> moveResources(process, shipping))
        push!(model.env_processes, shippingProcess)
    end

        
    
    println("\n#################  SUPPLY CHAIN SIMULATION STARTS  ###################\n")

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
company1 = ManufacturingUnit(a_input, a_output, Dict(componentList[1] => 150), 6.0, 350)
company2 = ManufacturingUnit(b_input, b_output, Dict(componentList[1] => 50), 10.0, 1000)
company3 = ManufacturingUnit(c_input, c_output, Dict(componentList[1] => 100, componentList[2] => 50), 2.5, 500)

# Shipping time is different for each company but shipping size is always the same for each 
# manufacturer.
shipping1 = Shipping(company1, Dict(company1 => 2.0, company2 => 5.5, company3 => 10.0), 500, component_a)
shipping2 = Shipping(company2, Dict(company3 => 7.0), 1200, component_b)

companyList = [company1, company2, company3]
shippingList = [shipping1, shipping2]

model = createModel(companyList, shippingList, componentList)
simulation = Simulation(model)
SysModels.start(simulation)
# 5000 hours is approximately 208.33 days.
SysModels.run(simulation, 2000hours)
