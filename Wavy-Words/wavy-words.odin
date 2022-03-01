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

WINDOW_H	:: 800
WINDOW_W	:: 800
FONT		:: `C:\Windows\Fonts\arialbd.ttf`
FONTSCALE	:: 125
CHARACTER	:: '#'
SENTENCE	:: "Duty calls, 3 o'clock tea!"

update_uni_2fv :: proc( program : u32, var_name : cstring, new_value_ptr : [^] f32) {
    gl.UniformMatrix2fv(gl.GetUniformLocation(program, var_name), 1, gl.TRUE, new_value_ptr)
}

    update_uni_4fv :: proc( program : u32, var_name : cstring, new_value_ptr : [^] f32) {
    gl.UniformMatrix4fv(gl.GetUniformLocation(program, var_name), 1, gl.TRUE, new_value_ptr)
    }

draw_string :: proc( posx, posy : int, str : string) {
}


Character_texture :: struct {
    texID   : u32,
    width   : i32, 
    height  : i32,
    bbox_x  : f32,
    bbox_y  : f32,
    advance : f32,
    bitmap  : [^] byte,
}

rune_to_glyph_texture : map[rune]Character_texture

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

    // Create map of rune to character_texture for printable characters.
    rune_to_glyph_texture = make(map[rune] Character_texture)
    defer delete(rune_to_glyph_texture)
    
    character_scale : f32
    character_scale = tt.ScaleForPixelHeight(&font, FONTSCALE)
    
    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
    
    for r in 32..126 {// The printable ASCII range, per wikipedia.
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
	// Memory leak: the bitmaps should be freed with tt.FreeBitmap... but it's unclear what the second arg of FreeBitmap does.

	// Get bbox values.
	box1, box2, box3, box4 : i32
	tt.GetGlyphBox(&font, glyph_index, &box1, &box2, &box3, &box4)
	//f.println("Debug: rune, raw coords: ", rune(r), box1, box2, box3, box4) // @debug
	raw_ascent, raw_decent, raw_linegap    : i32

	// Get advance and l_bearing.
	raw_advance, raw_l_bearing : i32
	tt.GetGlyphHMetrics(&font, glyph_index, &raw_advance, &raw_l_bearing)
	
	// Scale to font size.
	bbox_x          := character_scale * f32(box1)
	bbox_y          := character_scale * f32(box2)
	advance		:= character_scale * f32(raw_advance)
	l_bearing	:= character_scale * f32(raw_l_bearing)
	//f.println("Debug: rune, scaled coords: ", rune(r), bbox_x, bbox_y) // @debug
	
	id : u32
	gl.GenTextures(1, &id)
	gl.BindTexture(gl.TEXTURE_2D, id)
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
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)	

	ct : Character_texture
	ct.texID   = id
	ct.width   = bm_w
	ct.height  = bm_h
	ct.bbox_x  = bbox_x
	ct.bbox_y  = bbox_y
	ct.advance = advance
	ct.bitmap  = glyph_bitmap
	rune_to_glyph_texture[rune(r)] = ct
    }
    
    //-------------------------------------------------------------
    //Set up a rectangle to have the character texture drawn on it.
    //-------------------------------------------------------------

    // Make the rendered region a rectangle with origin (0,0,0).
    render_rect_w , render_rect_h : f32
    render_rect_w = WINDOW_W
    render_rect_h = WINDOW_H

    proj_mat := [4] f32 {
        1/render_rect_w, 0,
        0, 1/render_rect_h,
    }
    proj_mat_ptr : [^] f32 = &proj_mat[0]
    // Remember to update the pointer in the render loop!

    //------------------------------------------------------------------
    //Tell the GPU about the data, and give it space to draw characters.
    //------------------------------------------------------------------

    VAO : u32
    gl.GenVertexArrays(1, &VAO)
    gl.BindVertexArray(VAO)

    VBO : u32
    gl.GenBuffers(1, &VBO)
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
    // Allocate space to draw a rectangle with the character glyph on it.
    
    // The zero value of a multi pointer is nil (per odin-lang.org/docs/overview).
    gl.BufferData(gl.ARRAY_BUFFER, size_of(f32) * 4*6, nil, gl.DYNAMIC_DRAW)

    // Note: THE LAST ARGUMENT IS IN BYTES, NOT ARRAY POSITION!!! (common bug)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 0 * size_of(f32))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 2 * size_of(f32))
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)

    //-------------------------------------------------------------
    //Compile the vertex and fragment shader.
    //-------------------------------------------------------------

    shader_program : u32
    program_ok: bool;
    /*
      vertex_shader := string(#load("v-basic.glsl"))
    fragment_shader := string(#load("f-basic.glsl"))
    */
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
    renderCharacter :: proc( r : rune, xpos , ypos : f32) -> (advance : f32) {
	char_texture := rune_to_glyph_texture[r]
	w, h : f32
	w = f32(char_texture.width)
	h = f32(char_texture.height)
	x := xpos + char_texture.bbox_x
	y := ypos + char_texture.bbox_y
	
	bufferData := [4 * 6] f32 {
	    x    , y + h, 0, 0,
	    x    , y    , 0, 1,
	    x + w, y    , 1, 1,
	    x    , y + h, 0, 0,
	    x + w, y    , 1, 1,
	    x + w, y + h, 1, 0,
	}

	gl.BindTexture(gl.TEXTURE_2D, char_texture.texID)
	gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(bufferData), &bufferData)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	return char_texture.advance
    }

    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    
    watch : time.Stopwatch
    time.stopwatch_start(&watch)
    
    for !glfw.WindowShouldClose(window) {
        glfw.PollEvents()
	
        translation_mat := [16] f32 {
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
         }

        trans_mat_ptr : [^] f32 = &translation_mat[0]

        // Draw commands.
        gl.BindVertexArray(VAO)
        defer gl.BindVertexArray(0)

        update_uni_2fv(shader_program, "projection", proj_mat_ptr)
        update_uni_4fv(shader_program, "translation", trans_mat_ptr)

        gl.ClearColor(0.1, 0.1, 0.1, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT)

	// Render string.
	x, y, advance: f32
	x = -0.9 * WINDOW_H
	y = 0

	// Add wave effect to the text
	ha, wl : f32 // Half-amplitude, wavelength
	// Call odin run <this file> -define:ha=200 to change this value at compile time.
	ha = #config(ha, 100)
	wl = f32(WINDOW_W) * #config(wl, 0.2)
	    
	raw_duration := time.stopwatch_duration(watch)
        secs := f32(time.duration_seconds(raw_duration))
	t := 3 * secs
	
	for r in SENTENCE {
	    ywave := ha * m.sin(x/wl + t) + y
	    advance = renderCharacter(r, x, ywave)
	    x += advance
	}

	// Send buffer to screen.
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

