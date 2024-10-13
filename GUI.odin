package main

import "vendor:glfw"
import "core:fmt"

GUI_data :: struct{}

GUI : GUI_data 


GUI_Render :: proc(){

    if(glfw.GetKey(window,glfw.KEY_TAB)==glfw.PRESS){
        guiWidth, guiHeight :=glfw.GetWindowSize(window)
        glfw.SetCursorPos(window,f64(guiWidth)/2.0,f64(guiHeight)/2.0)
        glfw.SetInputMode(window,glfw.CURSOR,glfw.CURSOR_NORMAL)
    }
}