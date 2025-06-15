local cmp = require("cmp")
local cmp_types = require("cmp.types")
local CompletionItemKind = cmp_types.lsp.CompletionItemKind
local ts = vim.treesitter
local tsq = vim.treesitter.query

local source = {}

source.new = function()
	return setmetatable({}, { __index = source })
end

---@return boolean
function source:is_available()
	return true
end

function source:get_debug_name()
	return "Treesitter"
end

---Invoke completion
---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
function source:complete(params, callback)
	local parser = ts.get_parser(params.context.bufnr)
	if not parser then
		callback(nil)
		return
	end

	---@type lsp.CompletionItem[]
	local results = {}

	parser:for_each_tree(function(tree, ltree)
		local query = tsq.get(ltree:lang(), "locals")

		if not query then
			return
		end

		for id, node, _, _ in query:iter_captures(tree:root(), params.context.bufnr) do
			local name = query.captures[id]
			if vim.startswith(name, "local.definition") then
				---@type lsp.CompletionItemKind|nil
				local kind

				if name == "local.definition.constant" then
					kind = CompletionItemKind.Constant
				elseif name == "local.definition.function" then
					kind = CompletionItemKind.Function
				elseif name == "local.definition.method" then
					kind = CompletionItemKind.Method
				elseif name == "local.definition.var" then
					kind = CompletionItemKind.Variable
				elseif name == "local.definition.parameter" then
					kind = CompletionItemKind.Variable
				elseif name == "local.definition.macro" then
					kind = CompletionItemKind.Function
				elseif name == "local.definition.type" then
					kind = CompletionItemKind.Class
				elseif name == "local.definition.field" then
					kind = CompletionItemKind.Field
				elseif name == "local.definition.enum" then
					kind = CompletionItemKind.Enum
				elseif name == "local.definition.namespace" then
					kind = CompletionItemKind.Module
				elseif name == "local.definition.import" then
					kind = CompletionItemKind.Module
				elseif name == "local.definition.associated" then
					goto continue
				end

				---@type lsp.CompletionItem
				local result = {
					label = ts.get_node_text(node, params.context.bufnr),
					labelDetails = {
						description = "Treesitter",
					},
					kind = kind,
				}
				table.insert(results, result)
			end
			::continue::
		end
	end)

	callback(results)
end

return source
