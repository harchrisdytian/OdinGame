package main

import intr "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:slice"
import "vendor:glfw"
// import ""
import vkb "Extern/odin-vk-bootstrap"
import vma "Extern/odin-vma"
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
// test_model: Scene

lastXpos: f32
lastYpos: f32

// lighting globals
coral: glm.vec3

linear: UniformValue
constant: UniformValue
quadratic: UniformValue

// BaseCube: Scene
// BaseArch: Scene
// ter: terrain

SWAP_FRAMES :: 2


GAME_TITLE :: "The Projector"
DEFAULT_WIDTH :: 800
DEFAULT_HEIGHT :: 600
// Vulkan Type Defines

FRAG :: #load("Shaders/vfrag.spv")
VERT :: #load("Shaders/vVert.spv")

MODEL_VERT :: #load("Shaders/color_triangle.vert.spv")
MODEL_FRAG :: #load("Shaders/color_triangle.frag.spv")


engine: Engine

Engine :: struct {
	frame_id:               u32,
	shader_stages:          [2]vk.PipelineShaderStageCreateInfo,
	mesh_shader_stages:     [2]vk.PipelineShaderStageCreateInfo,
	createInfo:             vk.InstanceCreateInfo,
	instance:               vk.Instance,
	physicalDevice:         vk.PhysicalDevice,
	device:                 vk.Device,
	surface:                vk.SurfaceKHR,
	queue_familiy_indicies: [queue_families]int,
	queues:                 [queue_families]vk.Queue,
	swapchain:              Swapchain,
	render_pass:            vk.RenderPass,
	pipeline_layout:        vk.PipelineLayout,
	mesh_pipeline_layout:   vk.PipelineLayout,
	pipline:                vk.Pipeline,
	mesh_pipline:           vk.Pipeline,
	command_pool:           vk.CommandPool,
	imm_command_pool:       vk.CommandPool,
	command_buffer:         [SWAP_FRAMES]vk.CommandBuffer,
	imm_command_buffer:     vk.CommandBuffer,
	image_available:        [SWAP_FRAMES]vk.Semaphore,
	signal_semaphore:       [SWAP_FRAMES]vk.Semaphore,
	fence:                  [SWAP_FRAMES]vk.Fence,
	immidate_fence:         vk.Fence,
	vma_alloc :             vma.Allocator,
	alloctor_buffer:        Buffer,
	mesh:                   Mesh,
	rect: MeshBuffer
}

Mesh :: struct {
	pipeline_layout: vk.PipelineLayout,
}

PipelineData :: struct {
	dyanamic_states:            []vk.DynamicState,
	dyanamic_state_create_info: vk.PipelineDynamicStateCreateInfo,
	vertex_input_info:          vk.PipelineVertexInputStateCreateInfo,
	vertex_input:               vk.PipelineInputAssemblyStateCreateInfo,
	viewport_state:             vk.PipelineViewportStateCreateInfo,
	rasterizer:                 vk.PipelineRasterizationStateCreateInfo,
	multisampler:               vk.PipelineMultisampleStateCreateInfo,
	attachments:                vk.PipelineColorBlendAttachmentState,
	color_blend:                vk.PipelineColorBlendStateCreateInfo,
	pipeline_info:              vk.GraphicsPipelineCreateInfo,
}
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

MeshBuffer :: struct {
	index_buffer:           Buffer,
	vert_buffer:            Buffer,
	vertext_buffer_address: vk.DeviceAddress,
}

Buffer :: struct {
	buffer:     vk.Buffer,
	info:       vma.Allocation_Info,
	allocator:  vma.Allocator,
	allocation: vma.Allocation,
}

Vertex :: struct {
	position:   glm.vec3,
	uv_x:   f32,
	normal: glm.vec4,
	uv_y:   f32,
	color:  glm.vec4,
}

Push_Constant :: struct {
	world_mat:     glm.mat4,
	vertex_buffer: vk.DeviceAddress,
}


CheckVK :: proc(Res: vk.Result, Description: string = "something") {
	if (Res != vk.Result.SUCCESS) {
		fmt.print("failed to do {}")
	}
}


DEVICE_FEATURES := [?]cstring{vk.KHR_SWAPCHAIN_EXTENSION_NAME,vk.EXT_MEMORY_BUDGET_EXTENSION_NAME}
VALIDATION_lAYERS := [?]cstring{"VK_LAYER_KHRONOS_validation"}
init :: proc() -> glfw.WindowHandle {

	if (glfw.Init() && glfw.VulkanSupported()) {


		glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
		g_logger := context.logger

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
		instance_builder_, ok := vkb.init_instance_builder()
		vkb.instance_set_app_name(&instance_builder_, "OdinGame")
		vkb.instance_require_api_version(&instance_builder_, vk.API_VERSION_1_3)

		when ODIN_DEBUG 
		{
			vkb.instance_request_validation_layers(&instance_builder_)
			default_debug_callback :: proc "system" (
				message_severity: vk.DebugUtilsMessageSeverityFlagsEXT,
				message_types: vk.DebugUtilsMessageTypeFlagsEXT,
				p_callback_data: ^vk.DebugUtilsMessengerCallbackDataEXT,
				p_user_data: rawptr,
			) -> b32 {
				context = runtime.default_context()

				if .WARNING in message_severity {
					fmt.print("[%v]: %s", message_types, p_callback_data.pMessage)
				} else if .ERROR in message_severity {
					fmt.eprintf("[%v]: %s", message_types, p_callback_data.pMessage)
					//runtime.debug_trap()
				} else {
					fmt.print("[%v]: %s", message_types, p_callback_data.pMessage)
				}

				return false // Applications must return false herev
			}

			vkb.instance_set_debug_callback(&instance_builder_, default_debug_callback)
		}
		VKB_instance, ok2 := vkb.build_instance(&instance_builder_)
		engine.instance = VKB_instance.handle


		res := glfw.CreateWindowSurface(engine.instance, window, nil, &engine.surface)

		count: u32
		if (vk.EnumeratePhysicalDevices(engine.instance, &count, nil) != vk.Result.SUCCESS) {
			fmt.eprint("ERROR: can't enummerate the physical device")
		}

		if (count == 0) {
			fmt.eprint("ERROR: there is no physical device")
		}

		_physicalDevices := make([]vk.PhysicalDevice, count)
		vk.EnumeratePhysicalDevices(engine.instance, &count, &_physicalDevices[0])

		engine.physicalDevice = _physicalDevices[0]
		fmt.print(engine.physicalDevice)
		when ODIN_DEBUG {
			deviceProperties: vk.PhysicalDeviceProperties
			vk.GetPhysicalDeviceProperties(engine.physicalDevice, &deviceProperties)
			// TODO: check for device properties as needed :)
		}

		if (res != vk.Result.SUCCESS) {
			fmt.eprint("ERROR: failed to create Surface", res)

		}

		find_queue_family()

		create_device()

		//find queuse
		for &que, f in &engine.queues {
			vk.GetDeviceQueue(engine.device, u32(engine.queue_familiy_indicies[f]), 0, &que)
		}

		fmt.print("should be something", vkb.convert_vulkan_to_vma_version(VKB_instance.api_version))
		vma_vulkan_functions := vma.create_vulkan_functions()
		

		vma_vulkan_functions.get_physical_device_memory_properties2_khr = vk.GetPhysicalDeviceMemoryProperties2
		vma_vulkan_functions.get_buffer_memory_requirements2_khr = vk.GetBufferMemoryRequirements2
		
	    allocator_create_info: vma.Allocator_Create_Info = {
			flags              = {.Buffer_Device_Address},
			instance           = engine.instance,
			vulkan_api_version = (VKB_instance.api_version),
			physical_device    = engine.physicalDevice,
			device             = engine.device,
			vulkan_functions   = &vma_vulkan_functions,
		}

		CheckVK(vma.create_allocator(allocator_create_info,&engine.vma_alloc), "failed to create buffer")
		
		


		create_swapchain()

		create_renderpass()

		create_command_pool()
		create_sync_object()

		default_data()
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
	vk.WaitForFences(engine.device, 1, &engine.fence[engine.frame_id], true, max(u64))
	image_index: u32
	vk.ResetFences(engine.device, 1, &engine.fence[engine.frame_id])

	res := vk.AcquireNextImageKHR(
		engine.device,
		engine.swapchain.handle,
		max(u64),
		engine.image_available[engine.frame_id],
		{},
		&image_index,
	)

	#partial switch res {
	case vk.Result.ERROR_OUT_OF_DATE_KHR, vk.Result.SUBOPTIMAL_KHR:
		recreate_swapchain()
		return
	}

	vk.ResetCommandBuffer(engine.command_buffer[engine.frame_id], {})
	record_command_buffer(image_index)

	queue_submit_info: vk.SubmitInfo
	queue_submit_info.sType = .SUBMIT_INFO
	queue_submit_info.pWaitSemaphores = &engine.image_available[engine.frame_id]
	queue_submit_info.waitSemaphoreCount = 1
	queue_submit_info.pWaitDstStageMask =
	&vk.PipelineStageFlags{vk.PipelineStageFlag.COLOR_ATTACHMENT_OUTPUT}
	queue_submit_info.commandBufferCount = 1
	queue_submit_info.pCommandBuffers = &engine.command_buffer[engine.frame_id]
	queue_submit_info.signalSemaphoreCount = 1
	queue_submit_info.pSignalSemaphores = &engine.signal_semaphore[engine.frame_id]

	CheckVK(
		vk.QueueSubmit(
			engine.queues[.PRESENT],
			1,
			&queue_submit_info,
			engine.fence[engine.frame_id],
		),
	)

	chains := [?]vk.SwapchainKHR{engine.swapchain.handle}
	presentInfo: vk.PresentInfoKHR
	presentInfo.sType = .PRESENT_INFO_KHR
	presentInfo.waitSemaphoreCount = 1
	presentInfo.pWaitSemaphores = &engine.signal_semaphore[engine.frame_id]
	presentInfo.swapchainCount = 1
	presentInfo.pSwapchains = &chains[0]
	presentInfo.pImageIndices = &image_index
	presentInfo.pResults = nil


	err := vk.QueuePresentKHR(engine.queues[.PRESENT], &presentInfo)

	engine.frame_id = (engine.frame_id + 1) % SWAP_FRAMES

}

immediate_submit :: proc(data: $T, fn: proc(cmd: vk.CommandBuffer, data: T)) {
	CheckVK(
		vk.ResetFences(engine.device, 1, &engine.immidate_fence),
		"failed to reset Immediate fense",
	)
	CheckVK(vk.ResetCommandBuffer(engine.imm_command_buffer, {}))

	cmd := engine.imm_command_buffer

	begin_info: vk.CommandBufferBeginInfo
	begin_info.sType = .COMMAND_BUFFER_BEGIN_INFO
	begin_info.flags = {.ONE_TIME_SUBMIT}

	CheckVK(vk.BeginCommandBuffer(cmd, &begin_info))

	fn(cmd, data)

	CheckVK(vk.EndCommandBuffer(cmd), "failed to end imediate command buffer")


	cmd_submit_info: vk.CommandBufferSubmitInfo
	cmd_submit_info.sType = .COMMAND_BUFFER_SUBMIT_INFO
	cmd_submit_info.commandBuffer = cmd
	sub_info: vk.SubmitInfo2
	sub_info.sType = .SUBMIT_INFO_2
	sub_info.waitSemaphoreInfoCount = 0
	sub_info.signalSemaphoreInfoCount = 0
	sub_info.commandBufferInfoCount = 1
	sub_info.pCommandBufferInfos = &cmd_submit_info

	CheckVK(vk.QueueSubmit2(engine.queues[.GRAPHICS], 1, &sub_info, engine.immidate_fence))
	CheckVK(vk.WaitForFences(engine.device, 1, &engine.immidate_fence, true, 9999999))
}


upload_mesh :: proc(inds: []u32, verts: []Vertex) -> (new_surface: MeshBuffer) {


	vert_size := vk.DeviceSize(len(verts) * size_of(Vertex))
	ind_size := vk.DeviceSize(len(inds) * size_of(u32))

	new_surface.vert_buffer = create_buffer(
		vert_size,
		{.STORAGE_BUFFER, .TRANSFER_DST, .SHADER_DEVICE_ADDRESS},
		.Gpu_Only,
	)

	device_address_info: vk.BufferDeviceAddressInfo
	device_address_info.sType = .BUFFER_DEVICE_ADDRESS_INFO
	device_address_info.buffer = new_surface.vert_buffer.buffer
	fmt.print(new_surface.vert_buffer)
	new_surface.vertext_buffer_address = vk.GetBufferDeviceAddress(
		engine.device,
		&device_address_info,
	)

	new_surface.index_buffer = create_buffer(ind_size, {.INDEX_BUFFER, .TRANSFER_DST}, .Gpu_Only)

	stageing := create_buffer(vert_size + ind_size, {.TRANSFER_SRC}, .Cpu_Only)
	intr.mem_copy(stageing.info.mapped_data, raw_data(verts), vert_size)

	intr.mem_copy(
		rawptr(uintptr(stageing.info.mapped_data) + uintptr(vert_size)),
		raw_data(inds),
		ind_size,
	)
	_CopyData :: struct {
		staging_buffer:     vk.Buffer,
		vertex_buffer:      vk.Buffer,
		index_buffer:       vk.Buffer,
		vertex_buffer_size: vk.DeviceSize,
		index_buffer_size:  vk.DeviceSize,
	}
	copy_data: _CopyData

	copy_data.staging_buffer = stageing.buffer
	copy_data.vertex_buffer = new_surface.vert_buffer.buffer
	copy_data.index_buffer = new_surface.index_buffer.buffer
	copy_data.vertex_buffer_size = vert_size
	copy_data.index_buffer_size = ind_size

	immediate_submit(copy_data, proc(cmd: vk.CommandBuffer, data: _CopyData) {
		vert_copy := vk.BufferCopy {
			srcOffset = 0,
			dstOffset = 0,
			size      = data.vertex_buffer_size,
		}
		vk.CmdCopyBuffer(cmd, data.staging_buffer, data.vertex_buffer, 1, &vert_copy)


		index_copy := vk.BufferCopy {
			srcOffset = data.vertex_buffer_size,
			dstOffset = 0,
			size      = data.index_buffer_size,
		}

		vk.CmdCopyBuffer(cmd, data.staging_buffer, data.index_buffer, 1, &index_copy)
	})
	return
}


create_buffer :: proc(
	alloc_size: vk.DeviceSize,
	usage: vk.BufferUsageFlags,
	memory_usage: vma.Memory_Usage,
) -> (
	new_buffer: Buffer,
) {
	buffer_info: vk.BufferCreateInfo
	buffer_info.sType = .BUFFER_CREATE_INFO
	buffer_info.size = alloc_size
	buffer_info.usage = usage
	

	vma_alloc_info: vma.Allocation_Create_Info
	vma_alloc_info.usage = memory_usage
	vma_alloc_info.flags = {.Mapped}

	new_buffer.allocator = engine.vma_alloc
	fmt.print("ajsdlf;jladjf;j f \n \n \n  create buffer \n \n \n")
	fmt.print(engine.alloctor_buffer.allocator)
	
	if (
		vma.create_buffer(
			new_buffer.allocator,
			buffer_info,
			vma_alloc_info,
			&new_buffer.buffer,
			&new_buffer.allocation,
			&new_buffer.info,
		) != vk.Result.SUCCESS)
		{
			
	fmt.print(	" createing buffer")
	}
	

	fmt.print("\n {} \n", new_buffer.buffer)
	
	return new_buffer
}

destroy_buffer :: proc(buff: Buffer) {
	vma.destroy_buffer(buff.allocator, buff.buffer, buff.allocation)
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {

	if key == glfw.KEY_ESCAPE {
		running = false
	}

	if key == glfw.KEY_TAB && action == glfw.RELEASE {
		GUI.state.isInDebugMode = !GUI.state.isInDebugMode
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
	vk.GetPhysicalDeviceQueueFamilyProperties(engine.physicalDevice, &queue_count, nil)
	available_queues := make([]vk.QueueFamilyProperties, queue_count)
	vk.GetPhysicalDeviceQueueFamilyProperties(
		engine.physicalDevice,
		&queue_count,
		raw_data(available_queues),
	)

	for queue, index in available_queues {

		if vk.QueueFlag.GRAPHICS in queue.queueFlags && engine.queue_familiy_indicies[queue_families.GRAPHICS] == -1 do engine.queue_familiy_indicies[queue_families.GRAPHICS] = int(index)

		present_support: b32
		vk.GetPhysicalDeviceSurfaceSupportKHR(
			engine.physicalDevice,
			u32(index),
			engine.surface,
			&present_support,
		)
		if present_support && engine.queue_familiy_indicies[queue_families.PRESENT] == -1 do engine.queue_familiy_indicies[queue_families.PRESENT] = int(index)

		for que in engine.queue_familiy_indicies do if que == -1 do continue
		break
	}
}
create_device :: proc() {

	find_queue_family()

	//initilize event queues    

	queuePriority: f32 = 1.0
	queue_create_infos: [dynamic]vk.DeviceQueueCreateInfo
	defer delete(queue_create_infos)
	for i in engine.queue_familiy_indicies {
		createInfo: vk.DeviceQueueCreateInfo
		createInfo.sType = .DEVICE_QUEUE_CREATE_INFO
		createInfo.pNext = nil
		createInfo.queueFamilyIndex = u32(engine.queue_familiy_indicies[queue_families.GRAPHICS])
		createInfo.queueCount = 1
		createInfo.pQueuePriorities = &queuePriority
		append(&queue_create_infos, createInfo)
	}

	device_features13 : vk.PhysicalDeviceVulkan13Features
	device_features13.sType = .PHYSICAL_DEVICE_VULKAN_1_3_FEATURES
	device_features13.dynamicRendering = true
	device_features13.synchronization2 = true

	device_features12 : vk.PhysicalDeviceVulkan12Features
	device_features12.sType = .PHYSICAL_DEVICE_VULKAN_1_2_FEATURES
	device_features12.bufferDeviceAddress = true
	device_features12.descriptorIndexing = true
	device_features12.pNext = &device_features13
	
	
	
	deviceFeaturs2 :vk.PhysicalDeviceFeatures2
	deviceFeaturs2.sType = .PHYSICAL_DEVICE_FEATURES_2
	deviceFeaturs2.pNext = &device_features12
	
	deviceFeatures: vk.PhysicalDeviceFeatures
	deviceCreateInfo: vk.DeviceCreateInfo
	deviceCreateInfo.sType = .DEVICE_CREATE_INFO
	deviceCreateInfo.pEnabledFeatures = nil
	deviceCreateInfo.queueCreateInfoCount = u32(len(queue_create_infos))
	deviceCreateInfo.pQueueCreateInfos = raw_data(queue_create_infos)
	deviceCreateInfo.ppEnabledExtensionNames = raw_data(DEVICE_FEATURES[:])
	deviceCreateInfo.enabledExtensionCount = u32(len(DEVICE_FEATURES))
	deviceCreateInfo.queueCreateInfoCount = 1
	deviceCreateInfo.pNext = &deviceFeaturs2
	fmt.print("something ")
	if (vk.CreateDevice(engine.physicalDevice, &deviceCreateInfo, nil, &engine.device) !=
		   vk.Result.SUCCESS) {
		fmt.eprint("ERROR: cannot loadengine.frame_idlogical device")
	}


	mem_props2: vk.PhysicalDeviceMemoryProperties2
	mem_props2.sType = .PHYSICAL_DEVICE_MEMORY_PROPERTIES_2
	mem_props2.pNext = nil

	// m_VulkanFunctions.vkGetPhysicalDeviceMemoryProperties2KHR(engine.physicalDevice, &mem_props2)

	vk.GetPhysicalDeviceMemoryProperties2(engine.physicalDevice, &mem_props2)
	// access heaps
	for i in 0..<mem_props2.memoryProperties.memoryTypeCount {
	    mem_type := mem_props2.memoryProperties.memoryTypes[i]
	    fmt.println("Heap: ", mem_type.heapIndex, " Flags: ", mem_type.propertyFlags)
	}

	fmt.print("something ")
}

create_swapchain :: proc() {
	// geting support
	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(
		engine.physicalDevice,
		engine.surface,
		&engine.swapchain.support.capabilities,
	)
	formatCount: u32
	vk.GetPhysicalDeviceSurfaceFormatsKHR(engine.physicalDevice, engine.surface, &formatCount, nil)
	if formatCount > 0 {
		engine.swapchain.support.format = make([]vk.SurfaceFormatKHR, formatCount)
		vk.GetPhysicalDeviceSurfaceFormatsKHR(
			engine.physicalDevice,
			engine.surface,
			&formatCount,
			raw_data(engine.swapchain.support.format),
		)
		fmt.print("format stuff")
	}

	presentModeCount: u32
	vk.GetPhysicalDeviceSurfacePresentModesKHR(
		engine.physicalDevice,
		engine.surface,
		&presentModeCount,
		nil,
	)
	if presentModeCount > 0 {
		engine.swapchain.support.present_mode = make([]vk.PresentModeKHR, presentModeCount)
		vk.GetPhysicalDeviceSurfacePresentModesKHR(
			engine.physicalDevice,
			engine.surface,
			&presentModeCount,
			raw_data(engine.swapchain.support.present_mode),
		)
	}

	engine.swapchain.format = engine.swapchain.support.format[0]
	for format in engine.swapchain.support.format {
		if format.format == vk.Format.B8G8R8A8_SRGB &&
		   format.colorSpace == vk.ColorSpaceKHR.SRGB_NONLINEAR {
			engine.swapchain.format = format
			break
		}
	}

	engine.swapchain.present_mode = vk.PresentModeKHR.FIFO

	for presentMode in engine.swapchain.support.present_mode {
		if presentMode == vk.PresentModeKHR.MAILBOX {
			engine.swapchain.present_mode = presentMode
			break
		}
	}

	if engine.swapchain.support.capabilities.currentExtent.width != max(u32) {
		engine.swapchain.extent = engine.swapchain.support.capabilities.currentExtent
		fmt.println(
			"\n chain extent one",
			engine.swapchain.support.capabilities.currentExtent,
			"\n ",
		)

	} else {
		width, height := glfw.GetFramebufferSize(window)

		extent := vk.Extent2D{u32(width), u32(height)}

		extent.width = clamp(
			extent.width,
			engine.swapchain.support.capabilities.minImageExtent.width,
			engine.swapchain.support.capabilities.maxImageExtent.width,
		)
		extent.height = clamp(
			extent.height,
			engine.swapchain.support.capabilities.minImageExtent.height,
			engine.swapchain.support.capabilities.maxImageExtent.height,
		)

		engine.swapchain.extent = extent

	}

	engine.swapchain.image_count = engine.swapchain.support.capabilities.minImageCount + 1

	if engine.swapchain.support.capabilities.maxImageCount < 0 &&
	   engine.swapchain.image_count > engine.swapchain.support.capabilities.maxImageCount {
		engine.swapchain.image_count = engine.swapchain.support.capabilities.maxImageCount
	}


	create_info: vk.SwapchainCreateInfoKHR
	create_info.sType = .SWAPCHAIN_CREATE_INFO_KHR
	create_info.surface = engine.surface
	create_info.minImageCount = engine.swapchain.image_count
	create_info.presentMode = engine.swapchain.present_mode
	create_info.imageFormat = engine.swapchain.format.format
	create_info.imageColorSpace = engine.swapchain.format.colorSpace
	create_info.imageExtent = engine.swapchain.extent
	create_info.imageArrayLayers = 1
	create_info.imageUsage = {.COLOR_ATTACHMENT}

	queueIndicies := [len(engine.queue_familiy_indicies)]u32 {
		u32(engine.queue_familiy_indicies[queue_families.PRESENT]),
		u32(engine.queue_familiy_indicies[queue_families.GRAPHICS]),
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

	create_info.preTransform = engine.swapchain.support.capabilities.currentTransform
	create_info.compositeAlpha = {.OPAQUE}
	create_info.presentMode = engine.swapchain.present_mode
	create_info.clipped = true
	create_info.oldSwapchain = vk.SwapchainKHR{}

	if vk.CreateSwapchainKHR(engine.device, &create_info, nil, &engine.swapchain.handle) !=
	   vk.Result.SUCCESS {
		fmt.eprint("ERROR: failed to create swapchain")
	}
	vk.GetSwapchainImagesKHR(
		engine.device,
		engine.swapchain.handle,
		&engine.swapchain.image_count,
		nil,
	)
	engine.swapchain.images = make([]vk.Image, engine.swapchain.image_count)
	vk.GetSwapchainImagesKHR(
		engine.device,
		engine.swapchain.handle,
		&engine.swapchain.image_count,
		raw_data(engine.swapchain.images),
	)

	create_image_views()
}

recreate_swapchain :: proc() {
	destroy_swapchain()
	create_swapchain()
}

destroy_swapchain :: proc() {
	for v in engine.swapchain.image_views {
		vk.DestroyImageView(engine.device, v, nil)
	}
	for frame in engine.swapchain.frame_buffers {
		vk.DestroyFramebuffer(engine.device, frame, nil)
	}
	vk.DestroySwapchainKHR(engine.device, engine.swapchain.handle, nil)

}
create_image_views :: proc() {
	// create image views
	engine.swapchain.image_views = make([]vk.ImageView, len(engine.swapchain.images))
	for image, index in engine.swapchain.images {
		create_info: vk.ImageViewCreateInfo
		create_info.sType = .IMAGE_VIEW_CREATE_INFO
		create_info.image = image
		create_info.viewType = .D2
		create_info.format = engine.swapchain.format.format
		create_info.components.r = .IDENTITY
		create_info.components.g = .IDENTITY
		create_info.components.b = .IDENTITY
		create_info.components.a = .IDENTITY
		create_info.subresourceRange.aspectMask = {.COLOR}
		create_info.subresourceRange.levelCount = 1
		create_info.subresourceRange.layerCount = 1
		create_info.subresourceRange.baseMipLevel = 0
		create_info.subresourceRange.baseArrayLayer = 0

		if (vk.CreateImageView(
				   engine.device,
				   &create_info,
				   nil,
				   &engine.swapchain.image_views[index],
			   ) !=
			   vk.Result.SUCCESS) {
			fmt.eprint("ERROR: failed to create Image new")
		}
	}
}


create_layout_info :: proc(
	shader_stages: ^[2]vk.PipelineShaderStageCreateInfo,
	pipeline_layout: vk.PipelineLayout,
	renderpass: vk.RenderPass,
	pipeline_data: ^PipelineData,
) -> vk.GraphicsPipelineCreateInfo {
	pipeline_data.dyanamic_states = []vk.DynamicState {
		vk.DynamicState.SCISSOR,
		vk.DynamicState.VIEWPORT,
	}

	pipeline_data.dyanamic_state_create_info.sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO
	pipeline_data.dyanamic_state_create_info.dynamicStateCount = u32(
		len(pipeline_data.dyanamic_states),
	)
	pipeline_data.dyanamic_state_create_info.pDynamicStates = &pipeline_data.dyanamic_states[0]

	pipeline_data.vertex_input_info.sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO

	pipeline_data.vertex_input.sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
	pipeline_data.vertex_input.topology = .TRIANGLE_LIST
	pipeline_data.vertex_input.primitiveRestartEnable = false

	pipeline_data.viewport_state.sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO
	pipeline_data.viewport_state.viewportCount = 1
	pipeline_data.viewport_state.scissorCount = 1

	pipeline_data.rasterizer.sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO
	pipeline_data.rasterizer.polygonMode = .FILL
	pipeline_data.rasterizer.lineWidth = 1
	pipeline_data.rasterizer.cullMode = {.FRONT}
	pipeline_data.rasterizer.frontFace = .CLOCKWISE

	pipeline_data.multisampler.sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
	pipeline_data.multisampler.minSampleShading = 1
	pipeline_data.multisampler.rasterizationSamples = {._1}

	pipeline_data.attachments.colorWriteMask = {.R, .G, .B, .A}

	pipeline_data.color_blend.attachmentCount = 1
	pipeline_data.color_blend.sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
	pipeline_data.color_blend.pAttachments = &pipeline_data.attachments

	pipeline_info: vk.GraphicsPipelineCreateInfo
	pipeline_info.sType = .GRAPHICS_PIPELINE_CREATE_INFO
	pipeline_info.stageCount = 2
	pipeline_info.pStages = &shader_stages[0]
	pipeline_info.pVertexInputState = &pipeline_data.vertex_input_info
	pipeline_info.pInputAssemblyState = &pipeline_data.vertex_input
	pipeline_info.pViewportState = &pipeline_data.viewport_state
	pipeline_info.pRasterizationState = &pipeline_data.rasterizer
	pipeline_info.pMultisampleState = &pipeline_data.multisampler
	pipeline_info.pColorBlendState = &pipeline_data.color_blend
	pipeline_info.pDynamicState = &pipeline_data.dyanamic_state_create_info
	pipeline_info.layout = pipeline_layout
	pipeline_info.renderPass = renderpass
	pipeline_info.subpass = 0
	pipeline_info.basePipelineIndex = -1
	return pipeline_info
}


create_pipeline :: proc(
	shader_stages: ^[2]vk.PipelineShaderStageCreateInfo,
	pipeline_layout: vk.PipelineLayout,
	renderpass: vk.RenderPass,
) -> vk.Pipeline {

	pipeline: vk.Pipeline
	pipeline_data: PipelineData
	pipeline_info := create_layout_info(shader_stages, pipeline_layout, renderpass, &pipeline_data)
	fmt.println(" \n", pipeline_info,pipeline)

	if (vk.CreateGraphicsPipelines(engine.device, 0, 1, &pipeline_info, nil, &pipeline) !=
		   vk.Result.SUCCESS) {
		fmt.eprint("ERROR: failed to create graphics pipeline")
	}
	return pipeline
}

create_renderpass_info :: proc() -> (renderpass: vk.RenderPass) {


	dependency: vk.SubpassDependency
	dependency.srcSubpass = vk.SUBPASS_EXTERNAL
	dependency.dstSubpass = 0
	dependency.srcStageMask = {.COLOR_ATTACHMENT_OUTPUT}
	dependency.srcAccessMask = {}
	dependency.dstStageMask = {.COLOR_ATTACHMENT_OUTPUT}
	dependency.dstAccessMask = {.COLOR_ATTACHMENT_WRITE}

	color_attachment: vk.AttachmentDescription
	color_attachment.format = engine.swapchain.format.format
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

	render_pass: vk.RenderPassCreateInfo
	render_pass.sType = .RENDER_PASS_CREATE_INFO
	render_pass.attachmentCount = 1
	render_pass.pAttachments = &color_attachment
	render_pass.subpassCount = 1
	render_pass.pSubpasses = &subpass
	render_pass.dependencyCount = 1
	render_pass.pDependencies = &dependency

	if vk.CreateRenderPass(engine.device, &render_pass, nil, &renderpass) != .SUCCESS {
		fmt.eprint("ERROR: failed to create render pass")
	}
	return renderpass
}


create_renderpass :: proc() {
	fmt.print("wa")

	frag := create_shader_module(FRAG)
	vert := create_shader_module(VERT)
	color_tri := create_shader_module(MODEL_VERT)
	color_tri_frag := create_shader_module(MODEL_FRAG)


	engine.shader_stages[0] = {}
	engine.shader_stages[0].sType = .PIPELINE_SHADER_STAGE_CREATE_INFO
	engine.shader_stages[0].module = vert
	engine.shader_stages[0].stage = {.VERTEX}
	engine.shader_stages[0].pName = "main"

	engine.shader_stages[1] = {}
	engine.shader_stages[1].sType = .PIPELINE_SHADER_STAGE_CREATE_INFO
	engine.shader_stages[1].module = frag
	engine.shader_stages[1].stage = {.FRAGMENT}
	engine.shader_stages[1].pName = "main"

	engine.mesh_shader_stages[0] = {}

	engine.mesh_shader_stages[0].sType = .PIPELINE_SHADER_STAGE_CREATE_INFO
	engine.mesh_shader_stages[0].module = color_tri
	engine.mesh_shader_stages[0].stage = {.VERTEX}
	engine.mesh_shader_stages[0].pName = "main"

	engine.mesh_shader_stages[1] = engine.shader_stages[1]
	
	//engine.mesh_shader_stages[1].module = color_tri_frag 	
	
	defer vk.DestroyShaderModule(engine.device, vert, nil)
	defer vk.DestroyShaderModule(engine.device, frag, nil)
	defer vk.DestroyShaderModule(engine.device, color_tri, nil)


	engine.render_pass = create_renderpass_info()
	create_frame_buffers()

	buffer_range := vk.PushConstantRange {
		offset     = 0,
		size       = size_of(Push_Constant),
		stageFlags = {.VERTEX},
	}
	

	pipeline_layout: vk.PipelineLayoutCreateInfo
	pipeline_layout.sType = .PIPELINE_LAYOUT_CREATE_INFO

	if (vk.CreatePipelineLayout(engine.device, &pipeline_layout, nil, &engine.pipeline_layout) !=
		   vk.Result.SUCCESS) {
		fmt.eprint("ERROR: failed to create pipeline layout")
	}

	
	engine.pipline = create_pipeline(
		&engine.shader_stages,
		engine.pipeline_layout,
		engine.render_pass,
	)

	pipeline_layout.pushConstantRangeCount = 1
	pipeline_layout.pPushConstantRanges = &buffer_range

    if (vk.CreatePipelineLayout(engine.device, &pipeline_layout, nil, &engine.mesh_pipeline_layout) !=
		   vk.Result.SUCCESS) {
		fmt.eprint("ERROR: failed to create pipeline layout")
	}
	
    engine.mesh_pipline = create_pipeline(
	 	&engine.mesh_shader_stages,
	 	engine.mesh_pipeline_layout,
	 	engine.render_pass,
	)
	
}

default_data :: proc(){
	rect_verts := [4]Vertex{
        { position = {0.5,-0.5, 0},  color = { 0,0, 0.0, 1.0 }},
        { position = {0.5,0.5, 0},   color = { 0.5, 0.5, 0.5 ,1.0 }},
        { position = {-0.5,-0.5, 0}, color = { 1,0, 0.0, 1.0 }},
        { position = {-0.5,0.5, 0},  color = { 0.0, 1.0, 0.0, 1.0 }},
    }
    rect_indices := [6]u32 {
        0, 1, 2,
        2, 1, 3,
    }
    engine.rect = upload_mesh(rect_indices[:], rect_verts[:])
}

create_command_pool :: proc() {
	pool_info: vk.CommandPoolCreateInfo
	pool_info.sType = .COMMAND_POOL_CREATE_INFO
	pool_info.flags = {.RESET_COMMAND_BUFFER}
	pool_info.queueFamilyIndex = u32(engine.queue_familiy_indicies[.GRAPHICS])

	if (vk.CreateCommandPool(engine.device, &pool_info, nil, &engine.command_pool) !=
		   vk.Result.SUCCESS) {
		fmt.eprint("ERROR: failed to create command pool")
	}

	if (vk.CreateCommandPool(engine.device, &pool_info, nil, &engine.imm_command_pool) !=
		   vk.Result.SUCCESS) {
		fmt.eprint("ERROR: failed to create command pool")
	}


	alloc_info: vk.CommandBufferAllocateInfo
	alloc_info.sType = .COMMAND_BUFFER_ALLOCATE_INFO
	alloc_info.commandPool = engine.command_pool
	alloc_info.level = .PRIMARY
	alloc_info.commandBufferCount = len(engine.command_buffer)

	if (vk.AllocateCommandBuffers(engine.device, &alloc_info, &engine.command_buffer[0]) !=
		   vk.Result.SUCCESS) {
		fmt.eprint("ERROR: failed to allocate command buffers")
	}


	if (vk.AllocateCommandBuffers(engine.device, &alloc_info, &engine.imm_command_buffer) !=
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
		if (vk.CreateSemaphore(engine.device, &semaphore, nil, &engine.signal_semaphore[i]) !=
			   .SUCCESS) {
			fmt.eprint("ERROR: failed to create semaphore")
		}
		if (vk.CreateSemaphore(engine.device, &semaphore, nil, &engine.image_available[i]) !=
			   .SUCCESS) {
			fmt.eprint("ERROR: failed to create semaphore")
		}
		if (vk.CreateFence(engine.device, &fence, nil, &engine.fence[i]) != .SUCCESS) {
			fmt.eprint("ERROR: failed to create semaphore")
		}
	}
	fmt.print("fence")
	if (vk.CreateFence(engine.device, &fence, nil, &engine.immidate_fence) != .SUCCESS) {
		fmt.eprint("ERROR: failed to create semaphore")
	}
}

create_frame_buffers :: proc() {
	engine.swapchain.frame_buffers = make([]vk.Framebuffer, len(engine.swapchain.image_views))

	for view, index in engine.swapchain.image_views {
		attachments := [?]vk.ImageView{view}

		frame_buffer: vk.FramebufferCreateInfo
		frame_buffer.sType = .FRAMEBUFFER_CREATE_INFO
		frame_buffer.renderPass = engine.render_pass
		frame_buffer.attachmentCount = 1
		frame_buffer.pAttachments = &attachments[0]
		frame_buffer.width = engine.swapchain.extent.width
		frame_buffer.height = engine.swapchain.extent.height
		frame_buffer.layers = 1

		if (vk.CreateFramebuffer(
				   engine.device,
				   &frame_buffer,
				   nil,
				   &engine.swapchain.frame_buffers[index],
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

	if (vk.CreateShaderModule(engine.device, &info, nil, &module) == vk.Result.SUCCESS) {
		return module
	} else {
		fmt.eprintln("ERROR: failed to create shader module")
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

record_command_buffer :: proc(image_index: u32) {
	begin_info: vk.CommandBufferBeginInfo
	begin_info.sType = .COMMAND_BUFFER_BEGIN_INFO


	command_buffer := engine.command_buffer[engine.frame_id]
	if vk.BeginCommandBuffer(command_buffer, &begin_info) != .SUCCESS {
		fmt.eprint("ERROR: command buffer not beginning")
	}

	clear_color: vk.ClearValue
	clear_color.color.float32 = {0.0, 0.0, 0.0, 1.0}

	render_pass_begin_info: vk.RenderPassBeginInfo
	render_pass_begin_info.sType = .RENDER_PASS_BEGIN_INFO
	render_pass_begin_info.renderPass = engine.render_pass
	render_pass_begin_info.framebuffer = engine.swapchain.frame_buffers[image_index]
	render_pass_begin_info.renderArea = {
		extent = engine.swapchain.extent,
	}
	render_pass_begin_info.pClearValues = &clear_color
	render_pass_begin_info.clearValueCount = 1


	vk.CmdBeginRenderPass(command_buffer, &render_pass_begin_info, .INLINE)

	//vk.CmdBindPipeline(command_buffer, .GRAPHICS, engine.)

	viewport: vk.Viewport

	viewport.width = f32(engine.swapchain.extent.width)
	viewport.height = f32(engine.swapchain.extent.height)
	viewport.maxDepth = 1.0

	vk.CmdSetViewport(command_buffer, 0, 1, &viewport)


	scissor: vk.Rect2D
	scissor.extent = engine.swapchain.extent

	vk.CmdSetScissor(command_buffer, 0, 1, &scissor)

	attachment_info := vk.RenderingAttachmentInfo {
		sType       = .RENDERING_ATTACHMENT_INFO,
		imageView   = engine.swapchain.image_views[image_index],
		imageLayout = nil,
		loadOp      = .LOAD,
		storeOp     = .STORE
	}
	rendering_info := vk.RenderingInfo {
		sType = .RENDERING_INFO,
		renderArea = scissor,
		layerCount = 1,
		colorAttachmentCount = 1,
		pColorAttachments = &attachment_info
		
	}
	
	

	//vk.CmdDraw(command_buffer, 3, 1, 0, 0)
	vk.CmdBeginRendering(command_buffer,&rendering_info)
	// begin mesh pipeline
	vk.CmdBindPipeline(command_buffer,.GRAPHICS,engine.mesh_pipline)

	push_constant := Push_Constant{
		glm.identity(glm.mat4),
		engine.rect.vertext_buffer_address
	}
	vk.CmdPushConstants(
		command_buffer,
		engine.mesh_pipeline_layout,
		{.VERTEX},
		0,
		size_of(Push_Constant),
		&push_constant
	
	)

	vk.CmdBindIndexBuffer(command_buffer,engine.rect.index_buffer.buffer, 0, .UINT32)

	vk.CmdDrawIndexed(command_buffer, 6,1,0,0,0)
	
	
	vk.CmdEndRenderPass(command_buffer)
	vk.CmdEndRendering(command_buffer)
	vk.EndCommandBuffer(command_buffer)

}
