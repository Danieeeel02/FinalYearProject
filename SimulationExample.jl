include("CompanyModeler.jl")
using CSV
using DataFrames

####### NOTE: This is the simulation example based on the datasets contained within the folder "/example".
#######       Run this file to simulate the supply chain example from the folder.

########################### Extracting data from files ###########################

# CSV files are read using the CSV library imported above and subsequently
# stored inside a DataFrame.

#units_df = CSV.read("example/manufacturingUnitInfo.csv", DataFrame)
#shipping_df = CSV.read("example/shippingInfo.csv", DataFrame)
#components_df = CSV.read("example/componentInfo.csv", DataFrame)

########################### Initialising the variables ###########################

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

########################### Running the programme ###########################

# Set the number of times the simulation wants to be run by changing the 
# variable below. Change the variable below to 1 to just run the simulation once.
num_of_simulation_runs = 10

delay_list = []
defect_list = []
delay_lengths_list = []
delayed_shipping_time_list = []
shipping_num_list = []
total_output_list = []
total_components_shipped_list = []

for count in 1 : num_of_simulation_runs

    model = createModel(companyList, shippingList, componentList)

    # Below are the list of variables that we are interested in studying
    # and testing for this simulation programme.
    model.data["number_of_shipping_delays"] = 0
    model.data["number_of_defective_components"] = 0
    model.data["length_of_delays"] = 0
    model.data["total_shipping_time_with_delays"] = 0
    model.data["number_of_shippings_done"] = 0
    model.data["total_final_output"] = 0
    model.data["number_of_components_shipped"] = 0

    simulation = Simulation(model)
    SysModels.start(simulation)
    # Simulation time can be adjusted as desired.
    SysModels.run(simulation, 1000days)

    push!(delay_list, model.data["number_of_shipping_delays"])
    push!(defect_list, model.data["number_of_defective_components"])
    push!(delay_lengths_list, model.data["length_of_delays"])
    push!(delayed_shipping_time_list, model.data["total_shipping_time_with_delays"])
    push!(shipping_num_list, model.data["number_of_shippings_done"])
    push!(total_components_shipped_list, model.data["number_of_components_shipped"])
    push!(total_output_list, model.data["total_final_output"])

end

list_copy = copy(total_output_list)
for count in 1 : num_of_simulation_runs
    if count > 1
        total_output_list[count] -= list_copy[count - 1]
    end
end

########################### Testing the programme ###########################

# Extracting and analysing output data
println("Delay list: ", delay_list)
println("Defect list: ", defect_list)
println("Lengths of delay list: ", delay_lengths_list)
println("Total shipping times with delay list", delayed_shipping_time_list)
println("Total shipping done list", shipping_num_list)
println("Total output list", total_output_list)
println("Total components shipped list: ", total_components_shipped_list)

# Writing results out to a csv file in this stated location
path = "results3.csv"

# Storing data in a DataFrame to be added to the csv file later.
df = DataFrame(

    delay_list = delay_list,
    defect_list = defect_list,
    delay_lengths_list = delay_lengths_list,
    delayed_shipping_time_list = delayed_shipping_time_list,
    shipping_num_list = shipping_num_list,
    total_output_list = total_output_list,
    total_components_shipped_list = total_components_shipped_list

)

# Saving all the results from the simulations onto a csv file to allow for
# data analysis. Every time the simulation is run, the output data written
# to the file will be overwritten by new data obtained from more recent 
# simulations.
CSV.write(path, df, header = true)

