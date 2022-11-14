// A simple program in Odin which renders a sentence and animates
// it like a wave.
//
// Created by Benjamin Thompson. Available at:
// https://github.com/bg-thompson/OpenGL-Tutorials-In-Odin
// Last updated: 2022.11.14
//
// To compile and run the program, use the command
//
//     odin run Wavy-Words
//
// Created for educational purposes. Used verbatim, it is probably
// unsuitable for production code.

package main

import    "vendor:glfw"
import gl "vendor:OpenGL"
import tt "vendor:stb/truetype"
import    "core:time"
import    "core:math"
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
WINDOW_H        :: 800
WINDOW_W        :: 800
FONT            :: `C:\Windows\Fonts\arialbd.ttf`
FONTSCALE       :: 125
CHARACTER       :: '#'
SENTENCE        :: "Duty calls, 3 o'clock tea!"

// Information needed to render a single letter.
CharacterTexture :: struct {
    texID   : u32,
    width   : i32, 
    height  : i32,
    bbox_x  : f32,
    bbox_y  : f32,
    advance : f32,
    bitmap  : [^] byte,
}

rune_to_glyph_texture : map[rune]CharacterTexture

update_uni_2fv :: proc( program : u32, var_name : cstring, new_value_ptr : [^] f32) {
    gl.UniformMatrix2fv(gl.GetUniformLocation(program, var_name), 1, gl.TRUE, new_value_ptr)
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

    window := glfw.CreateWindow(WINDOW_W, WINDOW_H, "Wavy Words", nil, nil)
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
    // Create texture maps for printable ascii characters (32-126)
    //-------------------------------------------------------------

    // Load .ttf file
    ttf_buffer :: [1<<23] u8 // Assumes file < 8MB
    fontdata, succ := os.read_entire_file(FONT)
    if !succ {
        f.println("ERROR: Couldn't load font file: ", FONT)
        os.exit(1)
    }
    font_ptr : [^] u8 = &fontdata[0]

    // Initialize font for stb_truetype
    font : tt.fontinfo
    tt.InitFont(
        info   = &font,
        data   = font_ptr,
        offset = 0,
    )

    // Create rune to character_texture map for printable characters.
    rune_to_glyph_texture = make(map[rune] CharacterTexture)
    defer delete(rune_to_glyph_texture)
    
    character_scale : f32
    character_scale = tt.ScaleForPixelHeight(&font, FONTSCALE)
    
    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
    
    for r in 32..=126 {// The printable ASCII range, per wikipedia.
        bm_w, bm_h, xo, yo : i32
        glyph_index := tt.FindGlyphIndex(&font, rune(r))
        glyph_bitmap := tt.GetGlyphBitmap(
            info    = &font,
            scale_x = 0,
            scale_y = character_scale,
            glyph   = glyph_index,
            width   = &bm_w,
            height  = &bm_h,
            xoff    = &xo,
            yoff    = &yo,
        )
        // Memory leak: the bitmaps should be freed with tt.FreeBitmap...
        // ...but it is unclear what the second arg of FreeBitmap does.

        // Get bbox values.
        box1, box2, box3, box4 : i32
        tt.GetGlyphBox(&font, glyph_index, &box1, &box2, &box3, &box4)

        // Get advance and l_bearing.
        raw_advance, raw_l_bearing : i32
        tt.GetGlyphHMetrics(&font, glyph_index, &raw_advance, &raw_l_bearing)
        
        // Scale to font size.
        bbox_x          := character_scale * f32(box1)
        bbox_y          := character_scale * f32(box2)
        advance         := character_scale * f32(raw_advance)
        l_bearing       := character_scale * f32(raw_l_bearing)

        // Register glyph texture with GPU.
        texture_id : Texture
        gl.GenTextures(1, &texture_id)
        // Note: textures are so small, we can load all of them instead
        // of the ones we need.
        gl.BindTexture(gl.TEXTURE_2D, texture_id)

        // Describe textures.
        gl.TexImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RED,
            bm_w,
            bm_h,
            0,
            gl.RED,
            gl.UNSIGNED_BYTE,
            glyph_bitmap,
        )

        // Wrapping and filtering options.
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)       

        // Save vital texture information for use when rendering the sentence.
        ct : CharacterTexture
        ct.texID   = texture_id
        ct.width   = bm_w
        ct.height  = bm_h
        ct.bbox_x  = bbox_x
        ct.bbox_y  = bbox_y
        ct.advance = advance
        ct.bitmap  = glyph_bitmap
        rune_to_glyph_texture[rune(r)] = ct
    }

    //------------------------------------------------------------------
    //Tell the GPU about the data, and give it space to draw characters.
    //------------------------------------------------------------------
    
    gl.GenVertexArrays(1, &global_vao)
    gl.BindVertexArray(global_vao)

    vbo : VBO
    gl.GenBuffers(1, &vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    
    // Allocate space to draw a rectangle with the character glyph on it.
    
    // The zero value of a multi pointer is nil (per odin-lang.org/docs/overview).
    gl.BufferData(gl.ARRAY_BUFFER,      
                  size_of(f32) * 4*6,  // Two triangles per letter.
                  nil,                 // No vertex data, yet.
                  gl.DYNAMIC_DRAW)     // Expect the data to be updated.

    // Position / texture position attributes. Don't forget to enable!
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 0 * size_of(f32))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 2 * size_of(f32))
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)

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
    //Render a character!
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

    // Draw commands.
    gl.BindVertexArray(vao)
    defer gl.BindVertexArray(0)

    update_uni_2fv(global_shader, "projection", proj_mat_ptr)

    gl.ClearColor(0.1, 0.1, 0.1, 1)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    // Render SENTENCE.
    x, y, advance: f32
    x = -0.9 * WINDOW_H
    y = 0

    // Add wave effect to the text
    ha, wl : f32 // Half-amplitude, wavelength
    // Call
    //
    //     odin run Wavy-Words -define:ha=200
    //
    // to change this value at compile time.
    ha =                 #config(ha, 100)
    wl = f32(WINDOW_W) * #config(wl, 0.2)
    
    raw_duration := time.stopwatch_duration(watch)
    secs := f32(time.duration_seconds(raw_duration))
    t := 3 * secs

    // Render letters in SENTENCE.
    // Note that render_character calls gl.DrawArrays, and in general
    // gl.DrawArrays calls should be minimized if possible. In our
    // case the sentence is small enough that it's fine to call it
    // several times.
    for r in SENTENCE {
        ywave := ha * math.sin(x/wl + t) + y
        advance = render_character(r, x, ywave, vao)
        x += advance
    }

    // Send buffer to screen.
    glfw.SwapBuffers(window)
}

render_character :: proc( r : rune, xpos , ypos : f32, vao : VAO) -> (advance : f32) {
    char_texture : CharacterTexture
    char_texture = rune_to_glyph_texture[r]
    w := f32(char_texture.width)
    h := f32(char_texture.height)
    x := xpos + char_texture.bbox_x
    y := ypos + char_texture.bbox_y
    
    character_vertices : [4 * 6] f32 = {
        // Position ; Texture Coords
        x    , y + h, 0, 0,
        x    , y    , 0, 1,
        x + w, y    , 1, 1,
        x    , y + h, 0, 0,
        x + w, y    , 1, 1,
        x + w, y + h, 1, 0,
    }

    gl.BindVertexArray(vao)
    gl.BindTexture(gl.TEXTURE_2D, char_texture.texID)
    gl.BufferSubData(gl.ARRAY_BUFFER,               // update vertices
                     0,                             // offset
                     size_of(character_vertices),   // size
                     &character_vertices)           // data
    // Draw the character!
    gl.DrawArrays(gl.TRIANGLES, 0, 6)
    advance = char_texture.advance
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
