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

local function get_comments(src)
   return (select(2, Parser.parse(src)))
end

local function get_error(src)
   local ok, err = pcall(Parser.parse, src)
   assert.is_false(ok)
   return err
end

describe("Parser", function()
   it("parses empty", function()
       assert.same({tag = "Object"}, get_ast(""))
   end)
   it("parses single-line comments", function()
         assert.same({
               {contents = " hogehoge",   location = {line = 1, column = 1, offset = 1}, end_column = 10},
               {contents = " fuga hoge",  location = {line = 2, column = 1, offset = 12}, end_column = 12},
                     },
            get_comments([[
# hogehoge
// fuga hoge
 ]]))
   end)
   it("parses multi-line comments", function()
         assert.same({
               {contents = " fugahoge ",   location = {line = 1, column = 1, offset = 1}, end_column = 14},
               {contents = "\n * hoge\n ",  location = {line = 2, column = 1, offset = 16}, end_column = 2},
               {contents = "\n * hoge\n\nfuga\n ",  location = {line = 5, column = 1, offset = 33}, end_column = 2},
                     },
            get_comments([[
/* fugahoge */
/*
 * hoge
 */


/*
 * hoge

fuga
 */
 ]]))
   end)
   it("parses bool", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {"x", tag = "Name"},
                       {"true", tag = "Boolean"}},
                      {tag = "Pair",
                       {"y", tag = "Name"},
                       {"false", tag = "Boolean"}}
                     },
            get_ast([[
x = true
y = false
]]))
   end)
   it("parses int", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {"x", tag = "Name"},
                       {"1", tag = "Number"}},
                      {tag = "Pair",
                       {"y", tag = "Name"},
                       {"0", tag = "Number"}},
                      {tag = "Pair",
                       {"z", tag = "Name"},
                       {"-1", tag = "Number"}}
                     },
         get_ast([[
x = 1
y = 0
z = -1
]]))
   end)
   it("parses float", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {"x", tag = "Name"},
                       {"1.0", tag = "Float"}},
                      {tag = "Pair",
                       {"y", tag = "Name"},
                       {".5", tag = "Float"}},
                      {tag = "Pair",
                       {"z", tag = "Name"},
                       {"-124.12", tag = "Float"}},
                      {tag = "Pair",
                       {"w", tag = "Name"},
                       {"-0.524", tag = "Float"}}
                     },
         get_ast([[
x = 1.0
y = .5
z = -124.12
w = -0.524
]]))
   end)
   it("parses empty double quoted string", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {"x", tag = "Name"},
                       {"", tag = "String"}}},
         get_ast([[
x = ""
]]))
   end)
   it("parses double quoted string", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {"x", tag = "Name"},
                       {"hoge", tag = "String"}},
                      {tag = "Pair",
                       {"y", tag = "Name"},
                       {"hoge \"fuga\" hoge", tag = "String"}},
                      {tag = "Pair",
                       {"z", tag = "Name"},
                       {"??", tag = "String"}}},
         get_ast([[
x = "hoge"
y = "hoge \"fuga\" hoge"
z = "\u003F\U0000003F"
]]))
   end)
   it("parses halfwidth katakana string", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {"x", tag = "Name"},
                       {"ｴｰﾃﾙ病", tag = "String"}}},
         get_ast([[
x = "ｴｰﾃﾙ病"
]]))
   end)
   it("parses identifiers", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {"x", tag = "Name"},
                       {"hoge", tag = "Name"}},
                      {tag = "Pair",
                       {"y", tag = "Name"},
                       {"hoge.fuga", tag = "Name"}},
                      {tag = "Pair",
                       {"z", tag = "Name"},
                       {"_000.hoge::fuga-piyo", tag = "Name"}}},
            get_ast([[
x = hoge
y = hoge.fuga
z = _000.hoge::fuga-piyo
]]))
   end)
   it("parses HIL", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {"x", tag = "Name"},
                       {"${hoge}", tag = "HIL"}},
                      {tag = "Pair",
                       {"y", tag = "Name"},
                       {"${hoge {\"fuga\"} hoge}", tag = "HIL"}},
                      {tag = "Pair",
                       {"z", tag = "Name"},
                       {"${name(hoge)}", tag = "HIL"}}},
            get_ast([[
x = "${hoge}"
y = "${hoge {\"fuga\"} hoge}"
z = "${name(hoge)}"
]]))
   end)
   it("fails parsing invalid HIL", function()
         assert.same({line = 1, column = 5, end_column = 5, msg = "Unknown token near '$'"}, get_error("x = ${hoge}"))
         assert.same({line = 1, column = 5, end_column = 5, msg = "expected terminating brace"}, get_error("x = \"${{hoge}\""))
         assert.same({line = 1, column = 5, end_column = 5, msg = "unfinished string"}, get_error("x = \"${{hoge}\"\n"))
   end)
   it("parses heredocs", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {"hoge", tag = "Name"},
                       {"<<EOF\nHello\nWorld\nEOF\n", tag = "Heredoc"}},
                      {tag = "Pair",
                       {"fuga", tag = "Name"},
                       {"<<FOO123\n\thoge\n\tfuga\nFOO123\n", tag = "Heredoc"}},
                      {tag = "Pair",
                       {"piyo", tag = "Name"},
                       {"<<-EOF\n\t\t\tOuter text\n\t\t\t\tIndented text\n\t\t\tEOF\n", tag = "Heredoc"}}},
            get_ast([[
hoge = <<EOF
Hello
World
EOF
fuga = <<FOO123
	hoge
	fuga
FOO123
piyo = <<-EOF
			Outer text
				Indented text
			EOF
]]))
   end)
   it("parses indented heredocs", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {"hoge", tag = "Name"},
                       {"<<-EOF\n    Hello\n      World\n    EOF\n", tag = "Heredoc"}}},
            get_ast([[
hoge = <<-EOF
    Hello
      World
    EOF
]]))
   end)
   it("parses empty single quoted string", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {"x", tag = "Name"},
                       {"", tag = "String"}}},
            get_ast([[
x = ''
]]))
   end)
   it("parses single quoted string", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {"x", tag = "Name"},
                       {"foo bar \"foo bar\"", tag = "String"}}},
            get_ast([[
x = 'foo bar "foo bar"'
]]))
   end)
   it("parses list", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {"x", tag = "Name"},
                       {tag = "List"}},
                      {tag = "Pair",
                       {"y", tag = "Name"},
                       {tag = "List"}},
                      {tag = "Pair",
                       {"z", tag = "Name"},
                       {tag = "List"}},
                      {tag = "Pair",
                       {"w", tag = "Name"},
                       {tag = "List"}}
                     },
            get_ast([[
x = [1, 2, 3]
y = []
z = ["", "", ]
w = [1, "string", <<EOF\nheredoc contents\nEOF]
]]))
   end)
end)
