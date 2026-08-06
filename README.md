PageCropper.jl is a tool for finding bounding rectangles of scanned book pages.
It attempts to recognize the topmost page, discarding the visible parts of other pages.
It was built from scratch and for educational purposes.

detekcija stranica
- seeded region growing (roughly locate borders)
- vertical and horizontal edge detection (find page edges)
- hough transform (find inner borders and gutter)


parameters
- single page/double page (default)