// An elementary program in Odin which renders "The Blue Marble" taken
// by the Apollo 17 Crew, 1972, animated with mild psychedelic colors.
//
// The photo is in the public domain, and available at:
// https://commons.wikimedia.org/wiki/File:The_Blue_Marble.jpg
//
// The .qoi (Quite OK Image Format) version of the image in this directory
// was converted from the .jpg version above with IrfanView.
//
// Created by Benjamin Thompson. Available at:
// https://github.com/bg-thompson/OpenGL-Tutorials-In-Odin
// Last updated: 2024.09.15
//
// To compile and run the program with optimizations, use the command
//
//     odin run Psychedelic-Earth -o:speed
//
// Created for educational purposes. Used verbatim, it is probably
// unsuitable for production code.

package main

import    "vendor:glfw"
import gl "vendor:OpenGL"
import    "core:image"
import  q "core:image/qoi"
import    "core:time"
import  m "core:math"
import  f "core:fmt"
import    "core:os"
import    "base:runtime"

// Create alias types for vertex array / buffer objects
VAO             :: u32
VBO             :: u32
ShaderProgram   :: u32
Texture         :: u32

// Global variables.
global_vao       : VAO
global_shader    : ShaderProgram
watch            : time.Stopwatch

// Constants
WINDOW_H :: 800
WINDOW_W :: 800
IMAGELOC :: `blue-marble.qoi`

// Functions to update constants in shader programs.
update_uni_2fv :: proc( program : u32, var_name : cstring, new_value_ptr : [^] f32) {
    gl.UniformMatrix2fv(gl.GetUniformLocation(program, var_name), 1, gl.TRUE, new_value_ptr)
}

update_uni_3fv :: proc( program : u32, var_name : cstring, new_value_ptr : [^] f32) {
    gl.UniformMatrix3fv(gl.GetUniformLocation(program, var_name), 1, gl.TRUE, new_value_ptr)
}

main :: proc() {
    //-------------------------------------------------------------
    // Use glfw to setup a window to render with OpenGl.
    //-------------------------------------------------------------
    glfw.Init()
    defer glfw.Terminate()

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

    window := glfw.CreateWindow(WINDOW_W, WINDOW_H, "Psychedelic Earth", nil, nil)
    assert(window != nil)
    defer glfw.DestroyWindow(window)
    
    glfw.MakeContextCurrent(window)
    glfw.SwapInterval(1)

    // Load OpenGL 3.3 function pointers.
    gl.load_up_to(3,3, glfw.gl_set_proc_address)

    ww, hh := glfw.GetFramebufferSize(window)
    gl.Viewport(0,0,ww,hh)

    // Key press / Window-resize behaviour
    glfw.SetKeyCallback(window, callback_key)
    glfw.SetWindowRefreshCallback(window, window_refresh)
    
    //-------------------------------------------------------------
    //Set up a rectangle to have the image texture drawn on it.
    //-------------------------------------------------------------

    w, h : f32
    w    = WINDOW_W
    h    = WINDOW_H

    rect_verts : [6 * 4] f32 
    rect_verts = { // rect coords : vec2, texture coords : vec2
	-w,  h,   0, 0,
	-w, -h,   0, 1,
	 w, -h,   1, 1,
	-w,  h,   0, 0,
	w,   h,   1, 0,
	w,  -h,   1, 1,
    }

    // Load image at compile time
    image_file_bytes    := #load(IMAGELOC)

    // Load image  Odin's core:image library.
    image_ptr           :  ^image.Image
    err                 :  image.Error
    options             := image.Options{.alpha_add_if_missing}

    //    image_ptr, err =  q.load_from_file(IMAGELOC, options)
    image_ptr, err =  q.load_from_bytes(image_file_bytes, options)
    defer q.destroy(image_ptr)
    image_w := i32(image_ptr.width)
    image_h := i32(image_ptr.height)

    if err != nil {
        f.println("ERROR: Image:", IMAGELOC, "failed to load.")
    }

    // Copy bytes from icon buffer into slice.
    earth_pixels_u8 := make([]u8, len(image_ptr.pixels.buf))
    for b, i in image_ptr.pixels.buf {
        earth_pixels_u8[i] = b
    }

    //-------------------------------------------------------------
    //Tell the GPU about the image (texture).
    //-------------------------------------------------------------

    gl.GenVertexArrays(1, &global_vao)
    gl.BindVertexArray(global_vao)

    vbo : VBO
    gl.GenBuffers(1, &vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)

    Earth_texture : Texture
    gl.GenTextures(1, &Earth_texture)
    gl.BindTexture(gl.TEXTURE_2D, Earth_texture)
    
    // Describe GPU buffer.
    gl.BufferData(gl.ARRAY_BUFFER, size_of(rect_verts), &rect_verts, gl.STATIC_DRAW)

    // Position and color attributes. Don't forget to enable!
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 0 * size_of(f32))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 2 * size_of(f32))
    
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)

    // Describe texture.
    gl.TexImage2D(
        gl.TEXTURE_2D,    // texture type
        0,                // level of detail number (default = 0)
        gl.RGBA,          // texture format
        image_w,          // width
        image_h,          // height
        0,                // border, must be 0
        gl.RGBA,          // pixel data format
        gl.UNSIGNED_BYTE, // data type of pixel data
        &earth_pixels_u8[0],  // image data
    )

    // Texture wrapping options.
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    
    // Texture filtering options.
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

    //-------------------------------------------------------------
    //Compile the vertex and fragment shader.
    //-------------------------------------------------------------

    program_ok      : bool
    vertex_shader   := string(#load("vertex.glsl"  ))
    fragment_shader := string(#load("fragment.glsl"))

    global_shader, program_ok = gl.load_shaders_source(vertex_shader, fragment_shader);

    if !program_ok {
        f.println("ERROR: Failed to load and compile shaders."); os.exit(1)
    }

    gl.UseProgram(global_shader)

    //-------------------------------------------------------------
    //Render the image!
    //-------------------------------------------------------------

    // Start rotation timer.
    time.stopwatch_start(&watch)

    // Texture blending options.
    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

    // Main loop.
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
    // Calculate projection matrix.
    render_rect_w , render_rect_h : f32
    render_rect_w = WINDOW_W
    render_rect_h = WINDOW_H

    proj_mat := [4] f32 {
        1/render_rect_w, 0,
        0, 1/render_rect_h,
    }

    // Calculate translation matrix.
    raw_duration := time.stopwatch_duration(watch)
    secs := f32(time.duration_seconds(raw_duration))
    
    // Small function which oscillates between 0 and 1 with wavelength
    // 2*pi/n secs.
    osc :: proc( t : f32, n : f32) -> f32 {
	return (1 + m.sin(n * t)) / 2
    }
    
    // Calculate fragment shader values to get psychedelic effect.
    t1 := osc(secs, 2)
    t2 := osc(secs, 2.5)
    t3 := osc(secs, 3)
    
    psych_mat := [9] f32 {
	1 - t1, 0,      t1,
	0,      1 - t2, t2,
	0,      t3,     1 - t3,
    }
    
    proj_mat_ptr  : [^] f32 = &proj_mat[0]
    psych_mat_ptr : [^] f32 = &psych_mat[0]

    gl.BindVertexArray(vao)
    defer gl.BindVertexArray(0)
    
    // Send matrices to the shader.
    update_uni_2fv(global_shader, "projection",  proj_mat_ptr)
    update_uni_3fv(global_shader, "psych_mat",   psych_mat_ptr)
    
    // Draw commands.
    gl.ClearColor(0.1, 0.1, 0.1, 1)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    gl.DrawArrays(gl.TRIANGLES, 0, 6)
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
