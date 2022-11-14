// An elementary program in Odin which creates a rainbow RGB triangle
// which rotates over time.
//
// Created by Benjamin Thompson. Available at:
// https://github.com/bg-thompson/OpenGL-Tutorials-In-Odin
// Last updated: 2022.11.13
//
// To compile and run the program, use the command
//
//     odin run Rainbow-Triangle
//
// Created for educational purposes. Used verbatim, it is probably
// unsuitable for production code.

package main

import    "vendor:glfw"
import gl "vendor:OpenGL"
import    "core:time"
import    "core:math"
import    "core:fmt"
import    "core:os"
import    "core:runtime"

// Create alias types for vertex array / buffer objects
VAO             :: u32
VBO             :: u32
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

    window := glfw.CreateWindow(800, 800, "Character Render", nil, nil)
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

    // Create equilateral triangle on unit circle.

    sq := math.sqrt(f32(3)) * 0.5
    
    vertices : [15] f32 = {
        // Coordinates ; Colors
         1.0,   0,       1, 0, 0,
        -0.5,  sq,       0, 1, 0,
        -0.5, -sq,       0, 0, 1,
    }

    // Set up vertex array / buffer objects.
    gl.GenVertexArrays(1, &global_vao)
    gl.BindVertexArray(global_vao)

    vbo : VBO
    gl.GenBuffers(1, &vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)

    // Describe GPU buffer.
    gl.BufferData(gl.ARRAY_BUFFER,     // target
                  size_of(vertices),   // size of the buffer object's data store
                  &vertices,           // data used for initialization
                  gl.STATIC_DRAW)      // usage

    // Position and color attributes. Don't forget to enable!
    gl.VertexAttribPointer(0,                   // index
                           2,                   // size
                           gl.FLOAT,            // type
                           gl.FALSE,            // normalized
                           5 * size_of(f32),    // stride
                           0)                   // offset
    
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 5 * size_of(f32), 2 * size_of(f32))

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

    gl.UseProgram(global_shader)

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
    raw_duration := time.stopwatch_duration(watch)
    secs         := f32(time.duration_seconds(raw_duration))
    theta        := -secs
    gl.Uniform1f(gl.GetUniformLocation(global_shader, "theta"), theta)

    gl.BindVertexArray(vao)
    defer gl.BindVertexArray(0)
    
    // Draw commands.
    gl.ClearColor(0.1, 0.1, 0.1, 1)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    gl.DrawArrays(gl.TRIANGLES,    // Draw triangles.
                  0,               // Begin drawing at index 0.
                  3)               // Use 3 indices.
    glfw.SwapBuffers(window)
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
