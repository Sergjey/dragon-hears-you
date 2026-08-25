-- Shared module (ModuleScript). Available to both client and server.
local Hello = {}

function Hello.greet(name: string): string
	return `Hello, {name}!`
end

return Hello
