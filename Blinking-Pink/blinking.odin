package main

import "vendor:glfw"
import gl "vendor:OpenGL"
import f "core:fmt"
import "core:time"
import m "core:math"

main :: proc() {
    // Initialize glfw, specify OpenGL version.
    glfw.Init()
    defer glfw.Terminate()
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
    
    // Create render window.
    window := glfw.CreateWindow(800, 600, "Blinking", nil, nil)
    assert(window != nil)
    defer glfw.DestroyWindow(window)
    glfw.MakeContextCurrent(window)

    // Enable Vsync.
    glfw.SwapInterval(1)

    // Load OpenGL function pointers.
    gl.load_up_to(3,3, glfw.gl_set_proc_address)

    // Set normalized device coords to window coords transformation.
    w, h := glfw.GetFramebufferSize(window)
    gl.Viewport(0,0,w,h)
    
    // Start timer.
    watch : time.Stopwatch
    time.stopwatch_start(&watch)

    // Render loop
    for !glfw.WindowShouldClose(window) {
	glfw.PollEvents()
	// Create oscillating value (osl).
	raw_duration := time.stopwatch_duration(watch)
	secs := f32(time.duration_seconds(raw_duration))
	osl := (m.sin(3 * secs) + 1) * 0.5
	// Clear screen with color.
	gl.ClearColor(0.9 * osl, 0.2, 0.8, 1) // Pink: 0.9, 0.2, 0.8
	gl.Clear(gl.COLOR_BUFFER_BIT)
	// Render image, then sleep for a bit.
	glfw.SwapBuffers(window)
	time.sleep(5 * time.Millisecond)
    }
}
