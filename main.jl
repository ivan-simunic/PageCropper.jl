using Images
using ImageSegmentation
using TestImages
using ImageFiltering

img = load("slika.png") .|> Gray
segments = seeded_region_growing(img, [
    (CartesianIndex(500, 300), 1),
    (CartesianIndex(1, 1), 2),
    (CartesianIndex(921, 1), 2),
    (CartesianIndex(1, 596), 2),
    (CartesianIndex(921, 596), 2),
])

target_label = 1
mask = labels_map(segments) .== target_label
blend_pixel(pixel, is_masked) = is_masked ? weighted_color_mean(0.4, colorant"red", RGB(pixel)) : RGB(pixel)
overlay_img = blend_pixel.(img, mask)


x1 = findfirst(col -> any(col), eachcol(mask))
x2 = findlast(col -> any(col), eachcol(mask))
y1 = findfirst(row -> any(row), eachrow(mask))
y2 = findlast(row -> any(row), eachrow(mask))

overlay_img[y1:y2, x1:x2]

rough = img[y1:y2, x1:x2] .|> Gray


filter = [
    1 0 -1;
    1 0 -1;
    1 0 -1
]

(binary_img = (imfilter(rough, filter) .> 0.1)) .|> Gray


tolerance = deg2rad(15) # Max allowable tilt away from perfectly vertical

angles_near_0 = range(0, stop=tolerance, length=30)
angles_near_pi = range(π - tolerance, stop=π, length=30)
vertical_angles = vcat(angles_near_0, angles_near_pi)

using ImageFeatures

detected_lines = hough_transform_standard(
    binary_img;
    angles = vertical_angles,
    vote_threshold = 40,   # Minimum line length in pixels to be counted
    max_linecount = 10     # Maximum number of lines to return
)

using Plots

# 1. Plot the original image as the background canvas.
# Plots.jl automatically sets up the axes and handles top-left orientation.
plot(img)

# Get the height (number of rows) and width (number of columns) of your image
h, w = size(img)

# 2. Loop through your detected (r, t) tuples and calculate the endpoints
for (r, t) in detected_lines
    y1 = 1
    y2 = h
    
    # Derive x from the normal form equation: x*cos(t) + y*sin(t) = r
    x1 = (r - y1 * sin(t)) / cos(t)
    x2 = (r - y2 * sin(t)) / cos(t)
    
    # 3. Draw the line segments on top of the image canvas
    plot!([x1, x2], [y1, y2], color=:red, linewidth=2, label="")
end

# Display the final visualization in your IDE or notebook
current()

# 1. Calculate the x-coordinate at the image midpoint for every line
h, w = size(rough)
mid_y = h / 2

lines_with_x = map(detected_lines) do (r, t)
    x_mid = (r - mid_y * sin(t)) / cos(t)
    return (r=r, t=t, x=x_mid)
end

# 2. Sort lines from left to right based on their x position
sort!(lines_with_x, by = l -> l.x)

# 3. Group lines into clusters based on a pixel gap threshold
gap_threshold = 40.0 # Max distance in pixels to be considered the same cluster
clusters = [[lines_with_x[1]]]

for i in 2:length(lines_with_x)
    # If the gap to the previous line is larger than our threshold, start a new cluster
    if lines_with_x[i].x - lines_with_x[i-1].x > gap_threshold
        push!(clusters, [lines_with_x[i]])
    else
        # Otherwise, add it to the current cluster
        push!(clusters[end], lines_with_x[i])
    end
end

# 4. Extract the rightmost cluster, then take its leftmost line
rightmost_cluster = clusters[end]
target_line = rightmost_cluster[1]

println("Selected Line -> r: $(target_line.r), t: $(target_line.t) at x: $(target_line.x)")



# 1. Reset the plot by showing the image as the background
plot(img, title="Selected Target Line")

h, w = size(img)

# 2. Extract the Hough parameters from the target line struct
r_target = target_line.r
t_target = target_line.t

# 3. Define endpoints at the top and bottom boundaries (y=1 and y=h)
y_top = 1
y_bottom = h

# 4. Calculate corresponding x-coordinates using the Hough equation:
# x = (r - y*sin(t)) / cos(t)
x_top = (r_target - y_top * sin(t_target)) / cos(t_target)
x_bottom = (r_target - y_bottom * sin(t_target)) / cos(t_target)

# 5. Draw the single selected line with high visibility
plot!([x_top, x_bottom], [y_top, y_bottom], 
      color=:cyan, 
      linewidth=1, 
      label="Target Line (r:$(round(r_target, digits=1)), t:$(round(t_target, digits=2)))")

# Show final plot
current()