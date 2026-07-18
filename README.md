PageCropper.jl is a tool for finding bounding rectangles of scanned book pages.
It attempts to recognize the topmost page, discarding the visible parts of other pages.
It was built from scratch and for educational purposes.

detekcija stranica
- seeded region growing (roughly locate borders)
- vertical and horizontal edge detection (find page edges)
- hough transform (find inner borders and gutter)

parameters
- single page/double page (default)


Prvo pronađi granice knjige uz seeded region growing


Implementacija:
1. koristeći postojeće implementacije
2. napisati vlastite implementacije
3. zamijeniti postojeće vlastitim implementacijama
4. objaviti kao paket na githubu (for educational purposes)

subota cilj:
- rougly locate borders