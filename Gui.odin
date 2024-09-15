package main
import img "vendor:stb/truetype"
import "core:fmt"
import "core:io"
import "core:os"



gui_init :: proc(){
   fontHandle,fontERR := os.open("Fonts/ClearSans-Regular.ttf",os.O_RDONLY,0)
    if(fontERR != fontERR){
        fmt.print("ERROR: font not loaded")
    }
    defer (os.close(fontHandle))
  
}


gui_render ::proc(){

}