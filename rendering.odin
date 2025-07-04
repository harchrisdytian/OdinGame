package main

import "base:runtime"
import "core:fmt"
import "core:slice"
import "vendor:glfw"
// import ""
import math "core:math/linalg"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import stb "vendor:stb/image"
import vk "vendor:vulkan"

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
ctx: runtime.Context

model: math.Matrix4f32
view: math.Matrix4f32
projection: math.Matrix4f32
cam: Camera
position: glm.vec3

lightPos: glm.vec3

lastFrame, deltaTime, currentFrame: f32
test_model: Scene

lastXpos: f32
lastYpos: f32

// lighting globals
coral: glm.vec3

linear: UniformValue
constant: UniformValue
quadratic: UniformValue

BaseCube: Scene
BaseArch: Scene
ter: terrain

SWAP_FRAMES :: 2


GAME_TITLE :: "The Projector"
DEFAULT_WIDTH :: 800
DEFAULT_HEIGHT :: 600
// Vulkan Type Defines

FRAG :: #load("Shaders/vfrag.spv")
VERT :: #load("Shaders/vVert.spv")

v_frame_id: u32
v_shader_stages: [2]vk.PipelineShaderStageCreateInfo
v_appInfo: vk.ApplicationInfo
v_createInfo: vk.InstanceCreateInfo
v_instance: vk.Instance
v_physicalDevice: vk.PhysicalDevice
v_device: vk.Device
v_surface: vk.SurfaceKHR
v_queue_familiy_indicies: [queue_families]int
v_queues: [queue_families]vk.Queue
v_swapchain: Swapchain
v_render_pass: vk.RenderPass
v_pipline_layout: vk.PipelineLayout
v_pipline: vk.Pipeline
v_command_pool: vk.CommandPool
v_command_buffer: [SWAP_FRAMES]vk.CommandBuffer
v_image_available: [SWAP_FRAMES]vk.Semaphore
v_signal_semaphore: [SWAP_FRAMES]vk.Semaphore
v_fence: [SWAP_FRAMES]vk.Fence


Swapchain :: struct {
	handle:        vk.SwapchainKHR,
	images:        []vk.Image,
	image_views:   []vk.ImageView,
	format:        vk.SurfaceFormatKHR,
	extent:        vk.Extent2D,
	present_mode:  vk.PresentModeKHR,
	image_count:   u32,
	support:       SwapchainDetails,
	frame_buffers: []vk.Framebuffer,
}

SwapchainDetails :: struct {
	capabilities: vk.SurfaceCapabilitiesKHR,
	format:       []vk.SurfaceFormatKHR,
	present_mode: []vk.PresentModeKHR,
}

queue_families :: enum {
	GRAPHICS,
	PRESENT,
}


CheckVK :: proc(Res :vk.Result, Description:string="something") {
    if(Res != vk.Result.SUCCESS)
    {
	fmt.print("failed to do {}")
    }
}


DEVICE_FEATURES := [?]cstring{vk.KHR_SWAPCHAIN_EXTENSION_NAME}
VALIDATION_lAYERS := [?]cstring{"VK_LAYER_KHRONOS_validation" }
init :: proc() -> glfw.WindowHandle {

	if (glfw.Init() && glfw.VulkanSupported()) {

		for &que in &v_queue_familiy_indicies do que = -1

		glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)

		v_appInfo.sType = vk.StructureType.APPLICATION_INFO
		v_appInfo.apiVersion = vk.API_VERSION_1_3
		v_appInfo.pEngineName = "hardy engine"
		v_appInfo.engineVersion = vk.MAKE_VERSION(0, 0, 1)
		v_appInfo.applicationVersion = vk.MAKE_VERSION(0, 0, 1)

		v_createInfo.sType = vk.StructureType.INSTANCE_CREATE_INFO
		v_createInfo.pApplicationInfo = &v_appInfo

		glfwExt := slice.clone_to_dynamic(
			glfw.GetRequiredInstanceExtensions(),
			context.temp_allocator,
		)

		monitor := glfw.GetVideoMode(glfw.GetPrimaryMonitor())
		window = glfw.CreateWindow(
			DEFAULT_WIDTH,
			DEFAULT_HEIGHT,
			GAME_TITLE,
			glfw.GetPrimaryMonitor(),
			nil,
		)

		ctx = context
		// initilze vulkan
		vk.load_proc_addresses_global(rawptr(glfw.GetInstanceProcAddress))
		assert(vk.CreateInstance != nil, "vulkan function pointers not loaded") // enableing vulkan debuggin 

		when ODIN_DEBUG 
		{
			layerCount: u32
			vk.EnumerateInstanceLayerProperties(&layerCount, nil)
			layers := make([]vk.LayerProperties, layerCount)
			vk.EnumerateInstanceLayerProperties(&layerCount, raw_data(layers))
			check := false


			append(&glfwExt, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)

			for name in VALIDATION_lAYERS {
				for layer in layers {
					NamedLayer := layer.layerName
					if name == cstring(raw_data(NamedLayer[:])) {
						check = true
						fmt.print("found")
					}
				}
				if (!check) {
					fmt.eprint("ERROR: validation line not available: ", name)
				}
				//os.exit(1)

			}
			severity: vk.DebugUtilsMessageSeverityFlagsEXT
			severity |= {.INFO}
			severity |= {.WARNING}
			severity |= {.VERBOSE}
			severity |= {.ERROR}
			dgb_createInfo: vk.DebugUtilsMessengerCreateInfoEXT
			dgb_createInfo.sType = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT
			dgb_createInfo.messageSeverity = severity
			dgb_createInfo.messageType = {
				.GENERAL,
				.VALIDATION,
				.PERFORMANCE,
				.DEVICE_ADDRESS_BINDING,
			}
			dgb_createInfo.pfnUserCallback = vk_messenger_callback
			v_createInfo.ppEnabledLayerNames = &VALIDATION_lAYERS[0]
			v_createInfo.enabledLayerCount = len(VALIDATION_lAYERS)

			v_createInfo.pNext = &dgb_createInfo
		} else {
			v_createInfo.enabledLayerCount = 0
		}

		v_createInfo.ppEnabledExtensionNames = raw_data(glfwExt)
		v_createInfo.enabledExtensionCount = cast(u32)len(glfwExt)
		vk.load_proc_addresses(rawptr(glfw.GetInstanceProcAddress))

		//vk.ProcEnumeratePhysicalDevices = glfw.GetInstanceProcAddress(v_instance, "vkGetDeviceProcAddr")

		if (vk.CreateInstance(&v_createInfo, nil, &v_instance) != vk.Result.SUCCESS) {
			fmt.eprint("ERROR: failed to create instance")
		}

		vk.load_proc_addresses_instance(v_instance)
		res := glfw.CreateWindowSurface(v_instance, window, nil, &v_surface)

		count: u32
		if (vk.EnumeratePhysicalDevices(v_instance, &count, nil) != vk.Result.SUCCESS) {
			fmt.eprint("ERROR: can't enummerate the physical device")
		}

		if (count == 0) {
			fmt.eprint("ERROR: there is no physical device")
		}

		v_physicalDevices := make([]vk.PhysicalDevice, count)
		vk.EnumeratePhysicalDevices(v_instance, &count, &v_physicalDevices[0])

		v_physicalDevice = v_physicalDevices[0]
		fmt.print(v_physicalDevice)
		when ODIN_DEBUG {
			deviceProperties: vk.PhysicalDeviceProperties
			vk.GetPhysicalDeviceProperties(v_physicalDevice, &deviceProperties)
			// TODO: check for device properties as needed :)
		}

		if (res != vk.Result.SUCCESS) {
			fmt.eprint("ERROR: failed to create Surface", res)

		}

		find_queue_family()

		create_device()

		//find queuse
		for &que, f in &v_queues {
			vk.GetDeviceQueue(v_device, u32(v_queue_familiy_indicies[f]), 0, &que)
		}


		create_swapchain()

		create_renderpass()
		
		create_command_pool()
		create_sync_object()
	
    } else {
		//   cam.position = {0.0, 0.0, 3.0}
		//    cam.worldUp = {0.0, 1.0, 0.0}

		//    cam.front = {0.0, 0.0, -1.0}
		//    cam.yaw = -90.0
		//  	lightPos = {-1.2,1.0,2.0}
		//    //do proc stuff
		//    glfw.WindowHint(glfw.RESIZABLE, 1)
		//    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4)
		//    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 6)
		//    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

		//    // intialize glfw
		//    if (glfw.Init() != b32(true)) {

		// 	   fmt.println("glfw fail to init")
		// 	   return nil
		// 	}

		// 	_vidMode :^glfw.VidMode=glfw.GetVideoMode(glfw.GetPrimaryMonitor())
		// 	glfw.WindowHint(glfw.RED_BITS,_vidMode.red_bits)
		// 	glfw.WindowHint(glfw.GREEN_BITS,_vidMode.green_bits)
		// 	glfw.WindowHint(glfw.BLUE_BITS,_vidMode.blue_bits)
		// 	glfw.WindowHint(glfw.REFRESH_RATE,_vidMode.refresh_rate)
		// 	window = glfw.CreateWindow(_vidMode.width, _vidMode.height, "something", glfw.GetPrimaryMonitor(), nil)

		// 	glfw.MakeContextCurrent(window)
		// 	glfw.SwapInterval(1)
		// 	glfw.SetFramebufferSizeCallback(window, size_callback)
		// 	glfw.SetKeyCallback(window, key_callback)
		// 	gl.load_up_to(4, 6, glfw.gl_set_proc_address)
		// 	gl.Enable(gl.DEPTH_TEST):0

		// 	size_callback(window,_vidMode.width,_vidMode.height)

		// 	glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED);
		// 	glfw.SetCharCallback(window,GUI_charCallBack)
		// 	//fmt.println(give_output())

		// 	//test_model.models= ModelCreatePath("Models/survival_guitar_backpack.glb")
		// 	test_model.models= ModelCreatePath("Models/baseCube.glb")
		// 	BaseCube.models =  ModelCreatePath("Models/unitbox.glb")
		// 	BaseArch.models =  ModelCreatePath("Models/survival_guitar_backpack.glb")
		// 	//fmt.print(BaseArch)
		// 	//fmt.print(BaseArch)

		// 	test_model.transform = glm.mat4Scale({1,1,1}) *0.01
		// 	BaseArch.transform = glm.mat4Scale({1,1,1})
		// 	BaseCube.transform = glm.mat4Scale({1,1,1})
		// 	//test_model.transform = glm.mat4Translate({0.2,2,0.4})
		// 	// for &i in test_model.models{
		// 		// 	setupMesh(&i)
		// 		// }

		// 		ter = make_terrain("HeightMaps/hightmap.png")
		// 		setup_scene(&test_model)
		// 		setup_scene(&BaseCube)
		// 		setup_scene(&BaseArch)


		// 	program, shader_worked = gl.load_shaders("Shaders/shader1.vert", "Shaders/shader1.frag")
		// 	gl.UseProgram(program)
		// 	if (!shader_worked) {
		// 		fmt.print("reg shader didn't work")
		// 	}
		// 	lightProgram, shader_worked = gl.load_shaders("Shaders/shader2.vert", "Shaders/shader2.frag")
		// 	if(!shader_worked){
		// 		fmt.print("light shder")
		// 	}
		// vert_data := [?] f32 {
		// 	-0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 0.0,
		// 	0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 0.0,
		// 	0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 1.0,
		// 	0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 1.0,:0:
		//    -0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 1.0,
		//    -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 0.0,

		//    -0.5, -0.5,  0.5,  0.0,  0.0, 1.0,   0.0, 0.0,
		// 	0.5, -0.5,  0.5,  0.0,  0.0, 1.0,   1.0, 0.0,
		// 	0.5,  0.5,  0.5,  0.0,  0.0, 1.0,   1.0, 1.0,
		// 	0.5,  0.5,  0.5,  0.0,  0.0, 1.0,   1.0, 1.0,
		//    -0.5,  0.5,  0.5,  0.0,  0.0, 1.0,   0.0, 1.0,
		//    -0.5, -0.5,  0.5,  0.0,  0.0, 1.0,   0.0, 0.0,

		//    -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0, 0.0,
		//    -0.5,  0.5, -0.5, -1.0,  0.0,  0.0,  1.0, 1.0,
		//    -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0, 1.0,
		//    -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0, 1.0,
		//    -0.5, -0.5,  0.5, -1.0,  0.0,  0.0,  0.0, 0.0,
		//    -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0, 0.0,

		// 	0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0, 0.0,
		// 	0.5,  0.5, -0.5,  1.0,  0.0,  0.0,  1.0, 1.0,
		// 	0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0, 1.0,
		// 	0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0, 1.0,
		// 	0.5, -0.5,  0.5,  1.0,  0.0,  0.0,  0.0, 0.0,
		// 	0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0, 0.0,

		//    -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0, 1.0,
		// 	0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  1.0, 1.0,
		// 	0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0, 0.0,
		// 	0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0, 0.0,
		//    -0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  0.0, 0.0,
		//    -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0, 1.0,

		//    -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0, 1.0,
		// 	0terraintessellation.5,  0.5, -0.5,  0.0,  1.0,  0.0,  1.0, 1.0,
		// 	0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0, 0.0,
		// 	0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0, 0.0,
		//    -0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  0.0, 0.0,
		//    -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0, 1.0} // top let


		// gl.GenVertexArrays(1, &vao)

		// gl.GenBuffers(1, &vbo)
		// // gl.GenBuffers(1,&ebo)

		// gl.BindVertexArray(vao)

		// gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
		// gl.BufferData(gl.ARRAY_BUFFER, size_of(vert_data), &vert_data[0], gl.STATIC_DRAW)


		// gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 0)
		// gl.EnableVertexAttribArray(0)
		// gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 3 * size_of(f32))
		// gl.EnableVertexAttribArray(1)
		// gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 6 * size_of(f32))
		// gl.EnableVertexAttribArray(2)

		// gl.GenVertexArrays(1, &lightVao)
		// gl.BindVertexArray(lightVao)

		// gl.BindBuffer(gl.ARRAY_BUFFER,vbo)
		// gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 0)
		// gl.EnableVertexAttribArray(0)

		// gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 3 * size_of(f32))
		// gl.EnableVertexAttribArray(1)
		// gl.VertexAttribPointer(2, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 6 * size_of(f32))
		// gl.EnableVertexAttribArray(2)

		// //color
		// texture1 = load_texture("C:/Users/christian hardy/OdinGame/Textures/container2.png")
		// fmt.print(texture1)
		// texture2 = load_texture("C:/Users/christian hardy/OdinGame/Textures/container2_specular.png"))
		// //gl.EnableVertexAttribArray(1)
		// gl.BindBuffer(gl.ARRAY_BUFFER, 0)

		// gl.BindVertexArray(0)
		// gl.BindVertexArray(vao)
		// gl.UseProgram(lightProgram)
		// gl.Uniform1i(gl.GetUniformLocation(lightProgram,"material.diffuse"), 0)
		// gl.Uniform1i(gl.GetUniformLocation(lightProgram,"material.specular"), 1)

		// position = 1

		// //stb.image_free(data)
		// model = 1
		// view = 1
		// projection = 1
		// projection = glm.mat4Perspective(f32(math.to_radians(45.0)), 512 / 512, 0.1, 1000)
		// model *= glm.mat4Rotate({1, 0.5, 0}, f32(math.to_radians(glfw.GetTime() * 45.0)))
		// view = CameraViewMatrix(cam)

		// modelLoc = gl.GetUniformLocation(program, "model")
		// viewLoc = gl.GetUniformLocation(program, "view")
		// projectionLoc = gl.GetUniformLocation(program, "projection")

		// gl.UniformMatrix4fv(modelLoc, 1, gl.FALSE, &model[0][0])
		// gl.UniformMatrix4fv(viewLoc, 1, gl.FALSE, &view[0][0])
		// gl.UniformMatrix4fv(projectionLoc, 1, gl.FALSE, &projection[0][0])

		// glfw.SetCursorPosCallback(window, mouse_callback)

		// gui_init()

		// return window
	}
	return nil
}

end :: proc(window: glfw.WindowHandle) {
	gl.DeleteVertexArrays(1, &vao)
	//gl.DeleteProgram()
	glfw.DestroyWindow(window)
	glfw.Terminate()

}

update :: proc() {
	if GUI.state.isInDebugMode {
		return
	}

	currentFrame = f32(glfw.GetTime())
	deltaTime = currentFrame - lastFrame
	lastFrame = currentFrame
	key := glfw.GetKey(window, glfw.KEY_W)
	movSpeed := 19.5 * deltaTime
	return

	// TODO: replace with the same things

	// if (glfw.GetKey(window, glfw.KEY_W) == glfw.PRESS ||
	// 	   glfw.GetKey(window, glfw.KEY_UP) == glfw.PRESS) {
	// 	CameraProcessMovement(&cam, .UP,movSpeed)
	// }
	// if (glfw.GetKey(window, glfw.KEY_D) == glfw.PRESS ||
	// 	   glfw.GetKey(window, glfw.KEY_RIGHT) == glfw.PRESS) {
	// 	CameraProcessMovement(&cam, .RIGHT, movSpeed)
	// }
	// if (glfw.GetKey(window, glfw.KEY_A) == glfw.PRESS ||
	// 	   glfw.GetKey(window, glfw.KEY_LEFT) == glfw.PRESS) {
	// 	CameraProcessMovement(&cam, .LEFT, movSpeed)
	// }
	// if (glfw.GetKey(window, glfw.KEY_S) ==
	// 	   glfw.PRESS || glfw.GetKey(window, glfw.KEY_DOWN) ==
	// 	   glfw.PRESS) {
	// 	CameraProcessMovement(&cam, .DOWN, movSpeed)
	// }
	// if (glfw.GetKey(window,glfw.KEY_SPACE) == glfw.PRESS ) {
	// 	CameraProcessMovement(&cam, .SPACE, movSpeed)

	// }

	// tempSpeed :f32=1.9
	// if (glfw.GetKey(window, glfw.KEY_I) == glfw.PRESS ) {
	// 	spotA.y += tempSpeed * deltaTime
	// }
	// if (glfw.GetKey(window, glfw.KEY_K) == glfw.PRESS ) {
	// 	spotA.y -= tempSpeed * deltaTime
	// }if (glfw.GetKey(window, glfw.KEY_J) == glfw.PRESS ) {
	// 	spotA.x += tempSpeed * deltaTime
	// }
	// if (glfw.GetKey(window, glfw.KEY_L) == glfw.PRESS ) {
	// 	spotA.x -= tempSpeed * deltaTime
	// }if (glfw.GetKey(window, glfw.KEY_U) == glfw.PRESS ) {
	// 	spotA.z += tempSpeed * deltaTime
	// }
	// if (glfw.GetKey(window, glfw.KEY_O) == glfw.PRESS ) {
	// 	spotA.z -= tempSpeed * deltaTime
	// }
	// //spotb
	// if (glfw.GetKey(window, glfw.KEY_T) == glfw.PRESS ) {
	// 	spotB.y += tempSpeed * deltaTime
	// }
	// if (glfw.GetKey(window, glfw.KEY_G) == glfw.PRESS ) {
	// 	spotB.y -= tempSpeed * deltaTime
	// }if (glfw.GetKey(window, glfw.KEY_F) == glfw.PRESS ) {
	// 	spotB.x += tempSpeed * deltaTime
	// }
	// if (glfw.GetKey(window, glfw.KEY_H) == glfw.PRESS ) {
	// 	spotB.z -= tempSpeed * deltaTime
	// }if (glfw.GetKey(window, glfw.KEY_R) == glfw.PRESS ) {
	// 	spotB.z += tempSpeed * deltaTime
	// }
	// if (glfw.GetKey(window, glfw.KEY_Y) == glfw.PRESS ) {
	// 	spotB.z -= tempSpeed * deltaTime
	// }
}


draw :: proc() {
    vk.WaitForFences(v_device, 1, &v_fence[v_frame_id], true, max(u64))
    image_index: u32
    vk.ResetFences(v_device, 1, &v_fence[v_frame_id])

    res := vk.AcquireNextImageKHR(
	    v_device,
	    v_swapchain.handle,
	    max(u64),
	    v_image_available[v_frame_id],
	    {},
	    &image_index,
    )

    #partial switch res 
    {
    case vk.Result.ERROR_OUT_OF_DATE_KHR, vk.Result.SUBOPTIMAL_KHR:
	    recreate_swapchain()
	    return
    }

    vk.ResetCommandBuffer(v_command_buffer[v_frame_id], {})
    record_command_buffer()

    queue_submit_info : vk.SubmitInfo 
    queue_submit_info.sType = .SUBMIT_INFO
    queue_submit_info.pWaitSemaphores = &v_image_available[v_frame_id]
    queue_submit_info.waitSemaphoreCount = 1 
    queue_submit_info.pWaitDstStageMask = &vk.PipelineStageFlags{vk.PipelineStageFlag.COLOR_ATTACHMENT_OUTPUT}
    queue_submit_info.commandBufferCount = 1
    queue_submit_info.pCommandBuffers = &v_command_buffer[v_frame_id]
    queue_submit_info.signalSemaphoreCount =1
    queue_submit_info.pSignalSemaphores = &v_signal_semaphore[v_frame_id]
    
    CheckVK(vk.QueueSubmit(v_queues[.PRESENT], 1,&queue_submit_info,v_fence[v_frame_id]))
   
    chains  := [?]vk.SwapchainKHR{v_swapchain.handle}
    presentInfo : vk.PresentInfoKHR
    presentInfo.sType = .PRESENT_INFO_KHR
    presentInfo.waitSemaphoreCount =1 
    presentInfo.pWaitSemaphores =&v_signal_semaphore[v_frame_id]
    presentInfo.swapchainCount =1
    presentInfo.pSwapchains = &chains[0]
    presentInfo.pImageIndices = &image_index
    presentInfo.pResults = nil

    err := vk.QueuePresentKHR(v_queues[.PRESENT], &presentInfo)
    
    v_frame_id= (v_frame_id +1) % SWAP_FRAMES 
    return

	//    gl.ClearColor(0.2, 0.3, 0.3, 1.)
	// gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	// lightPos.x = 1.0 + f32(math.sin(glfw.GetTime()*2.0))
	// lightPos.y = f32(math.sin((glfw.GetTime()/2.0))) * 1.0

	// gl.UseProgram(lightProgram)
	// shadder :Shadder
	// shadder.amProgram = lightProgram

	// //draw_scene(test_model,&shadder,lightPos,cam,view,projection)
	// //test_model.transform *= glm.mat4Scale({1,1,1})

	// //new_m := test_model
	// //new_m.transform += glm.mat4Translate(position)
	// //position.x += 0.07 * deltaTime
	// //draw_scene(new_m,&shadder,lightPos,cam,view,projection)

	// MainLevel(&shadder,lightPos,cam,view,projection,&ter)

	// gl.UseProgram(program)

	// model = 1.0
	// model *= glm.mat4Translate(lightPos)
	// scale : glm.vec3=0.3
	// //model *= glm.mat4Scale(scale)
	// view = CameraViewMatrix(cam)
	// gl.UniformMatrix4fv(modelLoc, 1, gl.FALSE, &model[0][0])
	// gl.UniformMatrix4fv(viewLoc, 1, gl.FALSE, &view[0][0])
	// gl.UniformMatrix4fv(projectionLoc, 1, gl.FALSE, &projection[0][0])

	// gl.BindVertexArray(vao)

	// gl.DrawArrays(gl.TRIANGLES, 0, 36)
	// //fmt.print(projectionLoc)

	// //fmt.print("in a loop")
	// gl.BindVertexArray(0)
	// GUI_Render()
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {

	if key == glfw.KEY_ESCAPE {
		running = false
	}

	if key == glfw.KEY_TAB && action == glfw.RELEASE {

		GUI.state.isInDebugMode = !GUI.state.isInDebugMode
		//glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_NORMAL)

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
	if (!GUI.state.isInDebugMode) {
		//processCameraMouseMovements(&cam, xoffset, yoffset)
	}

}

size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	return
	// gl.Viewport(0, 0, width, height)
	// guiWidth = width
	// guiHeight = height
	// projection = glm.mat4Perspective(f32(math.to_radians(45.0)), f32(width) / f32(height), 0.1, 1000)
}


find_queue_family :: proc() {
	queue_count: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(v_physicalDevice, &queue_count, nil)
	available_queues := make([]vk.QueueFamilyProperties, queue_count)
	vk.GetPhysicalDeviceQueueFamilyProperties(
		v_physicalDevice,
		&queue_count,
		raw_data(available_queues),
	)

	for queue, index in available_queues {

		if vk.QueueFlag.GRAPHICS in queue.queueFlags && v_queue_familiy_indicies[queue_families.GRAPHICS] == -1 do v_queue_familiy_indicies[queue_families.GRAPHICS] = int(index)

		present_support: b32
		vk.GetPhysicalDeviceSurfaceSupportKHR(
			v_physicalDevice,
			u32(index),
			v_surface,
			&present_support,
		)
		if present_support && v_queue_familiy_indicies[queue_families.PRESENT] == -1 do v_queue_familiy_indicies[queue_families.PRESENT] = int(index)

		for que in v_queue_familiy_indicies do if que == -1 do continue
		break
	}
}
create_device :: proc() {

	find_queue_family()

	//initilize event queues    

	queuePriority: f32 = 1.0
	queue_create_infos: [dynamic]vk.DeviceQueueCreateInfo
	defer delete(queue_create_infos)
	for i in v_queue_familiy_indicies {
		createInfo: vk.DeviceQueueCreateInfo
		createInfo.sType = .DEVICE_QUEUE_CREATE_INFO
		createInfo.pNext = nil
		createInfo.queueFamilyIndex = u32(v_queue_familiy_indicies[queue_families.GRAPHICS])
		createInfo.queueCount = 1
		createInfo.pQueuePriorities = &queuePriority
		append(&queue_create_infos, createInfo)
	}

	deviceFeatures: vk.PhysicalDeviceFeatures
	deviceCreateInfo: vk.DeviceCreateInfo
	deviceCreateInfo.sType = .DEVICE_CREATE_INFO
	deviceCreateInfo.pEnabledFeatures = &deviceFeatures
	deviceCreateInfo.queueCreateInfoCount = u32(len(queue_create_infos))
	deviceCreateInfo.pQueueCreateInfos = raw_data(queue_create_infos)
	deviceCreateInfo.ppEnabledExtensionNames = raw_data(DEVICE_FEATURES[:])
	deviceCreateInfo.enabledExtensionCount = u32(len(DEVICE_FEATURES))
	deviceCreateInfo.queueCreateInfoCount = 1

	if (vk.CreateDevice(v_physicalDevice, &deviceCreateInfo, nil, &v_device) !=
		   vk.Result.SUCCESS) {
		fmt.eprint("ERROR: cannot load logical device")
	}
}

create_swapchain :: proc() {
	// geting support
	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(
		v_physicalDevice,
		v_surface,
		&v_swapchain.support.capabilities,
	)
	formatCount: u32
	vk.GetPhysicalDeviceSurfaceFormatsKHR(v_physicalDevice, v_surface, &formatCount, nil)
	if formatCount > 0 {
		v_swapchain.support.format = make([]vk.SurfaceFormatKHR, formatCount)
		vk.GetPhysicalDeviceSurfaceFormatsKHR(
			v_physicalDevice,
			v_surface,
			&formatCount,
			raw_data(v_swapchain.support.format),
		)
		fmt.print("format stuff")
	}

	presentModeCount: u32
	vk.GetPhysicalDeviceSurfacePresentModesKHR(v_physicalDevice, v_surface, &presentModeCount, nil)
	if presentModeCount > 0 {
		v_swapchain.support.present_mode = make([]vk.PresentModeKHR, presentModeCount)
		vk.GetPhysicalDeviceSurfacePresentModesKHR(
			v_physicalDevice,
			v_surface,
			&presentModeCount,
			raw_data(v_swapchain.support.present_mode),
		)
	}

	v_swapchain.format = v_swapchain.support.format[0]
	for format in v_swapchain.support.format {
		if format.format == vk.Format.B8G8R8A8_SRGB &&
		   format.colorSpace == vk.ColorSpaceKHR.SRGB_NONLINEAR {
			v_swapchain.format = format
			break
		}
	}

	v_swapchain.present_mode = vk.PresentModeKHR.FIFO

	for presentMode in v_swapchain.support.present_mode {
		if presentMode == vk.PresentModeKHR.MAILBOX {
			v_swapchain.present_mode = presentMode
			break
		}
	}

	if v_swapchain.support.capabilities.currentExtent.width != max(u32) {
		v_swapchain.extent = v_swapchain.support.capabilities.currentExtent
		fmt.println("\n chain extent one", v_swapchain.support.capabilities.currentExtent, "\n ")

	} else {
		width, height := glfw.GetFramebufferSize(window)

		extent := vk.Extent2D{u32(width), u32(height)}

		extent.width = clamp(
			extent.width,
			v_swapchain.support.capabilities.minImageExtent.width,
			v_swapchain.support.capabilities.maxImageExtent.width,
		)
		extent.height = clamp(
			extent.height,
			v_swapchain.support.capabilities.minImageExtent.height,
			v_swapchain.support.capabilities.maxImageExtent.height,
		)

		v_swapchain.extent = extent

	}

	v_swapchain.image_count = v_swapchain.support.capabilities.minImageCount + 1

	if v_swapchain.support.capabilities.maxImageCount < 0 &&
	   v_swapchain.image_count > v_swapchain.support.capabilities.maxImageCount {
		v_swapchain.image_count = v_swapchain.support.capabilities.maxImageCount
	}


	create_info: vk.SwapchainCreateInfoKHR
	create_info.sType = .SWAPCHAIN_CREATE_INFO_KHR
	create_info.surface = v_surface
	create_info.minImageCount = v_swapchain.image_count
	create_info.presentMode = v_swapchain.present_mode
	create_info.imageFormat = v_swapchain.format.format
	create_info.imageColorSpace = v_swapchain.format.colorSpace
	create_info.imageExtent = v_swapchain.extent
	create_info.imageArrayLayers = 1
	create_info.imageUsage = {.COLOR_ATTACHMENT}

	queueIndicies := [len(v_queue_familiy_indicies)]u32 {
		u32(v_queue_familiy_indicies[queue_families.PRESENT]),
		u32(v_queue_familiy_indicies[queue_families.GRAPHICS]),
	}

	if (queueIndicies[queue_families.GRAPHICS] != queueIndicies[queue_families.PRESENT]) {
		create_info.imageSharingMode = .CONCURRENT
		create_info.queueFamilyIndexCount = 2
		create_info.pQueueFamilyIndices = &queueIndicies[0]
	} else {
		create_info.imageSharingMode = .EXCLUSIVE
		create_info.queueFamilyIndexCount = 0
		create_info.pQueueFamilyIndices = nil
	}

	create_info.preTransform = v_swapchain.support.capabilities.currentTransform
	create_info.compositeAlpha = {.OPAQUE}
	create_info.presentMode = v_swapchain.present_mode
	create_info.clipped = true
	create_info.oldSwapchain = vk.SwapchainKHR{}

	if vk.CreateSwapchainKHR(v_device, &create_info, nil, &v_swapchain.handle) !=
	   vk.Result.SUCCESS {
		fmt.eprint("ERROR: failed to create swapchain")
	}
	vk.GetSwapchainImagesKHR(v_device, v_swapchain.handle, &v_swapchain.image_count, nil)
	v_swapchain.images = make([]vk.Image, v_swapchain.image_count)
	vk.GetSwapchainImagesKHR(
		v_device,
		v_swapchain.handle,
		&v_swapchain.image_count,
		raw_data(v_swapchain.images),
	)

	create_image_views()
}

recreate_swapchain :: proc() {
	destroy_swapchain()
	create_swapchain()
}

destroy_swapchain :: proc() {
	for v in v_swapchain.image_views {
		vk.DestroyImageView(v_device, v, nil)
	}
	for frame in v_swapchain.frame_buffers {
		vk.DestroyFramebuffer(v_device, frame, nil)
	}
	vk.DestroySwapchainKHR(v_device, v_swapchain.handle, nil)

}
create_image_views :: proc() {
	// create image views
	v_swapchain.image_views = make([]vk.ImageView, len(v_swapchain.images))
	for image, index in v_swapchain.images {
		create_info: vk.ImageViewCreateInfo
		create_info.sType = .IMAGE_VIEW_CREATE_INFO
		create_info.image = image
		create_info.viewType = .D2
		create_info.format = v_swapchain.format.format
		create_info.components.r = .IDENTITY
		create_info.components.g = .IDENTITY
		create_info.components.b = .IDENTITY
		create_info.components.a = .IDENTITY
		create_info.subresourceRange.aspectMask = {.COLOR}
		create_info.subresourceRange.levelCount = 1
		create_info.subresourceRange.layerCount = 1
		create_info.subresourceRange.baseMipLevel = 0
		create_info.subresourceRange.baseArrayLayer = 0

		if (vk.CreateImageView(v_device, &create_info, nil, &v_swapchain.image_views[index]) !=
			   vk.Result.SUCCESS) {
			fmt.eprint("ERROR: failed to create Image new")
		}
	}
}
create_renderpass :: proc() {
	fmt.print("wa")

	frag := create_shader_module(FRAG)
	vert := create_shader_module(VERT)

	v_shader_stages[0] = {}
	v_shader_stages[0].sType = .PIPELINE_SHADER_STAGE_CREATE_INFO
	v_shader_stages[0].module = vert
	v_shader_stages[0].stage = {.VERTEX}
	v_shader_stages[0].pName = "main"

	v_shader_stages[1] = {}
	v_shader_stages[1].sType = .PIPELINE_SHADER_STAGE_CREATE_INFO
	v_shader_stages[1].module = frag
	v_shader_stages[1].stage = {.FRAGMENT}
	v_shader_stages[1].pName = "main"

	defer vk.DestroyShaderModule(v_device, vert, nil)
	defer vk.DestroyShaderModule(v_device, frag, nil)

	color_attachment: vk.AttachmentDescription
	color_attachment.format = v_swapchain.format.format
	color_attachment.samples = {._1}
	color_attachment.loadOp = .CLEAR
	color_attachment.storeOp = .STORE
	color_attachment.stencilLoadOp = .DONT_CARE
	color_attachment.stencilStoreOp = .DONT_CARE
	color_attachment.initialLayout = .UNDEFINED
	color_attachment.finalLayout = .PRESENT_SRC_KHR

	color_attachment_ref: vk.AttachmentReference
	color_attachment_ref.attachment = 0
	color_attachment_ref.layout = .COLOR_ATTACHMENT_OPTIMAL

	subpass: vk.SubpassDescription
	subpass.pipelineBindPoint = .GRAPHICS
	subpass.colorAttachmentCount = 1
	subpass.pColorAttachments = &color_attachment_ref


	dependency: vk.SubpassDependency
	dependency.srcSubpass = vk.SUBPASS_EXTERNAL
	dependency.dstSubpass = 0
	dependency.srcStageMask = {.COLOR_ATTACHMENT_OUTPUT}
	dependency.srcAccessMask = {}
	dependency.dstStageMask = {.COLOR_ATTACHMENT_OUTPUT}
	dependency.dstAccessMask = {.COLOR_ATTACHMENT_WRITE}


	render_pass: vk.RenderPassCreateInfo
	render_pass.sType = .RENDER_PASS_CREATE_INFO
	render_pass.attachmentCount = 1
	render_pass.pAttachments = &color_attachment
	render_pass.subpassCount = 1
	render_pass.pSubpasses = &subpass
	render_pass.dependencyCount = 1
	render_pass.pDependencies = &dependency
	
	if vk.CreateRenderPass(v_device, &render_pass, nil, &v_render_pass) != .SUCCESS {
		fmt.eprint("ERROR: failed to create render pass")
	}
	fmt.print("hellow morning")

	create_frame_buffers()

	dyanamic_states := []vk.DynamicState{vk.DynamicState.SCISSOR, vk.DynamicState.VIEWPORT}

	dyanamic_state_create_info: vk.PipelineDynamicStateCreateInfo
	dyanamic_state_create_info.sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO
	dyanamic_state_create_info.dynamicStateCount = u32(len(dyanamic_states))
	dyanamic_state_create_info.pDynamicStates = &dyanamic_states[0]

	vertex_input_info: vk.PipelineVertexInputStateCreateInfo
	vertex_input_info.sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO

	vertex_input: vk.PipelineInputAssemblyStateCreateInfo
	vertex_input.sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
	vertex_input.topology = .TRIANGLE_LIST
	vertex_input.primitiveRestartEnable = false

	viewport_state: vk.PipelineViewportStateCreateInfo
	viewport_state.sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO
	viewport_state.viewportCount = 1
	viewport_state.scissorCount = 1

	rasterizer: vk.PipelineRasterizationStateCreateInfo
	rasterizer.sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO
	rasterizer.polygonMode = .FILL
	rasterizer.lineWidth = 1
	rasterizer.cullMode = {.BACK}
	rasterizer.frontFace = .CLOCKWISE

	multisampler: vk.PipelineMultisampleStateCreateInfo
	multisampler.sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
	multisampler.minSampleShading = 1
	multisampler.rasterizationSamples = {._1}

	attachments: vk.PipelineColorBlendAttachmentState
	attachments.colorWriteMask = {.R, .G, .B, .A}

	color_blend: vk.PipelineColorBlendStateCreateInfo
	color_blend.attachmentCount = 1
	color_blend.sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
	color_blend.pAttachments = &attachments

	pipeline_layout: vk.PipelineLayoutCreateInfo
	pipeline_layout.sType = .PIPELINE_LAYOUT_CREATE_INFO

	if (vk.CreatePipelineLayout(v_device, &pipeline_layout, nil, &v_pipline_layout) !=
		   vk.Result.SUCCESS) {
		fmt.eprint("ERROR: failed to create pipeline layout")
	}

	pipeline: vk.GraphicsPipelineCreateInfo
	pipeline.sType = .GRAPHICS_PIPELINE_CREATE_INFO
	pipeline.stageCount = 2
	pipeline.pStages = &v_shader_stages[0]
	pipeline.pVertexInputState = &vertex_input_info
	pipeline.pInputAssemblyState = &vertex_input
	pipeline.pViewportState = &viewport_state
	pipeline.pRasterizationState = &rasterizer
	pipeline.pMultisampleState = &multisampler
	pipeline.pColorBlendState = &color_blend
	pipeline.pDynamicState = &dyanamic_state_create_info
	pipeline.layout = v_pipline_layout
	pipeline.renderPass = v_render_pass
	pipeline.subpass = 0
	pipeline.basePipelineIndex = -1

	if (vk.CreateGraphicsPipelines(v_device, 0, 1, &pipeline, nil, &v_pipline) !=
		   vk.Result.SUCCESS) {
		fmt.eprint("ERROR: failed to create graphics pipeline")
	}

}

create_command_pool :: proc() {
	pool_info: vk.CommandPoolCreateInfo
	pool_info.sType = .COMMAND_POOL_CREATE_INFO
	pool_info.flags = {.RESET_COMMAND_BUFFER}
	pool_info.queueFamilyIndex = u32(v_queue_familiy_indicies[.GRAPHICS])

	if (vk.CreateCommandPool(v_device, &pool_info, nil, &v_command_pool) != vk.Result.SUCCESS) {
		fmt.eprint("ERROR: failed to create command pool")
	}

	alloc_info: vk.CommandBufferAllocateInfo
	alloc_info.sType = .COMMAND_BUFFER_ALLOCATE_INFO
	alloc_info.commandPool = v_command_pool
	alloc_info.level = .PRIMARY
	alloc_info.commandBufferCount = len(v_command_buffer)

	if (vk.AllocateCommandBuffers(v_device, &alloc_info, &v_command_buffer[0]) !=
		   vk.Result.SUCCESS) {
		fmt.eprint("ERROR: failed to allocate command buffers")
	}

}

create_sync_object :: proc() {
	semaphore: vk.SemaphoreCreateInfo
	semaphore.sType = .SEMAPHORE_CREATE_INFO

	fence: vk.FenceCreateInfo
	fence.sType = .FENCE_CREATE_INFO
	fence.flags = {.SIGNALED}
	for i in 0 ..< SWAP_FRAMES {
		if (vk.CreateSemaphore(v_device, &semaphore, nil, &v_signal_semaphore[i]) != .SUCCESS) {
			fmt.eprint("ERROR: failed to create semaphore")
		}
		if (vk.CreateSemaphore(v_device, &semaphore, nil, &v_image_available[i]) != .SUCCESS) {
			fmt.eprint("ERROR: failed to create semaphore")
		}
		if (vk.CreateFence(v_device, &fence, nil, &v_fence[i]) != .SUCCESS) {
			fmt.eprint("ERROR: failed to create semaphore")
		}
	}
}

create_frame_buffers :: proc() {
	v_swapchain.frame_buffers = make([]vk.Framebuffer, len(v_swapchain.image_views))

	for view, index in v_swapchain.image_views {
		attachments := [?]vk.ImageView{view}

		frame_buffer: vk.FramebufferCreateInfo
		frame_buffer.sType = .FRAMEBUFFER_CREATE_INFO
		frame_buffer.renderPass = v_render_pass
		frame_buffer.attachmentCount = 1
		frame_buffer.pAttachments = &attachments[0]
		frame_buffer.width = v_swapchain.extent.width
		frame_buffer.height = v_swapchain.extent.height
		frame_buffer.layers = 1

		if (vk.CreateFramebuffer(
				   v_device,
				   &frame_buffer,
				   nil,
				   &v_swapchain.frame_buffers[index],
			   ) !=
			   .SUCCESS) {
			fmt.eprint("ERROR: failed to create frame buffer")
		}

	}
}

create_shader_module :: proc(code: []byte) -> (module: vk.ShaderModule) {
	shaderData := slice.reinterpret([]u32, code)

	// data needed to make a shader module
	info: vk.ShaderModuleCreateInfo
	info.sType = .SHADER_MODULE_CREATE_INFO
	info.pCode = raw_data(shaderData)
	info.codeSize = len(code)

	if (vk.CreateShaderModule(v_device, &info, nil, &module) == vk.Result.SUCCESS) {
		return module
	} else {
		fmt.eprint("ERROR: failed to create shader module")
	}
	return
}
load_texture :: proc(path: cstring) -> u32 {

	return 80085
	//    textureID: u32
	// gl.GenTextures(1,&textureID)

	// width, height, nrComponents :i32
	// data := stb.load(path,&width,&height,&nrComponents,0)

	// if(data != nil){
	// 	format : int
	// 	if(nrComponents == 0)
	// 	{
	// 		format = gl.RED;
	// 	}
	// 	else if(nrComponents == 3){
	// 		format = gl.RGB
	// 	}
	// 	else if(nrComponents == 4){
	// 		format = gl.RGBA
	// 	}
	// 	gl.BindTexture(gl.TEXTURE_2D, textureID);
	// 	gl.TexImage2D(gl.TEXTURE_2D, 0, i32(format), width, height, 0, u32(format), gl.UNSIGNED_BYTE, data);
	// 	gl.GenerateMipmap(gl.TEXTURE_2D)

	// 	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	//        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	//        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	//        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	// }else{
	// 	fmt.println("err: loaded image wrong")

	// }

	// return textureID
}

vk_messenger_callback :: proc "system" (
	messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT,
	messageTypes: vk.DebugUtilsMessageTypeFlagsEXT,
	pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT,
	pUserData: rawptr,
) -> b32 {
	context = ctx
	fmt.println("vulkan[]:", messageTypes, pCallbackData.pMessage)
	return false
}

record_command_buffer :: proc() {
	begin_info: vk.CommandBufferBeginInfo
	begin_info.sType = .COMMAND_BUFFER_BEGIN_INFO

	command_buffer := v_command_buffer[v_frame_id]
	if vk.BeginCommandBuffer(command_buffer, &begin_info) != .SUCCESS {
		fmt.eprint("ERROR: command buffer not beginning")
	}

	clear_color: vk.ClearValue
	clear_color.color.float32 = {0.0, 0.0, 0.0, 1.0}

	render_pass_begin_info: vk.RenderPassBeginInfo
	render_pass_begin_info.sType = .RENDER_PASS_BEGIN_INFO
	render_pass_begin_info.renderPass = v_render_pass
	render_pass_begin_info.framebuffer = v_swapchain.frame_buffers[v_frame_id]
	render_pass_begin_info.renderArea = {
		extent = v_swapchain.extent,
	}
	render_pass_begin_info.pClearValues = &clear_color
	render_pass_begin_info.clearValueCount = 1


	vk.CmdBeginRenderPass(command_buffer, &render_pass_begin_info, .INLINE)

	vk.CmdBindPipeline(command_buffer, .GRAPHICS, v_pipline)

	viewport: vk.Viewport

	viewport.width = f32(v_swapchain.extent.width)
	viewport.height = f32(v_swapchain.extent.height)
	viewport.maxDepth = 1.0

	vk.CmdSetViewport(command_buffer, 0, 1, &viewport)


	scissor: vk.Rect2D
	scissor.extent = v_swapchain.extent

	vk.CmdSetScissor(command_buffer, 0, 1, &scissor)
    
	vk.CmdDraw(command_buffer, 3, 1, 0, 0)
	vk.CmdEndRenderPass(command_buffer)
	vk.EndCommandBuffer(command_buffer)

}
