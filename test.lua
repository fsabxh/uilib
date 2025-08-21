--!strict
--[=[
	Batched Yield-Safe Signal (Standalone)

	RBXScriptSignal-like API with yield-safe handlers.
	No Nevermore loader. No external dependencies.

	Usage:
		local Signal = require(path.To.Signal)
		local sig = Signal.new()
		local conn = sig:Connect(function(a, b) print(a, b) end)
		sig:Fire(1, 2)
		conn:Disconnect()
]=]

--// Local safe spawner with error handling
local function safeSpawn(_memoryCategory: string, fn: (...any) -> (), ...: any)
	-- Run handlers asynchronously and surface errors with traceback
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = xpcall(function()
			fn(table.unpack(args, 1, args.n))
		end, debug.traceback)
		if not ok then
			warn("[GoodSignal] Handler error:\n" .. tostring(err))
		end
	end)
end

--// Types
export type SignalHandler<T...> = (T...) -> ()
export type Connection<T...> = typeof(setmetatable(
	{} :: {
		_memoryCategory: string,
		_signal: Signal<T...>?,
		_fn: SignalHandler<T...>?,
		_next: Connection<T...>?,
	},
	{} :: { __index: any }
))
export type Signal<T...> = typeof(setmetatable(
	{} :: {
		_handlerListHead: Connection<T...> | false,
	},
	{} :: { __index: any }
))

--// Connection class
local Connection = {}
Connection.ClassName = "Connection"
Connection.__index = Connection

function Connection.new<T...>(signal: Signal<T...>, fn: SignalHandler<T...>): Connection<T...>
	return setmetatable({
		-- selene: allow(incorrect_standard_library_use)
		_memoryCategory = debug.getmemorycategory(),
		_signal = signal,
		_fn = fn,
		_next = nil,
	}, Connection) :: any
end

function Connection.IsConnected<T...>(self: Connection<T...>): boolean
	return rawget(self :: any, "_signal") ~= nil
end

function Connection.Disconnect<T...>(self: Connection<T...>)
	local signal = rawget(self :: any, "_signal") :: Signal<T...>?
	if not signal then
		return
	end

	local ourNext = rawget(self :: any, "_next")

	if (signal :: any)._handlerListHead == self then
		(signal :: any)._handlerListHead = ourNext or false
	else
		local prev = (signal :: any)._handlerListHead
		while prev and rawget(prev, "_next") ~= self do
			prev = rawget(prev, "_next")
		end
		if prev then
			assert(rawget(prev, "_next") == self, "Bad state")
			rawset(prev, "_next", ourNext)
		end
	end

	-- Keep only _next for chain integrity; clear rest for GC
	for k in pairs(self) do
		if k ~= "_next" then
			(self :: any)[k] = nil
		end
	end
end

Connection.Destroy = Connection.Disconnect

-- Strict metatable (guard against typos)
setmetatable(Connection, {
	__index = function(_, key)
		error(string.format("Attempt to get Connection::%s (not a valid member)", tostring(key)), 2)
	end,
	__newindex = function(_, key, _)
		error(string.format("Attempt to set Connection::%s (not a valid member)", tostring(key)), 2)
	end,
})

--// Signal class
local Signal = {}
Signal.ClassName = "Signal"
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	return setmetatable({
		_handlerListHead = false,
	}, Signal) :: any
end

function Signal.isSignal(value: any): boolean
	return type(value) == "table" and getmetatable(value) == Signal
end

function Signal.Connect<T...>(self: Signal<T...>, fn: SignalHandler<T...>): Connection<T...>
	local connection = Connection.new(self, fn)
	if self._handlerListHead then
		rawset(connection :: any, "_next", self._handlerListHead)
		self._handlerListHead = connection
	else
		self._handlerListHead = connection
	end
	return connection
end

function Signal:GetConnectionCount(): number
	local n = 0
	local prev = self._handlerListHead
	while prev do
		n += 1
		prev = rawget(prev, "_next")
	end
	return n
end

function Signal.DisconnectAll<T...>(self: Signal<T...>): ()
	while self._handlerListHead do
		local last = self._handlerListHead
		last:Disconnect()
		assert(self._handlerListHead ~= last, "self._handlerListHead should not be last")
	end
	self._handlerListHead = false
end

function Signal.Fire<T...>(self: Signal<T...>, ...: T...): ()
	local connection: any = self._handlerListHead
	while connection do
		local nextNode = rawget(connection, "_next")
		if rawget(connection, "_signal") ~= nil then
			safeSpawn(connection._memoryCategory, connection._fn :: any, ...)
		end
		connection = nextNode
	end
end

function Signal.Wait<T...>(self: Signal<T...>): T...
	local waiting = coroutine.running()
	local connection: Connection<T...>
	connection = (self :: any):Connect(function(...: T...)
		connection:Disconnect()
		task.spawn(waiting, ...)
	end)
	return coroutine.yield()
end

function Signal.Once<T...>(self: Signal<T...>, fn: SignalHandler<T...>): Connection<T...>
	local connection: Connection<T...>
	connection = (self :: any):Connect(function(...: T...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

Signal.Destroy = Signal.DisconnectAll

-- Strict metatable (guard against typos)
setmetatable(Signal, {
	__index = function(_, key)
		error(string.format("Attempt to get Signal::%s (not a valid member)", tostring(key)), 2)
	end,
	__newindex = function(_, key, _)
		error(string.format("Attempt to set Signal::%s (not a valid member)", tostring(key)), 2)
	end,
})

return Signal
