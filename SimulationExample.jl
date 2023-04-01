include("CompanyModeler.jl")
using CSV
using DataFrames

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





#units_df = CSV.read("example1/manufacturingUnitInfo.csv", DataFrame)
#shipping_df = CSV.read("example1/shippingInfo.csv", DataFrame)
#components_df = CSV.read("example1/componentInfo.csv", DataFrame)


