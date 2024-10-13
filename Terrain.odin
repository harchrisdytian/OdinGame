package main

import "core:fmt"
import gl "vendor:OpenGL"
import math "core:math/linalg"
import stb "vendor:stb/image"
import glm "core:math/linalg/glsl"



terrain :: struct{
	model: UniformValue,
	view: UniformValue,
	projection:UniformValue,
	VAO:u32,
	num_strips:u32,
	num_verts_per_strip:u32,
	program:u32
}

make_terrain :: proc(hight_map_name :cstring) -> (ter : terrain)  
{
	
	width, height, nrComponents :i32
	height_map := stb.load(hight_map_name,&width,&height,&nrComponents,0)
	defer{ stb.image_free(height_map)}
	verts : [dynamic]f32
	indices : [dynamic]u32
	fmt.printf("1")
	//fmt.println(err)
	for x in 0..< height {
		for y in 0..<width {
			altitude := f32(height_map[(y + width * x ) * nrComponents])

			append(&verts, f32(f32(-height)/2.0 + f32(height) * f32(x) / f32(height)))
			append(&verts, f32(altitude  - 16.0))
			append(&verts, f32(f32(-width)/2.0 + f32(width) * f32(y) / f32(width)))
		}
	} 


	for i in 0..<height-1 {
		for j in 0..<width {
			for k in 0..=3{
				append(&indices,u32(j + width * (i + i32(k))))
			}
		}
	}
	fmt.printf("2")

	NUM_STRIPS :u32= u32(height-1)
	NUM_VERTS_PER_STRIP :u32=  u32(width*2)
	fmt.printf("3")

	terrainVAO:u32
	terrainVBO:u32
	terrainEBO:u32

	gl.GenVertexArrays(1, &terrainVAO)
	fmt.printf("4")
	gl.BindVertexArray(terrainVAO)
	
	gl.GenBuffers(1, &terrainVBO)
	gl.BindBuffer(gl.ARRAY_BUFFER, terrainVBO)
	gl.BufferData(gl.ARRAY_BUFFER,
		len(verts) * size_of(f32),       // size of vertices buffer
		&verts[0],                          // pointer to first element
		gl.STATIC_DRAW)
		fmt.printf("5")

	// position attribute
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 0, 0);
	gl.EnableVertexAttribArray(0);

	gl.GenBuffers(1, &terrainEBO);
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, terrainEBO);
	gl.BufferData(
				gl.ELEMENT_ARRAY_BUFFER,
	             len(indices)* size_of(u32), // size of indices buffer
	             &indices[0],                           // pointer to first element
	             gl.STATIC_DRAW);

	gl.BindVertexArray(terrainVAO);
	ter.program, shader_worked = gl.load_shaders("Shaders/TerrainShader.vert","Shaders/TerrainShader.frag")
	
	if(!shader_worked){
		fmt.print("ERR: terrain shader failed to load")
	}
	// render the mesh triangle strip by triangle strip - each row at a time
	ter.VAO = terrainVAO
	ter.num_strips = NUM_STRIPS
	ter.num_verts_per_strip = NUM_VERTS_PER_STRIP
	return ter
}	

draw_terrain:: proc(
	model: glm.mat4,
	view: glm.mat4,
	projection: glm.mat4,
	ter:^terrain)
{
	gl.UseProgram(ter.program)
	ter.model = UniformValue_make(ter.program,"model",model)
	ter.view = UniformValue_make(ter.program,"view",view)
	ter.projection = UniformValue_make(ter.program,"projection",projection)
	UniformValue_set(ter.model)
	UniformValue_set(ter.view)
	UniformValue_set(ter.projection)

	gl.BindVertexArray(ter.VAO)
	for  strip in 0..= ter.num_strips
	{
	    gl.DrawElements(gl.TRIANGLE_STRIP,   // primitive type
	                   i32(ter.num_verts_per_strip), // number of indices to render
	                   gl.UNSIGNED_INT,     // index data type
	                   rawptr(uintptr(size_of(u32) * ter.num_verts_per_strip * strip))) // offset to starting index
	}
}