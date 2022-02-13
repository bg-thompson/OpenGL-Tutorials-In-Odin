package main

import "vendor:glfw"
import gl "vendor:OpenGL"
import "core:time"
import f "core:fmt"
import m "core:math"
import   "core:os"

rgb_f32 :: struct {
	r : f32,
	g : f32,
	b : f32,
}

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

	// Load OpenGL 3.3 function pointers. VERY IMPORTANT!!!
	gl.load_up_to(3,3, glfw.gl_set_proc_address)

    w, h := glfw.GetFramebufferSize(window)
	gl.Viewport(0,0,w,h)

	// Key press / Window-resize behaviour
	glfw.SetKeyCallback(window, callback_key)
	glfw.SetFramebufferSizeCallback(window, callback_size)

	// Colors:
	c0 := rgbHexToFractions(0xFFFFFF)

	c1 := rgbHexToFractions(0xd3473d) // red
	c2 := rgbHexToFractions(0xf5efeb) // white
	c3 := rgbHexToFractions(0xf6ad0f) // orange
	c4 := rgbHexToFractions(0x316a96) // blue
	c5 := rgbHexToFractions(0x2e243f) // purple
	c6 := rgbHexToFractions(0x86bcd1) // light blue



	vertices : [6*4*6] f32 
	vertices = {                    //Colors
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


	indicies : [3 * 2 * 6] u32
	indicies = {
	// Face 1
		0, 1, 2,
		1, 2, 3,
	// Face 2
		4, 5, 6,
		5, 6, 7,
	// Face 3
		8, 9, 10,
		9, 10, 11,
	// Face 4
		12, 13, 14,
		13, 14, 15,
	// Face 5
		16, 17, 18,
		17, 18, 19,
	// Face 6
		20, 21, 22,
		21, 22, 23,
	}

	// Set up VAO, VBO
	VAO : u32
	gl.GenVertexArrays(1, &VAO)
	gl.BindVertexArray(VAO)

	VBO : u32
	gl.GenBuffers(1, &VBO)
	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)

	EBO : u32
	gl.GenBuffers(1, &EBO)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indicies), &indicies, gl.STATIC_DRAW)

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
		f.println("failed to load and compiler shaders"); os.exit(1)
	}

	gl.UseProgram(shader_program)
	gl.Enable(gl.DEPTH_TEST)

	// Rotation timing
	watch : time.Stopwatch
	time.stopwatch_start(&watch)

	for !glfw.WindowShouldClose(window) {
		defer time.sleep(5 * time.Millisecond)
		glfw.PollEvents()

		// Send theta value to GPU.
		raw_duration := time.stopwatch_duration(watch)
		secs := f32(time.duration_seconds(raw_duration))
		theta := f32(-secs)

		model_mat := [9] f32 {
			m.cos(theta), m.sin(-theta), 0,
			m.sin(theta), m.cos( theta), 0,
			           0,             0, 1,
		};
		camera_to_x_mat := [9] f32 {
			1, 0,  0,
			0, 0, -1,
			0, 1,  0,
		};
		ch           := f32(3)   // Cube offset
		k            := f32(0.5) // Cube scale
		view_mat := [16] f32 {
			k, 0, 0, 0,
			0, k, 0, 0,
			0, 0, k, ch,
			0, 0, 0, 1,
		};
		perspective_mat := [16] f32 { // The WebGL page on perspective motivates how to calculate this.
			2, 0, 0, 0,
			0, 2, 0, 0,
			0, 0, 3, -8,
			0, 0, 1, 0,
		};
	
		rotation_ptr    : [^] f32 = &model_mat[0]
		camera_to_x_ptr : [^] f32 = &camera_to_x_mat[0]
		translation_ptr : [^] f32 = &view_mat[0]
		perspective_ptr : [^] f32 = &perspective_mat[0]

		gl.UniformMatrix3fv(gl.GetUniformLocation(shader_program, "model_mat"), 1, gl.TRUE, rotation_ptr)
		gl.UniformMatrix3fv(gl.GetUniformLocation(shader_program, "camera_to_x_mat"), 1, gl.TRUE, camera_to_x_ptr)
		gl.UniformMatrix4fv(gl.GetUniformLocation(shader_program, "view_mat"), 1, gl.TRUE, translation_ptr)
		gl.UniformMatrix4fv(gl.GetUniformLocation(shader_program, "perspective_mat"), 1, gl.TRUE, perspective_ptr)

		// Draw commands.
		gl.BindVertexArray(VAO)
		defer gl.BindVertexArray(0)

		gl.ClearColor(0.0, 0.0, 0.0, 1)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		// First arg: vertex array starting index, Last arg: how many vertices to draw.
		gl.DrawElements(gl.TRIANGLES, 6 * 6, gl.UNSIGNED_INT, rawptr(uintptr(0)))
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


rgbHexToFractions :: proc( hex_color : int ) -> ( ret : rgb_f32) {
	rint := (hex_color & 0x00_FF_00_00) >> 16
	gint := (hex_color & 0x00_00_FF_00) >> 8
	bint := (hex_color & 0x00_00_00_FF) >> 0
	ret.r = f32(rint)/255
	ret.g = f32(gint)/255
	ret.b = f32(bint)/255
	return 
}

