#= TODO
- write structs and function signatures you anticipate
- implement possibly using libraries
- implement whatever externals u used
=#

using ImageFeatures
using ImageFiltering
using ImageSegmentation
using Images
using Plots
using TestImages




#= natural language algorithm description
1. zoom in on the book (removing the background) using seeded region growing algorithm


2. detect horizontal and vertical edges


3. find the correct inner borders (6) and gutter


4. visualize the result

=#


# implementation using high level functions

function get_rectangles(img)
    zoomed_in, y_offset, x_offset = zoom_in(img)
    height, width = size(zoomed_in)

    vertical_edges = detect_edges(zoomed_in, "vertical")
    horizontal_edges = detect_edges(zoomed_in, "horizontal")


    gutter = find_midline(vertical_edges) |>
        translate(x_offset, y_offset)
    right_line = vertical_edges[:, width÷2+1:end] |>
        find_righthand_border |>
        translate(x_offset+width÷2, y_offset)
    left_line = vertical_edges[:, 1:width÷2] |>
        find_lefthand_border |> 
        translate(x_offset, y_offset)
    topright_line = horizontal_edges[:, width÷2+1:end] |>
        find_top_border |>
        translate(x_offset+width÷2, y_offset)
    botright_line = horizontal_edges[:, width÷2+1:end] |> 
        find_bottom_border |>
        translate(x_offset + width÷2, y_offset)
    topleft_line = horizontal_edges[:, 1:width÷2] |> 
        find_top_border |>
        translate(x_offset, y_offset)
    botleft_line = horizontal_edges[:, 1:width÷2] |> 
        find_bottom_border |>
        translate(x_offset, y_offset)

    r_topright = intersect(right_line, topright_line)
    r_botright = intersect(botright_line, right_line)t
    r_botleft = intersect(botright_line, gutter)
    r_topleft = intersect(gutter, topright_line)
    l_topright = intersect(gutter, topleft_line)
    l_botright = intersect(gutter, botleft_line)
    l_botleft = intersect(botleft_line, left_line)
    l_topleft = intersect(left_line, topleft_line)

    return (
        (r_topright, r_botright, r_botleft, r_topleft),
        (l_topright, l_botright, l_botleft, l_topleft)
    )
end



get_results("scans", "results")


# plumbing