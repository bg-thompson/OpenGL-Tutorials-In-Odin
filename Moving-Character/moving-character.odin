// Created by Benjamin Thompson (github: bg-thompson)
// Last updated: 2022.03.01
// Created for educational purposes. Used verbatim, it is
// probably unsuitable for production code.

package main

import "vendor:glfw"
import gl "vendor:OpenGL"
import tt "vendor:stb/truetype"
import "core:time"
import f "core:fmt"
import m "core:math"
import   "core:os"

WINDOW_H :: 800
WINDOW_W :: 800
FONT     :: `C:\Windows\Fonts\arialbd.ttf`
CHARACTER:: '@'
FONTSCALE:: 100

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

    window := glfw.CreateWindow(WINDOW_W, WINDOW_H, "Character Render", nil, nil)
    assert(window != nil)
    defer glfw.DestroyWindow(window)
    
    glfw.MakeContextCurrent(window)
    glfw.SwapInterval(1)

    // Load OpenGL 3.3 function pointers. VERY IMPORTANT!!!
    gl.load_up_to(3,3, glfw.gl_set_proc_address)

    w_window, h_window := glfw.GetFramebufferSize(window)
    gl.Viewport(0,0,w_window, h_window)

    // Key press / Window-resize behaviour
    glfw.SetKeyCallback(window, callback_key)
    glfw.SetFramebufferSizeCallback(window, callback_size)
    
    //-------------------------------------------------------------
    //Set up a rectangle to have the character texture drawn on it.
    //-------------------------------------------------------------

    h, w : f32
    h = 300
    w = 300

    rect_verts : [6 * 4] f32 
    rect_verts = { // rect coords : vec2, texture coords : vec2
    0, h,     0, 0,
    0, 0,    0, 1,
    w, 0,    1, 1,
    0, h,    0, 0,
    w, 0,    1, 1,
    w, h,     1, 0,
    }

    // Make the rendered region a rectangle with origin (0,0,0).
    render_rect_w , render_rect_h : f32
    render_rect_w = WINDOW_W
    render_rect_h = WINDOW_H

    proj_mat := [4] f32 {
        1/render_rect_w, 0,
        0, 1/render_rect_h,
    }
    proj_mat_ptr : [^] f32 = &proj_mat[0]
    // Remember to update this in the render loop!

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

    VAO : u32
    gl.GenVertexArrays(1, &VAO)
    gl.BindVertexArray(VAO)

    VBO : u32
    gl.GenBuffers(1, &VBO)
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(rect_verts), &rect_verts, gl.STATIC_DRAW)

    // Position and color attributes. DON'T FORGET TO ENABLE!!!
    // Even more importantly... THE LAST ARGUMENT IS IN BYTES, NOT ARRAY POSITION!!!
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 0 * size_of(f32))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 2 * size_of(f32))
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
    Glyph_texture : u32
    gl.GenTextures(1, &Glyph_texture)
    gl.BindTexture(gl.TEXTURE_2D, Glyph_texture)

    gl.TexImage2D(
        gl.TEXTURE_2D,
        0,
        gl.RED,
        bitmap_w,
        bitmap_h,
        0,
        gl.RED,
        gl.UNSIGNED_BYTE,
        glyph_bitmap,
    )
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)


    //-------------------------------------------------------------
    //Compile the vertex and fragment shader.
    //-------------------------------------------------------------

    shader_program : u32
    program_ok: bool;

      vertex_shader := string(#load("vertex.glsl"))
    fragment_shader := string(#load("fragment.glsl"))

    shader_program, program_ok = gl.load_shaders_source(vertex_shader, fragment_shader);

    if !program_ok {
        f.println("failed to load and compiler shaders"); os.exit(1)
    }

    gl.UseProgram(shader_program)

    //-------------------------------------------------------------
    //Render the character!
    //-------------------------------------------------------------

    // Rotate the character over time.
    watch : time.Stopwatch
    time.stopwatch_start(&watch)

    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

    for !glfw.WindowShouldClose(window) {
        glfw.PollEvents()

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

        // Draw commands.
        gl.BindVertexArray(VAO)
        defer gl.BindVertexArray(0)
        gl.BindTexture(gl.TEXTURE_2D, Glyph_texture)


        update_uni_2fv(shader_program, "projection", proj_mat_ptr)
        update_uni_4fv(shader_program, "translation", trans_mat_ptr)

        gl.ClearColor(0.1, 0.1, 0.1, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        // First arg: vertex array starting index, Last arg: how many vertices to draw.
        gl.DrawArrays(gl.TRIANGLES, 0, 6)
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

