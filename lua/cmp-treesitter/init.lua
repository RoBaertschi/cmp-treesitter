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

		--- Key for allLocals
		---@type {[string]: {node: TSNode}}
		local scopes = {}

		local row, col = unpack(params.context.cursor)
		local cursor_node = tree:root():named_descendant_for_range(row, col, row, col)
		if not cursor_node then
			return
		end

		---@type {[string]: {result: lsp.CompletionItem, node: TSNode}}
		local treeResults = {}

		for id, node, _, _ in query:iter_captures(tree:root(), params.context.bufnr) do
			-- if allLocals[node:id()] ~= nil then
			-- 	table.insert(allLocals[node:id()].capture_ids, id)
			-- else
			-- 	allLocals[node:id()] = {
			-- 		node = node,
			-- 		capture_ids = { id },
			-- 	}
			-- end

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
				treeResults[node:id()] = { result = result, node = node }
			end

			if name == "local.scope" then
				scopes[node:id()] = { node = node }
			end
			::continue::
		end

		---@type TSNode[]
		local cursor_parent_scopes = {}

		local node = cursor_node

		print(vim.inspect(scopes), node:type())
		while node do
			if scopes[node:id()] ~= nil then
				table.insert(cursor_parent_scopes, node)
			end

			-- cursor_parents[node:id()] = true
			local newNode = node:parent()
			if not newNode then
				break
			end
			node = newNode
		end

		local actualResults = {}

		---@param node TSNode
		local function recurse_tree(node, startScope)
			if scopes[node:id()] and node ~= startScope then
				-- print("skipped scope: " .. ts.get_node_text(node, params.context.bufnr))
				return
			end
			local result = treeResults[node:id()]
			if result then
				table.insert(actualResults, result.result)
			end

			for n in node:iter_children() do
				recurse_tree(n, startScope)
			end
		end

		for _, n in ipairs(cursor_parent_scopes) do
			recurse_tree(n, n)
		end

		for _, result in ipairs(actualResults) do
			table.insert(results, result)
		end
	end)

	callback(results)
end

return source
