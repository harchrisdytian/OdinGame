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
	vk.GetSwapchainImagesKHR(engine.device, engine.swapchain, &count, nil)
	images := make([]vk.Image, count)
	vk.GetSwapchainImagesKHR(engine.device, engine.swapchain, &count, raw_data(images))
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
		{.HOST_VISIBLE, .HOST_COHERENT},
		physicalDevice,
	)
	memory: vk.DeviceMemory
	must(vk.AllocateMemory(device, &memInfo, nil, &memory))

	return buffer, memory
}
