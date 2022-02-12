package main

// A function which takes a hex string representing a colour (e.g
// FF00DC and returns the RGB values as a fraction of 1.
//
// Created so colours can be easily specified in OpenGL via hex.

import f "core:fmt"
import s "core:strings"

rgbHexToFractions :: proc( hex_color : int ) -> ( r,g,b : f32) {
	rint := (hex_color & 0x00_FF_00_00) >> 16
	gint := (hex_color & 0x00_00_FF_00) >> 8
	bint := (hex_color & 0x00_00_00_FF) >> 0
	r = f32(rint)/255
	g = f32(gint)/255
	b = f32(bint)/255
	return 
}

main :: proc() {
	hex1 := 0x082011
	r1, g1, b1 := rgbHexToFractions(hex1)
	f.printf("String: %x, floats: %f %f %f\n", hex1, r1, g1, b1)
	hex2 := 0xFF0080
	r2, g2, b2 := rgbHexToFractions(hex2)
	f.printf("String: %x, floats: %f %f %f\n", hex2, r2, g2, b2)
}
