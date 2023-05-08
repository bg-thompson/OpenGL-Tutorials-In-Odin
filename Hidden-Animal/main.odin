// A program which draws a hidden triangulated animal.
// Moving the cursor over a triangle reveals it, in time
// revealing the animal.

// Inspired by an image in "Vector Elephant set." by Rashevskaya Art at
// https://thehungryjpeg.com/product/3734798-vector-elephant-set-elephant-triangle-geometric-illustration
// Note: the geometry underlying the image is simple geometry and therefore
// public domain under US copywrite law.

// Created by Benjamin Thompson. Available at:
// https://github.com/bg-thompson/OpenGL-Tutorials-In-Odin
// Last updated: 2023.01.28
//
// To compile and run the program, use the command
//
//     odin run Hidden-Animal
//
// Created for educational purposes. Used verbatim, it is probably
// unsuitable for production code.

package animal

import f  "core:fmt"
import s  "core:strings"
import v  "core:strconv"
import    "core:time"
import m  "core:math"
import mr "core:math/rand"
import    "core:os"
import    "core:runtime"
import    "vendor:glfw"
import gl "vendor:OpenGL"

cam_pos_wv		: [2] f32
mouse_wv                : [2] f32

Triangle :: struct {
    a,b,c      : Node,
    diameter2   : f32,
    color      : Solid_Color,
    hovering   : bool,
}

triangles      : [] Triangle

Solid_Color :: distinct [3] f32

// Global Colors
color_black :: Solid_Color{0,0,0}
color_white :: Solid_Color{1,1,1}
color_cyan  :: Solid_Color{0,1,1}
color_grey  :: Solid_Color{0.5,0.5,0.5}

main :: proc() {
    // Initialize window and OpenGL.
    glfw.Init()
    defer glfw.Terminate()
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
    
    // Create window for the illustration.
    global_window = glfw.CreateWindow(INITIAL_WINDOW_SIZE_W,
                                      INITIAL_WINDOW_SIZE_H,
                                      "Hidden animal",
                                      nil, nil)
    assert(global_window != nil)
    defer glfw.DestroyWindow(global_window)
    glfw.MakeContextCurrent(global_window)
    glfw.SetWindowSizeLimits(global_window, MINIMUM_WINDOW_SIZE_W, MINIMUM_WINDOW_SIZE_H, glfw.DONT_CARE, glfw.DONT_CARE)
    
    // Initialize the window and GPU buffers, and
    // initialize textures used to render pieces.
    init_window(global_window)

    // Load data, create triangles.
    import_nodes()
    import_triangles()

    // Main loop.
    for !glfw.WindowShouldClose(global_window) {
	
	// Check for window resize and process keyboard presses.
        glfw.PollEvents()
	
	cam_zom = 1 // pixels-to-world-space-ratio

	process_keyboard_events(global_window)
	process_mouse_events(global_window)
	
	// Keyboard camera movement
	dx := cam_zom * CAMERA_SCROLL_SPEED 
	
	if shift_camera.x { cam_pos_wv.x -= dx }
	if shift_camera.y { cam_pos_wv.y -= dx }
	if shift_camera.z { cam_pos_wv.x += dx }
	if shift_camera.w { cam_pos_wv.y += dx }

	// Reset keyboard camera movement
	shift_camera       = false

	// Change color of triangle if cursor underneath it.
	for t,i in triangles {
	    xdist := mouse_wv.x - t.a.coord.x
	    ydist := mouse_wv.y - t.a.coord.y
	    // Don't call inside_triangles for triangles that are far away.
	    if xdist * xdist + ydist * ydist <= t.diameter2 {
		if inside_triangle(mouse_wv, t.a.coord, t.b.coord, t.c.coord) {
		    if !t.hovering {
			triangles[i].hovering = true
			current_color := triangles[i].color
			triangles[i].color = update_color(current_color)
		    }
		} else {
		    triangles[i].hovering = false
		}
	    }
	}

        // Render screen.
        render_screen(global_window)
    }
}

update_color :: proc(color : Solid_Color) -> Solid_Color {
    sufficently_different := false
    nr : f32
    for !sufficently_different {
	r := mr.int_max(128)
	nr = 0.5 * f32(r) / f32(128) + 0.3
	if m.abs(color.r - nr) > 0.2 {
	    sufficently_different = true
	}
    }
    return Solid_Color{ nr, nr, nr}
}

process_keyboard_events :: proc(window : glfw.WindowHandle) {
    // GetKey returns either glfw.PRESS or glfw.RELEASE.
    // ESC
    if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS {
	glfw.SetWindowShouldClose(window, true)
    }
    // Right
    if glfw.GetKey(window, glfw.KEY_RIGHT) == glfw.PRESS {
	shift_camera.x = true
    }
    // Up
    if glfw.GetKey(window, glfw.KEY_UP) == glfw.PRESS {
	shift_camera.y = true
    }
    // Left
    if glfw.GetKey(window, glfw.KEY_LEFT) == glfw.PRESS {
	shift_camera.z = true
    }
    // Down
    if glfw.GetKey(window, glfw.KEY_DOWN) == glfw.PRESS {
	shift_camera.w = true
    }
}

process_mouse_events :: proc( window : glfw.WindowHandle) {
    // Get mouse position, normalized to a point in [0,1] x [0,1].
    // Convert the ridiculous standard of setting the origin to be the top left
    // instead of the bottom left.
    mousexraw, mouseyraw := glfw.GetCursorPos(window)
    mouse_px : [2] f32 = {f32(mousexraw), window_h_px - f32(mouseyraw)}
    mouse_wv = cam_zom * mouse_px + cam_pos_wv
}

// If the user blocks .PollEvents() (e.g. due to resizing the window, or right
// clicking on the menu bar, rendering will freeze, so redraw the window.

window_refresh :: proc "c" ( window : glfw.WindowHandle ) {
    context = runtime.default_context()
    w, h : i32
    w, h = glfw.GetWindowSize(window)
    gl.Viewport(0,0,w,h)
    render_screen(global_window)
}

// Import drawing data
NODEDATA :: string(#load(`nodes.txt`))
TRIANGLES :: string(#load(`triangles.txt`))

Node :: struct{
    coord : [2] f32,
    index : i32,
}

nodes : [] Node

import_nodes :: proc() {
    lines := s.split_lines(NODEDATA)
    defer delete(lines)
    number_nodes := len(lines) / 2
    nodes = make([] Node, number_nodes)
    for i in 0..=number_nodes-1 {
	nodes[i].index = i32(i)
	float, ok := v.parse_f32(s.trim_right_space(lines[2*i]))
	assert(ok)
	nodes[i].coord.x = float
	float2, ok2 := v.parse_f32(s.trim_right_space(lines[2*i + 1]))
	assert(ok2)
	nodes[i].coord.y = -float2
    }
}

import_triangles :: proc() {
    lines := s.split_lines(TRIANGLES)
    defer delete(lines)
    
    triangles = make([] Triangle, len(lines))
    for l, i in lines {
	if l == "" { continue }
	ints := s.fields(l)
	int1, ok1 := v.parse_int(ints[0])
	int2, ok2 := v.parse_int(ints[1])
	int3, ok3 := v.parse_int(ints[2])
	assert(ok1 && ok2 && ok3)
	na := nodes[int1]
	nb := nodes[int2]
	nc := nodes[int3]
	triangles[i].a = na
	triangles[i].b = nb
	triangles[i].c = nc
	// Compute diameter of triangle, i.e. its longest side length.
	l1 := na.coord - nb.coord
	l2 := nb.coord - nc.coord
	l3 := nc.coord - na.coord
	ll :: proc ( vec : [2] f32 ) -> f32 { return vec.x * vec.x + vec.y * vec.y }
	diameter2 := max(ll(l1), ll(l2), ll(l3))
	triangles[i].diameter2 = diameter2
	triangles[i].color = color_white
	triangles[i].hovering = false
    }
}

// Rendering Types
VAO     :: distinct u32 // Vertex array  object
VBO     :: distinct u32 // Vertex buffer object
Shader  :: distinct u32

// Rendering Globals
solid_color_vao : VAO
solid_color_vbo : VBO
global_window   : glfw.WindowHandle
window_w_px     : f32
window_h_px     : f32

// Actions globals
shift_camera : [4] bool // 0-4: R, U, L, D

CAMERA_SCROLL_SPEED     :: 25 // Feels about right.

// Rendering Constants
INITIAL_WINDOW_SIZE_W :: 1920
INITIAL_WINDOW_SIZE_H :: 1080
MINIMUM_WINDOW_SIZE_W :: 200
MINIMUM_WINDOW_SIZE_H :: 200

// Picture constants and globals.
// The camera position is the lower-left coord.
// Setting the camera to the center of the screen leads to code
// that is more complicated.
//
// The zoom is the ratio of 1 pixel to 1 unit it world-space.

cam_zom : f32
sc_shader  : Shader

// Maximum number of vertices in vertex buffers.
// Note: a large number of grid points doesn't lead to
// an assertion error.
VB_STAGE_SIZE_IN_FLOATS     :: (1 << 10) * 6 // About 6000 floats.

Vertex_Buffer_Stage :: struct {
    vb : [VB_STAGE_SIZE_IN_FLOATS] f32,
    curr_index : int,
    fpv : int, // floats per vertex
}

// Number of floats in a color vertex set to the GPU.
FLOATS_IN_COLOR_VERTEX :: 5
// | x | y | r | g | b |
// | xy coords (f32 x 2) | rgb color (f32 x 3) |

init_window :: proc( window : glfw.WindowHandle) {
    // Enable V-Sync
    glfw.SwapInterval(1)
    
    // Load OpenGL 3.3 function pointers.
    gl.load_up_to(3, 3, glfw.gl_set_proc_address)
    w,h := glfw.GetFramebufferSize(window)
    gl.Viewport(0,0,w,h)
    
    // Window_refresh is defined below.
    glfw.SetWindowRefreshCallback(window, window_refresh)

    // Setup a Vertex Array Object for solid colors.
    gl.GenVertexArrays(1, cast(^u32) &solid_color_vao)
    gl.BindVertexArray( u32(solid_color_vao) )

    // Set up solid_color_vbo.
    gl.GenBuffers(1, cast(^u32) &solid_color_vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, u32(solid_color_vbo) )
    
    // Create GPU buffer space. Remember to enable!
    gl.BufferData(gl.ARRAY_BUFFER,                                      // target
                  VB_STAGE_SIZE_IN_FLOATS * size_of(f32),               // size
                  nil,                                                  // fill with SubData later
                  gl.DYNAMIC_DRAW)                                      // usage
    
    // Position attributes for solid_vbo_color.
    gl.VertexAttribPointer(0,                                           // index
                           2,                                           // size
                           gl.FLOAT,                                    // type
                           gl.FALSE,                                    // normalized
                           FLOATS_IN_COLOR_VERTEX * size_of(f32),       // stride
                           0 * size_of(f32),                            // offset
                          )


    
    // Color attributes for solid_vbo_color.
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, FLOATS_IN_COLOR_VERTEX * size_of(f32), 2 * size_of(f32))
    
    // Enable the attributes for vbo_color.
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)

    // Compile vertex and fragment shaders.
    shader_comp1_ok  : bool
    // Load shaders into executable at compile time.
    vs1 :: string(#load("sc-vertex-shader.glsl"))
    fs1 :: string(#load("sc-fragment-shader.glsl"))
    
    // sc_shader is a global variable.
    sc_shader_u32 : u32
    sc_shader_u32, shader_comp1_ok = gl.load_shaders_source(vs1, fs1)
    sc_shader = Shader(sc_shader_u32)

    if !shader_comp1_ok {
        f.println("ERROR: Loading and/or compilation of shaders failed!")
        os.exit(1)
    }

    // Set initial camera position.
    cam_pos_wv.x = -900
    cam_pos_wv.y = -600
    return
}
draw_triangle_solid_color :: proc( a,b,c : [2] f32, color : Solid_Color, vas : ^Vertex_Buffer_Stage) {
    assert(vas.fpv == 5)
    cvn := vas.curr_index
    // Triangle Coordinates
    vas.vb[(cvn + 0) * 5 + 0] = a.x
    vas.vb[(cvn + 0) * 5 + 1] = a.y
    vas.vb[(cvn + 1) * 5 + 0] = b.x
    vas.vb[(cvn + 1) * 5 + 1] = b.y
    vas.vb[(cvn + 2) * 5 + 0] = c.x
    vas.vb[(cvn + 2) * 5 + 1] = c.y
    // Triangle Colors
    for i in 0..=2 {
	vas.vb[(cvn + i) * 5 + 2] = color.r
	vas.vb[(cvn + i) * 5 + 3] = color.g
	vas.vb[(cvn + i) * 5 + 4] = color.b
    }
    vas.curr_index += 3
}

render_screen :: proc( window : glfw.WindowHandle) {
    // Get window width and height, and tell the GPU about them.
    window_w_px_int, window_h_px_int := glfw.GetFramebufferSize(window)
    window_w_px = f32(window_w_px_int)
    window_h_px = f32(window_h_px_int)
    
    // Make a buffer to hold the grid squares.
    poly_verts1 : Vertex_Buffer_Stage
    poly_verts1.curr_index = 0
    poly_verts1.fpv = FLOATS_IN_COLOR_VERTEX

    // Draw grid.
    // Select grid color based on mouse pressed.

    for trip in triangles {
	c1, c2, c3 := trip.a.coord, trip.b.coord, trip.c.coord
	draw_triangle_solid_color(c1, c2, c3, trip.color, &poly_verts1)
    }
    
    // Begin rendering.
    // Background color.
    bgc := color_white
    gl.ClearColor(bgc.r, bgc.g, bgc.b, 1)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    // Draw solid_color triangles.
    gl.UseProgram(u32(sc_shader))
    // Set uniforms in solid color shader.
    // Note: this can only be done when the shader is active!

    // Calculate width and hidth of window in world-view.
    // Send these and cam_posx, cam_posy to the shaders.
    window_w_wv := window_w_px * cam_zom
    window_h_wv := window_h_px * cam_zom
    cam_posx_wv    := cam_pos_wv.x
    cam_posy_wv    := cam_pos_wv.y

    set_uniform_f32 :: proc( float : f32, str : cstring, shader : Shader) {
	gl.Uniform1f(gl.GetUniformLocation(u32(shader), str), float)
    }

    set_uniform_f32(window_w_wv, "window_w_wv", sc_shader)
    set_uniform_f32(window_h_wv, "window_h_wv", sc_shader)
    set_uniform_f32(cam_posx_wv, "cam_posx_wv", sc_shader)
    set_uniform_f32(cam_posy_wv, "cam_posy_wv", sc_shader)

    gl.BindVertexArray( u32(solid_color_vao) )
    gl.BindBuffer(gl.ARRAY_BUFFER, u32(solid_color_vbo))
    
    gl.BufferSubData(gl.ARRAY_BUFFER,                                            //target
                     0,                                                          //offset
                     poly_verts1.curr_index * poly_verts1.fpv * size_of(f32),    // size
                     &poly_verts1.vb)                                            // data pointer

    gl.DrawArrays(gl.TRIANGLES, 0, i32(poly_verts1.curr_index))    
    
    // Display render.
    glfw.SwapBuffers(window)
    
    free_all(context.temp_allocator)    
}

// Determine if a point is inside a triangle.
// Uses the cross-product formula to calculate the sign of sin(theta).
inside_triangle :: proc( p : [2] $T, a, b, c : [2] T) -> bool {
    d1 := a - p
    d2 := b - p
    d3 := c - p
    s1 := int( (d1.x * d2.y - d1.y * d2.x) >= 0)
    s2 := int( (d2.x * d3.y - d2.y * d3.x) >= 0)
    s3 := int( (d3.x * d1.y - d3.y * d1.x) >= 0)
    sign_sum := s1 + s2 + s3
    return sign_sum == 0 || sign_sum == 3
}
