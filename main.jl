#= TODO
- implement using libraries
- find a dataset of 10 very diverse hard images
- implement a pipeline that visualizes every step in pluto and has sliders
- find good parameters
- implement whatever externals u used
- back to vs code, streamlined
- make it a julia package (for edu purposes)
- write a readme
- write a substack post about it (for PhD later)
- move on
=#

using ImageFeatures
using ImageFiltering
using ImageSegmentation
using Images
using Plots
using TestImages
using ImageTransformations
using ImageEdgeDetection
using ImageEdgeDetection: Percentile
using Plots



#= natural language algorithm description
1. zoom in on the book (removing the background) using seeded region growing algorithm


2. detect horizontal and vertical edges


3. find the correct inner borders (6) and gutter


4. visualize the result

=#


# main function

function get_rectangles(img)
    _, w = img.size
    img = rescale(img)
    zoomed_in, y_offset, x_offset = zoom_in(img)
    _, width = size(zoomed_in)

    edges = detect_edges(zoomed_in)

    gutter = find_midline(edges[:, 3*width÷7+1:4*width÷7]) |>
        line -> translate(line, x_offset+3*width÷7, y_offset)

    right_line = edges[:, 2*width÷3+1:end] |>
        edges -> find_border(edges, "right") |>
        line -> translate(line, x_offset+2*width÷3, y_offset)

    left_line = edges[:, 1:width÷3] |>
        edges -> find_border(edges, "left") |> 
        line -> translate(line, x_offset, y_offset)

    topright_line = edges[1:height÷3, width÷2+1:end] |>
        edges -> find_border(edges, "top") |>
        line -> translate(line, x_offset+width÷2, y_offset)

    botright_line = edges[2*height÷3+1:end, width÷2+1:end] |> 
        edges -> find_border(edges, "bottom") |>
        line -> translate(line, x_offset + width÷2, y_offset+2*height÷3)#STAL: proofread this and fix onward then back to find_border and so on

    topleft_line = edges[:, 1:width÷2] |> 
        edges -> find_border(edges, "top") |>
        line -> translate(line, x_offset, y_offset)

    botleft_line = edges[:, 1:width÷2] |> 
        edges -> find_border(edges, "bottom") |>
        line -> translate(line, x_offset, y_offset)

    r_topright = intersect(right_line, topright_line)
    r_botright = intersect(botright_line, right_line)
    r_botleft = intersect(botright_line, gutter)
    r_topleft = intersect(gutter, topright_line)
    l_topright = intersect(gutter, topleft_line)
    l_botright = intersect(gutter, botleft_line)
    l_botleft = intersect(botleft_line, left_line)
    l_topleft = intersect(left_line, topleft_line)

    # rescale to original size
    return (x -> x .* w/img.size[2]).(
        (r_topright, r_botright, r_botleft, r_topleft),
        (l_topright, l_botright, l_botleft, l_topleft)
    )
end



# run on scans/ and save into results/
_, _, image_names = walkdir("scans") |> first
for image_name in image_names
    img = load("scans/$image_name")
    img_gray = img .|> Gray
    rectangles = img_gray |> get_rectangles
    result = draw_rectangles(img, rectangles)
    save("results/$image_name", result)
end

# plumbing
img = load("scans/slika3.webp") .|> Gray

struct Line
    ρ::Float64
    Θ::Float64
end

function translate(line::Line, x, y)
    Line(
        line.ρ + x/cos(Θ) + y/sin(Θ),
        Θ
    )
end

"""
return an image 500 pixels high
"""
function rescale(img::AbstractArray{Gray{N0f8}})
    h, w = size(img)
    new_w = round(Int, 500 * w/h)
    return imresize(img, (500, new_w))
end
rescale(img)

"""
return a view zoomed in on the book
"""
function zoom_in(img::Array{Gray{N0f8}})
    h, w = img.size
    seeds = [
        [(CartesianIndex(i, j), 1) for j in 1:w for i in 1:10]...,
        [(CartesianIndex(i, j), 1) for j in 1:w for i in h-9:h]...,
        [(CartesianIndex(i, j), 1) for j in 1:10 for i in 1:h]...,
        [(CartesianIndex(i, j), 1) for j in w-9:w for i in 1:h]...,
        [(CartesianIndex(h÷2+i, w÷2+j), 2) for i in -100:100 for j in -100:100]...
    ]
    l = seeded_region_growing(img, seeds) |> labels_map

    y1 = findfirst(row -> 2 in row, eachrow(l))
    y2 = findlast(row -> 2 in row, eachrow(l))
    x1 = findfirst(col -> 2 in col, eachcol(l))
    x2 = findlast(col -> 2 in col, eachcol(l))
    
    frame=20
    return @view img[max(1, y1-frame):min(h, y2 + frame), max(1, x1-frame):min(w, x2+frame)]
end

##
img = load("scans/slika3.webp") .|> Gray
img = zoom_in(img)
img = rescale(img)
h, w = size(img)
img = @view img[:,3*w÷7:4*w÷7]
alg = Canny(spatial_scale = 1, high=Percentile(80), low=Percentile(10))
edges = BitMatrix(undef, size(img))
detect_edges!(edges, img, alg)
Gray.(edges)

# 1. Define vertical angle ranges (e.g., 0° to 15° and 165° to 180°)
θ_near_0   = range(0, stop=deg2rad(5), length=20)
θ_near_180 = range(deg2rad(175), stop=pi, length=20)
θ_vertical = vcat(θ_near_0, θ_near_180)

# 2. Run Hough transform searching ONLY in those angle bins
vertical_lines = hough_transform_standard(
    edges;
    stepsize = 1,
    angles = θ_vertical,
    vote_threshold = 10,
    max_linecount = 1
)


p = plot(img, title="Detected Vertical Borders", legend=false)
h = size(img, 1)

for (ρ, θ) in vertical_lines
    ys = [1.0, Float64(h)]
    xs = (ρ .- ys .* sin(θ)) ./ cos(θ) # Stable for theta near 0 or pi
    plot!(p, xs, ys, color=:red, linewidth=2)
end

display(p)
##

function detect_edges(img::AbstractArray{Gray{N0f8}})
    alg = Canny(spatial_scale = 1, high=Percentile(80), low=Percentile(10))
    edges = BitMatrix(undef, img |> size)
    detect_edges!(edges, img, alg)
    return edges
end

function find_midline(edges::AbstractArray{Bool})
    # 1. Define vertical angle ranges (e.g., 0° to 15° and 165° to 180°)
    θ_near_0   = range(0, stop=deg2rad(5), length=20)
    θ_near_180 = range(deg2rad(175), stop=pi, length=20)
    θ_vertical = vcat(θ_near_0, θ_near_180)

    # 2. Run Hough transform searching only in those angle bins
    midline = hough_transform_standard(
        edges;
        stepsize = 1,
        angles = θ_vertical,
        vote_threshold = 10,
        max_linecount = 1
    )

    return midline
end

function leftmost_of_rightmost_cluster(x::AbstractVector{<:Real}, maxdist::Real)
    isempty(x) && return nothing

    p = sortperm(x)

    idx = length(p)
    while idx > 1
        if x[p[idx]] - x[p[idx-1]] > maxdist
            break
        end
        idx -= 1
    end

    return p[idx]
end

function find_righthand_border(edges::Array{Gray{Bool}})
    # 1. Define vertical angle ranges (e.g., 0° to 15° and 165° to 180°)
    θ_near_0   = range(0, stop=deg2rad(5), length=20)
    θ_near_180 = range(deg2rad(175), stop=pi, length=20)
    θ_vertical = vcat(θ_near_0, θ_near_180)

    # 2. Run Hough transform searching only in those angle bins
    lines = hough_transform_standard(
        edges;
        stepsize = 1,
        angles = θ_vertical,
        vote_threshold = 10,
        max_linecount = 100
    )


    horizontal_midline = Line(h÷2, π/2)
    xs = []
    for line in lines
        push!(xs, intersect(horizontal_midline, line))
    end

    return lines[leftmost_of_rightmost_cluster(xs, 10)]
end

"""
return a line which is the right/left/top/bottom border of the topmost page
"""
function find_border(edges::Array{Gray{Bool}}, side="right")

end

