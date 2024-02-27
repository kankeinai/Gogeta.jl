using Flux
using Plots
using JuMP
using Gurobi
using Random

include("CNN_convert.jl")
include("CNN_util.jl")

using Images
using FileIO
image = load("/Users/eetureijonen/Pictures/IMG_0195.JPG");
downscaled_image = imresize(image, (50, 50));

input = reshape(Float32.(channelview(Gray.(downscaled_image))), 50, 50, 1, 1);
input = input[end:-1:1, :, :, :];
size(CNN_model[1:3](input))

Random.seed!(1234)
CNN_model = Flux.Chain(
    Conv((3,3), 1 => 10, relu),
    MaxPool((3,3)),
    Flux.flatten,
    Dense(2560 => 100, relu),
    Dense(100 => 1)
)

# input image
heatmap(input[:, :, 1, 1], background=false, legend=false, color=:inferno, aspect_ratio=:equal, axis=([], false))

# convolution layer outputs
outputs = [CNN_model[1](input)[:, :, i, 1] for i in 1:size(CNN_model[1:2](input))[3]];
display.(heatmap.(outputs, background=false, legend=false, color = :inferno, aspect_ratio=:equal, axis=([], false)));

# maxpool outputs
outputs = [CNN_model[1:2](input)[:, :, i, 1] for i in 1:size(CNN_model[1:2](input))[3]];
display.(heatmap.(outputs, background=false, legend=false, color = :inferno, aspect_ratio=:equal, axis=([], false)));

# create jump model from cnn
jump = Model(Gurobi.Optimizer)
#set_silent(jump)
create_model!(jump, CNN_model, input)

cnns = get_structure(CNN_model, input);
image_pass!(jump, input, cnns, 0)

# Test that jump model produces same outputs for all layers as the CNN
@time CNN_model[1](input)[:, :, :, 1] ≈ image_pass!(jump, input, cnns, 1)
@time CNN_model[1:2](input)[:, :, :, 1] ≈ image_pass!(jump, input, cnns, 2)
@time vec(CNN_model[1:3](input)) ≈ image_pass!(jump, input, cnns, 3)
@time vec(CNN_model[1:4](input)) ≈ image_pass!(jump, input, cnns, 4)
@time vec(CNN_model[1:5](input)) ≈ image_pass!(jump, input, cnns, 5)

# Plot true model maxpool fifth channel
heatmap(CNN_model[1:2](input)[:, :, 5, 1], background=false, legend=false, color=:inferno, aspect_ratio=:equal, axis=([], false))

# Plot jump model maxpool fifth channel
heatmap(image_pass!(jump, input, cnns, 2)[:, :, 5], background=false, legend=false, color=:inferno, aspect_ratio=:equal, axis=([], false))

