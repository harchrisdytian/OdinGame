package main
import "base:runtime"
import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:mem"
import "core:slice"
import "core:strings"
import "core:time"
import "vendor:glfw"
import stb "vendor:stb/image"
import vk "vendor:vulkan"


// Vertex :: struct {
// 	positon: glm.vec3,
// 	color:   glm.vec3,
// }

USE_X: bool : #config(USE_X, false)
TITLE :: "The Projector"

FRAMES_IN_FLIGHT :: 4
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
	window:              glfw.WindowHandle,
	instance:            vk.Instance,
	physicalDevice:      vk.PhysicalDevice,
	device:              vk.Device,
	swapchain:           Swapchain,
	layouts:             []Layout,
	queue:               vk.Queue,
	imageViews:          []vk.ImageView,
	pipeline:            vk.Pipeline,
	layout:              vk.PipelineLayout,
	commandPool:         vk.CommandPool,
	commandBuffer:       [FRAMES_IN_FLIGHT]vk.CommandBuffer,
	sync_object:         [FRAMES_IN_FLIGHT]SyncObjects,
	vertBuffer:          vk.Buffer,
	indexBuffer:         vk.Buffer,
	uniformBuffer:       [FRAMES_IN_FLIGHT]vk.Buffer,
	uniformBufferMemory: [FRAMES_IN_FLIGHT]vk.DeviceMemory,
	uniformBufferMapped: [FRAMES_IN_FLIGHT]rawptr,
	descriptorSet:       [FRAMES_IN_FLIGHT]vk.DescriptorSet,
	descriptorPool:      vk.DescriptorPool,
	memory:              vk.DeviceMemory,
	indexMemory:         vk.DeviceMemory,
	resized:             bool,
	depth:               DepthData,
}
DepthData :: struct {
	image:       vk.Image,
	imageMemory: vk.DeviceMemory,
	imageView:   vk.ImageView,
}

UniformBufferObject :: struct {
	model: glm.mat4,
	view:  glm.mat4,
	proj:  glm.mat4,
}

SyncObjects :: struct {
	present:        vk.Semaphore,
	renderFinished: vk.Semaphore,
	drawFence:      vk.Fence,
}
engine: Engine

Vertex :: struct {
	pos:       [3]f32,
	color:     [3]f32,
	textCoord: [2]f32,
}

vertices := [8]Vertex {
	Vertex{pos = {-0.5, -0.5, 0.0}, color = {1.0, 0.0, 0.0}, textCoord = {1.0, 0.0}},
	Vertex{pos = {0.5, -0.5, 0.0}, color = {0.0, 1.0, 0.0}, textCoord = {0.0, 0.0}},
	Vertex{pos = {0.5, 0.5, 0.0}, color = {0.0, 0.0, 1.0}, textCoord = {0.0, 1.0}},
	Vertex{pos = {-0.5, 0.5, 0.0}, color = {1.0, 1.0, 1.0}, textCoord = {1.0, 1.0}},
	Vertex{pos = {-0.5, -0.5, -0.5}, color = {1.0, 0.0, 0.0}, textCoord = {1.0, 0.0}},
	Vertex{pos = {0.5, -0.5, -0.5}, color = {0.0, 1.0, 0.0}, textCoord = {0.0, 0.0}},
	Vertex{pos = {0.5, 0.5, -0.5}, color = {0.0, 0.0, 1.0}, textCoord = {0.0, 1.0}},
	Vertex{pos = {-0.5, 0.5, -0.5}, color = {1.0, 1.0, 1.0}, textCoord = {1.0, 1.0}},
}

indcies := [12]u16{0, 1, 2, 2, 3, 0, 4, 5, 6, 6, 7, 4}

VERTEX_BINDING_DESCRIPTION :: vk.VertexInputBindingDescription{0, size_of(Vertex), .VERTEX}
VERTEX_ATTRIBUTE_DESICRIPTION := [3]vk.VertexInputAttributeDescription {
	vk.VertexInputAttributeDescription{0, 0, .R32G32B32_SFLOAT, u32(offset_of(Vertex, pos))},
	vk.VertexInputAttributeDescription{1, 0, .R32G32B32_SFLOAT, u32(offset_of(Vertex, color))},
	vk.VertexInputAttributeDescription{2, 0, .R32G32_SFLOAT, u32(offset_of(Vertex, textCoord))},
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
	// process_image()
	// calculateFromError()

	defer cleanup()

	when USE_X 
	{
		glfw.InitHint(glfw.PLATFORM, glfw.PLATFORM_X11)

	}
	glfw.Init()
	glfw.VulkanSupported()
	defer glfw.Terminate()

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	// glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)

	width: i32 = 1600
	height: i32 = 900

	engine.window = glfw.CreateWindow(width, height, TITLE, nil, nil)
	defer glfw.DestroyWindow(engine.window)

	glfw.SetFramebufferSizeCallback(engine.window, framebuffer_resize_callback)
	//fmt.print(rawptr(glfw.GetInstanceProcAddress))
	vk.load_proc_addresses_global(rawptr(glfw.GetInstanceProcAddress))

	fmt.assertf(vk.CreateInstance != nil, "Failed to load proc")

	create_instance()
	defer destroy_instance()

	vk.load_proc_addresses_instance(engine.instance)

	must(glfw.CreateWindowSurface(engine.instance, engine.window, nil, &engine.swapchain.surface))
	graphics_queue: int
	engine.physicalDevice, graphics_queue = pick_physical_device(
		get_pyhsical_devices(engine.instance),
	)
	create_logical_device(engine.physicalDevice, u32(graphics_queue))
	defer vk.DestroyDevice(engine.device, nil)


	vk.GetDeviceQueue(engine.device, 0, u32(graphics_queue), &engine.queue)

	engine.swapchain = Swapchain_make()
	defer Swapchain_destroy(engine.swapchain)


	images := get_swap_chain_images(engine.device, engine.swapchain.swapchain)

	engine.imageViews = create_image_views(
		engine.device,
		engine.swapchain.swapchain,
		engine.swapchain.format.format,
		engine.imageViews,
	)
	defer {
		for image in engine.imageViews {
			vk.DestroyImageView(engine.device, image, nil)
		}
	}


	descriptor_set_layout: vk.DescriptorSetLayout

	lay: Layout
	Layout_add_binding(&lay, .UNIFORM_BUFFER, 0, {.VERTEX})
	Layout_add_binding(&lay, .SAMPLER, 2, {.FRAGMENT})
	engine.layout, descriptor_set_layout = Layout_build(&lay, engine.device)
	defer 
	{
		vk.DestroyDescriptorSetLayout(engine.device, descriptor_set_layout, nil)
		vk.DestroyPipelineLayout(engine.device, engine.layout, nil)
	}


	engine.pipeline = create_graphics_pipeline(
		engine.device,
		engine.layout,
		&engine.swapchain.format.format,
	)
	defer (vk.DestroyPipeline(engine.device, engine.pipeline, nil))

	engine.commandPool = create_command_pool(engine.device, u32(graphics_queue))
	defer vk.DestroyCommandPool(engine.device, engine.commandPool, nil)

	engine.depth = create_depth_resources(
		engine.physicalDevice,
		engine.device,
		engine.swapchain.extent,
	)
	defer destroy_depth_resources(engine.depth)


	engine.commandBuffer = create_command_buffer(engine.device, engine.commandPool)


	image, imageMemory := create_texture_image()
	defer destroy_texture_image(image, imageMemory)


	image_view := create_texture_image_view(image)
	defer vk.DestroyImageView(engine.device, image_view, nil)

	image_sampler := create_texture_sampler()
	defer vk.DestroySampler(engine.device, image_sampler, nil)

	for &sync_object in engine.sync_object {
		sync_object = create_sync_object(engine.device)
	}
	defer {
		for &sync_object in engine.sync_object {
			destroy_sync_objects(engine.device, sync_object)
		}
	}

	engine.vertBuffer, engine.memory = create_vertex_buffer(engine.device, engine.physicalDevice)
	defer destroy_buffer(engine.device, engine.vertBuffer, engine.memory)


	engine.indexBuffer, engine.indexMemory = create_index_buffer(
		engine.device,
		engine.physicalDevice,
	)
	defer destroy_buffer(engine.device, engine.indexBuffer, engine.indexMemory)

	for i in 0 ..< FRAMES_IN_FLIGHT {

		engine.uniformBuffer[i], engine.uniformBufferMemory[i], engine.uniformBufferMapped[i] =
			create_uniform_buffer(engine.device)
	}
	defer {
		for i in 0 ..< FRAMES_IN_FLIGHT {
			destroy_buffer(engine.device, engine.uniformBuffer[i], engine.uniformBufferMemory[i])
			// vk.UnmapMemory(engine.device, &engine.uniformBufferMapped[i])
		}
	}


	engine.descriptorPool = Layout_create_decriptor_pool(&lay, FRAMES_IN_FLIGHT)
	defer vk.DestroyDescriptorPool(engine.device, engine.descriptorPool, nil)

	engine.descriptorSet = create_descriptor_set(
		engine.device,
		engine.descriptorPool,
		descriptor_set_layout,
		image_sampler,
		image_view,
	)

	currentFrame := 0
	// vk.CreateBuffer()
	loopTime := time.now()
	secs: f64
	for !glfw.WindowShouldClose(engine.window) {

		glfw.PollEvents()
		diff := time.diff(loopTime, time.now())
		loopTime = time.now()

		secs += time.duration_seconds(diff)

		draw_frame(currentFrame, secs)
		glfw.SwapBuffers(engine.window)
		currentFrame = (currentFrame + 1) % FRAMES_IN_FLIGHT
		if glfw.GetKey(engine.window, glfw.KEY_ESCAPE) == glfw.PRESS {
			glfw.SetWindowShouldClose(engine.window, true)
		}
	}
	// waiting for idle frame for cleanup
	vk.DeviceWaitIdle(engine.device)

}


find_depth_format :: proc(physicalDevice: vk.PhysicalDevice = engine.physicalDevice) -> vk.Format {
	return find_supported_format(
		{.D32_SFLOAT, .D32_SFLOAT_S8_UINT, .D24_UNORM_S8_UINT},
		.OPTIMAL,
		{.DEPTH_STENCIL_ATTACHMENT},
	)
}
has_stencil_component :: proc(format: vk.Format) -> bool {
	return format == .D32_SFLOAT_S8_UINT || format == .D24_UNORM_S8_UINT
}

create_depth_resources :: proc(
	physicalDevice: vk.PhysicalDevice = engine.physicalDevice,
	device: vk.Device = engine.device,
	swapChainExtent: vk.Extent2D,
) -> DepthData {

	data: DepthData


	depthFormat := find_depth_format(physicalDevice)
	data.image, data.imageMemory = create_image(
		device,
		physicalDevice,
		swapChainExtent.width,
		swapChainExtent.height,
		depthFormat,
		.OPTIMAL,
		{.DEPTH_STENCIL_ATTACHMENT},
		{.DEVICE_LOCAL},
	)
	data.imageView = create_image_view(device, data.image, depthFormat, {.DEPTH})
	return data
}

destroy_depth_resources :: proc(data: DepthData, device := engine.device) {
	destroy_texture_image(data.image, data.imageMemory)
	vk.DestroyImageView(device, data.imageView, nil)

}

create_vertex_buffer :: proc(
	device: vk.Device,
	physicalDevice: vk.PhysicalDevice,
	commandPool: vk.CommandPool = engine.commandPool,
	queue: vk.Queue = engine.queue,
) -> (
	buffer: vk.Buffer,
	memory: vk.DeviceMemory,
) {


	size := vk.DeviceSize(u64(size_of(Vertex) * len(vertices)))
	stage_buffer: vk.Buffer
	stage_memory: vk.DeviceMemory
	stage_buffer, stage_memory = create_buffer(size, {.TRANSFER_SRC})
	defer destroy_buffer(device, stage_buffer, stage_memory)

	memPtr: rawptr
	vk.MapMemory(device, stage_memory, 0, size_of(vertices), {}, &memPtr)
	mem.copy(memPtr, &vertices[0], len(vertices) * size_of(Vertex))
	vk.UnmapMemory(device, stage_memory)


	buffer, memory = create_buffer(size, {.VERTEX_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL})


	copy_buffer(stage_buffer, buffer, size, device, queue, commandPool)
	return buffer, memory
}

create_index_buffer :: proc(
	device: vk.Device = engine.device,
	physicalDevice: vk.PhysicalDevice,
	commandPool: vk.CommandPool = engine.commandPool,
	queue: vk.Queue = engine.queue,
) -> (
	buffer: vk.Buffer,
	memory: vk.DeviceMemory,
) {
	size := vk.DeviceSize(u64(size_of(u16) * len(indcies)))

	staging_buffer: vk.Buffer
	stage_memory: vk.DeviceMemory

	staging_buffer, stage_memory = create_buffer(size, {.TRANSFER_SRC})

	defer {
		vk.DestroyBuffer(device, staging_buffer, nil)
		vk.FreeMemory(device, stage_memory, nil)
	}

	memPtr: rawptr
	vk.MapMemory(device, stage_memory, 0, size, {}, &memPtr)
	mem.copy(memPtr, &indcies[0], size_of(u16) * len(indcies))
	fmt.print("is this happening something \n\n\n\\n\n")
	vk.UnmapMemory(device, stage_memory)

	buffer, memory = create_buffer(size, {.TRANSFER_DST, .INDEX_BUFFER}, {.DEVICE_LOCAL})
	copy_buffer(staging_buffer, buffer, size, device, queue, commandPool)

	return buffer, memory
}

create_image :: proc(
	device: vk.Device = engine.device,
	physicalDevice: vk.PhysicalDevice = engine.physicalDevice,
	width, height: u32,
	format: vk.Format,
	tiling: vk.ImageTiling,
	usage: vk.ImageUsageFlags,
	properties: vk.MemoryPropertyFlags,
) -> (
	vk.Image,
	vk.DeviceMemory,
) {
	info: vk.ImageCreateInfo
	info.sType = .IMAGE_CREATE_INFO
	extent: vk.Extent3D
	extent.width = width
	extent.height = height
	extent.depth = 1
	info.extent = extent
	info.imageType = .D2
	info.format = format
	info.mipLevels = 1
	info.arrayLayers = 1
	info.samples = {._1}
	info.tiling = tiling
	info.usage = usage
	info.sharingMode = .EXCLUSIVE
	image: vk.Image

	vk.CreateImage(device, &info, nil, &image)
	memoryRequirements: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(device, image, &memoryRequirements)
	allocInfo: vk.MemoryAllocateInfo
	allocInfo.sType = .MEMORY_ALLOCATE_INFO
	allocInfo.allocationSize = memoryRequirements.size

	allocInfo.memoryTypeIndex = find_memory_type(
		memoryRequirements.memoryTypeBits,
		properties,
		physicalDevice,
	)

	memory: vk.DeviceMemory
	vk.AllocateMemory(device, &allocInfo, nil, &memory)

	vk.BindImageMemory(device, image, memory, 0)
	return image, memory

}

create_texture_sampler :: proc(
	physicalDevice: vk.PhysicalDevice = engine.physicalDevice,
	device: vk.Device = engine.device,
) -> vk.Sampler {


	properties: vk.PhysicalDeviceProperties
	vk.GetPhysicalDeviceProperties(physicalDevice, &properties)

	samplerInfo: vk.SamplerCreateInfo
	samplerInfo.sType = .SAMPLER_CREATE_INFO
	samplerInfo.magFilter = .LINEAR
	samplerInfo.minFilter = .LINEAR
	samplerInfo.mipmapMode = .LINEAR
	samplerInfo.mipLodBias = 0.0
	samplerInfo.minLod = 0.0
	samplerInfo.maxLod = 0.0
	samplerInfo.addressModeU = .REPEAT
	samplerInfo.addressModeV = .REPEAT
	samplerInfo.addressModeW = .REPEAT
	samplerInfo.anisotropyEnable = true
	samplerInfo.maxAnisotropy = properties.limits.maxSamplerAnisotropy
	samplerInfo.compareEnable = true
	samplerInfo.compareOp = .ALWAYS
	samplerInfo.borderColor = .INT_OPAQUE_BLACK
	samplerInfo.unnormalizedCoordinates = false

	sampler: vk.Sampler
	vk.CreateSampler(device, &samplerInfo, nil, &sampler)

	return sampler
}

create_texture_image_view :: proc(
	image: vk.Image,
	device: vk.Device = engine.device,
) -> vk.ImageView {
	image_view := create_image_view(device, image, .R8G8B8A8_SRGB, {.COLOR})
	return image_view
}


create_texture_image :: proc(
	path: cstring = "statue-1275469_1280.jpg",
	format: vk.Format = .R8G8B8A8_SRGB,
	device: vk.Device = engine.device,
	physicalDevice: vk.PhysicalDevice = engine.physicalDevice,
) -> (
	vk.Image,
	vk.DeviceMemory,
) {
	texWidth, texHeight, channels: i32
	image := stb.load(path, &texWidth, &texHeight, &channels, 4)
	// defer free(image)
	size: vk.DeviceSize = vk.DeviceSize(u64(texWidth * texHeight * 4))

	stagingBuffer, stagingMemory := create_buffer(size, {.TRANSFER_SRC})
	// defer destroy_buffer(device, stagingBuffer, stagingMemory)

	memPtr: rawptr
	vk.MapMemory(device, stagingMemory, 0, size, {}, &memPtr)
	mem.copy(memPtr, image, int(size))
	vk.UnmapMemory(device, stagingMemory)

	vkImage, memory := create_image(
		device,
		physicalDevice,
		u32(texWidth),
		u32(texHeight),
		format,
		.OPTIMAL,
		{vk.ImageUsageFlag.TRANSFER_DST, vk.ImageUsageFlag.SAMPLED},
		{vk.MemoryPropertyFlag.DEVICE_LOCAL},
	)
	single_transition_image_layout(vkImage, .UNDEFINED, .TRANSFER_DST_OPTIMAL)
	copy_buffer_to_image(stagingBuffer, vkImage, u32(texWidth), u32(texHeight))
	single_transition_image_layout(vkImage, .TRANSFER_DST_OPTIMAL, .SHADER_READ_ONLY_OPTIMAL)

	return vkImage, memory
}

destroy_texture_image :: proc(
	image: vk.Image,
	imageMemory: vk.DeviceMemory,
	device := engine.device,
) {
	vk.DestroyImage(device, image, nil)
	vk.FreeMemory(device, imageMemory, nil)
}

create_descriptor_set :: proc(
	device: vk.Device = engine.device,
	descriptorPool: vk.DescriptorPool,
	layout: vk.DescriptorSetLayout,
	imageSampler: vk.Sampler,
	imageView: vk.ImageView,
) -> (
	sets: [FRAMES_IN_FLIGHT]vk.DescriptorSet,
) {
	layouts: [FRAMES_IN_FLIGHT]vk.DescriptorSetLayout
	for &i in layouts do i = layout

	info: vk.DescriptorSetAllocateInfo
	info.sType = .DESCRIPTOR_SET_ALLOCATE_INFO
	info.descriptorPool = descriptorPool
	info.descriptorSetCount = len(layouts)
	info.pSetLayouts = &layouts[0]

	vk.AllocateDescriptorSets(device, &info, &sets[0])

	for buffer, index in engine.uniformBuffer {

		bufferInfo: vk.DescriptorBufferInfo
		bufferInfo.buffer = engine.uniformBuffer[0]
		bufferInfo.offset = 0
		bufferInfo.range = size_of(UniformBufferObject)

		imageInfo: vk.DescriptorImageInfo
		imageInfo.sampler = imageSampler
		imageInfo.imageLayout = .SHADER_READ_ONLY_OPTIMAL
		imageInfo.imageView = imageView


		descriptor_write: [2]vk.WriteDescriptorSet
		descriptor_write[0].sType = .WRITE_DESCRIPTOR_SET
		descriptor_write[0].dstSet = sets[index]
		descriptor_write[0].dstBinding = 0
		descriptor_write[0].dstArrayElement = 0
		descriptor_write[0].descriptorCount = 1
		descriptor_write[0].descriptorType = .UNIFORM_BUFFER
		descriptor_write[0].pBufferInfo = &bufferInfo
		descriptor_write[1].sType = .WRITE_DESCRIPTOR_SET
		descriptor_write[1].dstSet = sets[index]
		descriptor_write[1].dstBinding = 2
		descriptor_write[1].dstArrayElement = 0
		descriptor_write[1].descriptorCount = 1
		descriptor_write[1].descriptorType = .COMBINED_IMAGE_SAMPLER
		descriptor_write[1].pImageInfo = &imageInfo

		vk.UpdateDescriptorSets(device, 2, &descriptor_write[0], 0, nil)


	}

	return sets
}
create_descriptor_pool :: proc(device: vk.Device = engine.device) -> vk.DescriptorPool {
	size: [2]vk.DescriptorPoolSize
	size[0].type = .UNIFORM_BUFFER
	size[0].descriptorCount = FRAMES_IN_FLIGHT
	size[1].type = .COMBINED_IMAGE_SAMPLER
	size[1].descriptorCount = FRAMES_IN_FLIGHT


	info: vk.DescriptorPoolCreateInfo
	info.sType = .DESCRIPTOR_POOL_CREATE_INFO
	info.flags = {.FREE_DESCRIPTOR_SET}
	info.maxSets = FRAMES_IN_FLIGHT
	info.poolSizeCount = 2

	info.pPoolSizes = &size[0]

	pool: vk.DescriptorPool
	must(vk.CreateDescriptorPool(device, &info, nil, &pool))

	return pool


}

create_uniform_buffer :: proc(device: vk.Device) -> (vk.Buffer, vk.DeviceMemory, rawptr) {
	size: vk.DeviceSize
	size = vk.DeviceSize(u64(size_of(UniformBufferObject)))

	uniformBuffer, uniformBufferMemory := create_buffer(
		size,
		{.UNIFORM_BUFFER},
		{.HOST_VISIBLE, .HOST_COHERENT},
	)
	mappedMem: rawptr
	vk.MapMemory(device, uniformBufferMemory, 0, size, {}, &mappedMem)
	return uniformBuffer, uniformBufferMemory, mappedMem
}


create_descriptor_set_layout :: proc(device: vk.Device = engine.device) -> vk.DescriptorSetLayout {
	binding: [2]vk.DescriptorSetLayoutBinding
	binding[0].binding = 0
	binding[0].descriptorCount = 1
	binding[0].descriptorType = .UNIFORM_BUFFER
	binding[0].stageFlags = {.VERTEX}
	binding[0].pImmutableSamplers = nil
	binding[1].binding = 1
	binding[1].descriptorCount = 1
	binding[1].descriptorType = .COMBINED_IMAGE_SAMPLER
	binding[1].stageFlags = {.FRAGMENT}
	binding[1].pImmutableSamplers = nil

	info: vk.DescriptorSetLayoutCreateInfo
	info.sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO
	info.pBindings = &binding[0]
	info.bindingCount = 2


	layout: vk.DescriptorSetLayout
	vk.CreateDescriptorSetLayout(device, &info, nil, &layout)

	return layout
}

copy_buffer :: proc(
	src, dst: vk.Buffer,
	size: vk.DeviceSize,
	device: vk.Device = engine.device,
	queue: vk.Queue = engine.queue,
	command_pool: vk.CommandPool = engine.commandPool,
) {
	buffer := begin_single_time_command()

	copy := vk.BufferCopy{0, 0, size}

	vk.CmdCopyBuffer(buffer, src, dst, 1, &copy)

	end_single_time_command(&buffer)

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

single_transition_image_layout :: proc(
	image: vk.Image,
	oldLayout: vk.ImageLayout,
	newLayout: vk.ImageLayout,
) {
	buffer := begin_single_time_command()


	barrier: vk.ImageMemoryBarrier
	barrier.sType = .IMAGE_MEMORY_BARRIER
	barrier.oldLayout = oldLayout
	barrier.newLayout = newLayout
	barrier.subresourceRange = vk.ImageSubresourceRange{{.COLOR}, 0, 1, 0, 1}

	barrier.image = image
	source_stage, destination_stage: vk.PipelineStageFlags
	if (oldLayout == .UNDEFINED && newLayout == .TRANSFER_SRC_OPTIMAL) {
		source_stage = {.TOP_OF_PIPE}
		destination_stage = {.TRANSFER}

		barrier.srcAccessMask = {}
		barrier.dstAccessMask = {.TRANSFER_WRITE}
	} else if (oldLayout == .TRANSFER_DST_OPTIMAL && newLayout == .SHADER_READ_ONLY_OPTIMAL) {
		source_stage = {.TRANSFER}
		destination_stage = {.FRAGMENT_SHADER}

		barrier.srcAccessMask = {.TRANSFER_WRITE}
		barrier.dstAccessMask = {.SHADER_READ}
	} else {
		fmt.eprint("unsupported layout trasition")
	}

	vk.CmdPipelineBarrier(buffer, source_stage, destination_stage, {}, 0, nil, 0, nil, 1, &barrier)

	end_single_time_command(&buffer)
}

copy_buffer_to_image :: proc(buffer: vk.Buffer, image: vk.Image, width, height: u32) {
	cmd := begin_single_time_command()

	fmt.print("\n\n\nwidth , height", width, height)
	region: vk.BufferImageCopy
	region.bufferOffset = 0
	region.bufferRowLength = 0
	region.bufferImageHeight = 0
	region.imageSubresource = {{.COLOR}, 0, 0, 1}
	region.imageOffset = {0, 0, 0}
	region.imageExtent = {width, height, 1}

	vk.CmdCopyBufferToImage(cmd, buffer, image, .TRANSFER_DST_OPTIMAL, 1, &region)

	end_single_time_command(&cmd)
}
framebuffer_resize_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	engine.resized = true

}

update_uniform_buffer :: proc(currImage: int, speed: f64) {


	ubo: UniformBufferObject
	ubo.model = glm.identity(glm.mat4)
	ubo.model *= glm.mat4Rotate(glm.vec3{0, 0, 1}, f32(speed))
	ubo.view = glm.mat4LookAt(glm.vec3{2, 2, 2}, glm.vec3{0, 0, 0}, glm.vec3{0, 1, 0})
	ubo.proj = glm.mat4Perspective(
		f32(math.to_radians_f32(45.0)),
		f32(engine.swapchain.extent.width) / f32(engine.swapchain.extent.height),
		0.1,
		1000,
	)


	// fmt.print("something wrong", ubo.model)
	mem.copy(engine.uniformBufferMapped[currImage], &ubo, size_of(ubo))
}

draw_frame :: proc(current_frame: int, deltaTime: f64) {

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
		engine.swapchain.swapchain,
		max(u64),
		engine.sync_object[current_frame].present,
		0,
		// engine.sync_object[current_frame].drawFence,
		&imageIndex,
	)
	if imageIndex >= u32(len(engine.imageViews)) {
		fmt.eprint("ERROR image index is too high")
		return
	}
	// fmt.print("\n\n\n\nsomething happended here \n\n\n\n")
	if res == .ERROR_OUT_OF_DATE_KHR || engine.resized {
		engine.resized = false
		Swapchain_recreate()
		return
	} else if res != .SUCCESS && res != .SUBOPTIMAL_KHR {
		fmt.eprint("failed to equired  swapchain image")
		return
	}

	if imageIndex >= u32(len(engine.imageViews)) {
		fmt.eprint("ERROR: out of bound imageview len")
		return

	}
	//  else {
	// 	fmt.eprint("failed to aquire image")
	// 	return
	// }

	vk.ResetFences(engine.device, 1, &engine.sync_object[current_frame].drawFence)

	update_uniform_buffer(int(imageIndex), deltaTime)

	record_command_buffer(engine.commandBuffer[current_frame], imageIndex, current_frame)

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
	submit_info.pSignalSemaphores = &engine.sync_object[imageIndex].renderFinished
	vk.QueueSubmit(engine.queue, 1, &submit_info, engine.sync_object[current_frame].drawFence)

	// out := vk.WaitForFences(
	// 	engine.device,
	// 	1,
	// 	&engine.sync_object[current_frame].drawFence,
	// 	true,
	// 	max(u64),
	// )


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
	presentInfo.pSwapchains = &engine.swapchain.swapchain
	presentInfo.swapchainCount = 1
	presentInfo.waitSemaphoreCount = 1
	presentInfo.pImageIndices = &imageIndex
	presentInfo.pWaitSemaphores = &engine.sync_object[imageIndex].renderFinished
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
	dstStageMask: vk.PipelineStageFlag2,
) {
	images := get_swap_chain_images(engine.device, engine.swapchain.swapchain)

	subresource: vk.ImageSubresourceRange
	subresource.aspectMask = {.COLOR}
	subresource.baseMipLevel = 0
	subresource.levelCount = 1
	subresource.baseArrayLayer = 0
	subresource.layerCount = 1

	barrier: vk.ImageMemoryBarrier2
	barrier.sType = .IMAGE_MEMORY_BARRIER_2
	barrier.srcAccessMask = srcAccesMask
	barrier.srcStageMask = {srcStageMask}
	barrier.dstAccessMask = dstAccessMask
	barrier.dstStageMask = {dstStageMask}
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


record_command_buffer :: proc(cmd: vk.CommandBuffer, imageIndex: u32, current_frame: int) {

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
		.ALL_GRAPHICS,
		.COLOR_ATTACHMENT_OUTPUT,
	)

	depthBarrier: vk.ImageMemoryBarrier2
	depthBarrier.sType = .IMAGE_MEMORY_BARRIER_2
	depthBarrier.srcStageMask = {.TOP_OF_PIPE}
	depthBarrier.srcAccessMask = {}
	depthBarrier.dstStageMask = {.EARLY_FRAGMENT_TESTS, .LATE_FRAGMENT_TESTS}
	depthBarrier.dstAccessMask = {.DEPTH_STENCIL_ATTACHMENT_READ, .DEPTH_STENCIL_ATTACHMENT_WRITE}
	depthBarrier.oldLayout = .UNDEFINED
	depthBarrier.newLayout = .DEPTH_ATTACHMENT_OPTIMAL
	depthBarrier.srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED

	depthBarrier.dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED
	depthBarrier.image = engine.depth.image
	depthBarrier.subresourceRange = vk.ImageSubresourceRange {
		aspectMask     = {.DEPTH},
		baseMipLevel   = 0,
		levelCount     = 1,
		baseArrayLayer = 0,
		layerCount     = 1,
	}
	depthDependacyInfo: vk.DependencyInfo
	depthDependacyInfo.sType = .DEPENDENCY_INFO
	depthDependacyInfo.dependencyFlags = {}
	depthDependacyInfo.imageMemoryBarrierCount = 1
	depthDependacyInfo.pImageMemoryBarriers = &depthBarrier
	vk.CmdPipelineBarrier2(cmd, &depthDependacyInfo)


	clearColor: vk.ClearValue
	// inside :[4]f32= 
	clearColor.color.float32 = {f32(0.5), f32(0.5), f32(0.5), f32(0.5)}
	depthClear: vk.ClearValue
	depthClear.depthStencil = (vk.ClearDepthStencilValue{1.0, 0})


	images := get_swap_chain_images(engine.device, engine.swapchain.swapchain)
	attachmentInfo: vk.RenderingAttachmentInfo
	attachmentInfo.sType = .RENDERING_ATTACHMENT_INFO
	attachmentInfo.imageView = engine.imageViews[imageIndex]
	attachmentInfo.loadOp = .CLEAR
	attachmentInfo.storeOp = .STORE
	attachmentInfo.clearValue = clearColor
	attachmentInfo.imageLayout = .COLOR_ATTACHMENT_OPTIMAL

	depthAttachmentInfo: vk.RenderingAttachmentInfo
	depthAttachmentInfo.sType = .RENDERING_ATTACHMENT_INFO
	depthAttachmentInfo.imageView = engine.depth.imageView
	depthAttachmentInfo.loadOp = .CLEAR
	depthAttachmentInfo.clearValue = depthClear
	depthAttachmentInfo.storeOp = .DONT_CARE
	depthAttachmentInfo.imageLayout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL


	rect: vk.Rect2D
	rect.extent = engine.swapchain.extent
	rect.offset = {0.0, 0.0}

	//rect.extent = chooee_swapchain_extent(Engine)
	renderingInfo: vk.RenderingInfo
	renderingInfo.sType = .RENDERING_INFO
	renderingInfo.renderArea = rect
	renderingInfo.layerCount = 1
	renderingInfo.colorAttachmentCount = 1
	renderingInfo.pColorAttachments = &attachmentInfo
	renderingInfo.pDepthAttachment = &depthAttachmentInfo

	vk.CmdBeginRendering(cmd, &renderingInfo)
	vk.CmdBindPipeline(cmd, .GRAPHICS, engine.pipeline)
	size: vk.DeviceSize
	size = 0
	vk.CmdBindVertexBuffers(cmd, 0, 1, &engine.vertBuffer, &size)
	vk.CmdBindIndexBuffer(cmd, engine.indexBuffer, 0, .UINT16)

	scissor: vk.Rect2D
	scissor.extent = engine.swapchain.extent
	scissor.offset = vk.Offset2D{0, 0}

	vk.CmdSetScissor(cmd, 0, 1, &scissor)
	viewport: vk.Viewport
	viewport.height = f32(engine.swapchain.extent.height)
	viewport.width = f32(engine.swapchain.extent.width)
	vk.CmdSetViewport(cmd, 0, 1, &viewport)
	vk.CmdBindDescriptorSets(
		cmd,
		.GRAPHICS,
		engine.layout,
		0,
		1,
		&engine.descriptorSet[current_frame],
		0,
		nil,
	)
	vk.CmdDrawIndexed(cmd, u32(len(indcies)), 1, 0, 0, 0)

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


create_graphics_pipeline :: proc(
	device: vk.Device,
	pipelineLayout: vk.PipelineLayout,
	format: [^]vk.Format,
) -> vk.Pipeline {

	PipelineCreater: Pipeline = Pipeline_create(SHADER_MODULE, pipelineLayout)
	Pipeline_create_frag_info(&PipelineCreater, "fragMain")
	Pipeline_create_vert_info(&PipelineCreater, "vertMain")
	Pipeline_create_pipeline_vertex(
		&PipelineCreater,
		{VERTEX_BINDING_DESCRIPTION},
		VERTEX_ATTRIBUTE_DESICRIPTION[:],
	)
	Pipeline_create_viewport_state(&PipelineCreater, 1, 1)
	Pipeline_create_rasterizer(&PipelineCreater, .Regular)
	Pipeline_create_Rendering(&PipelineCreater, format)
	return Pipeline_build(&PipelineCreater)
}

create_image_view :: proc(
	device: vk.Device,
	image: vk.Image,
	format: vk.Format,
	aspectFlags: vk.ImageAspectFlags,
) -> vk.ImageView {
	image_view: vk.ImageView
	info: vk.ImageViewCreateInfo
	info.sType = .IMAGE_VIEW_CREATE_INFO
	// info.flags = {.}
	info.image = image
	info.viewType = .D2
	info.format = format
	info.subresourceRange.aspectMask = aspectFlags
	info.subresourceRange.baseArrayLayer = 0
	info.subresourceRange.layerCount = 1
	info.subresourceRange.baseMipLevel = 0
	info.subresourceRange.levelCount = 1
	info.components.r = .IDENTITY
	info.components.g = .IDENTITY
	info.components.b = .IDENTITY
	info.components.a = .IDENTITY
	must(vk.CreateImageView(device, &info, nil, &image_view))
	return image_view
}
create_image_views :: proc(
	device: vk.Device,
	swapchain: vk.SwapchainKHR,
	format: vk.Format,
	old_image_views: []vk.ImageView,
) -> []vk.ImageView {
	for view in old_image_views {


		// vk.DestroyImageView(device, view, nil)
	}


	images := get_swap_chain_images(device, swapchain)
	image_view := make([]vk.ImageView, len(images))
	for image, index in images {
		image_view[index] = create_image_view(device, image, format, {.COLOR})
	}
	return image_view
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
					engine.swapchain.surface,
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
	features.samplerAnisotropy = true
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
