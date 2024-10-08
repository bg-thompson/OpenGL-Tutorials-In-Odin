# A collection of introductory OpenGL programs in Odin.

The programs below illustrate OpenGL functions in Odin using the wrappers in `"vendor:OpenGL"`. The programs start very basic and get progressively more complicated.

The glfw library wrappers for Odin in `"vendor:glfw"` are also illustrated.

## Building

Building the examples is trivial; the standard Odin distribution is the ONLY dependency. 

Simply call `odin run DIRECTORY -o:speed` where DIRECTORY is the name of one of the project's directories to build and run an example. (E.g. `odin run Rainbow-Triangle -o:speed`.)

## [Blinking Pink](./Blinking-Pink)

A window which oscillates between pink and blue.

<img src="./Readme-Imgs/blinking-pink.png" alt="An OS window filled with the color pink." width="400">

## [Rainbow Triangle](./Rainbow-Triangle)

An RGB triangle which rotates over time.

<img src="./Readme-Imgs/rainbow-triangle.jpg" alt="A OS window showing a slightly slanted RGB triangle." width="400">

## [Rotating Cube](./Rotating-Cube)

A cube with different faces which rotates over time.

<img src="./Readme-Imgs/rotating-cube.png" alt="An OS window showing a cube in the middle of rotation." width="400">

## [Psychedelic Earth](./Psychedelic-Earth)

An image of the Earth changes color over time.

<img src="./Readme-Imgs/psychedelic-earth.png" alt="An OS window showing a picture of the with purple seas and turqoise land." width="400">

## [Moving Character](./Moving-Character)

A character moves in a counter-clockwise circle over time.

<img src="./Readme-Imgs/moving-character.png" alt="An OS window showing the character '@'." width="400">

## [Wavy Words](./Wavy-Words)

The characters of a sentence move in the form of a sine wave over time.

<img src="./Readme-Imgs/wavy-words.png" alt="The sentence: Duty calls, 3 o'clock tea! in the shape of a sine wave." width="400">

## [Hidden Animal](./Hidden-Animal)

Triangles which together form an animal are revealed when the mouse cursor passes over them.

<img src="./Readme-Imgs/hidden-animal.png" alt="A collection of partially uncovered grey triangles which together form a popular animal." width="400">