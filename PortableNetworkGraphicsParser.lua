local Scheduler = require(script.Parent.Parent.Scheduler)

Scheduler.init()

local textstream = {}

function textstream:new(str, byte_mode)
	local stream = {
		_cdata = {},
		_readindex = 0,
		_strlen = #str
	}
	
	if byte_mode then
		for i = 1, #str do table.insert(stream._cdata, string.byte(str:sub(i,i))) end
	else
		for i = 1, #str do table.insert(stream._cdata, str:sub(i,i)) end
	end
	
	function stream:read(len)
		local result
		if byte_mode then
			result = {}
		else
			result = ''
		end
		
		for i = 1, len do
			stream._readindex = stream._readindex + 1
			if byte_mode then
				table.insert(result, stream._cdata[stream._readindex])
			else
				result = result .. stream._cdata[stream._readindex]
			end
		end
		
		return result
	end
	
	function stream:rollback(len)
		local result
		if byte_mode then
			result = {}
		else
			result = ''
		end
		
		for i = 1, len do
			stream._readindex = stream._readindex - 1
			if byte_mode then
				table.insert(result, stream._cdata[stream._readindex])
			else
				result = result .. stream._cdata[stream._readindex]
			end
		end
		
		return result
	end
	
	function stream:concat_bytes(t, offset, len)
		local str = ''
		
		for i = 1, len do
			str = str .. string.char(t[offset+i])
		end
		
		return str 
	end
	
	return stream
end

local module = {}

function module:tablefiltertype(t, _type)
	local newTab = {}
	for k,v in pairs(t) do
		if type(v) ~= _type then
			newTab[k] = v
		end
	end
	return newTab
end

function module:eqtable(t1, t2, typeFilter)
	t1 = module:tablefiltertype(t1, typeFilter)
	if #t1 ~= #t2 then 
		return false
	end
	for k,v in pairs(t1) do
		if t2[k] ~= v then 
			return false 
		end
	end
	return true
end

function module:newparser(str)
	local parser = {
		_pngstream = textstream:new(str, true),
		pngheader = {},
		chunks = {}
	}
	
	function parser:bytestonum(bytes)
		local a,b,c,d = bytes[1], bytes[2], bytes[3], bytes[4]
		  local n = a*16777216 + b*65536 + c*256 + d
		  n = (n > 2147483647) and (n - 4294967296) or n
		  return n
	end
	
	function parser:bytestostr(bytes)
		local str =''
		for k,v in pairs(bytes) do
			str = str .. string.char(v)
		end
		return str
	end
	
	function parser:getchunklen(header)
		local bytes = {header[1], header[2], header[3], header[4]}
		return parser:bytestonum(bytes)
	end
	
	function parser:getchunktype(header)
		local bytes = {header[5], header[6], header[7], header[8]}
		return parser:bytestostr(bytes)
	end
	
	function parser:readint(len)
		local n = len
		if len == nil then n = 4 end
		local bytes = parser._pngstream:read(n)
		return parser:bytestonum(bytes)
	end
	
	function parser:readbyte()
		return parser._pngstream:read(1)[1]
	end
	
	function parser:readchar(n)
		local len = n
		if n == nil then n = 4 end
		local bytes = parser._pngstream:read(len)
		return parser:bytestostr(bytes)
	end
	
	function parser:parsechunk(oldChunk)
		local chunk = {
			length = 0,
			type=''
		}
		local chunkHeader = parser._pngstream:read(8)
		chunk.length = parser:getchunklen(chunkHeader)
		chunk.type = parser:getchunktype(chunkHeader)
		if chunk.type == 'IHDR' then
			chunk = parser:parseihdr(chunk)
		elseif chunk.type == 'IDAT' then
			print('idat region')
			chunk = parser:parseidat(chunk, oldChunk)
		else
			parser:readchar(chunk.length)
		end
		chunk.crc = parser:readchar(4)
		table.insert(parser.chunks, chunk)
		return chunk
	end
	
	function parser:parseidat(chunk, oldChunk)
		chunk.data = {}
		if oldChunk == nil then
			chunk.data = parser:readchar(chunk.length)
		elseif oldChunk ~= nil and oldChunk.type == 'IDAT' then
			chunk.data = oldChunk.data .. parser:readchar(chunk.length)
		end
		return chunk
	end
	
	function parser:parseihdr(chunk)
		chunk.width = parser:readint()
		chunk.height = parser:readint()
		chunk.bitDepth = parser:readbyte()
		chunk.colorType = parser:readbyte()
		chunk.compression = parser:readbyte()
		chunk.filter = parser:readbyte()
		chunk.interlace = parser:readbyte()
		return chunk
	end
	
	function parser:parse()
		do -- signature checking
			local headerBytes = parser._pngstream:read(8)
			assert(module:eqtable(headerBytes, {137, 80, 78, 71, 13, 10, 26, 10}, type(function() end)), 'png signature not found')
		end
		
		local parseTick = tick()
		do -- chunk parsing
			--local chunk = parser:parsechunk()
			--while chunk.type ~= 'IEND' do
				--local oldChunk = parser.chunks[#parser.chunks]
			--end
			local chunk = Scheduler.schedule(parser.parsechunk)
			wait()
			chunk = Scheduler.getreturns(1)
			while chunk.type ~= 'IEND' do
				local oldChunk = parser.chunks[#parser.chunks]
				Scheduler.schedule({parser.parsechunk, {oldChunk}})
				wait()
				chunk = Scheduler.getreturns(1)
			end
		end
		
		print('done parsing')
		print(tick()-parseTick)
	end
	
	return parser
end

return module
