package main

import "core:fmt"


TextColorType :: enum {
	RED,
	YELLOW,
	CYAN,
}
TextColor :: [TextColorType]string {
	.RED    = "31m",
	.YELLOW = "33m",
	.CYAN   = "96m",
}

color_text :: proc(input: string, color: TextColorType = .CYAN) -> string {
	esc := "\033["

	textColor := TextColor
	textColorString := fmt.aprintf("%s%s", esc, textColor[color])
	return fmt.aprintf("%s%s%s", textColorString, input, "\033[0m")
}
