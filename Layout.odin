package main

import "core:fmt"
import vk "vendor:vulkan"

Layout :: struct {
	bindings:            [dynamic]LayoutBinding,
	descriptorSetLayout: vk.DescriptorSetLayout,
	descriptorPool:      vk.DescriptorPool,
}

LayoutBinding :: struct {
	id:         u32,
	mode:       LayoutBindingMode,
	stageFlags: vk.ShaderStageFlags,
}

LayoutBindingMode :: enum {
	UNIFORM_BUFFER,
	SAMPLER,
}

LayoutBindingModePresets := [LayoutBindingMode]vk.DescriptorSetLayoutBinding {
	.UNIFORM_BUFFER = vk.DescriptorSetLayoutBinding {
		descriptorCount = 1,
		descriptorType = .UNIFORM_BUFFER,
		pImmutableSamplers = nil,
	},
	.SAMPLER = vk.DescriptorSetLayoutBinding {
		descriptorCount = 1,
		descriptorType = .COMBINED_IMAGE_SAMPLER,
		pImmutableSamplers = nil,
	},
}

LayoutDiscriptorPoolPresets := [LayoutBindingMode]vk.DescriptorPoolSize {
	.UNIFORM_BUFFER = {type = .UNIFORM_BUFFER},
	.SAMPLER = {type = .COMBINED_IMAGE_SAMPLER},
}

SamplerData :: struct {
	imageSampler: vk.Sampler,
	imageView:    vk.ImageView,
}

UniformBufferObjectData :: struct {
	obj:    UniformBufferObject,
	buffer: vk.Buffer,
	size:   u32,
}

LayoutDescriptorSetDataData :: union {
	SamplerData,
	UniformBufferObjectData,
}

LayoutDescriptorSetData :: struct {
	mode: LayoutBindingMode,
	data: LayoutDescriptorSetDataData,
}

// Create descriptor pool based on layout bindings
Layout_create_decriptor_pool :: proc(
	using self: ^Layout,
	size: u32,
	device: vk.Device = engine.device,
) -> vk.DescriptorPool {
	poolSize := make([]vk.DescriptorPoolSize, len(bindings))
	for binding, index in bindings {
		poolSize[index] = LayoutDiscriptorPoolPresets[binding.mode]
		poolSize[index].descriptorCount = size
	}

	info := vk.DescriptorPoolCreateInfo {
		sType         = .DESCRIPTOR_POOL_CREATE_INFO,
		flags         = {.FREE_DESCRIPTOR_SET},
		maxSets       = size,
		pPoolSizes    = raw_data(poolSize),
		poolSizeCount = u32(len(poolSize)),
	}

	must(vk.CreateDescriptorPool(device, &info, nil, &descriptorPool))

	return descriptorPool
}

// Create descriptor sets with proper data binding
Layout_create_descriptor_set :: proc(
	using self: ^Layout,
	size: u32,
	data: []LayoutDescriptorSetData,
	// buffers: []vk.Buffer,
	device: vk.Device = engine.device,
) -> []vk.DescriptorSet {
	if len(data) != len(bindings) {
		panic("size of data isn't the same size")
	}

	descriptorSet := make([]vk.DescriptorSet, size)
	setLayout := make([]vk.DescriptorSetLayout, size)

	for &item in setLayout do item = self.descriptorSetLayout

	info: vk.DescriptorSetAllocateInfo
	info.sType = .DESCRIPTOR_SET_ALLOCATE_INFO
	info.descriptorSetCount = u32(len(bindings))
	info.descriptorPool = descriptorPool
	info.pSetLayouts = raw_data(setLayout)

	vk.AllocateDescriptorSets(device, &info, &descriptorSet[0])

	descriptorWrite := make([]vk.WriteDescriptorSet, len(bindings))
	// should be able to reuse
	bufferInfo: vk.DescriptorBufferInfo
	imageInfo: vk.DescriptorImageInfo
	// for buffer in buffers {
	for sets in descriptorSet {
		for bind, i in bindings {
			if bind.mode != data[i].mode {
				fmt.eprintf("{} Isn't equal to {}", bind.mode, data[i].mode)
				panic("failed to match bind modes")
			}
			switch bind.mode {
			case .UNIFORM_BUFFER:
				{
					// TODO calculate offset
					bufferInfo.buffer = data[i].data.(UniformBufferObjectData).buffer
					bufferInfo.offset = 0
					bufferInfo.range = size_of(UniformBufferObject)
					descriptorWrite[i] = vk.WriteDescriptorSet {
						sType           = .WRITE_DESCRIPTOR_SET,
						dstSet          = sets,
						dstBinding      = bind.id,
						dstArrayElement = 0,
						descriptorCount = 1,
						descriptorType  = .UNIFORM_BUFFER,
						pBufferInfo     = &bufferInfo,
					}
				}
			case .SAMPLER:
				{
					sampler: SamplerData = data[i].data.(SamplerData)
					imageInfo.sampler = sampler.imageSampler
					imageInfo.imageView = sampler.imageView
					imageInfo.imageLayout = .SHADER_READ_ONLY_OPTIMAL

					descriptorWrite[i] = vk.WriteDescriptorSet {
						sType           = .WRITE_DESCRIPTOR_SET,
						dstSet          = sets,
						dstBinding      = bind.id,
						dstArrayElement = 0,
						descriptorCount = 1,
						descriptorType  = .COMBINED_IMAGE_SAMPLER,
						pImageInfo      = &imageInfo,
					}
				}
			}
			// vk.WriteDescriptorSets
			// vk.UpdateDescriptorSets(device, u32(len(bindings)), &descriptorWrite[0], 0, nil)
		}
		vk.UpdateDescriptorSets(device, u32(len(bindings)), &descriptorWrite[0], 0, nil)
	}
	// }
	return descriptorSet
}

// Add a binding to the layout
Layout_add_binding :: proc(
	using self: ^Layout,
	mode: LayoutBindingMode,
	id: u32,
	stages: vk.ShaderStageFlags,
) {
	binding := LayoutBinding {
		id         = id,
		mode       = mode,
		stageFlags = stages,
	}
	append(&bindings, binding)
}

// Build the complete layout (pipeline layout + descriptor set layout)
Layout_build :: proc(
	using self: ^Layout,
	device: vk.Device,
) -> (
	vk.PipelineLayout,
	vk.DescriptorSetLayout,
) {
	tempBindings := make([]vk.DescriptorSetLayoutBinding, len(bindings))
	for binding, i in bindings {
		tempBindings[i] = LayoutBindingModePresets[binding.mode]
		tempBindings[i].binding = binding.id
		tempBindings[i].stageFlags = binding.stageFlags
	}

	info: vk.DescriptorSetLayoutCreateInfo
	info.sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO
	info.pBindings = raw_data(tempBindings)
	info.bindingCount = u32(len(tempBindings))

	vk.CreateDescriptorSetLayout(device, &info, nil, &descriptorSetLayout)

	layout: vk.PipelineLayout
	pipeInfo: vk.PipelineLayoutCreateInfo
	pipeInfo.sType = .PIPELINE_LAYOUT_CREATE_INFO
	pipeInfo.setLayoutCount = 1
	pipeInfo.pSetLayouts = &descriptorSetLayout
	pipeInfo.pushConstantRangeCount = 0
	must(vk.CreatePipelineLayout(device, &pipeInfo, nil, &layout))

	return layout, descriptorSetLayout
}

//TODO(chiristian) add push constant support
