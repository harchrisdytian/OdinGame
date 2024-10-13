package main

import "vendor:glfw"
import "core:fmt"

import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import math "core:math/linalg"
import "core:runtime"
import "core:unicode/utf8"
import "core:os"
import "core:bytes"
import "core:strings"
import "vendor:stb/truetype"

GUI_charAmount::96
GUI_data :: struct{
    state: GUI_state,
    imageData:[1<<23 ]byte,
    charData:[1<<23]truetype.bakedchar,
    packedChar:[GUI_charAmount]truetype.packedchar,
    img : u32,
    projection: glm.mat4,
    program:u32,
    ArrayBuffer:u32,
    ArrayObject:u32, 
    rect :GUI_rectangle
}

GUI_rectangle ::struct{
    ArrayBuffer:u32,
    ArrayObject :u32,
    projection:glm.mat4,
    program:u32,
    color: glm.vec3
}
guiWidth:i32
guiHeight:i32
testString : string

GUI_state::struct{
    isInDebugMode: bool,
    
}



tempLetter :i32 = 32
GUI : GUI_data 

gui_init :: proc(){

    fontHandle,fontERR := os.open("Fonts/ClearSans-Regular.ttf",os.O_RDONLY,0)
    defer (os.close(fontHandle))

     if(fontERR != os.ERROR_NONE){
         fmt.print("ERROR: font not loaded")
    }
     fontData : []byte
     fontSuccsess :bool
     fontData, fontSuccsess = os.read_entire_file_from_handle(fontHandle)

     if(!fontSuccsess){
        fmt.print("failed to read file")
     }     
     shaderErr:bool
     GUI.program ,shaderErr=gl.load_shaders("Shaders//TextShader.vert","Shaders//TextShader.frag")
     if(!shaderErr){
        fmt.print("failed to load font shader")

     }
     GUI.rect.program ,shaderErr=gl.load_shaders("Shaders//UIShader.vert","Shaders//UIShader.frag")

     if(!shaderErr){
        fmt.print("failed to load font shader")

     }

    fontInfo :truetype.fontinfo
    fontContext :truetype.pack_context 
    

     if(!truetype.InitFont(&fontInfo,&fontData[0],0)){
        fmt.print("err: font didn't load")
     }
     //beb := truetype.BakeFontBitmap( &fontData[0],0,32,&GUI.imageData[0],512,512,32,96,&GUI.charData[0])
    truetype.PackBegin(&fontContext,&GUI.imageData[0],512,512,0,1,nil)
    truetype.PackFontRange(&fontContext,&fontData[0],0, f32(truetype.POINT_SIZE(12.0)),32,GUI_charAmount,&GUI.packedChar[0])
    truetype.PackEnd(&fontContext)
     //fmt.print(beb)
     GUI_SetupFontTexture( )
    gl.GenVertexArrays(1, &GUI.ArrayObject)
    gl.BindVertexArray(GUI.ArrayObject)
    
    gl.GenBuffers(1, &GUI.ArrayBuffer)
    
    gl.BindBuffer(gl.ARRAY_BUFFER,GUI.ArrayBuffer)
    
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(0,2,gl.FLOAT,gl.FALSE,4 * size_of(f32),0)
    gl.VertexAttribPointer(1,2,gl.FLOAT,gl.FALSE,4 * size_of(f32),2 * size_of(f32))
    gl.BindVertexArray(0)

    gl.GenVertexArrays(1,&GUI.rect.ArrayObject)
    gl.BindVertexArray(GUI.rect.ArrayObject)

    gl.GenBuffers(1,&GUI.rect.ArrayBuffer)
    gl.BindBuffer(gl.ARRAY_BUFFER,GUI.rect.ArrayBuffer)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0,2,gl.FLOAT,gl.FALSE,2 * size_of(f32),0)
    
    
    
 }
 
gui_render ::proc()
{
     GUI_Render()
}

GUI_hover::proc(mousePos:glm.vec2,topLeft :glm.vec2,bottomRight:glm.vec2)->bool{
    
    if( (mousePos.x <=bottomRight.x && mousePos.x >= topLeft.x ) &&
        (mousePos.y <= bottomRight.y && mousePos.y >= topLeft.y)){
       return true
    }   
    return false
}

GUI_Button:: proc(label : string, position:glm.vec2, size:f32 ) -> bool
{   
    if GUI_hover(glm.vec2{lastXpos,lastYpos},position - glm.vec2{10,10}, (position - glm.vec2{20,20}) + glm.vec2{200,25})
    {
        if glfw.GetMouseButton(window,glfw.MOUSE_BUTTON_LEFT) != glfw.RELEASE
        {
            GUI_drawRect(position - glm.vec2{10,10},glm.vec2{200,25},glm.vec3{0.6,0.6,0.6}) 
            GUI_DrawText(label, position,size)
            return true
        }
        else
        {
            GUI_drawRect(position - glm.vec2{10,10},glm.vec2{200,25},glm.vec3{1.6,0.6,0.6}) 
            
        }
        
    }else{
        GUI_drawRect(position - glm.vec2{10,10},glm.vec2{200,25})
    }
    GUI_DrawText(label, position,size)
    
    return false
}


GUI_drawRect:: proc( rectPos:glm.vec2, size:glm.vec2, color :glm.vec3= {0.5,0.5,0.55})
{
    
    RectVerts :[]f32= {  //pos                      //uv
        rectPos.x          ,rectPos.y         ,
        rectPos.x + size.x ,rectPos.y         , 
        rectPos.x          ,rectPos.y + size.y, 
        rectPos.x + size.x ,rectPos.y + size.y, 
    }

    gl.UseProgram(GUI.rect.program)
    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA)
        
    backgroundColor :glm.vec3 = {0.5,0.5,0.8}
    proj := UniformValue_make(GUI.rect.program,"projection" ,GUI.projection)
    c := UniformValue_make(GUI.rect.program,"backgroundColor", color)
    
    UniformValue_set(proj)
    UniformValue_set(c)
    
    gl.BindVertexArray(GUI.rect.ArrayObject)
    gl.BindBuffer(gl.ARRAY_BUFFER,GUI.rect.ArrayBuffer)
    gl.BufferData(gl.ARRAY_BUFFER,len(RectVerts) * size_of(f32),&RectVerts[0], gl.DYNAMIC_DRAW)
    
    if(GUI.state.isInDebugMode){
        gl.DrawArrays(gl.TRIANGLE_STRIP,0,i32(len(RectVerts)/2))
    }
}

GUI_DrawText:: proc(text :string, textPos:glm.vec2,size:f32)
{
    tX,tY: f32
    quad: truetype.aligned_quad 
    
    maxX :f32= 0
    maxY :f32= 0
    CurPosX, CurPosY : = glfw.GetCursorPos(window)
    for char,index in text
    {

        truetype.GetPackedQuad(&GUI.packedChar[0],512,512, i32(char)-32,&tX,&tY,&quad,true)
        
        //glfw.SetCursorPos(window,f64(guiWidth)/2.0,f64(guiHeight)/2.0)
        glfw.SetInputMode(window,glfw.CURSOR,glfw.CURSOR_NORMAL)
        gl.UseProgram(GUI.program)

        //size :f32= 10
        xPos :f32 = textPos.x + (size * f32(index)) 
        yPos :f32 = textPos.y
        
        maxX += quad.x1
        if (maxY < yPos + quad.y1 + size){
            maxY = yPos + quad.y1 + size
        }

        CharVerts :[]f32= {  //pos                      //uv
            xPos + quad.x0       ,yPos + quad.y0       , quad.s0,quad.t0,
            xPos + quad.x1 + size,yPos + quad.y0       , quad.s1,quad.t0,
            xPos + quad.x0       ,yPos + quad.y1 + size, quad.s0,quad.t1,
            xPos + quad.x1 + size,yPos + quad.y1 + size, quad.s1,quad.t1,
        }

        textColor := glm.vec3{1.0,1.0,1.0}
        uni := UniformValue_make(GUI.program,"projection",GUI.projection)
        c := UniformValue_make(GUI.program,"textColor", textColor)
        
        UniformValue_set(uni)
        UniformValue_set(c)
        
        charInd :[]i32={ 0,1,2 ,1,2,4}
        //gl.UseProgram(GUI.program)
        
        gl.BindVertexArray(GUI.ArrayObject)
        gl.Enable(gl.BLEND)
        gl.BlendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA)
        
        gl.BindTexture(gl.TEXTURE_2D,GUI.img)
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindVertexArray(GUI.ArrayObject)
        gl.BindBuffer(gl.ARRAY_BUFFER,GUI.ArrayBuffer)
        gl.BufferData(gl.ARRAY_BUFFER,len(CharVerts) * size_of(f32),&CharVerts[0], gl.DYNAMIC_DRAW)
        
        if(GUI.state.isInDebugMode){
            gl.DrawArrays(gl.TRIANGLE_STRIP,0,i32(len(CharVerts)/4))
        }
    }

     
}
GUI_Render :: proc(){
        
        GUI.projection = glm.mat4Ortho3d(0,f32(guiWidth),f32(guiHeight),0,-10,100)

        tempString :string = "real Time"
        tempLetter +=1
        tempString = fmt.aprint("real time: ", tempLetter)
        
        
        if (GUI_Button("help", glm.vec2{20,100},1))
        {

            testString = ""
        }
        
        GUI_DrawText(testString,glm.vec2{20,160},1)
        
}

GUI_SetupFontTexture::proc(){
    gl.GenTextures(1,&GUI.img)
    gl.BindTexture(gl.TEXTURE_2D,GUI.img)
    gl.TexImage2D(gl.TEXTURE_2D,0,gl.RED,512,512,0,gl.RED, gl.UNSIGNED_BYTE,rawptr(&GUI.imageData[0]))
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)

}

GUI_charCallBack::proc "c" (window: glfw.WindowHandle, char: rune){
    
    context = runtime.default_context()
    testString = fmt.tprint(testString, char , sep = "")
}