package main

import "vendor:glfw"
import gl "vendor:OpenGL"
import "core:time"
import f "core:fmt"
import m "core:math"

main :: proc() {
	glfw.Init()
	defer glfw.Terminate()

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	window := glfw.CreateWindow(800, 600, "Cube", nil, nil)
	assert(window != nil)
	defer glfw.DestroyWindow(window)
	
	glfw.MakeContextCurrent(window)
	glfw.SwapInterval(1)

	gl.load_up_to(3,3, glfw.gl_set_proc_address)
    w, h := glfw.GetFramebufferSize(window)
	gl.Viewport(0,0,w,h)
	// Pink : 0.9, 0.2, 0.8
	watch : time.Stopwatch
	time.stopwatch_start(&watch)
	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()
		raw_duration := time.stopwatch_duration(watch)
		secs := f32(time.duration_seconds(raw_duration))
		tval := (m.sin(3 * secs) + 1) * 0.5
		gl.ClearColor(0.9 * tval, 0.2, 0.8, 1)
		gl.Clear(gl.COLOR_BUFFER_BIT)
		glfw.SwapBuffers(window)
		time.sleep(8 * time.Millisecond)
	}
}

