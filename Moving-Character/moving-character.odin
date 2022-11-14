// An elementary program in Odin which renders a character from a
// font and moves it in a circle.
//
// Created by Benjamin Thompson. Available at:
// https://github.com/bg-thompson/OpenGL-Tutorials-In-Odin
// Last updated: 2022.11.13
//
// To compile and run the program, use the command
//
//     odin run Moving-Character
//
// Created for educational purposes. Used verbatim, it is probably
// unsuitable for production code.

package main

import    "vendor:glfw"
import gl "vendor:OpenGL"
import tt "vendor:stb/truetype"
import    "core:time"
import  m "core:math"
import  f "core:fmt"
import    "core:os"
import    "core:runtime"

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
FONT     :: `C:\Windows\Fonts\arialbd.ttf`
CHARACTER:: '@'
FONTSCALE:: 100

// Functions to update constants in shader programs.
update_uni_2fv :: proc( program : u32, var_name : cstring, new_value_ptr : [^] f32) {
    gl.UniformMatrix2fv(gl.GetUniformLocation(program, var_name), 1, gl.TRUE, new_value_ptr)
}

update_uni_4fv :: proc( program : u32, var_name : cstring, new_value_ptr : [^] f32) {
    gl.UniformMatrix4fv(gl.GetUniformLocation(program, var_name), 1, gl.TRUE, new_value_ptr)
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

    window := glfw.CreateWindow(WINDOW_W, WINDOW_H, "Moving Character", nil, nil)
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
    //Set up a rectangle to have the character texture drawn on it.
    //-------------------------------------------------------------

    h, w : f32
    h    = 300
    w    = 300

    rect_verts : [6 * 4] f32 
    rect_verts = { // rect coords : vec2, texture coords : vec2
    0, h,    0, 0,
    0, 0,    0, 1,
    w, 0,    1, 1,
    0, h,    0, 0,
    w, 0,    1, 1,
    w, h,    1, 0,
    }

    //-------------------------------------------------------------
    //Use stb to load a .ttf font and create a bitmap from it.
    //-------------------------------------------------------------

    // Load .ttf file into buffer.
    ttf_buffer :: [1<<23] u8 // Assumes a .ttf file of under 8MB.
    fontdata, succ := os.read_entire_file(FONT)
    if !succ {
        f.println("ERROR: Couldn't load font at: ", FONT)
        os.exit(1)
    }
    font_ptr : [^] u8 = &fontdata[0]

    // Initialize font.
    font : tt.fontinfo
    tt.InitFont(info = &font, data = font_ptr, offset = 0)

    // Find glyph of character to render.
    char_index := tt.FindGlyphIndex(&font, CHARACTER)

    // Create Bitmap of glyph, and loading width and height.
    bitmap_w, bitmap_h, xo, yo : i32
    glyph_bitmap := tt.GetGlyphBitmap(
        info    = &font,
        scale_x = 0,
        scale_y = tt.ScaleForPixelHeight(&font, FONTSCALE),
        glyph   = char_index,
        width   = &bitmap_w,
        height  = &bitmap_h,
        xoff    = &xo,
        yoff    = &yo,
    )
    // Memory Leak: the above should be freed with tt.FreeBitmap

    //f.println("bitmap width, height of", CHARACTER, ":", bitmap_w, bitmap_h) // Debug

    //-------------------------------------------------------------
    //Tell the GPU about the data, especially the font texture.
    //-------------------------------------------------------------

    gl.GenVertexArrays(1, &global_vao)
    gl.BindVertexArray(global_vao)

    vbo : VBO
    gl.GenBuffers(1, &vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)

    Glyph_texture : Texture
    gl.GenTextures(1, &Glyph_texture)
    gl.BindTexture(gl.TEXTURE_2D, Glyph_texture)
    
    // Describe GPU buffer.
    gl.BufferData(gl.ARRAY_BUFFER, size_of(rect_verts), &rect_verts, gl.STATIC_DRAW)

    // Position and color attributes. Don't forget to enable!
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 0 * size_of(f32))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 2 * size_of(f32))
    
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

    gl.TexImage2D(
        gl.TEXTURE_2D,    // texture type
        0,                // level of detail number (default = 0)
        gl.RED,           // texture format
        bitmap_w,         // width
        bitmap_h,         // height
        0,                // border, must be 0
        gl.RED,           // pixel data format
        gl.UNSIGNED_BYTE, // data type of pixel data
        glyph_bitmap,     // image data
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
    //Render the character!
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
    
    proj_mat_ptr : [^] f32 = &proj_mat[0]

    // Calculate translation matrix.
    raw_duration := time.stopwatch_duration(watch)
    secs := f32(time.duration_seconds(raw_duration))

    theta := f32(m.PI * secs )

    radius := f32(0.5)
    translation_mat := [16] f32 {
        1, 0, 0, radius * m.cos(theta),
        0, 1, 0, radius * m.sin(theta),
        0, 0, 1, 0,
        0, 0, 0, 1,
    }

    trans_mat_ptr : [^] f32 = &translation_mat[0]

    gl.BindVertexArray(vao)
    defer gl.BindVertexArray(0)
    
    // Send matrices to the shader.
    update_uni_2fv(global_shader, "projection",  proj_mat_ptr)
    update_uni_4fv(global_shader, "translation", trans_mat_ptr)
    
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
