package main

import glfw "vendor:glfw"
import vk "vendor:vulkan"

Swapchain :: struct {
	physicalDevice: vk.PhysicalDevice,
	surface:        vk.SurfaceKHR,
	swapchain:      vk.SwapchainKHR,
	extent:         vk.Extent2D,
	format:         vk.SurfaceFormatKHR,
	mode:           vk.PresentModeKHR,
	images:         []SwapchainImage,
}

SwapchainImage :: struct {
	image: vk.Image,
	fence: vk.Fence,
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


Swapchain_get_images :: proc(self: Swapchain, device := engine.device) {
	images := get_swap_chain_images(device, self.swapchain)

}
Swapchain_make :: proc(
	device := engine.device,
	phyiscialDevice := engine.physicalDevice,
	surface: vk.SurfaceKHR = engine.swapchain.surface,
	old_swapchain: Swapchain = engine.swapchain,
) -> Swapchain {

	self: Swapchain
	self.physicalDevice = phyiscialDevice
	self.surface = surface


	capabilities: vk.SurfaceCapabilitiesKHR
	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(phyiscialDevice, surface, &capabilities)

	self.extent = choose_swapchain_extent(capabilities)
	self.format = pick_available_format(get_surface_formats(phyiscialDevice, surface))
	self.mode = pick_present_mode(get_surface_present_modes(phyiscialDevice, surface))

	minImageCount := max(3, capabilities.minImageCount)
	minImageCount += 1

	info := vk.SwapchainCreateInfoKHR {
		sType            = .SWAPCHAIN_CREATE_INFO_KHR,
		surface          = surface,
		minImageCount    = u32(minImageCount),
		imageFormat      = self.format.format,
		imageColorSpace  = self.format.colorSpace,
		imageUsage       = {.COLOR_ATTACHMENT},
		imageSharingMode = .EXCLUSIVE,
		imageExtent      = self.extent,
		imageArrayLayers = 1,
		preTransform     = capabilities.currentTransform,
		compositeAlpha   = {.OPAQUE},
		presentMode      = self.mode,
		clipped          = true,
		oldSwapchain     = old_swapchain.swapchain,
	}
	vk.CreateSwapchainKHR(device, &info, nil, &self.swapchain)

	return self
}

Swapchain_destroy :: proc(
	using self: Swapchain,
	device := engine.device,
	instance := engine.instance,
) {
	vk.DestroySwapchainKHR(device, swapchain, nil)
	vk.DestroySurfaceKHR(instance, self.surface, nil)
}

Swapchain_recreate :: proc(
	self := engine.swapchain,
	device: vk.Device = engine.device,
	physicalDevice := engine.physicalDevice,
) {

	using self
	width, height := glfw.GetFramebufferSize(engine.window)
	for width == 0 || height == 0 {
		width, height = glfw.GetFramebufferSize(engine.window)
		glfw.WaitEvents()
	}


	vk.DeviceWaitIdle(device)
	for image in engine.imageViews {
		vk.DestroyImageView(engine.device, image, nil)
	}
	vk.DestroyImage(engine.device, engine.depth.image, nil)
	vk.DestroyImageView(engine.device, engine.depth.imageView, nil)
	vk.FreeMemory(engine.device, engine.depth.imageMemory, nil)

	old_swapchain := engine.swapchain
	engine.swapchain = Swapchain_make(
		device,
		physicalDevice,
		engine.swapchain.surface,
		old_swapchain,
	)


	vk.DestroySwapchainKHR(device, old_swapchain.swapchain, nil)

	engine.imageViews = create_image_views(
		device,
		engine.swapchain.swapchain,
		engine.swapchain.format.format,
		engine.imageViews,
	)
	engine.depth = create_depth_resources(physicalDevice, device, self.extent)


}
