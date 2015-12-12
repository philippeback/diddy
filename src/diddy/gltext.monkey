#Rem
Copyright (c) 2011 Steve Revill and Shane Woolcock
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#End

#If TARGET<>"android" and TARGET<>"html5"
#Error "The GLText module is only available on the Android and HTML5 targets"
#End

Import mojo
Import "native/GLText.${LANG}"

Extern

Class GLText Extends Null = "GLText"
	Function GetNewInstance:GLText()
	Method Load:bool(file:String, size:Int, padX:Int, padY:Int)
	Method CreateText:bool(file:String, text:String, size:Int)
	Method Draw:Void(text:String, x:Float, y:Float)
	Method DrawTexture:Void(x:Float, y:Float)
	Method CalcWidth:Int(text:String)
	Method SetSize:Void(size:Int)
	Method GetSize:Int()
End