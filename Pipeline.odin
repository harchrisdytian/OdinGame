package main
import "core:fmt"
import vk "vendor:vulkan"

// This act as a opinionated builder version of
// vulkan's CreateGraphicsPipelines
// This is usefull for setting up pipelines
// this follow the builder pattern
Pipeline :: struct {
	shader:                 vk.ShaderModule,
	ShaderInfo:             [dynamic]vk.PipelineShaderStageCreateInfo,
	pipelineLayout:         vk.PipelineLayout,
	dynamic_states:         [2]vk.DynamicState,
	dynamic_state:          vk.PipelineDynamicStateCreateInfo,
	vertexPipelineInfo:     vk.PipelineVertexInputStateCreateInfo,
	inputAssemblyStateInfo: vk.PipelineInputAssemblyStateCreateInfo,
	viewPortStateInfo:      vk.PipelineViewportStateCreateInfo,
	rasterizer:             vk.PipelineRasterizationStateCreateInfo,
	multisampling:          vk.PipelineMultisampleStateCreateInfo,
	depthStecil:            vk.PipelineDepthStencilStateCreateInfo,
	colorBlendAttachment:   vk.PipelineColorBlendAttachmentState,
	colorBlending:          vk.PipelineColorBlendStateCreateInfo,
	pipelineRendering:      vk.PipelineRenderingCreateInfo,
}

// Rasterizers for different Raster modes stored in PipelineFills
PipelineFillMode :: enum {
	Regular,
}

PipelineFills := [PipelineFillMode]vk.PipelineRasterizationStateCreateInfo {
	.Regular = vk.PipelineRasterizationStateCreateInfo {
		sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		depthClampEnable = false,
		rasterizerDiscardEnable = false,
		polygonMode = .FILL,
		cullMode = {.BACK},
		frontFace = .CLOCKWISE,
		depthBiasEnable = false,
		depthBiasSlopeFactor = 1.0,
		lineWidth = 1.0,
	},
}

Pipeline_create :: proc(mod: []byte, _pipelineLayout: vk.PipelineLayout) -> Pipeline {
	using result: Pipeline
	shader = create_shader_module(mod)
	pipelineLayout = _pipelineLayout
	// NOTE(christian) initilize dynamic state since I don't think it changes as of yet..
	{
		dynamic_states[0] = .VIEWPORT
		dynamic_states[1] = .SCISSOR

		dynamic_state.sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO
		dynamic_state.dynamicStateCount = 2
		dynamic_state.pDynamicStates = raw_data(&dynamic_states)
	}
	// NOTE(christian) I don't think this will change either
	{
		inputAssemblyStateInfo.sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
		inputAssemblyStateInfo.topology = .TRIANGLE_LIST
	}
	// NOTE(Christian) This will probbaly not change unless msaa or whatever
	{
		multisampling.sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
		multisampling.rasterizationSamples = {._1}
		multisampling.sampleShadingEnable = true
	}
	// NOTE(Christian) This will very likely need a builder stage
	{
		depthStecil.sType = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO
		depthStecil.depthTestEnable = true
		depthStecil.depthWriteEnable = true
		depthStecil.depthCompareOp = .LESS
		depthStecil.depthBoundsTestEnable = false
		depthStecil.stencilTestEnable = false
	}

	// NOTE(Christian) This most likely changing based on transparancy
	{
		colorBlendAttachment.colorWriteMask = {.R, .G, .B, .A}
		colorBlendAttachment.blendEnable = false
	}

	// NOTE(Christian) This most likely changing based on transparancy
	{
		colorBlending.sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
		colorBlending.logicOp = .COPY
		colorBlending.logicOpEnable = false
		colorBlending.attachmentCount = 1
	}

	return result
}

Pipeline_create_frag_info :: proc(using self: ^Pipeline, name: cstring) {

	shaderInfo: vk.PipelineShaderStageCreateInfo
	shaderInfo.sType = .PIPELINE_SHADER_STAGE_CREATE_INFO
	shaderInfo.module = shader
	shaderInfo.pName = "fragMain"
	shaderInfo.stage = {.FRAGMENT}

	append(&ShaderInfo, shaderInfo)
}

Pipeline_create_vert_info :: proc(using self: ^Pipeline, name: cstring) {
	shaderInfo: vk.PipelineShaderStageCreateInfo
	shaderInfo.sType = .PIPELINE_SHADER_STAGE_CREATE_INFO
	shaderInfo.module = shader
	shaderInfo.pName = name
	shaderInfo.stage = {.VERTEX}

	append(&ShaderInfo, shaderInfo)
}

Pipeline_create_pipeline_vertex :: proc(
	using self: ^Pipeline,
	binding: []vk.VertexInputBindingDescription,
	attribute: []vk.VertexInputAttributeDescription,
) {

	vertexPipelineInfo.sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
	vertexPipelineInfo.vertexBindingDescriptionCount = u32(len(binding))
	vertexPipelineInfo.pVertexBindingDescriptions = raw_data(binding)
	vertexPipelineInfo.vertexAttributeDescriptionCount = u32(len(attribute))
	vertexPipelineInfo.pVertexAttributeDescriptions = raw_data(attribute)
}


// this create viewport state
// since we are using dynamic rendering it is unimportant to set
// pointers to the objects
Pipeline_create_viewport_state :: proc(
	using self: ^Pipeline,
	scissorCount: u32,
	viewportCount: u32,
) {
	viewPortStateInfo.sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO
	viewPortStateInfo.scissorCount = scissorCount
	viewPortStateInfo.viewportCount = viewportCount
}

Pipeline_create_rasterizer :: proc(using self: ^Pipeline, flag: PipelineFillMode) {
	rasterizer = PipelineFills[flag]

}

Pipeline_create_Rendering :: proc(
	using self: ^Pipeline,
	format: [^]vk.Format,
	physicalDevice: vk.PhysicalDevice = engine.physicalDevice,
) {
	pipelineRendering.sType = .PIPELINE_RENDERING_CREATE_INFO
	pipelineRendering.colorAttachmentCount = 1
	pipelineRendering.pColorAttachmentFormats = format
	pipelineRendering.depthAttachmentFormat = find_depth_format(physicalDevice)
}
Pipeline_build :: proc(using self: ^Pipeline, device := engine.device) -> (pipeline: vk.Pipeline) {
	dynamic_state.pDynamicStates = &dynamic_states[0]
	colorBlending.pAttachments = &colorBlendAttachment

	pipelineInfo: vk.GraphicsPipelineCreateInfo

	pipelineInfo.sType = .GRAPHICS_PIPELINE_CREATE_INFO
	pipelineInfo.pStages = raw_data(ShaderInfo[:])
	pipelineInfo.stageCount = 2
	pipelineInfo.pVertexInputState = &vertexPipelineInfo
	pipelineInfo.pInputAssemblyState = &inputAssemblyStateInfo
	pipelineInfo.pViewportState = &viewPortStateInfo
	pipelineInfo.pRasterizationState = &rasterizer
	pipelineInfo.pDepthStencilState = &depthStecil
	pipelineInfo.pColorBlendState = &colorBlending
	pipelineInfo.pMultisampleState = &multisampling
	pipelineInfo.pDynamicState = &dynamic_state
	pipelineInfo.layout = pipelineLayout
	pipelineInfo.pNext = &pipelineRendering
	// pipelineInfo.renderPass = nil

	fmt.println("Dynamic state count:", dynamic_state.dynamicStateCount)
	fmt.println("Dynamic states[0]:", dynamic_states[0])
	fmt.println("Dynamic states[1]:", dynamic_states[1])
	fmt.println("Dynamic state pointer:", dynamic_state.pDynamicStates)

	must(vk.CreateGraphicsPipelines(device, {}, 1, &pipelineInfo, nil, &pipeline))

	return pipeline
}

