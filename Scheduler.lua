local module = {}

module.name = 'operation-scheduler'
module.operations = {}
module.returns = {}

function module.init()
	game:GetService('RunService').Heartbeat:connect(function()
		local pos = 0
		for k,v in pairs(module.operations) do
			pos = pos + 1
			if type(v) == "function" then
				module.returns[k] = v()
			elseif type(v) == "table" then
				module.returns[k] = v[1](unpack(v[2]))
			end
			table.remove(module.operations, pos)
		end
	end)
end

function module.schedule(func, args)
	table.insert(module.operations, func)
end

function module.filtertable(t, filter)
	local nt = {}
	for k,v in pairs(t) do
		if type(v) ~= filter then
			nt[k] = v
		end
	end
	return nt
end

function module.getreturns(len)
	local result = {}
	for i = 1, #module.returns do
		table.insert(result, table.remove(module.returns, i))
	end
	
	return unpack(result)
end

return module
