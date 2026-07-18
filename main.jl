using Images
using ImageSegmentation

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

rough = img[y1:y2, x1:x2]