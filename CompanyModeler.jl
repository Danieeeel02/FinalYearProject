using SysModels

# Production time will be in weeks, so needs to be converted to hours using this variable.
const hoursInAWeek = 24hours * 7

# Each manufacturing unit will be producing different components which will be supplied to other companies.
# They will also need different components from other units to produce their output.
mutable struct Component <: Resource
    # Name of the component
    name :: String

    # We specify the manufacturing using the name attribute of the location class.
    manufacturer :: String 
end

mutable struct ManufacturingUnit
    # Name of the manufacturer/company.
    location :: Location

    # Every unit will need inputs from other companies to manufacture new outputs. 
    inputsNeeded :: Dict{Component, Int}

    # The input resources that we currently have at hand. This will be used to produce
    # outputs.
    inputResourcesAvailable :: Dict{Component, Int}

    # The number of output which has been completely manufactured. These outputs will be ready
    # for shipping once it reaches the batch size as defined in the shipping struct.
    availableOutput :: Int 
    
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
mutable struct Widget <: Resource
end

##############################

function createModel(manufacturingUnits :: Array{ManufacturingUnit}, shippingList :: Array{Shipping},
    componentList :: Array{Component})
    
    # Using all the data from the shippingList to link all the units, which have supply dependencies on
    # each other. Components can only be shipped between linked manufacturing units.
    for shipping in shippingList
        # Key here refers to the supplying companies and it will be linked to all the units 
        # that it supplies resources to.
        for key in keys(shipping.inputAndOutputs)
            connectedUnits = keys(shipping.inputAndOutputs[key])
            for unit in connectedUnits
                link(key.location, unit.location)
                println("$(key.location.name) and $(unit.location.name) linked successfully.")
            end
        end
    end

    # At first, we create resources needed by the manufacturing units in order to carry out business.
    # Later on, if the supply diminishes, the supply chain would have to be held in order to produce
    # more resources that the company can ship to another company.
    function createOutput(process :: Process, unit :: ManufacturingUnit)
        # At this starting stage, the manufacturing unit does not have any outputs yet. So they would
        # have to use the initial resources that they have to start producing outputs.
        for component in componentList
            if component.manufacturer == unit.location.name
                distrib(component, unit.location)
                println("$(component.name) added to $(unit.location.name)")
            end
        end

        # This process of manufacturing will run forever in the background as long as the simulation is running.
        # If there is not enough materials to manufacture, the process would be stopped for as long as the 
        # shipping of the resources will take.
        while true
            resourceChecker = true
            inputNeeded = 0
            availableResources = 0

            for key in keys(unit.inputResourcesAvailable)
                inputNeeded = unit.inputsNeeded[key]
                availableResources = unit.inputResourcesAvailable[key]
                
                if inputNeeded > availableResources
                    resourceChecker = false
                end
            end

            # Checking if there is enough resources to manufacture the output. If yes, the resources 
            # available will be reduced accordingly to produce a set amount of outputs.
            
            if resourceChecker
                unit.availableOutput += unit.productionSize

                for key in keys(unit.inputResourcesAvailable)
                    unit.inputResourcesAvailable[key] = availableResources - inputNeeded
                end

                hold(process, unit.productionTime * hoursInAWeek)
                println("$(unit.location.name) has just produced $(unit.productionSize) units.")
            else 
                # hold statement has to be rectified. include details of shipping.
                longestShippingTime = 0

                # shippinglist = Array[shipping]
                # shipping = inputsoutputs :: dict(MU, dict(MU, float64)), shippingsize :: int
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
                print("For unit $(unit.location.name), operation is held for $(longestShippingTime) weeks. ")
                println("$(unit.location.name) does not have enough resources for manufacturing.")
            end
        end
    end

    # Shipping process method.
    function moveResources(process :: Process, shipping :: Shipping)

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

    model = Model()
    for unit in manufacturingUnits
        
        # The first parameter of the Process struct initialisation is the name of process.
        creatingProcess = Process("Create Output", process -> createOutput(process, unit))
        push!(model.env_processes, creatingProcess)

        #=
        for shipping in shippingList
            # Only add the shipping process for the manufacturing units if the shipping originates from
            # the company.
            if shipping.inputFrom.location.name == unit.location.name
                movingProcess = Process("Moving Resource", process -> moveResources(process, shipping))
                push!(model.env_processes, movingProcess)
            end
        end
        

        processingProcess = Process("Processing Resource", process -> processResources(process, unit))
        push!(model.env_processes, processingProcess)
        # Pushing all the processes involved for each manufacturing unit.
        =#

    end

    simulation = Simulation(model)
    SysModels.start(simulation)
    # 2000 hours is approximately 83.33 days.
    SysModels.run(simulation, 2000hours)

end


# Every company starts out with 0 resource available
componentList = [Component("Wood", "A"), Component("Metal", "B"), Component("Plastic", "C")]

# We consider that every company start with no available output and no available resources to start
# manufacturing their products.
company1 = ManufacturingUnit(Location("A"), Dict(), Dict(), 0, 6.0, 350) # No input needed to create output
company2 = ManufacturingUnit(Location("B"), Dict(componentList[1] => 50), Dict(componentList[1] => 250), 0, 10, 1000)
company3 = ManufacturingUnit(Location("C"), Dict(componentList[1] => 100, componentList[2] => 50), 
Dict(componentList[1]=> 350, componentList[2] => 225), 0, 2.5, 500)

# Shipping time is different for each company but shipping size is always the same for each 
# manufacturer.
shipping1 = Shipping(Dict(company1 => Dict(company2 => 5.5, company3 => 10.0)), 500)
shipping2 = Shipping(Dict(company2 => Dict(company3 => 7.0)), 1200)

companyList = [company1, company2, company3]
shippingList = [shipping1, shipping2]
createModel(companyList, shippingList, componentList)

#=
# Array with company as data type 
company_list = Company[]

function create_companies()
    # End company to received the assembled parts
    end_company = Company("Apple", Location("New York"))

    # Supplier of most electronic components such as semiconductors
    company1 = Company("ARM", Location("Shanghai"))
    company2 = Company("Murata", Location("Japan"))

    # Company that does most of the assembling of all the electronic parts
    company3 = Company("Foxconn", Location("Taipei"))

    push!(company_list, company1)
    push!(company_list, company2)
    push!(company_list, company3)
    push!(company_list, end_company)
end 

function create_model()
    # Creating all the links in the end company's supply chain.
    # Companies 1 and 2 send their supplies to company 3 for assembly.
    # Company 3 sends the finished product to Apple for sale.
    create_companies()

    link(company_list[1].location, company_list[3].location)
    link(company_list[2].location, company_list[3].location)
    link(company_list[3].location, company_list[4].location)
    
    return company_list
end 


m = create_model()
println(company_list[1].get_location())
=#