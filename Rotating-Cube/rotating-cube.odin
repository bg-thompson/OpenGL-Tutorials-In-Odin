// An elementary program in Odin which creates a colored cube
// which rotates over time.
//
// Created by Benjamin Thompson. Available at:
// https://github.com/bg-thompson/OpenGL-Tutorials-In-Odin
// Last updated: 2022.11.13
//
// To compile and run the program, use the command
//
//     odin run Rotating-Cube
//
// Created for educational purposes. Used verbatim, it is probably
// unsuitable for production code.

package main

import    "vendor:glfw"
import gl "vendor:OpenGL"
import    "core:time"
import m  "core:math"
import    "core:fmt"
import    "core:os"
import    "core:runtime"

// Create alias types for vertex array / buffer objects
VAO             :: u32
VBO             :: u32
EBO             :: u32
ShaderProgram   :: u32

// Global variables.
global_vao       : VAO
global_shader    : ShaderProgram
watch            : time.Stopwatch

main :: proc() {
    // Setup window, including priming for OpenGL 3.3.
    glfw.Init()
    defer glfw.Terminate()

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

    window := glfw.CreateWindow(800, 800, "Rotating Cube", nil, nil)
    assert(window != nil)
    defer glfw.DestroyWindow(window)
    
    glfw.MakeContextCurrent(window)
    glfw.SwapInterval(1)

    // Load OpenGL 3.3 function pointers.
    gl.load_up_to(3,3, glfw.gl_set_proc_address)

    w, h := glfw.GetFramebufferSize(window)
    gl.Viewport(0,0,w,h)

    // Key press / Window-resize behaviour
    glfw.SetKeyCallback(window, callback_key)
    glfw.SetWindowRefreshCallback(window, window_refresh)

    // Cube face colors.
    c1 := rgbHexToFractions(0xd3_47_3d) // red
    c2 := rgbHexToFractions(0xf5_ef_eb) // white
    c3 := rgbHexToFractions(0xf6_ad_0f) // orange
    c4 := rgbHexToFractions(0x31_6a_96) // blue
    c5 := rgbHexToFractions(0x2e_24_3f) // purple
    c6 := rgbHexToFractions(0x86_bc_d1) // light blue


    // Cube vertices and vertex colors.
    vertices : [6*4*6] f32
    vertices = {
        // coords  ; colors
            -1, -1, -1, c1.r, c1.g, c1.b,
        +1, -1, -1, c1.r, c1.g, c1.b,
        -1, +1, -1, c1.r, c1.g, c1.b,
        +1, +1, -1, c1.r, c1.g, c1.b,

        -1, -1, +1, c2.r, c2.g, c2.b,
        +1, -1, +1, c2.r, c2.g, c2.b,
        -1, +1, +1, c2.r, c2.g, c2.b,
        +1, +1, +1, c2.r, c2.g, c2.b,

        -1, -1, -1, c3.r, c3.g, c3.b,
        -1, +1, -1, c3.r, c3.g, c3.b,
        -1, -1, +1, c3.r, c3.g, c3.b,
        -1, +1, +1, c3.r, c3.g, c3.b,

        +1, -1, -1, c4.r, c4.g, c4.b,
        +1, +1, -1, c4.r, c4.g, c4.b,
        +1, -1, +1, c4.r, c4.g, c4.b,
        +1, +1, +1, c4.r, c4.g, c4.b,

        -1, -1, -1, c5.r, c5.g, c5.b,
        +1, -1, -1, c5.r, c5.g, c5.b,
        -1, -1, +1, c5.r, c5.g, c5.b,
        +1, -1, +1, c5.r, c5.g, c5.b,

        -1, +1, -1, c6.r, c6.g, c6.b,
        +1, +1, -1, c6.r, c6.g, c6.b,
        -1, +1, +1, c6.r, c6.g, c6.b,
        +1, +1, +1, c6.r, c6.g, c6.b,
    }

    index_array : [3 * 2 * 6] u32
    index_array = {
        0,  1,   2,  1,  2,  3, // Face 1
        4,  5,   6,  5,  6,  7, // Face 2
        8,  9,  10,  9, 10, 11, // Face 3
        12, 13, 14, 13, 14, 15, // Face 4
        16, 17, 18, 17, 18, 19, // Face 5
        20, 21, 22, 21, 22, 23, // Face 6
    }

    // Set up vertex array / element array / buffer objects
    gl.GenVertexArrays(1, &global_vao)
    gl.BindVertexArray(global_vao)

    vbo : VBO
    gl.GenBuffers(1, &vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)

    ebo : EBO
    gl.GenBuffers(1, &ebo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
    
    // Describe GPU buffer.
    gl.BufferData(gl.ARRAY_BUFFER,     // target
                  size_of(vertices),   // size of the buffer object's data store
                  &vertices,           // data used for initialization
                  gl.STATIC_DRAW)      // usage

    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(index_array), &index_array, gl.STATIC_DRAW)

    // Position and color attributes. Don't forget to enable!
    gl.VertexAttribPointer(0,                   // index
                           3,                   // size
                           gl.FLOAT,            // type
                           gl.FALSE,            // normalized
                           6 * size_of(f32),    // stride
                           0)                   // offset
    
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), 3 * size_of(f32))

    // Enable the vertex position and color attributes defined above.
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)

    // Compile vertex shader and fragment shader.
    // Note how much easier this is in Odin than in C++!

    program_ok      : bool
    vertex_shader   := string(#load("vertex.glsl"  ))
    fragment_shader := string(#load("fragment.glsl"))

    global_shader, program_ok = gl.load_shaders_source(vertex_shader, fragment_shader);

    if !program_ok {
        fmt.println("ERROR: Failed to load and compile shaders."); os.exit(1)
    }

    // Enable shader, and depth-testing during rendering.
    gl.UseProgram(global_shader)
    gl.Enable(gl.DEPTH_TEST)


    // Start rotation timer.
    time.stopwatch_start(&watch)

    for !glfw.WindowShouldClose(window) {
        glfw.PollEvents()
        // If a key press happens, .PollEvents calls callback_key, defined below.
        // Note: glfw.PollEvents blocks on window menu interaction selection or
        // window resize. During window_resize, glfw.SetWindowRefreshCallback
        // calls window_refresh to redraw the window.
        
        render_screen(window, global_vao)
    }
}

render_screen :: proc( window : glfw.WindowHandle, vao : VAO) {
    // Send theta rotation value to GPU.
    raw_duration        := time.stopwatch_duration(watch)
    secs                := f32(time.duration_seconds(raw_duration))
    theta               := f32(-secs)

    // Define matrices for model rotation and camera.
    rotation_mat := [9] f32 {
        m.cos(theta), m.sin(-theta), 0,
        m.sin(theta), m.cos( theta), 0,
        0,                        0, 1,
    }

    // Note: while the following matrices are constant, Odin
    // cannot take pointer address of constants, so put them
    // in the stack. It is clearer to have them here
    // than as a constant in the vertex shader.
    camera_to_x_mat := [9] f32 {
        1, 0,  0,
        0, 0, -1,
        0, 1,  0,
    }
    
    ch :: f32(3)   // Cube offset
    k  :: f32(0.5) // Cube scale
    
    translation_mat := [16] f32 {
        k, 0, 0, 0,
        0, k, 0, 0,
        0, 0, k, ch,
        0, 0, 0, 1,
    }
    // The math behind calculating a perspective matrix like that
    // below can be found in any decent graphics programming textbook.
    perspective_mat := [16] f32 {
        2, 0, 0,  0,
        0, 2, 0,  0,
        0, 0, 3, -8,
        0, 0, 1,  0,
    };
    
    rotation_ptr    : [^] f32 = &rotation_mat[0]
    camera_to_x_ptr : [^] f32 = &camera_to_x_mat[0]
    translation_ptr : [^] f32 = &translation_mat[0]
    perspective_ptr : [^] f32 = &perspective_mat[0]

    // Send the matrices above to the vertex shader program.
    gl.UniformMatrix3fv(gl.GetUniformLocation(global_shader, "rotation_mat"   ), 1, gl.TRUE, rotation_ptr)
    gl.UniformMatrix3fv(gl.GetUniformLocation(global_shader, "camera_to_x_mat"), 1, gl.TRUE, camera_to_x_ptr)
    gl.UniformMatrix4fv(gl.GetUniformLocation(global_shader, "translation_mat"), 1, gl.TRUE, translation_ptr)
    gl.UniformMatrix4fv(gl.GetUniformLocation(global_shader, "perspective_mat"), 1, gl.TRUE, perspective_ptr)

    gl.BindVertexArray(vao)
    defer gl.BindVertexArray(0)
    
    // Draw commands.
    gl.ClearColor(0.0, 0.0, 0.0, 1)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

    gl.DrawElements(gl.TRIANGLES,         // Draw triangles.
                    6 * 6,                // Draw 36 vertices.
                    gl.UNSIGNED_INT,      // Data type of the indices.
                    rawptr(uintptr(0)))   // Pointer to indices. (Not needed.)
    glfw.SwapBuffers(window)
}

// A function which simply converts colors specified in hex
// to a triple of floats ranging from 0 to 1.
rgbHexToFractions :: proc( hex_color : int ) -> ( ret : [3] f32 ) {
    ret.r = f32( (hex_color & 0x00_FF_00_00) >> 16 )
    ret.g = f32( (hex_color & 0x00_00_FF_00) >> 8  )
    ret.b = f32( (hex_color & 0x00_00_00_FF) >> 0  )
    ret *= 1.0/255
    return 
}

// Quit the window if the ESC key is pressed. This procedure is called by
// glfw.SetKeyCallback.
callback_key :: proc "c" ( window : glfw.WindowHandle, key, scancode, action, mods : i32 ) {
    if action == glfw.PRESS && key == glfw.KEY_ESCAPE {
        glfw.SetWindowShouldClose(window, true)
    }
}

// If the window needs to be redrawn (e.g. the user resizes the window), redraw the window.
// This procedure is called by  glfw.SetWindowRefreshCallback.
window_refresh :: proc "c" ( window : glfw.WindowHandle ) {
    context = runtime.default_context()
    w, h : i32
    w, h = glfw.GetWindowSize(window)
    gl.Viewport(0,0,w,h)
    render_screen(window, global_vao)
}
