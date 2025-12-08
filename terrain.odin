package main

import "core:fmt"
import stb "vendor:stb/image"
import vk "vendor:vulkan"


Terrain :: struct {
	ind: []u32,
}

TERRAIN_BINDING_DESCRIPTION :: vk.VertexInputBindingDescription{0, size_of(u32), .VERTEX}
TERRAIN_ATTRIBUTE_DESICRIPTION :: [1]vk.VertexInputAttributeDescription {
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
	stb.write_png("assets/errorMap.png", gridSize, gridSize, 1, raw_data(errorMap), gridSize)
	fmt.printf("width {}, height: {} \n", width, height)
}

calculateFromError :: proc() -> []u32 {
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
	defer (delete(ind))

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

	fmt.printf("out: {} \n", ind)

	return ind[:]
}


processMap :: proc(a, b, c: [2]u32, error: [^]byte, tileSize: u32, indecies: ^[dynamic]u32) {

	m := a + b
	m.x >>= 1
	m.y >>= 1


	maxError: u8 = 3
	triangleSize := abs(a.x - c.x) + abs(a.y - c.y)

	if triangleSize > 1 && (error[m.y * tileSize + m.x] >= maxError) {

		processMap(c, a, m, error, tileSize, indecies)
		processMap(b, c, m, error, tileSize, indecies)
	} else {
		append(indecies, (a.y * tileSize + a.x))
		append(indecies, (b.y * tileSize + b.x))
		append(indecies, (c.y * tileSize + c.x))
	}
}
