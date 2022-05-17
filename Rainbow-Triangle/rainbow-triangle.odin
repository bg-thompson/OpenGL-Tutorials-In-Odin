// Created by Benjamin Thompson (github: bg-thompson)
// Last updated: 2022.05.17
// Created for educational purposes. Used verbatim, it is
// probably unsuitable for production code.

package main

import    "vendor:glfw"
import gl "vendor:OpenGL"
import    "core:time"
import f  "core:fmt"
import m  "core:math"
import    "core:os"

main :: proc() {
    // Setup window, including priming for OpenGL 3.3.
    glfw.Init()
    defer glfw.Terminate()

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

    window := glfw.CreateWindow(800, 800, "Rainbow Triangle", nil, nil)
    assert(window != nil)
    defer glfw.DestroyWindow(window)
    
    glfw.MakeContextCurrent(window)
    glfw.SwapInterval(1)

    // Load OpenGL 3.3 function pointers. VERY IMPORTANT!!!
    gl.load_up_to(3,3, glfw.gl_set_proc_address)

    w, h := glfw.GetFramebufferSize(window)
    gl.Viewport(0,0,w,h)

    // Key press / Window-resize behaviour
    glfw.SetKeyCallback(window, callback_key)
    glfw.SetFramebufferSizeCallback(window, callback_size)

    // Create equilateral triangle on unit circle (bonus: make it rotate!)

    vertices : [18] f32 
    vertices = { // Coordinates;        Colors
	 1.0,                     0, 0, 1, 0, 0,
	-0.5, m.sqrt(f32(3)) *  0.5, 0, 0, 1, 0,
	-0.5, m.sqrt(f32(3)) * -0.5, 0, 0, 0, 1,
    }

    // Set up VAO, VBO
    VAO : u32
    gl.GenVertexArrays(1, &VAO)
    gl.BindVertexArray(VAO)

    VBO : u32
    gl.GenBuffers(1, &VBO)
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)

    // Position and color attributes. DON'T FORGET TO ENABLE!!!
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), 0)
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), 3 * size_of(f32))
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)

    // Compile vs and fs. Note how much easier this is than in C++!

    shader_program : u32
    program_ok: bool;
    vertex_shader := string(#load("vertex.glsl"))
    fragment_shader := string(#load("fragment.glsl"))

    shader_program, program_ok = gl.load_shaders_source(vertex_shader, fragment_shader);

    if !program_ok {
        f.println("failed to load and compile shaders"); os.exit(1)
    }

    gl.UseProgram(shader_program)

    // Rotation timing
    watch : time.Stopwatch
    time.stopwatch_start(&watch)

    for !glfw.WindowShouldClose(window) {
	// defer time.sleep(5 * time.Millisecond)
        glfw.PollEvents()

        // Send theta value to GPU.
        raw_duration := time.stopwatch_duration(watch)
        secs := f32(time.duration_seconds(raw_duration))
        theta := f32(-secs)
        gl.Uniform1f(gl.GetUniformLocation(shader_program, "theta"), theta)

        // Draw commands.
        gl.BindVertexArray(VAO)
        defer gl.BindVertexArray(0)

        gl.ClearColor(0.1, 0.1, 0.1, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        // First arg: vertex array starting index, Last arg: how many vertices to draw.
        gl.DrawArrays(gl.TRIANGLES, 0, 3)
        glfw.SwapBuffers(window)
    }
}

callback_key :: proc "c" ( window : glfw.WindowHandle, key, scancode, action, mods : i32 ) {
    if action == glfw.PRESS && key == glfw.KEY_ESCAPE {
        glfw.SetWindowShouldClose(window, true)
    }
}

callback_size :: proc "c" ( window : glfw.WindowHandle, w : i32, h : i32 ) {
    // w, h are the size in pixel of the new window.
    gl.Viewport(0, 0, w, h)    
}

