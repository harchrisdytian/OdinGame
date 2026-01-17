package main

import "core:fmt"
import vk "vendor:vulkan"

must :: proc(res: vk.Result, loc := #caller_location) {
	if (res != .SUCCESS) {
		fmt.eprint("error at", loc)
	}
}

get_pyhsical_devices :: proc(instance: vk.Instance) -> []vk.PhysicalDevice {
	count: u32
	vk.EnumeratePhysicalDevices(instance, &count, nil)
	devices := make([]vk.PhysicalDevice, count)
	vk.EnumeratePhysicalDevices(instance, &count, raw_data(devices))
	return devices
}

get_surface_formats :: proc(
	device: vk.PhysicalDevice,
	surface: vk.SurfaceKHR,
) -> []vk.SurfaceFormatKHR {
	count: u32
	vk.GetPhysicalDeviceSurfaceFormatsKHR(device, surface, &count, nil)
	formats := make([]vk.SurfaceFormatKHR, count)
	vk.GetPhysicalDeviceSurfaceFormatsKHR(device, surface, &count, raw_data(formats))
	return formats
}
get_surface_present_modes :: proc(
	device: vk.PhysicalDevice,
	surface: vk.SurfaceKHR,
) -> []vk.PresentModeKHR {
	count: u32
	vk.GetPhysicalDeviceSurfacePresentModesKHR(device, surface, &count, nil)
	formats := make([]vk.PresentModeKHR, count)
	vk.GetPhysicalDeviceSurfacePresentModesKHR(device, surface, &count, raw_data(formats))
	return formats
}

get_swap_chain_images :: proc(device: vk.Device, swapchain: vk.SwapchainKHR) -> []vk.Image {
	count: u32
	vk.GetSwapchainImagesKHR(engine.device, swapchain, &count, nil)
	images := make([]vk.Image, count)
	vk.GetSwapchainImagesKHR(engine.device, swapchain, &count, raw_data(images))
	return images
}

create_semaphore :: proc(device: vk.Device) -> vk.Semaphore {
	semaphoreInfo: vk.SemaphoreCreateInfo
	semaphoreInfo.sType = .SEMAPHORE_CREATE_INFO
	semaphore: vk.Semaphore
	must(vk.CreateSemaphore(device, &semaphoreInfo, nil, &semaphore))
	return semaphore
}

create_fence :: proc(device: vk.Device, flag: vk.FenceCreateFlags) -> vk.Fence {

	info: vk.FenceCreateInfo
	info.sType = .FENCE_CREATE_INFO
	info.flags = flag
	fence: vk.Fence

	must(vk.CreateFence(device, &info, nil, &fence))
	return fence
}

find_memory_type :: proc(
	flag: u32,
	type: vk.MemoryPropertyFlags,
	physicalDevice: vk.PhysicalDevice,
) -> u32 {
	prop: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(physicalDevice, &prop)
	for i in 0 ..< prop.memoryTypeCount {

		if (flag & u32(1 << i)) != 0 && ((prop.memoryTypes[i].propertyFlags) & type) == type {
			return i
		}
	}

	return 0
}

create_buffer :: proc(
	size: vk.DeviceSize,
	usage: vk.BufferUsageFlags,
	flags: vk.MemoryPropertyFlags = {.HOST_VISIBLE, .HOST_COHERENT},
	device := engine.device,
	physicalDevice := engine.physicalDevice,
) -> (
	vk.Buffer,
	vk.DeviceMemory,
) {
	info: vk.BufferCreateInfo
	info.sType = .BUFFER_CREATE_INFO
	info.size = size
	info.usage = usage
	info.sharingMode = .EXCLUSIVE
	buffer: vk.Buffer

	vk.CreateBuffer(device, &info, nil, &buffer)
	memRequiremnets: vk.MemoryRequirements
	vk.GetBufferMemoryRequirements(device, buffer, &memRequiremnets)

	memInfo: vk.MemoryAllocateInfo
	memInfo.sType = .MEMORY_ALLOCATE_INFO
	memInfo.allocationSize = memRequiremnets.size
	memInfo.memoryTypeIndex = find_memory_type(
		memRequiremnets.memoryTypeBits,
		flags,
		physicalDevice,
	)
	memory: vk.DeviceMemory
	must(vk.AllocateMemory(device, &memInfo, nil, &memory))
	vk.BindBufferMemory(device, buffer, memory, 0)
	return buffer, memory
}

destroy_buffer :: proc(device: vk.Device, buffer: vk.Buffer, memory: vk.DeviceMemory) {
	vk.DestroyBuffer(device, buffer, nil)
	vk.FreeMemory(device, memory, nil)
}

begin_single_time_command :: proc(
	device: vk.Device = engine.device,
	command_pool: vk.CommandPool = engine.commandPool,
) -> (
	buffer: vk.CommandBuffer,
) {
	info: vk.CommandBufferAllocateInfo
	info.sType = .COMMAND_BUFFER_ALLOCATE_INFO
	info.commandBufferCount = 1
	info.commandPool = command_pool
	info.level = .PRIMARY


	vk.AllocateCommandBuffers(device, &info, &buffer)
	command_info: vk.CommandBufferBeginInfo
	command_info.sType = .COMMAND_BUFFER_BEGIN_INFO
	command_info.flags = {.ONE_TIME_SUBMIT}
	vk.BeginCommandBuffer(buffer, &command_info)
	return buffer
}
end_single_time_command :: proc(buffer: ^vk.CommandBuffer, queue: vk.Queue = engine.queue) {
	vk.EndCommandBuffer(buffer^)
	submit: vk.SubmitInfo
	submit.sType = .SUBMIT_INFO
	submit.commandBufferCount = 1
	submit.pCommandBuffers = buffer

	fence: vk.Fence
	fence = create_fence(engine.device, {})
	vk.QueueSubmit(queue, 1, &submit, fence)
	vk.WaitForFences(engine.device, 1, &fence, true, max(u64))
	vk.DestroyFence(engine.device, fence, nil)
	vk.FreeCommandBuffers(engine.device, engine.commandPool, 1, buffer)
}

find_supported_format :: proc(
	candidates: []vk.Format,
	tiling: vk.ImageTiling,
	features: vk.FormatFeatureFlags,
	physicalDevice: vk.PhysicalDevice = engine.physicalDevice,
) -> vk.Format {
	for format in candidates {
		prop: vk.FormatProperties
		vk.GetPhysicalDeviceFormatProperties(physicalDevice, format, &prop)
		if (tiling == .LINEAR && (prop.linearTilingFeatures & features) == features) {
			return format
		}
		if (tiling == .OPTIMAL && (prop.optimalTilingFeatures & features) == features) {
			return format
		}
	}

	fmt.eprint("failed to find format")
	return {}
}
