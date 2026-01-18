package main

import "core:fmt"
import stb "vendor:stb/image"
import vk "vendor:vulkan"

import "core:mem"
ERROR_MAP_PATH :: "assets/errorMap.png"
HIGHT_MAP_PATH :: "assets/hightmap.png"

TERRAIN_BINDING_DESCRIPTION :: vk.VertexInputBindingDescription{0, size_of(u32), .VERTEX}
TERRAIN_ATTRIBUTE_DESICRIPTION := [1]vk.VertexInputAttributeDescription {
	vk.VertexInputAttributeDescription{0, 0, .R32_UINT, u32(size_of(u32))},
}

process_image :: proc() {
	width, height, channels: i32
	heightMap: [^]u8 = stb.load("assets/hightmap.png", &width, &height, &channels, 1)
	defer (stb.image_free(heightMap))

	if (width != height) {
		fmt.eprintf("error: texture not perfectly square width, height", width, height)
	}

	gridSize := width


	cellSize := width - 1
	errorMap := make([]u8, gridSize * gridSize)
	defer delete(errorMap)

	SmallestTriangel := cellSize * cellSize

	Traingles := SmallestTriangel * 2 - 2
	lastIndex := Traingles - SmallestTriangel

	for i := Traingles - 1; i >= 0; i -= 1 {
		id := i + 2
		a, b, c: [2]i32
		a.xy = 0
		b.xy = 0
		c.xy = 0
		// left half

		if (id & 1) == 1 {
			b.x = cellSize
			b.y = cellSize
			c.x = cellSize
		} else {
			a.x = cellSize
			a.y = cellSize
			c.y = cellSize
		}

		id >>= 1
		for id > 1 {
			// fmt.print(id)
			m: [2]i32
			m.x = (a.x + b.x) >> 1
			m.y = (a.y + b.y) >> 1

			if (id & 1) == 1 {
				b.xy = a.xy
				a.xy = c.xy
			} else {
				a.xy = b.xy
				b.xy = c.xy
			}
			c.xy = m.xy

			id >>= 1
		}


		h1 := i32(heightMap[(a.y * width) + a.x])
		h2 := i32(heightMap[(b.y * width) + b.x])
		intHeight := (h1 + h2) / 2

		middleIndex := ((a.y + b.y) >> 1) * width + ((a.x + b.x) >> 1)
		middleErr := u8(abs(intHeight - i32(heightMap[middleIndex])))
		middleIndex = ((a.y + b.y) >> 1) * gridSize + ((a.x + b.x) >> 1)

		if i >= lastIndex {
			errorMap[middleIndex] = middleErr
		} else {
			leftChildErr := errorMap[((a.y + c.y) >> 1) * gridSize + ((a.x + c.x) >> 1)]
			rightChildErr := errorMap[((b.y + c.y) >> 1) * gridSize + ((b.x + c.x) >> 1)]
			errorMap[middleIndex] = max(
				middleErr, // errorMap[middleIndex],
				leftChildErr,
				rightChildErr,
			)
		}
	}


	// write_png :: proc(filename: cstring, w, h, comp: c.int, data: rawptr, stride_in_bytes: c.int)     -> c.int ---
	stb.write_png(ERROR_MAP_PATH, gridSize, gridSize, 1, raw_data(errorMap), gridSize)
	fmt.printf("width {}, height: {} \n", width, height)
}

calculateFromError :: proc() -> ([]u32, u32) {
	width: i32
	height: i32
	channels: i32
	heightMap: [^]u8 = stb.load("assets/hightmap.png", &width, &height, &channels, 1)
	defer stb.image_free(heightMap)
	errWidth: i32
	errHeight: i32
	errChannels: i32
	errorMap: [^]u8 = stb.load("assets/errorMap.png", &errWidth, &errHeight, &errChannels, 1)

	defer stb.image_free(errorMap)
	assert(width == height && errWidth == errHeight)


	errWidth -= 1
	// i: int = 1
	ind := make([dynamic]u32)
	// defer (delete(ind))

	processMap(
		{0, 0},
		{u32(errWidth), u32(errWidth)},
		{u32(errWidth), 0},
		errorMap,
		u32(errWidth + 1),
		&ind,
	)

	// fmt.printf("out: {} \n", i)
	// i = 0
	processMap(
		{u32(errWidth), u32(errWidth)},
		{0, 0},
		{0, u32(errWidth)},
		errorMap,
		u32(errWidth + 1),
		&ind,
	)

	fmt.printf("out: {} \n, out2: {}", ind, ind[:])

	return ind[:], u32(errWidth - 1)
}


processMap :: proc(a, b, c: [2]u32, error: [^]byte, tileSize: u32, indecies: ^[dynamic]u32) {

	m := a + b
	m.x >>= 1
	m.y >>= 1


	maxError: u8 = 3
	triangleSize := abs(a.x - c.x) + abs(a.y - c.y)

	if triangleSize > 1 && (error[m.y * tileSize + m.x] >= maxError) {

		processMap(c, a, m, error, tileSize, indecies)
		processMap(m, b, c, error, tileSize, indecies)
	} else {
		append(indecies, (a.y * tileSize + a.x))
		append(indecies, (b.y * tileSize + b.x))
		append(indecies, (c.y * tileSize + c.x))
	}
}

Terrain :: struct {
	indexBuffer:    vk.Buffer,
	indexMemory:    vk.DeviceMemory,
	indexCount:     u32,
	image:          vk.Image,
	imageMem:       vk.DeviceMemory,
	size:           vk.Buffer,
	sizeMemory:     vk.DeviceMemory,
	sampler:        vk.Sampler,
	view:           vk.ImageView,
	pipeline:       vk.Pipeline,
	lay:            vk.PipelineLayout,
	set:            vk.DescriptorSetLayout,
	sets:           []vk.DescriptorSet,
	descriptorPool: vk.DescriptorPool,
	gridSize:       uint,
}

Terrain_create :: proc() -> Terrain {
	using terrain: Terrain

	inds, gridSizer := calculateFromError()

	gridSize = uint(gridSizer)
	fmt.printf("\n\n\nfmt: {}", inds)


	IND_SIZE := len(inds) * size_of(u32)

	staging_buffer: vk.Buffer
	stage_memory: vk.DeviceMemory

	staging_buffer, stage_memory = create_buffer(vk.DeviceSize(IND_SIZE), {.TRANSFER_SRC})
	defer destroy_buffer(engine.device, staging_buffer, stage_memory)


	data: rawptr
	vk.MapMemory(engine.device, stage_memory, 0, vk.DeviceSize(vk.WHOLE_SIZE), {}, &data)
	mem.copy(data, raw_data(inds), IND_SIZE)
	// verify := ([^]u32)(data)
	// fmt.printf(
	// 	"Verification - first few copied values: %d, %d, %d\n",
	// 	verify[0],
	// 	verify[1],
	// 	verify[2],
	// )

	vk.UnmapMemory(engine.device, stage_memory)
	indexCount = u32(len(inds))

	indexBuffer, indexMemory = create_buffer(
		vk.DeviceSize(IND_SIZE),
		{.INDEX_BUFFER, .TRANSFER_DST},
	)
	copy_buffer(staging_buffer, indexBuffer, vk.DeviceSize(IND_SIZE))

	{
		size, sizeMemory = create_buffer(vk.DeviceSize(size_of(uint)), {.UNIFORM_BUFFER})
		sizeData: rawptr
		vk.MapMemory(engine.device, sizeMemory, 0, vk.DeviceSize(size_of(uint)), {}, &sizeData)

		sizeD := uint(gridSize)
		fmt.printf("GRID_SIZE {} bn", gridSize)
		mem.copy_non_overlapping(sizeData, &sizeD, size_of(uint))
		vk.UnmapMemory(engine.device, sizeMemory)
		tempdata: rawptr
		vk.MapMemory(engine.device, sizeMemory, 0, vk.DeviceSize(size_of(u32)), {}, &tempdata)
		readBack: u32
		mem.copy(&readBack, tempdata, size_of(uint))
		fmt.printf("READ BACK{}\n", readBack)

	}
	image, imageMem = create_texture_image(HIGHT_MAP_PATH)


	//create image sampler for some reason
	sampler = create_texture_sampler()
	view = create_image_view(engine.device, image, .R8_UNORM, {.COLOR})
	layout: Layout
	Layout_add_binding(&layout, .SAMPLER, 3, {.VERTEX}) // height map
	Layout_add_binding(&layout, .SAMPLER, 2, {.FRAGMENT}) // texture
	Layout_add_binding(&layout, .UNIFORM_BUFFER, 1, {.VERTEX}) // size
	Layout_add_binding(&layout, .UNIFORM_BUFFER, 0, {.VERTEX}) // ubo
	lay, set = Layout_build(&layout, engine.device)

	setData: [4]LayoutDescriptorSetData

	setData[0].data = SamplerData {
		imageSampler = sampler,
		imageView    = view,
	}
	setData[0].mode = .SAMPLER
	setData[1].mode = .SAMPLER
	setData[1].data = SamplerData {
		imageSampler = sampler,
		imageView    = view,
	}
	setData[2].mode = .UNIFORM_BUFFER
	setData[2].data = UniformBufferObjectData {
		size   = size_of(uint), // don't think i need for now might remove from struct
		buffer = size,
	}

	setData[3].mode = .UNIFORM_BUFFER
	setData[3].data = UniformBufferObjectData {
		size   = size_of(UniformBufferObject), // don't think i need for now might remove from struct
		buffer = engine.uniformBuffer,
	}
	descriptorPool = Layout_create_decriptor_pool(&layout, FRAMES_IN_FLIGHT)
	sets = Layout_create_descriptor_set(&layout, FRAMES_IN_FLIGHT, setData[:])

	PipelineCreater: Pipeline = Pipeline_create(SHADER_MODULE, lay)
	Pipeline_create_frag_info(&PipelineCreater, "fragMain")
	Pipeline_create_vert_info(&PipelineCreater, "TerrainMain")
	Pipeline_create_pipeline_vertex(&PipelineCreater, {}, {})

	Pipeline_create_viewport_state(&PipelineCreater, 1, 1)
	Pipeline_create_rasterizer(&PipelineCreater, .Regular)
	Pipeline_create_Rendering(&PipelineCreater, &engine.swapchain.format.format)
	pipeline = Pipeline_build(&PipelineCreater)

	return terrain

}
