using Random
using Distributions

#print(rand(MersenneTwister(abs(rand(Int))), Float64))

d= Normal(0.5, 1)

# prints a random number between 0 and 1
print(rand())