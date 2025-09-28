package main
import "base:runtime"
import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:mem"
import "core:slice"
import "core:strings"
import "vendor:glfw"
import vk "vendor:vulkan"


// Vertex :: struct {
// 	positon: glm.vec3,
// 	color:   glm.vec3,
// }

TITLE :: "The Projector"

FRAMES_IN_FLIGHT :: 2
VALIDATION_LAYER: []cstring : {"VK_LAYER_KHRONOS_validation"}
EXSTENTION_LAYER: []cstring : {vk.EXT_DEBUG_UTILS_EXTENSION_NAME}
DEVICE_EXSTENTION_LAYER: []cstring : {
	vk.KHR_SWAPCHAIN_EXTENSION_NAME,
	vk.KHR_SPIRV_1_4_EXTENSION_NAME,
	vk.KHR_SYNCHRONIZATION_2_EXTENSION_NAME,
	vk.KHR_CREATE_RENDERPASS_2_EXTENSION_NAME,
	vk.EXT_DEBUG_MARKER_EXTENSION_NAME,
}

SHADER_MODULE :: #load("shaders/slang.spv")

Engine :: struct {
	window:         glfw.WindowHandle,
	instance:       vk.Instance,
	physicalDevice: vk.PhysicalDevice,
	device:         vk.Device,
	surface:        vk.SurfaceKHR,
	surfaceformat:  vk.SurfaceFormatKHR,
	extent:         vk.Extent2D,
	swapchain:      vk.SwapchainKHR,
	queue:          vk.Queue,
	imageViews:     []vk.ImageView,
	pipeline:       vk.Pipeline,
	commandPool:    vk.CommandPool,
	commandBuffer:  [FRAMES_IN_FLIGHT]vk.CommandBuffer,
	sync_object:    [FRAMES_IN_FLIGHT]SyncObjects,
	vertBuffer:     vk.Buffer,
	memory:         vk.DeviceMemory,
	resized:        bool,
}
SyncObjects :: struct {
	present:        vk.Semaphore,
	renderFinished: vk.Semaphore,
	drawFence:      vk.Fence,
}
engine: Engine

Vertex :: struct {
	pos:   [2]f32,
	color: [3]f32,
}

vertices := [3]Vertex {
	Vertex{pos = {0.0, -0.25}, color = {1.0, 0.0, 0.0}},
	Vertex{pos = {0.5, 0.5}, color = {0.0, 1.0, 0.0}},
	Vertex{pos = {-0.5, 0.5}, color = {0.0, 0.0, 1.0}},
}

VERTEX_BINDING_DESCRIPTION :: vk.VertexInputBindingDescription{0, size_of(Vertex), .VERTEX}
VERTEX_ATTRIBUTE_DESICRIPTION :: [2]vk.VertexInputAttributeDescription {
	vk.VertexInputAttributeDescription{0, 0, .R32G32_SFLOAT, u32(offset_of(Vertex, pos))},
	vk.VertexInputAttributeDescription{1, 0, .R32G32B32_SFLOAT, u32(offset_of(Vertex, color))},
}
cleanup :: proc() {

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

main :: proc() {
	defer cleanup()

	glfw.Init()
	glfw.VulkanSupported()
	defer glfw.Terminate()

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	// glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)

	width: i32 = 1600
	height: i32 = 900
	engine.window = glfw.CreateWindow(width, height, TITLE, glfw.GetPrimaryMonitor(), nil)
	defer glfw.DestroyWindow(engine.window)

	glfw.SetFramebufferSizeCallback(engine.window, framebuffer_resize_callback)
	//fmt.print(rawptr(glfw.GetInstanceProcAddress))
	vk.load_proc_addresses_global(rawptr(glfw.GetInstanceProcAddress))

	fmt.assertf(vk.CreateInstance != nil, "Failed to load proc")


	create_instance()

	defer destroy_instance()


	fmt.print("here", engine.instance, "wome")

	must(glfw.CreateWindowSurface(engine.instance, engine.window, nil, &engine.surface))
	graphics_queue: int
	engine.physicalDevice, graphics_queue = pick_physical_device(
		get_pyhsical_devices(engine.instance),
	)
	create_logical_device(engine.physicalDevice, u32(graphics_queue))
	defer vk.DestroyDevice(engine.device, nil)


	vk.GetDeviceQueue(engine.device, 0, u32(graphics_queue), &engine.queue)

	engine.swapchain, engine.surfaceformat, engine.extent = create_swapchain(
		engine.physicalDevice,
		engine.surface,
	)
	defer vk.DestroySwapchainKHR(engine.device, engine.swapchain, nil)

	images := get_swap_chain_images(engine.device, engine.swapchain)

	engine.imageViews = create_image_views(
		engine.device,
		engine.swapchain,
		engine.surfaceformat.format,
		engine.imageViews,
	)
	defer {
		for image in engine.imageViews {
			vk.DestroyImageView(engine.device, image, nil)
		}
	}
	layout := create_pipeline_layout(engine.device)
	defer (vk.DestroyPipelineLayout(engine.device, layout, nil))

	engine.pipeline = create_graphics_pipeline(engine.device, layout, &engine.surfaceformat.format)
	defer (vk.DestroyPipeline(engine.device, engine.pipeline, nil))

	engine.commandPool = create_command_pool(engine.device, u32(graphics_queue))
	defer vk.DestroyCommandPool(engine.device, engine.commandPool, nil)

	engine.commandBuffer = create_command_buffer(engine.device, engine.commandPool)

	for &sync_object in engine.sync_object {

		sync_object = create_sync_object(engine.device)
	}
	defer {
		for &sync_object in engine.sync_object {
			destroy_sync_objects(engine.device, sync_object)
		}
	}

	engine.vertBuffer, engine.memory = create_vertex_buffer(engine.device, engine.physicalDevice)

	currentFrame := 0
	// vk.CreateBuffer()
	for !glfw.WindowShouldClose(engine.window) {

		glfw.PollEvents()
		draw_frame(currentFrame)
		glfw.SwapBuffers(engine.window)
		currentFrame = (currentFrame + 1) % FRAMES_IN_FLIGHT
	}
}
create_vertex_buffer :: proc(
	device: vk.Device,
	physicalDevice: vk.PhysicalDevice,
) -> (
	vk.Buffer,
	vk.DeviceMemory,
) {


	buffer, memory := create_buffer(
		vk.DeviceSize(u64(size_of(Vertex) * len(vertices))),
		{.VERTEX_BUFFER},
	)
	vk.BindBufferMemory(device, buffer, memory, 0)
	memPtr: rawptr
	vk.MapMemory(device, memory, 0, size_of(vertices), {}, &memPtr)
	mem.copy(memPtr, &vertices[0], len(vertices) * size_of(Vertex))
	fmt.print("is this happening something \n\n\n\\n\n")

	return buffer, memory
}


create_sync_object :: proc(device: vk.Device) -> SyncObjects {
	object: SyncObjects
	object.present = create_semaphore(device)
	object.renderFinished = create_semaphore(device)
	object.drawFence = create_fence(device, {.SIGNALED})
	return object
}
destroy_sync_objects :: proc(device: vk.Device, object: SyncObjects) {
	vk.DestroySemaphore(device, object.present, nil)
	vk.DestroySemaphore(device, object.renderFinished, nil)
	vk.DestroyFence(device, object.drawFence, nil)
}

framebuffer_resize_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {

}
draw_frame :: proc(current_frame: int) {
	for (.TIMEOUT ==
		    vk.WaitForFences(
			    engine.device,
			    1,
			    &engine.sync_object[current_frame].drawFence,
			    true,
			    max(u64),
		    )) {}
	imageIndex: u32

	// fmt.printf(
	// 	u32(offset_of(Vertex, color)),// "\n\n\n\n\n\ncolor{}:pos{}\n\n\n\n",
	// 	u32(offset_of(Vertex, pos)),
	// )
	res := vk.AcquireNextImageKHR(
		engine.device,
		engine.swapchain,
		max(u64),
		engine.sync_object[current_frame].present,
		engine.sync_object[current_frame].drawFence,
		&imageIndex,
	)

	// fmt.print("\n\n\n\nsomething happended here \n\n\n\n")
	if res == .ERROR_OUT_OF_DATE_KHR {
		engine.resized = false
		recreate_swapchain(engine.device, engine.physicalDevice, engine.surface)
	}
	//  else {
	// 	fmt.eprint("failed to aquire image")
	// 	return
	// }
	vk.ResetFences(engine.device, 1, &engine.sync_object[current_frame].drawFence)


	recordCommandBuffer(engine.commandBuffer[current_frame], imageIndex)

	stage_mask: vk.PipelineStageFlags
	stage_mask = {.COLOR_ATTACHMENT_OUTPUT}
	submit_info: vk.SubmitInfo
	submit_info.sType = .SUBMIT_INFO
	submit_info.waitSemaphoreCount = 1
	submit_info.pWaitSemaphores = &engine.sync_object[current_frame].present
	submit_info.pWaitDstStageMask = &stage_mask
	submit_info.pCommandBuffers = &engine.commandBuffer[current_frame]
	submit_info.commandBufferCount = 1
	submit_info.signalSemaphoreCount = 1
	submit_info.pSignalSemaphores = &engine.sync_object[current_frame].renderFinished
	vk.QueueSubmit(engine.queue, 1, &submit_info, engine.sync_object[current_frame].drawFence)
	out := vk.WaitForFences(
		engine.device,
		1,
		&engine.sync_object[current_frame].drawFence,
		true,
		max(u64),
	)


	// for vk.WaitForFences(
	// 	    engine.device,
	// 	    1,
	// 	    &engine.sync_object[current_frame].drawFence,
	// 	    true,
	// 	    max(u64),
	//     ) ==
	//     .TIMEOUT {}

	presentInfo: vk.PresentInfoKHR
	presentInfo.sType = .PRESENT_INFO_KHR
	presentInfo.pSwapchains = &engine.swapchain
	presentInfo.swapchainCount = 1
	presentInfo.waitSemaphoreCount = 1
	presentInfo.pImageIndices = &imageIndex
	presentInfo.pWaitSemaphores = &engine.sync_object[current_frame].renderFinished
	vk.QueuePresentKHR(engine.queue, &presentInfo)

}

create_command_pool :: proc(device: vk.Device, queueIndex: u32) -> vk.CommandPool {
	info: vk.CommandPoolCreateInfo
	info.sType = .COMMAND_POOL_CREATE_INFO
	info.flags = {.RESET_COMMAND_BUFFER}
	info.queueFamilyIndex = queueIndex


	pool: vk.CommandPool
	vk.CreateCommandPool(device, &info, nil, &pool)
	return pool
}
create_command_buffer :: proc(
	device: vk.Device,
	commandPool: vk.CommandPool,
) -> [FRAMES_IN_FLIGHT]vk.CommandBuffer {

	info: vk.CommandBufferAllocateInfo
	info.sType = .COMMAND_BUFFER_ALLOCATE_INFO
	info.level = .PRIMARY
	info.commandBufferCount = FRAMES_IN_FLIGHT
	info.commandPool = commandPool

	command_buffer: [FRAMES_IN_FLIGHT]vk.CommandBuffer

	vk.AllocateCommandBuffers(device, &info, &command_buffer[0])
	return command_buffer
}
transition_image_layout :: proc(
	cmd: vk.CommandBuffer,
	imageIndex: u32,
	oldLayout: vk.ImageLayout,
	newLayout: vk.ImageLayout,
	srcAccesMask: vk.AccessFlags2,
	dstAccessMask: vk.AccessFlags2,
	srcStageMask: vk.PipelineStageFlag2,
	dstStageMask: vk.PipelineStageFlag,
) {
	images := get_swap_chain_images(engine.device, engine.swapchain)

	subresource: vk.ImageSubresourceRange

	subresource.aspectMask = {.COLOR}
	subresource.baseMipLevel = 0
	subresource.levelCount = 1
	subresource.baseArrayLayer = 0
	subresource.layerCount = 1

	barrier: vk.ImageMemoryBarrier2
	barrier.sType = .IMAGE_MEMORY_BARRIER_2
	barrier.srcAccessMask = srcAccesMask
	barrier.dstAccessMask = dstAccessMask
	barrier.oldLayout = oldLayout
	barrier.newLayout = newLayout
	barrier.srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED
	barrier.dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED
	barrier.image = images[imageIndex]
	barrier.subresourceRange = subresource

	info: vk.DependencyInfo
	info.sType = .DEPENDENCY_INFO
	info.dependencyFlags = {}
	info.imageMemoryBarrierCount = 1
	info.pImageMemoryBarriers = &barrier
	vk.CmdPipelineBarrier2(cmd, &info)
}


recordCommandBuffer :: proc(cmd: vk.CommandBuffer, imageIndex: u32) {

	beginInfo: vk.CommandBufferBeginInfo
	beginInfo.sType = .COMMAND_BUFFER_BEGIN_INFO
	// beginInfo.
	vk.BeginCommandBuffer(cmd, &beginInfo)
	// vk.TransitionImageLayout(engine.device,)
	transition_image_layout(
		cmd,
		imageIndex,
		.UNDEFINED,
		.COLOR_ATTACHMENT_OPTIMAL,
		{},
		{.COLOR_ATTACHMENT_WRITE},
		.TOP_OF_PIPE,
		.COLOR_ATTACHMENT_OUTPUT,
	)

	clearColor: vk.ClearValue
	// inside :[4]f32= 
	clearColor.color.float32 = {f32(0.0), f32(0.0), f32(0.0), f32(0.0)}


	images := get_swap_chain_images(engine.device, engine.swapchain)
	attachmentInfo: vk.RenderingAttachmentInfo
	attachmentInfo.sType = .RENDERING_ATTACHMENT_INFO
	attachmentInfo.imageView = engine.imageViews[imageIndex]
	attachmentInfo.loadOp = .CLEAR
	attachmentInfo.storeOp = .STORE
	attachmentInfo.clearValue = clearColor
	attachmentInfo.imageLayout = .COLOR_ATTACHMENT_OPTIMAL


	rect: vk.Rect2D
	rect.extent = engine.extent
	rect.offset = {0.0, 0.0}

	//rect.extent = choose_swapchain_extent(Engine)
	renderingInfo: vk.RenderingInfo
	renderingInfo.sType = .RENDERING_INFO
	renderingInfo.renderArea = rect
	renderingInfo.layerCount = 1
	renderingInfo.colorAttachmentCount = 1
	renderingInfo.pColorAttachments = &attachmentInfo

	vk.CmdBeginRendering(cmd, &renderingInfo)
	vk.CmdBindPipeline(cmd, .GRAPHICS, engine.pipeline)
	size: vk.DeviceSize
	size = 0
	vk.CmdBindVertexBuffers(cmd, 0, 1, &engine.vertBuffer, &size)

	scissor: vk.Rect2D
	scissor.extent = engine.extent
	scissor.offset = vk.Offset2D{0, 0}

	vk.CmdSetScissor(cmd, 0, 1, &scissor)
	viewport: vk.Viewport
	viewport.height = f32(engine.extent.height)
	viewport.width = f32(engine.extent.width)
	vk.CmdSetViewport(cmd, 0, 1, &viewport)
	vk.CmdDraw(cmd, 3, 1, 0, 0)
	vk.CmdEndRendering(cmd)
	transition_image_layout(
		cmd,
		imageIndex,
		.ATTACHMENT_OPTIMAL,
		.PRESENT_SRC_KHR,
		{.COLOR_ATTACHMENT_WRITE},
		{},
		.COLOR_ATTACHMENT_OUTPUT,
		.BOTTOM_OF_PIPE,
	)

	vk.EndCommandBuffer(cmd)

}
create_pipeline_layout :: proc(device: vk.Device) -> vk.PipelineLayout {
	layout: vk.PipelineLayout

	info: vk.PipelineLayoutCreateInfo
	info.sType = .PIPELINE_LAYOUT_CREATE_INFO
	info.setLayoutCount = 0
	info.pushConstantRangeCount = 0
	must(vk.CreatePipelineLayout(device, &info, nil, &layout))
	return layout
}

recreate_swapchain :: proc(
	device: vk.Device,
	physicalDevice: vk.PhysicalDevice,
	surface: vk.SurfaceKHR,
) {

	width, height := glfw.GetFramebufferSize(engine.window)
	for width == 0 || height == 0 {
		width, height = glfw.GetFramebufferSize(engine.window)
		glfw.WaitEvents()
	}
	vk.DeviceWaitIdle(device)

	engine.swapchain, engine.surfaceformat, engine.extent = create_swapchain(
		physicalDevice,
		engine.surface,
	)
	engine.imageViews = create_image_views(
		device,
		engine.swapchain,
		engine.surfaceformat.format,
		engine.imageViews,
	)
}
create_graphics_pipeline :: proc(
	device: vk.Device,
	pipelineLayout: vk.PipelineLayout,
	format: [^]vk.Format,
) -> vk.Pipeline {
	shader := create_shader_module(SHADER_MODULE)

	vertShaderInfo: vk.PipelineShaderStageCreateInfo
	vertShaderInfo.sType = .PIPELINE_SHADER_STAGE_CREATE_INFO
	vertShaderInfo.module = shader
	vertShaderInfo.pName = "vertMain"
	vertShaderInfo.stage = {.VERTEX}

	fragShaderInfo: vk.PipelineShaderStageCreateInfo
	fragShaderInfo.sType = .PIPELINE_SHADER_STAGE_CREATE_INFO
	fragShaderInfo.module = shader
	fragShaderInfo.pName = "fragMain"
	fragShaderInfo.stage = {.FRAGMENT}

	stages: [2]vk.PipelineShaderStageCreateInfo = {vertShaderInfo, fragShaderInfo}
	dynamic_states: [2]vk.DynamicState
	dynamic_states[0] = .VIEWPORT
	dynamic_states[1] = .SCISSOR

	dynamic_state: vk.PipelineDynamicStateCreateInfo
	dynamic_state.sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO
	dynamic_state.dynamicStateCount = len(dynamic_states)
	dynamic_state.pDynamicStates = raw_data(dynamic_states[:])

	vert_desc := VERTEX_BINDING_DESCRIPTION
	vert_att_desc := VERTEX_ATTRIBUTE_DESICRIPTION
	vertexPipelineInfo: vk.PipelineVertexInputStateCreateInfo
	vertexPipelineInfo.sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
	vertexPipelineInfo.vertexBindingDescriptionCount = 1
	vertexPipelineInfo.pVertexBindingDescriptions = &vert_desc
	vertexPipelineInfo.vertexAttributeDescriptionCount = u32(len(VERTEX_ATTRIBUTE_DESICRIPTION))
	vertexPipelineInfo.pVertexAttributeDescriptions = &vert_att_desc[0]

	inputAssemblyStateInfo: vk.PipelineInputAssemblyStateCreateInfo
	inputAssemblyStateInfo.sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
	inputAssemblyStateInfo.topology = .TRIANGLE_LIST

	// vk.Viewport
	viewPortStateInfo: vk.PipelineViewportStateCreateInfo
	viewPortStateInfo.sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO
	viewPortStateInfo.scissorCount = 1
	viewPortStateInfo.viewportCount = 1

	rasterizer: vk.PipelineRasterizationStateCreateInfo
	rasterizer.sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO
	rasterizer.depthClampEnable = false
	rasterizer.rasterizerDiscardEnable = false
	rasterizer.polygonMode = .FILL
	rasterizer.cullMode = {.BACK}
	rasterizer.frontFace = .CLOCKWISE
	rasterizer.depthBiasEnable = false
	rasterizer.depthBiasSlopeFactor = 1.0
	rasterizer.lineWidth = 1.0

	multisampling: vk.PipelineMultisampleStateCreateInfo
	multisampling.sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
	multisampling.rasterizationSamples = {._1}
	multisampling.sampleShadingEnable = true

	colorBlendAttachment: vk.PipelineColorBlendAttachmentState
	colorBlendAttachment.colorWriteMask = {.R, .G, .B, .A}
	colorBlendAttachment.blendEnable = false

	colorBlending: vk.PipelineColorBlendStateCreateInfo
	colorBlending.sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
	colorBlending.logicOp = .COPY
	colorBlending.logicOpEnable = false
	colorBlending.attachmentCount = 1
	colorBlending.pAttachments = &colorBlendAttachment

	pipelineRendering: vk.PipelineRenderingCreateInfo
	pipelineRendering.sType = .PIPELINE_RENDERING_CREATE_INFO
	pipelineRendering.colorAttachmentCount = 1
	pipelineRendering.pColorAttachmentFormats = format

	pipelineInfo: vk.GraphicsPipelineCreateInfo
	pipelineInfo.sType = .GRAPHICS_PIPELINE_CREATE_INFO
	pipelineInfo.pStages = raw_data(stages[:])
	pipelineInfo.stageCount = 2
	pipelineInfo.pVertexInputState = &vertexPipelineInfo
	pipelineInfo.pInputAssemblyState = &inputAssemblyStateInfo
	pipelineInfo.pViewportState = &viewPortStateInfo
	pipelineInfo.pRasterizationState = &rasterizer
	pipelineInfo.pColorBlendState = &colorBlending
	pipelineInfo.pMultisampleState = &multisampling
	pipelineInfo.pDynamicState = &dynamic_state
	pipelineInfo.layout = pipelineLayout
	pipelineInfo.pNext = &pipelineRendering
	// pipelineInfo.renderPass = nil

	pipeline: vk.Pipeline
	must(vk.CreateGraphicsPipelines(device, {}, 1, &pipelineInfo, nil, &pipeline))
	return pipeline

}


create_image_views :: proc(
	device: vk.Device,
	swapchain: vk.SwapchainKHR,
	format: vk.Format,
	old_image_views: []vk.ImageView,
) -> []vk.ImageView {
	for view in old_image_views {

		vk.DestroyImageView(device, view, nil)
	}

	images := get_swap_chain_images(device, swapchain)
	info := make([]vk.ImageViewCreateInfo, len(images))
	image_view := make([]vk.ImageView, len(images))
	for image, index in images {
		info[index].sType = .IMAGE_VIEW_CREATE_INFO
		// info[index].flags = {.}
		info[index].image = image
		info[index].viewType = .D2
		info[index].format = format
		info[index].subresourceRange.aspectMask = {.COLOR}
		info[index].subresourceRange.baseArrayLayer = 0
		info[index].subresourceRange.layerCount = 1
		info[index].subresourceRange.baseMipLevel = 0
		info[index].subresourceRange.levelCount = 1
		info[index].components.r = .IDENTITY
		info[index].components.g = .IDENTITY
		info[index].components.b = .IDENTITY
		info[index].components.a = .IDENTITY
		must(vk.CreateImageView(device, &info[index], nil, &image_view[index]))
	}
	return image_view
}

create_swapchain :: proc(
	device: vk.PhysicalDevice,
	surface: vk.SurfaceKHR,
) -> (
	vk.SwapchainKHR,
	vk.SurfaceFormatKHR,
	vk.Extent2D,
) {
	capabilities: vk.SurfaceCapabilitiesKHR
	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &capabilities)
	extent := choose_swapchain_extent(capabilities)
	format := pick_available_format(get_surface_formats(device, surface))
	mode := pick_present_mode(get_surface_present_modes(device, surface))
	minImageCount := max(3, capabilities.minImageCount)
	minImageCount += 1

	info := vk.SwapchainCreateInfoKHR {
		sType            = .SWAPCHAIN_CREATE_INFO_KHR,
		surface          = surface,
		minImageCount    = u32(minImageCount),
		imageFormat      = format.format,
		imageColorSpace  = format.colorSpace,
		imageUsage       = {.COLOR_ATTACHMENT},
		imageSharingMode = .EXCLUSIVE,
		imageExtent      = extent,
		imageArrayLayers = 1,
		preTransform     = capabilities.currentTransform,
		compositeAlpha   = {.OPAQUE},
		presentMode      = mode,
		clipped          = true,
	}
	swapchain: vk.SwapchainKHR
	vk.CreateSwapchainKHR(engine.device, &info, nil, &swapchain)
	return swapchain, format, extent
}

pick_available_format :: proc(formats: []vk.SurfaceFormatKHR) -> vk.SurfaceFormatKHR {

	for format in formats {
		if format.format == vk.Format.B8G8R8A8_SRGB &&
		   format.colorSpace == vk.ColorSpaceKHR.SRGB_NONLINEAR {
			return format
		}
	}
	return formats[0]
}

pick_present_mode :: proc(modes: []vk.PresentModeKHR) -> vk.PresentModeKHR {
	for mode in modes {
		if mode == vk.PresentModeKHR.MAILBOX {
			return mode
		}
	}
	return .FIFO
}

choose_swapchain_extent :: proc(capabilities: vk.SurfaceCapabilitiesKHR) -> vk.Extent2D {
	if capabilities.currentExtent.width != max(u32) {
		return capabilities.currentExtent
	}
	width, height := glfw.GetFramebufferSize(engine.window)

	return vk.Extent2D {
		width = clamp(
			u32(width),
			capabilities.minImageExtent.width,
			capabilities.maxImageExtent.width,
		),
		height = clamp(
			u32(height),
			capabilities.minImageExtent.height,
			capabilities.maxImageExtent.height,
		),
	}
}
pick_physical_device :: proc(devices: []vk.PhysicalDevice) -> (vk.PhysicalDevice, int) {


	for device in devices {
		properties: vk.PhysicalDeviceProperties
		vk.GetPhysicalDeviceProperties(device, &properties)

		if (properties.apiVersion < vk.API_VERSION_1_3) {
			fmt.eprintf("This physical device doesn't support API 1.3")
		}
		// TODO: actually vaildate device extentions
		count: u32
		vk.GetPhysicalDeviceQueueFamilyProperties(device, &count, nil)
		queueFamilyProperties := make([]vk.QueueFamilyProperties, count)
		vk.GetPhysicalDeviceQueueFamilyProperties(device, &count, raw_data(queueFamilyProperties))

		for queueFamilyProperty, index in queueFamilyProperties {

			is_supported: b32
			must(
				vk.GetPhysicalDeviceSurfaceSupportKHR(
					device,
					u32(index),
					engine.surface,
					&is_supported,
				),
			)


			if is_supported {
				if vk.QueueFlag.GRAPHICS in queueFamilyProperty.queueFlags {
					fmt.printf("yes do {} \n\n\n", index)
					return device, index

				} else {
					fmt.print("what do")
				}
			}


		}

	}
	return {}, 1
}

create_logical_device :: proc(device: vk.PhysicalDevice, queue_index: u32) {

	featureDynamicState: vk.PhysicalDeviceExtendedDynamicStateFeaturesEXT
	featureDynamicState.sType = .PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_FEATURES_EXT
	featureDynamicState.extendedDynamicState = true
	feature13: vk.PhysicalDeviceVulkan13Features
	feature13.sType = .PHYSICAL_DEVICE_VULKAN_1_3_FEATURES
	feature13.dynamicRendering = true
	feature13.synchronization2 = true
	feature13.pNext = &featureDynamicState
	feature12: vk.PhysicalDeviceVulkan12Features
	feature12.sType = .PHYSICAL_DEVICE_VULKAN_1_2_FEATURES
	// feature12.
	feature11: vk.PhysicalDeviceVulkan11Features
	feature11.sType = .PHYSICAL_DEVICE_VULKAN_1_1_FEATURES
	feature11.shaderDrawParameters = true
	feature11.pNext = &feature13
	features: vk.PhysicalDeviceFeatures
	features.sampleRateShading = true
	feature: vk.PhysicalDeviceFeatures2
	feature.sType = .PHYSICAL_DEVICE_FEATURES_2
	feature.features = features
	feature.pNext = &feature11

	priority: []f32 = {1.0}
	enabled_extentions := DEVICE_EXSTENTION_LAYER
	queueFamilyCreateInfo: vk.DeviceQueueCreateInfo
	queueFamilyCreateInfo.sType = .DEVICE_QUEUE_CREATE_INFO
	queueFamilyCreateInfo.queueFamilyIndex = queue_index
	queueFamilyCreateInfo.queueCount = 1
	queueFamilyCreateInfo.pQueuePriorities = raw_data(priority)
	deviceCreateInfo: vk.DeviceCreateInfo
	deviceCreateInfo.sType = .DEVICE_CREATE_INFO
	deviceCreateInfo.pQueueCreateInfos = &queueFamilyCreateInfo
	deviceCreateInfo.queueCreateInfoCount = 1
	deviceCreateInfo.enabledExtensionCount = u32(len(enabled_extentions))
	deviceCreateInfo.ppEnabledExtensionNames = raw_data(enabled_extentions)
	deviceCreateInfo.pNext = &feature
	must(vk.CreateDevice(device, &deviceCreateInfo, nil, &engine.device))
}

create_instance :: proc() {

	appInfo: vk.ApplicationInfo
	appInfo.apiVersion = vk.MAKE_VERSION(1, 0, 0)
	appInfo.pEngineName = TITLE
	appInfo.engineVersion = vk.MAKE_VERSION(1, 0, 0)
	appInfo.apiVersion = vk.API_VERSION_1_4

	ExtensionCount: u32
	extenstions := glfw.GetRequiredInstanceExtensions()
	must(vk.EnumerateInstanceExtensionProperties(nil, &ExtensionCount, nil))


	properties := make([]vk.ExtensionProperties, ExtensionCount)

	must(vk.EnumerateInstanceExtensionProperties(nil, &ExtensionCount, raw_data(properties)))

	if (!validate_extentions(extenstions, properties)) {
		fmt.eprint("failed to get required extentions")
	}

	finalExtentions: [dynamic]cstring
	for extention in (extenstions) {
		append(&finalExtentions, extention)

	}
	for extention in EXSTENTION_LAYER {

		append(&finalExtentions, extention)
	}
	createInfo: vk.InstanceCreateInfo
	createInfo.sType = .INSTANCE_CREATE_INFO
	createInfo.pApplicationInfo = &appInfo
	createInfo.enabledExtensionCount = u32(len(finalExtentions))
	createInfo.ppEnabledExtensionNames = raw_data(finalExtentions)
	createInfo.ppEnabledLayerNames = raw_data(VALIDATION_LAYER)
	createInfo.enabledLayerCount = u32(len(VALIDATION_LAYER))

	must(vk.CreateInstance(&createInfo, nil, &engine.instance))

	vk.load_proc_addresses_instance(engine.instance)
	when ODIN_DEBUG 
	{
		default_debug_callback :: proc "system" (
			message_severity: vk.DebugUtilsMessageSeverityFlagsEXT,
			message_types: vk.DebugUtilsMessageTypeFlagsEXT,
			p_callback_data: ^vk.DebugUtilsMessengerCallbackDataEXT,
			p_user_data: rawptr,
		) -> b32 {
			context = runtime.default_context()

			if .WARNING in message_severity {
				fmt.print("\n\n\n")
				fmt.printfln(
					"[{}]: {}",
					color_text(fmt.tprint(message_types)),
					p_callback_data.pMessage,
				)
			} else if .ERROR in message_severity {
				if (.VALIDATION in message_types) {

					fmt.eprintfln(
						"[[{}]: {}",
						color_text(fmt.tprint(message_types)),
						p_callback_data.pMessage,
					)

				}
				//runtime.debug_trap()
			} else {
				fmt.printfln("[{}]: {}", message_types, p_callback_data.pMessage)
			}

			return false // Applications must return false herev
		}

		debugCreateInfo: vk.DebugUtilsMessengerCreateInfoEXT
		debugCreateInfo.sType = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT
		debugCreateInfo.messageSeverity = {.VERBOSE, .ERROR, .INFO, .WARNING}
		debugCreateInfo.messageType = {.GENERAL, .VALIDATION}
		debugCreateInfo.pfnUserCallback = default_debug_callback

		messanger: vk.DebugUtilsMessengerEXT
		fmt.print("what")
		fmt.print("hello", vk.CreateDebugUtilsMessengerEXT)
		vk.CreateDebugUtilsMessengerEXT(engine.instance, &debugCreateInfo, nil, &messanger)
	}


}

destroy_instance :: proc() {

	vk.DestroyInstance(engine.instance, nil)
}
// validates all the extentions passed to the function
validate_extentions :: proc(
	required_extentions: []cstring,
	available_extentions: []vk.ExtensionProperties,
) -> bool {
	for &i in available_extentions {


		fmt.print("something: ", cstring(&i.extensionName[0]), "\n")
	}
	all_found := true
	for name in required_extentions {
		found := false
		for &available_extention in available_extentions {
			available_extention_name: cstring = cstring(&available_extention.extensionName[0])

			if name == available_extention_name {
				found = true
			}
		}
		if !found {
			all_found = false
		}
	}
	return all_found
}
