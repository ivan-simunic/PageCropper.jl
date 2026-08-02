using Images
using ImageSegmentation
using TestImages
using ImageFiltering
using Plots
using ImageFeatures



img = load("scans/slika.webp") .|> Gray
function zoom_in(img)
    x, y = img.size
    segments = seeded_region_growing(img, [
        (CartesianIndex(div(x, 2), div(y, 2)), 1),
        (CartesianIndex(1, 1), 2),
        (CartesianIndex(x, 1), 2),
        (CartesianIndex(1, y), 2),
        (CartesianIndex(x, y), 2),
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

    img[y1:y2, x1:x2] .|> Gray
end
rough = zoom_in(img)

function edges(img)
    filter = [
        1 0 -1;
        1 0 -1;
        1 0 -1
    ]

    imfilter(rough, filter) .> 0.1
end
binary_img = edges(rough)

function right_line(binary_img)
    tolerance = deg2rad(15) # Max allowable tilt away from perfectly vertical

    angles_near_0 = range(0, stop=tolerance, length=30)
    angles_near_pi = range(π - tolerance, stop=π, length=30)
    vertical_angles = vcat(angles_near_0, angles_near_pi)


    detected_lines = hough_transform_standard(
        binary_img;
        angles = vertical_angles,
        vote_threshold = 40,   # Minimum line length in pixels to be counted
        max_linecount = 10     # Maximum number of lines to return
    )


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

    return target_line
end
line = right_line(binary_img)

function plot_line(img, target_line)

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
end

function gutter_line(binary_img)
    tolerance = deg2rad(15) # Max allowable tilt away from perfectly vertical

    angles_near_0 = range(0, stop=tolerance, length=30)
    angles_near_pi = range(π - tolerance, stop=π, length=30)
    vertical_angles = vcat(angles_near_0, angles_near_pi)

    detected_lines = hough_transform_standard(
        binary_img;
        angles = vertical_angles,
        vote_threshold = 40,   # Minimum line length in pixels to be counted
        max_linecount = 10     # Maximum number of lines to return
    )

    # Get the height and width directly from the input image
    h, w = size(binary_img)
    mid_y = h / 2
    mid_x = w / 2

    # Define the boundaries for the middle 1/10th gutter zone
    gutter_min = 0.45 * w
    gutter_max = 0.55 * w

    # Calculate the x-coordinate at the image midpoint for every line
    lines_with_x = map(detected_lines) do (r, t)
        x_mid = (r - mid_y * sin(t)) / cos(t)
        return (r=r, t=t, x=x_mid)
    end

    # Filter out lines that don't fall within the middle 1/10th window
    gutter_candidates = [l for l in lines_with_x if gutter_min <= l.x <= gutter_max]
    
    if isempty(gutter_candidates)
        println("No lines found in the gutter zone (middle 1/10th of the image).")
        return nothing
    end

    # Out of the candidates in the gutter, pick the one closest to the absolute center
    sort!(gutter_candidates, by = l -> abs(l.x - mid_x))
    target_line = gutter_candidates[1]



    println("Selected Gutter Line -> r: $(target_line.r), t: $(target_line.t) at x: $(target_line.x)")

    return target_line
end
midline = gutter_line(binary_img)

plot_line(rough, line)
plot_line(rough, midline)




#= natural language algorithm description
1. zoom in on the book (removing the background) using seeded region growing algorithm


2. detect horizontal and vertical edges


3. find the correct inner borders (6) and gutter


4. visualize the result

=#



## implementation using high level functions
zoomed_in = zoom_in(img)
height, width = size(zoomed_in)

vertical_edges = detect_edges(zoomed_in, "vertical")
horizontal_edges = detect_edges(zoomed_in, "horizontal")

gutter = find_gutter(vertical_edges)
right_line = find_inner_border(vertical_edges[:, width÷2:end])

##


# implementation of functions used above (with docstrings)