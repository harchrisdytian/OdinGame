package main

import "base:runtime"
import "core:fmt"
import glm "core:math/linalg/glsl"
import "vendor:glfw"

mouse_pressed :: enum {
	LEFT,
	RIGHT,
	MIDDLE,
}
mouse_state :: bit_set[mouse_pressed]

Input :: struct {
	input: glm.vec3,
	mouse: Mouse,
}

Mouse :: struct {
	pos:   glm.vec2,
	last:  glm.vec2,
	delta: glm.vec2,
	mouse: mouse_state,
}

HandleInput :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	using engine.player.input
	holding: f32 = 0.0
	context = runtime.default_context()
	if (action == glfw.PRESS) {
		holding = f32(1.0)
	} else if (action == glfw.RELEASE) {
		holding = f32(0.0)
	}

	if (key == glfw.KEY_W || key == glfw.KEY_UP) {
		input.y = holding
		fmt.printf("Holding w")
	}
	if (key == glfw.KEY_S || key == glfw.KEY_DOWN) {
		input.y = -holding
	}
	if (key == glfw.KEY_A || key == glfw.KEY_LEFT) {
		input.x = -holding
	}
	if (key == glfw.KEY_D || key == glfw.KEY_RIGHT) {
		input.x = holding
	}
	if (key == glfw.KEY_Q || key == glfw.KEY_LEFT_SHIFT || key == glfw.KEY_RIGHT_SHIFT) {
		input.z = -holding
	}
	if (key == glfw.KEY_E || key == glfw.KEY_LEFT_CONTROL || key == glfw.KEY_RIGHT_CONTROL) {
		input.z = holding
	}

}

HandleMouse :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
	using engine.player.input.mouse
	if (action == glfw.PRESS) {
		if (button == glfw.MOUSE_BUTTON_LEFT) do mouse |= {.LEFT}
		if (button == glfw.MOUSE_BUTTON_RIGHT) do mouse |= {.RIGHT}
		if (button == glfw.MOUSE_BUTTON_MIDDLE) do mouse |= {.MIDDLE}
	}
	if (action == glfw.RELEASE) {
		if (button == glfw.MOUSE_BUTTON_LEFT) do mouse |= {.LEFT}
		if (button == glfw.MOUSE_BUTTON_RIGHT) do mouse |= {.RIGHT}
		if (button == glfw.MOUSE_BUTTON_MIDDLE) do mouse |= {.MIDDLE}
	}
}
HandleMousePos :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {

	using engine.player.input.mouse

	pos = glm.vec2{f32(xpos), f32(ypos)}
	if last != {} {
		delta = pos - last
	}
	last = pos

}
HandleScroll :: proc "c" (window: glfw.WindowHandle, xoffset, yoffset: f64) {
	using engine.player.input.mouse
	// TODO handle
	return
}
