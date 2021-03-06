#Rem
Copyright (c) 2011 Steve Revill and Shane Woolcock
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#End

#Rem
Header: Diddy XML DOM parser
This is a very simple XML DOM parser, and expects a document to be as close to well-formed as possible.
The only real leniency it has is that attributes may be defined without surrounding quotes/double quotes.
All XML characters should be escaped in strings. &gt; &lt; etc.
Currently it supports regular tag and attribute definitions, processing instructions, and skipping comments.
For now, exported indentation is hardcoded to 2 spaces.
Written from scratch, using as little string manipulation as possible.
#End

Private
Import diddy.stringbuilder
Import diddy.exception
Import diddy.constants

' only import os or mojo if LoadString is enabled
#If XML_USE_LOADSTRING
	' import os if LoadString is implemented there, otherwise import mojo
	#If TARGET="stdcpp" Or TARGET="glfw"
		Import os
	#Else
		Import mojo
	#End
#End

Public
#Rem
Summary: Parses XML files and/or strings to generate an XMLDocument instance.
#End
Class XMLParser
Private
	Const TAG_DEFAULT:Int = 0
	Const TAG_COMMENT:Int = 1
	Const TAG_CDATA:Int = 2
	Const TAG_DOCTYPE:Int = 3
	
	Field str:String
	Field tags:Int[] ' tag character indexes, alternating < and >
	Field tagType:Int[] 
	Field tagCount:Int = 0
	Field tagsLength:Int
	Field quotes:Int[] ' quote character indexes, alternating opening and closing
	Field quoteCount:Int = 0
	Field quotesLength:Int
	Field pis:Int[] ' pi character indexes, alternating <? And ?> (index is on <>)
	Field piCount:Int = 0
	Field pisLength:Int
	
	Method CacheControlCharacters:Void()
		tagsLength = 128
		quotesLength = 128
		pisLength = 128
		tags = New Int[tagsLength]
		tagType = New Int[tagsLength]
		quotes = New Int[quotesLength]
		pis = New Int[quotesLength]
		tagCount = 0
		quoteCount = 0
		piCount = 0
		Local inTag:Bool = False
		Local inQuote:Bool = False
		Local inComment:Bool = False
		Local inCdata:Bool = False
		Local inDoctype:Bool = False
		Local inPi:Bool = False
		Local strlen:Int = str.Length
		For Local i:Int = 0 Until strlen
			' if we're in a comment, we're only looking for -->
			If inComment Then
				If str[i] = ASC_GREATER_THAN And str[i-1] = ASC_HYPHEN And str[i-2] = ASC_HYPHEN Then
					If tagCount+1 >= tagsLength Then
						tagsLength *= 2
						tags = tags.Resize(tagsLength)
						tagType = tagType.Resize(tagsLength)
					End
					tags[tagCount] = i
					tagType[tagCount] = TAG_COMMENT
					tagCount += 1
					inComment = False
				End
			' if we're in a cdata, we're only looking for ]]>
			ElseIf inCdata Then
				If str[i] = ASC_GREATER_THAN And str[i-1] = ASC_CLOSE_BRACKET And str[i-2] = ASC_CLOSE_BRACKET Then
					If tagCount+1 >= tagsLength Then
						tagsLength *= 2
						tags = tags.Resize(tagsLength)
						tagType = tagType.Resize(tagsLength)
					End
					tags[tagCount] = i
					tagType[tagCount] = TAG_CDATA
					tagCount += 1
					inCdata = False
				End
			' if we're in a quoted string, we're only looking for "
			ElseIf inQuote Then
				If str[i] = ASC_DOUBLE_QUOTE Then
					If quoteCount+1 >= quotesLength Then
						quotesLength *= 2
						quotes = quotes.Resize(quotesLength)
					End
					quotes[quoteCount] = i
					quoteCount += 1
					inQuote = False
				End
			' check if we should start a new quoted string
			ElseIf str[i] = ASC_DOUBLE_QUOTE Then
				If quoteCount+1 >= quotesLength Then
					quotesLength *= 2
					quotes = quotes.Resize(quotesLength)
				End
				quotes[quoteCount] = i
				quoteCount += 1
				inQuote = True
			' if we're in a processing instruction, we're only looking for ?>
			ElseIf inPi Then
				If str[i] = ASC_GREATER_THAN And str[i-1] = ASC_QUESTION Then
					If piCount+1 >= pisLength Then
						pisLength *= 2
						pis = pis.Resize(pisLength)
					End
					pis[piCount] = i
					piCount += 1
					inPi = False
				End
			' if we're in a doctype, we're only looking for >
			ElseIf inDoctype Then
				If str[i] = ASC_GREATER_THAN Then
					If tagCount+1 >= tagsLength Then
						tagsLength *= 2
						tags = tags.Resize(tagsLength)
						tagType = tagType.Resize(tagsLength)
					End
					tags[tagCount] = i
					tagType[tagCount] = TAG_DOCTYPE
					tagCount += 1
					inDoctype = False
				End
			' less than
			ElseIf str[i] = ASC_LESS_THAN Then
				' if we're in a tag, die
				If inTag Then Throw New XMLParseException("XMLParser.CacheControlCharacters: Invalid less than!")
				' check for prolog
				If str[i+1] = ASC_EXCLAMATION Then
					' comment?
					If str[i+2] = ASC_HYPHEN And str[i+3] = ASC_HYPHEN Then
						If tagCount+1 >= tagsLength Then
							tagsLength *= 2
							tags = tags.Resize(tagsLength)
							tagType = tagType.Resize(tagsLength)
						End
						tags[tagCount] = i
						tagType[tagCount] = TAG_COMMENT
						tagCount += 1
						inComment = True
					' cdata?
					ElseIf str[i+2] = ASC_OPEN_BRACKET And
							(str[i+3] = ASC_UPPER_C Or str[i+3] = ASC_LOWER_C) And
							(str[i+4] = ASC_UPPER_D Or str[i+4] = ASC_LOWER_D) And
							(str[i+5] = ASC_UPPER_A Or str[i+5] = ASC_LOWER_A) And
							(str[i+6] = ASC_UPPER_T Or str[i+6] = ASC_LOWER_T) And
							(str[i+7] = ASC_UPPER_A Or str[i+7] = ASC_LOWER_A) And
							str[i+8] = ASC_OPEN_BRACKET Then
						If tagCount+1 >= tagsLength Then
							tagsLength *= 2
							tags = tags.Resize(tagsLength)
							tagType = tagType.Resize(tagsLength)
						End
						tags[tagCount] = i
						tagType[tagCount] = TAG_CDATA
						tagCount += 1
						inCdata = True
					' doctype?
					ElseIf (str[i+2] = ASC_UPPER_D Or str[i+2] = ASC_LOWER_D) And
							(str[i+3] = ASC_UPPER_O Or str[i+3] = ASC_LOWER_O) And
							(str[i+4] = ASC_UPPER_C Or str[i+4] = ASC_LOWER_C) And
							(str[i+5] = ASC_UPPER_T Or str[i+5] = ASC_LOWER_T) And
							(str[i+6] = ASC_UPPER_Y Or str[i+6] = ASC_LOWER_Y) And
							(str[i+7] = ASC_UPPER_P Or str[i+7] = ASC_LOWER_P) And
							(str[i+8] = ASC_UPPER_E Or str[i+8] = ASC_LOWER_E) Then
						If tagCount+1 >= tagsLength Then
							tagsLength *= 2
							tags = tags.Resize(tagsLength)
							tagType = tagType.Resize(tagsLength)
						End
						tags[tagCount] = i
						tagType[tagCount] = TAG_DOCTYPE
						tagCount += 1
						inDoctype = True
					Else
						Throw New XMLParseException("XMLParser.CacheControlCharacters: Invalid prolog.")
					End
				' check for processing instruction
				ElseIf str[i+1] = ASC_QUESTION Then
					If piCount+1 >= pisLength Then
						pisLength *= 2
						pis = pis.Resize(pisLength)
					End
					pis[piCount] = i
					piCount += 1
					inPi = True
				' finally, it must just be opening a tag
				Else
					If tagCount+1 >= tagsLength Then
						tagsLength *= 2
						tags = tags.Resize(tagsLength)
						tagType = tagType.Resize(tagsLength)
					End
					tags[tagCount] = i
					tagType[tagCount] = TAG_DEFAULT
					tagCount += 1
					inTag = True
				End
			' greater than
			ElseIf str[i] = ASC_GREATER_THAN Then
				If Not inTag Then Throw New XMLParseException("XMLParser.CacheControlCharacters: Invalid greater than!")
				If tagCount+1 = tagsLength Then
					tagsLength *= 2
					tags = tags.Resize(tagsLength)
					tagType = tagType.Resize(tagsLength)
				End
				tags[tagCount] = i
				tagType[tagCount] = TAG_DEFAULT
				tagCount += 1
				inTag = False
			End
		Next
		If inQuote Then Throw New XMLParseException("XMLParser.CacheControlCharacters: Unclosed quote!")
		If inTag Then Throw New XMLParseException("XMLParser.CacheControlCharacters: Unclosed tag!")
		If inComment Then Throw New XMLParseException("XMLParser.CacheControlCharacters: Unclosed comment!")
		If inCdata Then Throw New XMLParseException("XMLParser.CacheControlCharacters: Unclosed cdata!")
		If inPi Then Throw New XMLParseException("XMLParser.CacheControlCharacters: Unclosed processing instruction!")
	End

	' get the contents of a tag (given start and end)
	Method GetTagContents:XMLElement(startIndex:Int, endIndex:Int)
		' die if empty tag
		If startIndex = endIndex Then Throw New XMLParseException("XMLParser.GetTagContents: Empty tag detected.")
		' our element
		Local e:XMLElement = New XMLElement
		Local a:Int, singleQuoted:Bool, doubleQuoted:Bool, key:String, value:String
		
		' get the name
		a = startIndex
		While a < endIndex
			If str[a]=ASC_SPACE Or str[a]=ASC_TAB Or str[a]=ASC_LF Or str[a]=ASC_CR Then
				e.name = str[startIndex..a]
				a += 1
				Exit
			ElseIf a = endIndex-1 Then
				e.name = str[startIndex..endIndex]
			End
			a += 1
		End
		startIndex = a
		
		' TODO: validate tag name is alphanumeric
		' if no name, die
		If e.name = "" Then Throw New XMLParseException("XMLParser.GetTagContents: Error reading tag name.")
		
		' loop on all tokens
		While startIndex < endIndex
			' trim leading whitespace
			While startIndex < endIndex And (str[startIndex]=ASC_SPACE Or str[startIndex]=ASC_TAB Or str[startIndex]=ASC_LF Or str[startIndex]=ASC_CR)
				startIndex += 1
			End
			
			' clear check variables
			singleQuoted = False
			doubleQuoted = False
			key = ""
			value = ""
			
			' find the key
			a = startIndex
			While a < endIndex
				If str[a] = ASC_EQUALS Or str[a]=ASC_SPACE Or str[a]=ASC_TAB Or str[a]=ASC_LF Or str[a]=ASC_CR Or a = endIndex-1 Then
					If a=endIndex-1 Then
						key = str[startIndex..endIndex]
					Else
						key = str[startIndex..a]
					End
					a += 1
					Exit
				End
				a += 1
			End
			startIndex = a
			
			' if the key is empty, there was an error (unless we've hit the end of the string)
			If key = "" Then
				If a < endIndex Then
					Throw New XMLParseException("XMLParser.GetTagContents: Error reading attribute key.")
				Else
					Exit
				End
			End
			
			' if it stopped on an equals, get the value
			If str[a-1] = ASC_EQUALS Then
				singleQuoted = False
				doubleQuoted = False
				While a < endIndex
					' check if it's a single quote
					If str[a] = ASC_SINGLE_QUOTE And Not doubleQuoted Then
						' if this is the first index, mark it as quoted
						If a = startIndex Then
							singleQuoted = True
						' otherwise, if we're not quoted at all, die
						ElseIf Not singleQuoted And Not doubleQuoted Then
							Throw New XMLParseException("XMLParser.GetTagContents: Unexpected single quote detected in attribute value.")
						Else
							' we must be ending the quote here, so grab it and break out
							singleQuoted = False
							value = str[startIndex+1..a]
							a += 1
							Exit
						End
						
					' check if it's a double quote
					ElseIf str[a] = ASC_DOUBLE_QUOTE And Not singleQuoted Then
						' if this is the first index, mark it as quoted
						If a = startIndex Then
							doubleQuoted = True
						' otherwise, if we're not quoted at all, die
						ElseIf Not singleQuoted And Not doubleQuoted Then
							Throw New XMLParseException("XMLParser.GetTagContents: Unexpected double quote detected in attribute value.")
						Else
							' we must be ending the quote here, so break out
							doubleQuoted = False
							value = str[startIndex+1..a]
							a += 1
							Exit
						End
						
					' should we be ending the attribute?
					ElseIf a = endIndex-1 Or (Not singleQuoted And Not doubleQuoted And (str[a]=ASC_SPACE Or str[a]=ASC_TAB Or str[a]=ASC_LF Or str[a]=ASC_CR))
						If a=endIndex-1 Then
							value = str[startIndex..endIndex]
						Else
							value = str[startIndex..a]
						End
						a += 1
						Exit
					End
					a += 1
				End
				startIndex = a
				value = UnescapeXMLString(value)
				
				If singleQuoted Or doubleQuoted Then Throw New XMLParseException("XMLParser.GetTagContents: Unclosed quote detected.")
			End
			
			' set the attribute
			e.SetAttribute(key, value)

			If a >= endIndex Then Exit
		End
		Return e
	End

	Method TrimString:Void(startIdx:Int, endIdx:Int, trimmed:Int[])
		Local trimStart:Int = startIdx, trimEnd:Int = endIdx
		While trimEnd > trimStart
			Local ch:Int = str[trimEnd-1]
			If ch = ASC_CR Or ch = ASC_LF Or ch = ASC_SPACE Or ch = ASC_TAB Then
				trimEnd -= 1
			Else
				Exit
			End
		End
		While trimStart < trimEnd
			Local ch:Int = str[trimStart]
			If ch = ASC_CR Or ch = ASC_LF Or ch = ASC_SPACE Or ch = ASC_TAB Then
				trimStart += 1
			Else
				Exit
			End
		End
		trimmed[0] = trimStart
		trimmed[1] = trimEnd
	End
	
Public
#Rem
Summary: Reads and parses an XML file using the LoadString method.
Currently doesn't support nested PI or prolog.
[code]
Local doc:XMLDocument = New XMLParser().ParseFile("foo.xml")
[/code]
#End
	Method ParseFile:XMLDocument(filename:String)
#If Not XML_USE_LOADSTRING
		Throw New UnsupportedOperationException("ParseFile has been temporarily disabled due to LoadString() on HTML5 and other targets requiring Mojo to be imported.  To continue using it, set #XML_USE_LOADSTRING=True")
#Else
		Local xmlString:String = LoadString(filename)
		If Not xmlString Then
			Throw New XMLParseException("XMLParser.ParseFile: Error: Cannot load " + filename)
		End
		Return ParseString(xmlString)
#End
	End

#Rem
Summary: Parses an XML string.
Currently doesn't support nested PI or prolog.
[code]
Local doc:XMLDocument = New XMLParser().ParseString("<foo></foo>")
[/code]
#End
	Method ParseString:XMLDocument(str:String)
		Self.str = str
		
		Local doc:XMLDocument = New XMLDocument
		Local elements:Stack<XMLElement> = New Stack<XMLElement>
		Local thisE:XMLElement = Null, newE:XMLElement = Null
		Local index:Int = 0, a:Int, b:Int, c:Int, nextIndex:Int
		Local trimmed:Int[] = New Int[2]
		
		' cache all the control characters
		CacheControlCharacters()
		
		' find first opening tag
		If tagCount = 0 Then Throw New XMLParseException("XMLParser.ParseString: Something seriously wrong... no tags!")
		
		' parse processing instructions
		index = 0
		a = pis[index]+2
		b = pis[index+1]-1
		While index < piCount
			TrimString(a, b, trimmed)
			If trimmed[0] <> trimmed[1] Then
				newE = GetTagContents(trimmed[0], trimmed[1])
				newE.pi = True
				doc.pi.Push(newE)
				newE = Null
			Else
				Throw New XMLParseException("XMLParser.ParseString: Empty processing instruction.")
			End
			index += 2
		End
		
		' loop on tags
		index = 0
		While index+1 < tagCount
			' we skip comments
			If tagType[index] = TAG_COMMENT Then
				' skip comments
			
			' if it's cdata
			ElseIf tagType[index] = TAG_CDATA Then
				' get the text between < and >
				a = tags[index]+9 ' "![CDATA[".Length
				b = tags[index+1]-2 ' "]]".Length
				
				' add a cdata element
				newE = New XMLElement
				newE.cdata = True
				newE.value = str[a..b]
				newE.parent = thisE
				thisE.AddChild(newE)
				newE = Null
				
			' otherwise we do normal tag stuff
			Else
				' get the text between < and >
				a = tags[index]+1
				b = tags[index+1]
				
				' trim the string
				TrimString(a, b, trimmed)
				
				' if it's a completely empty tag name, die
				If trimmed[0] = trimmed[1] Then Throw New XMLParseException("XMLParser.ParseString: Empty tag.")
				
				' check if the first character is a slash (end tag)
				If str[trimmed[0]] = ASC_SLASH Then
					' if no current element, die
					If thisE = Null Then Throw New XMLParseException("XMLParser.ParseString: Closing tag found outside main document tag.")
					
					' strip the slash
					trimmed[0] += 1
					
					' check that the tag name length matches
					If trimmed[1] - trimmed[0] <> thisE.name.Length Then Throw New XMLParseException("Closing tag ~q"+str[trimmed[0]..trimmed[1]]+"~q does not match opening tag ~q"+thisE.name+"~q")
					
					' check that the tag name matches (manually so that we don't create an entire string slice when the first character could be wrong!)
					For Local nameIdx:Int = 0 Until thisE.name.Length
						If str[trimmed[0]+nameIdx] <> thisE.name[nameIdx] Then Throw New XMLParseException("Closing tag ~q"+str[trimmed[0]..trimmed[1]]+"~q does not match opening tag ~q"+thisE.name+"~q")
					Next
					
					' pop the element from the stack, or set the document root
					If Not elements.IsEmpty() Then
						thisE = elements.Pop()
					Else
						'doc.root = thisE
						Exit
					End
					
				' check if the last character is a slash (self closing tag)
				ElseIf str[trimmed[1]-1] = ASC_SLASH Then
					' strip the slash
					trimmed[1] -= 1
					
					' create an element from the tag
					newE = GetTagContents(trimmed[0], trimmed[1])
					
					' add as a child or set as the root
					If doc.root = Null Then doc.root = newE
					If thisE <> Null Then
						thisE.AddChild(newE)
					Else
						'doc.root = newE
						Exit
					End
					newE = Null
					
				' otherwise it's an opening tag
				Else
					' create an element from the tag
					newE = GetTagContents(trimmed[0], trimmed[1])

					If doc.root = Null Then doc.root = newE
					
					' add as a child if we already have an element
					If thisE <> Null Then
						thisE.AddChild(newE)
					End
					
					' push this element
					elements.Push(thisE)
					
					' and set as the current
					thisE = newE
					newE = Null
				End
			End
			
			' get any text between tags
			index += 1
			If index < tagCount Then
				a = tags[index]+1
				b = tags[index+1]
				TrimString(a, b, trimmed)
				If trimmed[0] <> trimmed[1] Then
					If thisE <> Null Then
						thisE.value += UnescapeXMLString(str[trimmed[0]..trimmed[1]])
					Else
						'AssertError("Loose text outside of any tag!") - Getting this for some reason, I'll fix it later :/
					End
				End
			End
			
			' next tag
			index += 1
		End
		If doc.root = Null Then Throw New XMLParseException("XMLParser.ParseString: Error parsing XML: no document tag found.")
		Return doc
	End
End

#Rem
Summary: Defines an XML DOM.
#End
Class XMLDocument
Private
	Field xmlVersion:String = "1.0"
	Field xmlEncoding:String = "UTF-8"
	Field root:XMLElement
	Field pi:Stack<XMLElement> = New Stack<XMLElement>
	Field prologs:Stack<XMLElement> = New Stack<XMLElement>
	
Public
	
#Rem
Summary: Instantiates a new XMLDocument with an optional root element name.
If no root name is passed, the root node will be null, and the document is invalid.
#End
	Method New(rootName:String="")
		If rootName <> "" Then root = New XMLElement(rootName)
	End

#Rem
Summary: Instantiates a new XMLDocument with the passed root node.
#End
	Method New(root:XMLElement)
		Self.root = root
	End
	
#Rem
Summary: Generates an XML string from the XMLDocument.
Optionally formats the string.  Default is formatted.
#End
	Method ExportString:String(formatXML:Bool = True)
		' we start with the xml instruction
		Local output:String = "<?xml version=~q"+xmlVersion+"~q encoding=~q"+xmlEncoding+"~q?>"
		If formatXML Then output += "~n"
		' root node
		output += root.ToString(formatXML) + "~n"
		' done!
		Return output
	End

#Rem
Summary: Saves the XMLDocument to a file.
Currently unimplemented.
#End
	Method SaveFile:Void(filename:String)
		' TODO when file IO is ready!
	End

#Rem
Summary: Returns the DOM root element.
#End
	Method Root:XMLElement() Property
		Return root
	End
	
#Rem
Summary: Returns a Stack of prologs.
#End
	Method Prologs:Stack<XMLElement>() Property
		Return prologs
	End
	
#Rem
Summary: Returns a Stack of processing instructions.
#End
	Method ProcessingInstructions:Stack<XMLElement>() Property
		Return pi
	End
	
#Rem
Summary: Returns the XML version of this document.
#End
	Method Version:String() Property
		Return xmlVersion
	End
	
#Rem
Summary: Returns the string encoding of this document.
#End
	Method Encoding:String() Property
		Return xmlEncoding
	End
End

Class XMLAttribute
Private
	Field name:String
	Field value:String

Public
' Constructors
	Method New(name:String, value:String)
		Self.name = name
		Self.value = value
	End
	
	Method Matches:Bool(check:String)
		Return check = name + "=" + value
	End
	
	Method Name:String() Property
		Return name
	End
	
	Method Value:String() Property
		Return value
	End
	
	Method StringValue:String(def:String)
		If Not value Then Return def
		Return value
	End
	
	Method FloatValue:Float(def:Float)
		If Not value Then Return def
		Return Float(value)
	End
	
	Method IntValue:Int(def:Int)
		If Not value Then Return def
		Return Int(value)
	End
	
	Method BoolValue:Bool(def:Bool)
		If Not value Then Return def
		Return value.ToLower() = "true" Or value = "1"
	End
End

Class XMLElement
Private
	Field openTagStart:String = "<"
	Field openTagEnd:String = ">"
	Field selfCloseEnd:String = " />"
	Field closeTagStart:String = "</"
	Field closeTagEnd:String = ">"
	
	Field name:String
	Field attributes:Stack<XMLAttribute> = New Stack<XMLAttribute>
	Field children:Stack<XMLElement> = New Stack<XMLElement>
	Field value:String
	Field parent:XMLElement

	Field pi:Bool
	Field prolog:Bool
	Field cdata:Bool
	
Public
' Constructors
	Method New()
	End
	
	Method New(name:String, parent:XMLElement = Null)
		Self.parent = parent
		Self.name = name
		If parent <> Null Then parent.children.Push(Self)
	End

' Methods
	Method IsProcessingInstruction:Bool()
		Return pi
	End
	
	Method IsProlog:Bool()
		Return prolog
	End
	
	Method IsCharacterData:Bool()
		Return cdata
	End
	
	' avoid using this method if you can, because you should try not to have "floating" elements
	Method AddChild:Void(child:XMLElement)
		If children.Contains(child) Return
		children.Push(child)
		child.parent = Self
	End
	
	Method HasAttribute:Bool(name:String)
		If Not name Then Return False ' checking for an empty name, will always return false
		For Local i% = 0 Until attributes.Length()
			Local att:XMLAttribute = attributes.Get(i)
			If att.name = name Then Return True
		Next
		Return False
	End
	
	Method GetAttribute:String(name:String, defaultValue:String = "")
		If Not name Then Return "" ' reading an empty name will always return ""
		For Local i% = 0 Until attributes.Length()
			Local att:XMLAttribute = attributes.Get(i)
			If att.name = name Then Return att.value
		Next
		Return defaultValue
	End
	
	Method SetAttribute:String(name:String, value:String)
		' we'll prevent the developer from setting an attribute with an empty name, as it makes no sense
		If Not name Then Throw New IllegalArgumentException("XMLElement.SetAttribute: name must not be empty")
		For Local i% = 0 Until attributes.Length()
			Local att:XMLAttribute = attributes.Get(i)
			If att.name = name Then
				Local old:String = att.value
				att.value = value
				Return old
			End
		Next
		attributes.Push(New XMLAttribute(name, value))
		Return ""
	End
	
	Method ClearAttribute:String(name:String)
		If Not name Then Return "" ' clearing an attribute with an empty name just returns ""
		For Local i% = 0 Until attributes.Length()
			Local att:XMLAttribute = attributes.Get(i)
			If att.name = name Then
				attributes.RemoveEach(att)
				Return att.value
			End
		Next
		Return ""
	End
	
	Method Dispose:Void(removeSelf:Bool = True)
		' dispose children
		#Rem FIXME
		Local en:IEnumerator<XMLElement> = children.Enumerator()
		While en.HasNext()
			Local element:XMLElement = en.NextObject()
			element.Dispose(False)
			en.Remove()
		End
		#End
		' remove self from parent if this is not recursing
		If removeSelf And parent <> Null Then parent.children.RemoveEach(Self)
		' clear out the parent
		parent = Null
	End
	
	Method ToString:String(formatXML:Bool=True, indentation:Int=0)
		Local rv:String = ""
		If formatXML Then
			For Local i% = 0 Until indentation
				rv += "  "
			Next
		End
		rv += openTagStart + name
		If Not attributes.IsEmpty() Then
			For Local i% = 0 Until attributes.Length()
				Local att:XMLAttribute = attributes.Get(i)
				rv += " " + att.name + "=~q" + EscapeXMLString(att.value) + "~q"
			Next
		End
		If children.IsEmpty() Then
			Local esc:String = EscapeXMLString(value.Trim())
			If esc.Length() = 0
				rv += selfCloseEnd
			Else
				rv += openTagEnd + value.Trim() + closeTagStart + name + closeTagEnd
			End
		Else
			rv += openTagEnd
			If formatXML Then
				rv += "~n"
			End
			For Local i% = 0 Until children.Length()
				rv += children.Get(i).ToString(formatXML, indentation + 1)
			End
			Local esc:String = EscapeXMLString(value.Trim())
			If esc.Length() > 0 Then
				If Not formatXML Then
					rv += esc
				Else
					rv += "~n" + esc + "~n"
				End
			End
			If formatXML Then
				For Local i% = 0 Until indentation
					rv += "  "
				Next
			End
			rv += closeTagStart + name + closeTagEnd
		End
		If formatXML Then
			rv += "~n"
		End
		Return rv
	End
	
	Method GetChildrenByName:Stack<XMLElement>(findName$, att1$="", att2$="", att3$="", att4$="", att5$="", att6$="", att7$="", att8$="", att9$="", att10$="")
		If Not findName Then Throw New IllegalArgumentException("XMLElement.GetChildrenByName: findName must not be empty")
		Local rv:Stack<XMLElement> = New Stack<XMLElement>
		For Local element:XMLElement = Eachin children
			If element.name = findName Then
				If att1 And Not element.MatchesAttribute(att1) Then Continue
				If att2 And Not element.MatchesAttribute(att2) Then Continue
				If att3 And Not element.MatchesAttribute(att3) Then Continue
				If att4 And Not element.MatchesAttribute(att4) Then Continue
				If att5 And Not element.MatchesAttribute(att5) Then Continue
				If att6 And Not element.MatchesAttribute(att6) Then Continue
				If att7 And Not element.MatchesAttribute(att7) Then Continue
				If att8 And Not element.MatchesAttribute(att8) Then Continue
				If att9 And Not element.MatchesAttribute(att9) Then Continue
				If att10 And Not element.MatchesAttribute(att10) Then Continue
				rv.Push(element)
			End
		Next
		Return rv
	End
	
	Method GetFirstChildByName:XMLElement(findName$, att1$="", att2$="", att3$="", att4$="", att5$="", att6$="", att7$="", att8$="", att9$="", att10$="")
		If Not findName Then Throw New IllegalArgumentException("XMLElement.GetFirstChildByName: findName must not be empty")
		For Local element:XMLElement = Eachin children
			If element.name = findName Then
				If att1 And Not element.MatchesAttribute(att1) Then Continue
				If att2 And Not element.MatchesAttribute(att2) Then Continue
				If att3 And Not element.MatchesAttribute(att3) Then Continue
				If att4 And Not element.MatchesAttribute(att4) Then Continue
				If att5 And Not element.MatchesAttribute(att5) Then Continue
				If att6 And Not element.MatchesAttribute(att6) Then Continue
				If att7 And Not element.MatchesAttribute(att7) Then Continue
				If att8 And Not element.MatchesAttribute(att8) Then Continue
				If att9 And Not element.MatchesAttribute(att9) Then Continue
				If att10 And Not element.MatchesAttribute(att10) Then Continue
				Return element
			End
		Next
		Return Null
	End
	
	Method MatchesAttribute:Bool(check:String)
		For Local attr:XMLAttribute = EachIn attributes
			If attr.Matches(check) Then Return True
		Next
		Return False
	End
	
' Properties
	Method Children:Stack<XMLElement>() Property
		Return children
	End
	
	Method Parent:XMLElement() Property
		Return parent
	End
	
	Method Name:String() Property
		Return name
	End
	
	Method Name:Void(name:String) Property
		If Not name Then Throw New IllegalArgumentException("XMLElement.Name: name must not be empty")
		Self.name = name
	End
	
	Method Value:String() Property
		Return value
	End
	
	Method Value:Void(value:String) Property
		Self.value = value
	End
	
	Method Attributes:Stack<XMLAttribute>() Property
		Return attributes
	End
End

' hopefully this stringbuilder-based replace should be faster since it doesn't create intermediate string objects!
Function EscapeXMLString:String(str:String)
	If Not str Then Return ""
	xmlsb.Length = 0
	For Local i:Int = 0 Until str.Length
		Select str[i]
			Case ASC_AMPERSAND
				xmlsb.Append("&amp;")
			Case ASC_LESS_THAN
				xmlsb.Append("&lt;")
			Case ASC_GREATER_THAN
				xmlsb.Append("&gt;")
			Case ASC_SINGLE_QUOTE
				xmlsb.Append("&apos;")
			Case ASC_DOUBLE_QUOTE
				xmlsb.Append("&quot;")
			Default
				xmlsb.AppendByte(str[i])
		End
	End
	Return xmlsb.ToString()
End

' unescaping is rare so we won't bother using a stringbuilder
Function UnescapeXMLString:String(str:String)
	If Not str Then Return ""
	str = str.Replace("&quot;", "~q")
	str = str.Replace("&apos;", "'")
	str = str.Replace("&gt;", ">")
	str = str.Replace("&lt;", "<")
	str = str.Replace("&amp;", "&")
	Return str
End

Private
Global xmlsb:StringBuilder = New StringBuilder
