# OdinGame

3D terrain game built with Odin and Vulkan.

## Quick Start

### Prerequisites
- Odin compiler
- Vulkan SDK

### Build Commands
```bash
# Basic build
odin build .

# Run the game
odin run .

# Debug build
odin run . -debug

# RenderDoc support
odin run . -debug -define:USE_X=true
```

### Shader Compilation
```bash
# Compile shaders (required after shader changes)
cd shaders && ./compile.sh
```

## Naming Conventions

### Constants
```odin
SCREAMING_SNAKE_CASE :: value
FRAMES_IN_FLIGHT :: 4
VALIDATION_LAYER: []cstring : {"VK_LAYER_KHRONOS_validation"}
```

### Types and Structs
```odin
PascalCase :: struct {
    field: type,
}

Engine :: struct {
    window: glfw.WindowHandle,
    device: vk.Device,
}
```

### Variables
```odin
camelCase: type
globalVariable: Engine
localVariable := 42
```

### Procedures
```odin
snake_case :: proc(param: type) -> return_type {
    // implementation
}

create_buffer :: proc() -> vk.Buffer
destroy_terrain :: proc()
```

### Files
- Module files: `PascalCase.odin` (e.g., `Pipeline.odin`, `Layout.odin`)
- Utility files: `camelCase.odin` (e.g., `vulkanUtils.odin`, `terrain.odin`)

## Terrain System

Brief overview of terrain implementation:
- Heightmap-based terrain generation
- Level of Detail (LOD) system for performance
- GPU-side vertex generation using `SV_VertexID`
- Error map optimization for adaptive tessellation

## Build Notes

- Uses modern Vulkan features including dynamic rendering
- Validation layers enabled in debug builds
- Custom error handling with source location tracking