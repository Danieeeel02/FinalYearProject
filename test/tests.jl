using Test
include("../CompanyModeler.jl")

# Setting up example test datasets
location1 = Location("A")
location2 = Location("B")
location3 = Location("C")
location4 = Location("D")

component1 = Component(
    "Transistor",
    location1
)

component2 = Component(
    "Motherboard",
    location3
)

unit1 = ManufacturingUnit(
    location1,
    location2,
    Dict(component1 => 250),
    4.5hours,
    4500,
    rand(),
    rand(),
    34000,
    12000,
    true
)

unit2 = ManufacturingUnit(
    location3,
    location4,
    Dict(component1 => 405),
    3.0hours,
    3000,
    rand(),
    rand(),
    15000,
    25000,
    false
)

shipping = Shipping(
    unit1,
    Dict(unit2 => 3.0hours),
    2000,
    component1
)

# Initialising the model to be tested
model = createModel([unit1, unit2], [shipping], [component1, component2])
model.locations["A"] = location1
model.locations["B"] = location2
model.locations["C"] = location3
model.locations["D"] = location4

# Test suites categorised by structs being tested
@testset "Testing createModel() function" begin
    @test isa(model, Model)
    @test_throws MethodError createModel(unit1, shipping, component1) 
    @test location1 in values(model.locations)

    # Testing that multiple processes are happening at the same time
    @test length(model.env_processes) > 1
    @test (model.env_processes)[1].name == "Create Output"

end

@testset "Testing ManufacturingUnit struct" begin
    @test isa(unit1, ManufacturingUnit)
    @test unit1 != unit2
    @test unit1 == unit1
    @test unit1.defectRate < 1 && unit1.defectRate > 0
    @test unit2.shippingDelayRate < 1 && unit2.shippingDelayRate > 0

    # Testing the initial resource allocation for units
    @test length(location1.resources) == 20000
    @test length(location3.resources) == unit2.productionSize

    # Test linking of input and output locations
    @test location2 in keys(location1.links)
    @test !(location3 in keys(location1.links))

end

@testset "Testing Shipping struct" begin
    # Testing the linking of supplier and receiver(s)
    @test location3 in keys(location2.links)
    @test isa(shipping.componentShipped, Resource)

end

@testset "Testing Component struct" begin
    @test isa(component1, Resource)
    @test isa(component1, Component)
    @test component1.name == "Transistor"
    @test component2.inputLocation != location2
    @test !(component1 in location2.resources)

end
