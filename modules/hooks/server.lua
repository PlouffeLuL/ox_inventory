if not lib then return end

local eventHooks = {}
local microtime = os.microtime

function TriggerEventHooks(event, payload)
    local hooks = eventHooks[event]

    if hooks then
		local fromInventory = payload.fromInventory and tostring(payload.fromInventory) or payload.inventoryId and tostring(payload.inventoryId)
		local toInventory = payload.toInventory and tostring(payload.toInventory)

        for i = 1, #hooks do
			local hook = hooks[i]
			local itemFilter = hook.itemFilter

			if itemFilter then
				local itemName = payload.fromSlot?.name or payload.item?.name

				if not itemName or not itemFilter[itemName] then
					if type(payload.toSlot) ~= 'table' or not itemFilter[payload.toSlot.name] then
						goto skipLoop
					end
				end
			end

			local inventoryFilter = hook.inventoryFilter

			if inventoryFilter then
				local matchedPattern

				for j = 1, #inventoryFilter do
					local pattern = inventoryFilter[j]

					if fromInventory:match(pattern) or (toInventory and toInventory:match(pattern)) then
						matchedPattern = true
						break
					end
				end

				if not matchedPattern then goto skipLoop end
			end

			if hook.print then
				shared.info(('Triggering event hook "%s:%s:%s".'):format(hook.resource, event, i))
			end

			local start = microtime()
            local _, response = pcall(hooks[i], payload)
			local executionTime = microtime() - start

			if executionTime >= 100000 then
				shared.warning(('Execution of event hook "%s:%s:%s" took %.2fms.'):format(hook.resource, event, i, executionTime / 1e3))
			end

			if event == 'createItem' then
				if type(response) == 'table' then
					payload.metadata = response
				end
			elseif response == false then
                return false
            end

			::skipLoop::
        end
    end

	if event == 'createItem' then
		return payload.metadata
	end

    return true
end

exports('registerHook', function(event, cb, options)
    if not eventHooks[event] then
        eventHooks[event] = {}
    end

	local mt = getmetatable(cb)
	mt.__index = nil
	mt.__newindex = nil
   	cb.resource = GetInvokingResource()

	if options then
		for k, v in pairs(options) do
			cb[k] = v
		end
	end

    eventHooks[event][#eventHooks[event] + 1] = cb
end)

AddEventHandler('onResourceStop', function(resource)
    for _, hooks in pairs(eventHooks) do
        for i = #hooks, 1, -1 do
            if hooks[i].resource == resource then
                table.remove(hooks, i)
            end
        end
    end
end)
