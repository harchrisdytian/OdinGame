package main

import "core:fmt"
import "vendor:glfw"

// import ""
import gl "vendor:OpenGL"
import stb "vendor:stb/image"

import math "core:math/linalg"
import glm "core:math/linalg/glsl"


window: glfw.WindowHandle
program: u32
lightProgram: u32
shader_worked: bool
firstMouse: bool
vao: u32
lightVao: u32
vbo: u32
ebo: u32
texture1: u32
texture2: u32
modelLoc: i32
viewLoc: i32
projectionLoc: i32
showCurser: bool

model: math.Matrix4f32
view: math.Matrix4f32
projection: math.Matrix4f32
cam: Camera
position:glm.vec3

lightPos: glm.vec3

lastFrame, deltaTime,currentFrame :f32

test_model: Scene

lastXpos: f32
lastYpos: f32

// lighting globals
coral : glm.vec3

linear : UniformValue
constant : UniformValue
quadratic :UniformValue

BaseCube : Scene
BaseArch : Scene
ter :terrain

init :: proc() -> glfw.WindowHandle {
	   //coral = {1.0,0.5,0.31}
		   
	   
	   cam.position = {0.0, 0.0, 3.0}
	   cam.worldUp = {0.0, 1.0, 0.0}
	   
	   cam.front = {0.0, 0.0, -1.0}
	   cam.yaw = -90.0
	 	lightPos = {-1.2,1.0,2.0}  
	   //do proc stuff
	   glfw.WindowHint(glfw.RESIZABLE, 1)
	   glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4)
	   glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 6)
	   glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	   
	   // intialize glfw
	   if (glfw.Init() != b32(true)) {
		   
		   fmt.println("glfw fail to init")
		   return nil
		}
		
		_vidMode :^glfw.VidMode=glfw.GetVideoMode(glfw.GetPrimaryMonitor())
		glfw.WindowHint(glfw.RED_BITS,_vidMode.red_bits)
		glfw.WindowHint(glfw.GREEN_BITS,_vidMode.green_bits)
		glfw.WindowHint(glfw.BLUE_BITS,_vidMode.blue_bits)
		glfw.WindowHint(glfw.REFRESH_RATE,_vidMode.refresh_rate)	
		window = glfw.CreateWindow(_vidMode.width, _vidMode.height, "something", glfw.GetPrimaryMonitor(), nil)
		
		glfw.MakeContextCurrent(window)
		glfw.SwapInterval(1)
		glfw.SetFramebufferSizeCallback(window, size_callback)
		glfw.SetKeyCallback(window, key_callback)
		gl.load_up_to(4, 6, glfw.gl_set_proc_address)
		gl.Enable(gl.DEPTH_TEST)
		
		glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED);
		//fmt.println(give_output())
		
		//test_model.models= ModelCreatePath("Models/survival_guitar_backpack.glb")
		test_model.models= ModelCreatePath("Models/baseCube.glb")
		BaseCube.models =  ModelCreatePath("Models/unitbox.glb")
		BaseArch.models =  ModelCreatePath("Models/survival_guitar_backpack.glb")
		//fmt.print(BaseArch)
		//fmt.print(BaseArch)
		
		test_model.transform = glm.mat4Scale({1,1,1}) *0.01
		BaseArch.transform = glm.mat4Scale({1,1,1})
		BaseCube.transform = glm.mat4Scale({1,1,1})
		//test_model.transform = glm.mat4Translate({0.2,2,0.4})
		// for &i in test_model.models{
			// 	setupMesh(&i)
			// }
			
			ter = make_terrain("HeightMaps/hightmap.png")
			setup_scene(&test_model)
			setup_scene(&BaseCube)
			setup_scene(&BaseArch)
		

		program, shader_worked = gl.load_shaders("Shaders/shader1.vert", "Shaders/shader1.frag")
		gl.UseProgram(program)
		if (!shader_worked) {
			fmt.print("reg shader didn't work")
		}
		lightProgram, shader_worked = gl.load_shaders("Shaders/shader2.vert", "Shaders/shader2.frag")
		if(!shader_worked){
			fmt.print("light shder")
		}

	vert_data := [?] f32 { 
		-0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 0.0,
		0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 0.0,
		0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 1.0,
		0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 1.0,
	   -0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 1.0,
	   -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 0.0,
   
	   -0.5, -0.5,  0.5,  0.0,  0.0, 1.0,   0.0, 0.0,
		0.5, -0.5,  0.5,  0.0,  0.0, 1.0,   1.0, 0.0,
		0.5,  0.5,  0.5,  0.0,  0.0, 1.0,   1.0, 1.0,
		0.5,  0.5,  0.5,  0.0,  0.0, 1.0,   1.0, 1.0,
	   -0.5,  0.5,  0.5,  0.0,  0.0, 1.0,   0.0, 1.0,
	   -0.5, -0.5,  0.5,  0.0,  0.0, 1.0,   0.0, 0.0,
   
	   -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0, 0.0,
	   -0.5,  0.5, -0.5, -1.0,  0.0,  0.0,  1.0, 1.0,
	   -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0, 1.0,
	   -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0, 1.0,
	   -0.5, -0.5,  0.5, -1.0,  0.0,  0.0,  0.0, 0.0,
	   -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0, 0.0,
   
		0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0, 0.0,
		0.5,  0.5, -0.5,  1.0,  0.0,  0.0,  1.0, 1.0,
		0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0, 1.0,
		0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0, 1.0,
		0.5, -0.5,  0.5,  1.0,  0.0,  0.0,  0.0, 0.0,
		0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0, 0.0,
   
	   -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0, 1.0,
		0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  1.0, 1.0,
		0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0, 0.0,
		0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0, 0.0,
	   -0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  0.0, 0.0,
	   -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0, 1.0,
   
	   -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0, 1.0,
		0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  1.0, 1.0,
		0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0, 0.0,
		0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0, 0.0,
	   -0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  0.0, 0.0,
	   -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0, 1.0} // top let 

	
	gl.GenVertexArrays(1, &vao)

	gl.GenBuffers(1, &vbo)
	// gl.GenBuffers(1,&ebo)

	gl.BindVertexArray(vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vert_data), &vert_data[0], gl.STATIC_DRAW)


	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 3 * size_of(f32))
	gl.EnableVertexAttribArray(1)	
	gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 6 * size_of(f32))
	gl.EnableVertexAttribArray(2)
	
	gl.GenVertexArrays(1, &lightVao)
	gl.BindVertexArray(lightVao)

	gl.BindBuffer(gl.ARRAY_BUFFER,vbo)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)
	
	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 3 * size_of(f32))
	gl.EnableVertexAttribArray(1)	
	gl.VertexAttribPointer(2, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 6 * size_of(f32))
	gl.EnableVertexAttribArray(2)	

	//color
	texture1 = load_texture("C:/Users/christian hardy/OdinGame/Textures/container2.png")
	fmt.print(texture1)
	texture2 = load_texture("C:/Users/christian hardy/OdinGame/Textures/container2_specular.png")
	//gl.EnableVertexAttribArray(1)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	gl.BindVertexArray(0)
	gl.BindVertexArray(vao)
	gl.UseProgram(lightProgram)
	gl.Uniform1i(gl.GetUniformLocation(lightProgram,"material.diffuse"), 0)
	gl.Uniform1i(gl.GetUniformLocation(lightProgram,"material.specular"), 1)

	position = 1

	//stb.image_free(data)
	model = 1
	view = 1
	projection = 1
	projection = glm.mat4Perspective(f32(math.to_radians(45.0)), 512 / 512, 0.1, 1000)
	model *= glm.mat4Rotate({1, 0.5, 0}, f32(math.to_radians(glfw.GetTime() * 45.0)))
	view = CameraViewMatrix(cam)

	modelLoc = gl.GetUniformLocation(program, "model")
	viewLoc = gl.GetUniformLocation(program, "view")
	projectionLoc = gl.GetUniformLocation(program, "projection")

	gl.UniformMatrix4fv(modelLoc, 1, gl.FALSE, &model[0][0])
	gl.UniformMatrix4fv(viewLoc, 1, gl.FALSE, &view[0][0])
	gl.UniformMatrix4fv(projectionLoc, 1, gl.FALSE, &projection[0][0])

	glfw.SetCursorPosCallback(window, mouse_callback)
	return window


}

end :: proc(window: glfw.WindowHandle) {
	gl.DeleteVertexArrays(1, &vao)
	//gl.DeleteProgram()
	glfw.DestroyWindow(window)
	glfw.Terminate()
}

update :: proc() {
    
    currentFrame = f32(glfw.GetTime())
    deltaTime = currentFrame - lastFrame
    lastFrame = currentFrame
	key := glfw.GetKey(window, glfw.KEY_W)
    movSpeed := 19.5 * deltaTime

	if (glfw.GetKey(window, glfw.KEY_W) == glfw.PRESS ||
		   glfw.GetKey(window, glfw.KEY_UP) == glfw.PRESS) {
		CameraProcessMovement(&cam, .UP,movSpeed)
	}
	if (glfw.GetKey(window, glfw.KEY_D) == glfw.PRESS ||
		   glfw.GetKey(window, glfw.KEY_RIGHT) == glfw.PRESS) {
		CameraProcessMovement(&cam, .RIGHT, movSpeed)
	}
	if (glfw.GetKey(window, glfw.KEY_A) == glfw.PRESS ||
		   glfw.GetKey(window, glfw.KEY_LEFT) == glfw.PRESS) {
		CameraProcessMovement(&cam, .LEFT, movSpeed)
	}
	if (glfw.GetKey(window, glfw.KEY_S) ==
		   glfw.PRESS || glfw.GetKey(window, glfw.KEY_DOWN) ==
		   glfw.PRESS) {
		CameraProcessMovement(&cam, .DOWN, movSpeed)
	}
	if (glfw.GetKey(window,glfw.KEY_SPACE) == glfw.PRESS ) {
		CameraProcessMovement(&cam, .SPACE, movSpeed)

	}
	tempSpeed :f32=1.9
	if (glfw.GetKey(window, glfw.KEY_I) == glfw.PRESS ) {
		spotA.y += tempSpeed * deltaTime
	} 
	if (glfw.GetKey(window, glfw.KEY_K) == glfw.PRESS ) {
		spotA.y -= tempSpeed * deltaTime
	}if (glfw.GetKey(window, glfw.KEY_J) == glfw.PRESS ) {
		spotA.x += tempSpeed * deltaTime
	} 
	if (glfw.GetKey(window, glfw.KEY_L) == glfw.PRESS ) {
		spotA.x -= tempSpeed * deltaTime
	}if (glfw.GetKey(window, glfw.KEY_U) == glfw.PRESS ) {
		spotA.z += tempSpeed * deltaTime
	} 
	if (glfw.GetKey(window, glfw.KEY_O) == glfw.PRESS ) {
		spotA.z -= tempSpeed * deltaTime
	}
	//spotb
	if (glfw.GetKey(window, glfw.KEY_T) == glfw.PRESS ) {
		spotB.y += tempSpeed * deltaTime
	} 
	if (glfw.GetKey(window, glfw.KEY_G) == glfw.PRESS ) {
		spotB.y -= tempSpeed * deltaTime
	}if (glfw.GetKey(window, glfw.KEY_F) == glfw.PRESS ) {
		spotB.x += tempSpeed * deltaTime
	} 
	if (glfw.GetKey(window, glfw.KEY_H) == glfw.PRESS ) {
		spotB.z -= tempSpeed * deltaTime
	}if (glfw.GetKey(window, glfw.KEY_R) == glfw.PRESS ) {
		spotB.z += tempSpeed * deltaTime
	} 
	if (glfw.GetKey(window, glfw.KEY_Y) == glfw.PRESS ) {
		spotB.z -= tempSpeed * deltaTime
	}
}


draw :: proc() {
	gl.ClearColor(0.2, 0.3, 0.3, 1.)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	lightPos.x = 1.0 + f32(math.sin(glfw.GetTime()*2.0))
	lightPos.y = f32(math.sin((glfw.GetTime()/2.0))) * 1.0 

	gl.UseProgram(lightProgram)
	shadder :Shadder
	shadder.mProgram = lightProgram
	
	//draw_scene(test_model,&shadder,lightPos,cam,view,projection)
	//test_model.transform *= glm.mat4Scale({1,1,1})
 
	//new_m := test_model
	//new_m.transform += glm.mat4Translate(position)
	//position.x += 0.07 * deltaTime
	//draw_scene(new_m,&shadder,lightPos,cam,view,projection)
	
	MainLevel(&shadder,lightPos,cam,view,projection,&ter)

	gl.UseProgram(program)

	model = 1.0
	model *= glm.mat4Translate(lightPos)
	scale : glm.vec3=0.3
	//model *= glm.mat4Scale(scale)
	view = CameraViewMatrix(cam)
	gl.UniformMatrix4fv(modelLoc, 1, gl.FALSE, &model[0][0])
	gl.UniformMatrix4fv(viewLoc, 1, gl.FALSE, &view[0][0])
	gl.UniformMatrix4fv(projectionLoc, 1, gl.FALSE, &projection[0][0])

	gl.BindVertexArray(vao)

	gl.DrawArrays(gl.TRIANGLES, 0, 36)
	//fmt.print(projectionLoc)

	//fmt.print("in a loop")
	gl.BindVertexArray(0)
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	if key == glfw.KEY_ESCAPE {
		running = false
	}

	if key == glfw.KEY_TAB
	{
		if(showCurser){
			showCurser = !showCurser
			glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_NORMAL)
		}

	}
}

mouse_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {

	if (!firstMouse) {
		lastXpos = f32(xpos)
		lastYpos = f32(ypos)
		firstMouse = true
	}
	xoffset := f32(xpos) - lastXpos
	yoffset := lastYpos - f32(ypos)

	lastXpos = f32(xpos)
	lastYpos = f32(ypos)

	processCameraMouseMovements(&cam, xoffset, yoffset)

}

size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {

	gl.Viewport(0, 0, width, height)
	projection = glm.mat4Perspective(f32(math.to_radians(45.0)), f32(width) / f32(height), 0.1, 1000)
}

load_texture :: proc (path: cstring ) -> u32 {
	textureID: u32
	gl.GenTextures(1,&textureID)

	width, height, nrComponents :i32
	data := stb.load(path,&width,&height,&nrComponents,0)
	
	if(data != nil){
		format : int
		if(nrComponents == 0)
		{
			format = gl.RED;
		}
		else if(nrComponents == 3){
			format = gl.RGB
		}
		else if(nrComponents == 4){
			format = gl.RGBA
		}
		gl.BindTexture(gl.TEXTURE_2D, textureID);
		gl.TexImage2D(gl.TEXTURE_2D, 0, i32(format), width, height, 0, u32(format), gl.UNSIGNED_BYTE, data);
		gl.GenerateMipmap(gl.TEXTURE_2D)

		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	}else{
		fmt.println("err: loaded image wrong")
		
	}

	return textureID		
}
