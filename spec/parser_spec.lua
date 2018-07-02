local Parser = require "hclua.parser"

local function strip_locations(ast)
   ast.location = nil
   ast.end_location = nil
   ast.end_column = nil
   ast.equals_location = nil
   ast.first_token = nil

   for i=1, #ast do
      if type(ast[i]) == "table" then
         strip_locations(ast[i])
      end
   end
end

local function get_ast(src)
   local ast = Parser.parse(src)
   assert.is_table(ast)
   strip_locations(ast)
   return ast
end

local function get_node(source)
   return get_ast(src)[1]
end

describe("Parser", function()
   it("parses empty", function()
       assert.same({tag = "Object"}, get_node(""))
   end)
end)
