using Random
using Distributions

# Define the mean and standard deviation of the normal distribution
μ = 0
σ = 1

# Create a normal distribution object
dist = Normal(μ, σ)

# Generate 10 random positive numbers from the normal distribution
println(abs.(randn(10)))


println(rand(1:100))