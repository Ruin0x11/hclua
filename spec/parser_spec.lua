local Parser = require "hclua.parser"
local inspect = require "inspect"

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
   assert:set_parameter("TableFormatLevel", 99)

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
                       {tag = "Keys",
                        {"x", tag = "Name"}},
                       {"true", tag = "Boolean"}},
                      {tag = "Pair",
                       {tag = "Keys",
                        {"y", tag = "Name"}},
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
                       {tag = "Keys",
                        {"x", tag = "Name"}},
                       {"1", tag = "Number"}},
                      {tag = "Pair",
                       {tag = "Keys",
                        {"y", tag = "Name"}},
                       {"0", tag = "Number"}},
                      {tag = "Pair",
                       {tag = "Keys",
                       {"z", tag = "Name"}},
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
                       {tag = "Keys", {"x", tag = "Name"}},
                       {"1.0", tag = "Float"}},
                      {tag = "Pair",
                       {tag = "Keys", {"y", tag = "Name"}},
                       {".5", tag = "Float"}},
                      {tag = "Pair",
                       {tag = "Keys", {"z", tag = "Name"}},
                       {"-124.12", tag = "Float"}},
                      {tag = "Pair",
                       {tag = "Keys", {"w", tag = "Name"}},
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
                       {tag = "Keys", {"x", tag = "Name"}},
                       {"", tag = "String"}}},
         get_ast([[
x = ""
]]))
   end)

   it("parses double quoted string", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {tag = "Keys", {"x", tag = "Name"}},
                       {"hoge", tag = "String"}},
                      {tag = "Pair",
                       {tag = "Keys", {"y", tag = "Name"}},
                       {"hoge \"fuga\" hoge", tag = "String"}},
                      {tag = "Pair",
                       {tag = "Keys", {"z", tag = "Name"}},
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
                       {tag = "Keys", {"x", tag = "Name"}},
                       {"ｴｰﾃﾙ病", tag = "String"}}},
         get_ast([[
x = "ｴｰﾃﾙ病"
]]))
   end)

   it("parses identifiers", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {tag = "Keys", {"x", tag = "Name"}},
                       {"hoge", tag = "Name"}},
                      {tag = "Pair",
                       {tag = "Keys", {"y", tag = "Name"}},
                       {"hoge.fuga", tag = "Name"}},
                      {tag = "Pair",
                       {tag = "Keys", {"z", tag = "Name"}},
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
                       {tag = "Keys", {"x", tag = "Name"}},
                       {"${hoge}", tag = "HIL"}},
                      {tag = "Pair",
                       {tag = "Keys", {"y", tag = "Name"}},
                       {"${hoge {\"fuga\"} hoge}", tag = "HIL"}},
                      {tag = "Pair",
                       {tag = "Keys", {"z", tag = "Name"}},
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
                       {tag = "Keys", {"hoge", tag = "Name"}},
                       {"<<EOF\nHello\nWorld\nEOF\n", tag = "Heredoc"}},
                      {tag = "Pair",
                       {tag = "Keys", {"fuga", tag = "Name"}},
                       {"<<FOO123\n\thoge\n\tfuga\nFOO123\n", tag = "Heredoc"}},
                      {tag = "Pair",
                       {tag = "Keys", {"piyo", tag = "Name"}},
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
                       {tag = "Keys", {"hoge", tag = "Name"}},
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
                       {tag = "Keys", {"x", tag = "Name"}},
                       {"", tag = "String"}}},
            get_ast([[
x = ''
]]))
   end)

   it("parses single quoted string", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {tag = "Keys", {"x", tag = "Name"}},
                       {"foo bar \"foo bar\"", tag = "String"}}},
            get_ast([[
x = 'foo bar "foo bar"'
]]))
   end)

   it("parses list", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {tag = "Keys", {"x", tag = "Name"}},
                       {tag = "List",
                        {"1", tag = "Number"},
                        {"2", tag = "Number"},
                        {"3", tag = "Number"}}},
                      {tag = "Pair",
                       {tag = "Keys", {"y", tag = "Name"}},
                       {tag = "List"}},
                      {tag = "Pair",
                       {tag = "Keys", {"z", tag = "Name"}},
                       {tag = "List",
                        {"", tag = "String"},
                        {"", tag = "String"}}},
                      {tag = "Pair",
                       {tag = "Keys", {"w", tag = "Name"}},
                       {tag = "List",
                        {"1", tag = "Number"},
                        {"string", tag = "String"},
                        {"<<EOF\nheredoc contents\nEOF\n", tag = "Heredoc"}}}
                     },
            get_ast([[
x = [1, 2, 3]
y = []
z = ["", "", ]
w = [1, "string", <<EOF
heredoc contents
EOF]
]]))
   end)

   it("parses list of maps", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {tag = "Keys", {"foo", tag = "Name"}},
                       {tag = "List",
                        {tag = "Object",
                         {tag = "Pair",
                          {tag = "Keys", {"key", tag = "Name"}},
                          {"hoge", tag = "String"}}},
                        {tag = "Object",
                         {tag = "Pair",
                          {tag = "Keys", {"key", tag = "Name"}},
                          {"fuga", tag = "String"}},
                         {tag = "Pair",
                          {tag = "Keys", {"key2", tag = "Name"}},
                          {"piyo", tag = "String"}}}}}},
         get_ast([[
foo = [
  {key = "hoge"},
  {key = "fuga", key2 = "piyo"},
]
]]))
   end)

   it("parses leading comment in list", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {tag = "Keys", {"foo", tag = "Name"}},
                       {tag = "List",
                        {"1", tag = "Number"},
                        {"2", tag = "Number"},
                        {"3", tag = "Number"}}}},
         get_ast([[
foo = [
1,
# bar
2,
3,
]
]]))
   end)

   it("parses empty object type", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {tag = "Keys", {"foo", tag = "Name"}},
                       {tag = "Object"}}},
         get_ast([[
foo = {}
]]))
   end)

   it("parses object type with two fields", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {tag = "Keys", {"foo", tag = "Name"}},
                       {tag = "Object",
                        {tag = "Pair",
                         {tag = "Keys", {"bar", tag = "Name"}},
                         {"hoge", tag = "String"}},
                        {tag = "Pair",
                         {tag = "Keys", {"baz", tag = "Name"}},
                         {tag = "List",
                          {"piyo", tag = "String"}}}}}},
         get_ast([[
foo = {
    bar = "hoge"
    baz = ["piyo"]
}
]]))
   end)

   it("parses object with nested empty map", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {tag = "Keys", {"foo", tag = "Name"}},
                       {tag = "Object",
                        {tag = "Pair",
                         {tag = "Keys", {"bar", tag = "Name"}},
                         {tag = "Object"}}}}},
         get_ast([[
foo = {
    bar = {}
}
]]))
   end)

   it("parses object with nested empty map and value", function()
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {tag = "Keys", {"foo", tag = "Name"}},
                       {tag = "Object",
                        {tag = "Pair",
                         {tag = "Keys", {"bar", tag = "Name"}},
                         {tag = "Object"}},
                        {tag = "Pair",
                         {tag = "Keys", {"foo", tag = "Name"}},
                         {"true", tag = "Boolean"}}}}},
         get_ast([[
foo = {
    bar = {}
    foo = true
}
]]))
   end)

   it("parses object keys", function()
         assert.same({tag = "Object", {tag = "Pair",
 {tag = "Keys", {"foo", tag = "Name"}}, {tag = "Object"}}}, get_ast([[foo {}]]))
         assert.same({tag = "Object", {tag = "Pair",
 {tag = "Keys", {"foo", tag = "Name"}}, {tag = "Object"}}}, get_ast([[foo = {}]]))
         assert.same({tag = "Object", {tag = "Pair",
 {tag = "Keys", {"foo", tag = "Name"}}, {"bar", tag = "Name"}}},
            get_ast([[foo = bar]]))
         assert.same({tag = "Object", {tag = "Pair",
 {tag = "Keys", {"foo", tag = "Name"}}, {"123", tag = "Number"}}},
            get_ast([[foo = 123]]))
         assert.same({tag = "Object", {tag = "Pair",
 {tag = "Keys", {"foo", tag = "Name"}}, {"${var.bar}", tag = "HIL"}}},
            get_ast([[foo = "${var.bar}]]))
         assert.same({tag = "Object", {tag = "Pair",
 {tag = "Keys", {"foo", tag = "String"}}, {tag = "Object"}}},
            get_ast([["foo" {}]]))
         assert.same({tag = "Object", {tag = "Pair",
 {tag = "Keys", {"foo", tag = "String"}}, {"${var.bar}", tag = "HIL"}}},
            get_ast([["foo" = "${var.bar}]]))
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {tag = "Keys", {"foo", tag = "Name"}, {"bar", tag = "Name"}},
                       {tag = "Object"}}},
            get_ast([[foo bar {}]]))
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {tag = "Keys", {"foo", tag = "Name"}, {"bar", tag = "String"}},
                       {tag = "Object"}}},
            get_ast([[foo "bar" {}]]))
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {tag = "Keys", {"foo", tag = "String"}, {"bar", tag = "Name"}},
                       {tag = "Object"}}},
            get_ast([["foo" bar {}]]))
         assert.same({tag = "Object",
                      {tag = "Pair",
                       {tag = "Keys", {"foo", tag = "Name"}, {"bar", tag = "Name"}, {"baz", tag = "Name"}},
                       {tag = "Object"}}},
            get_ast([[foo bar baz {}]]))
   end)

   it("fails parsing invalid keys", function()
         assert.same({line = 1, column = 5, end_column = 6, msg = "found invalid token when parsing object keys near '12'"},
            get_error("foo 12 {}"))
         assert.same({line = 1, column = 9, end_column = 9, msg = "nested object expected: { near '='"},
            get_error("foo bar = {}"))
         assert.same({line = 1, column = 5, end_column = 5, msg = "found invalid token when parsing object keys near '['"},
            get_error("foo []"))
         assert.same({line = 1, column = 1, end_column = 2, msg = "found invalid token when parsing object keys near '12'"},
            get_error("12 {}"))
   end)

   it("parses nested assignment to string and ident", function()
         assert.same({tag = 'Object',
                      {tag = 'Pair',
                       {tag = 'Keys',
                        {'foo', tag = 'Name' },
                        {'bar', tag = 'String' },
                        {'baz', tag = 'Name' }},
                       {tag = 'Object',
                        {tag = 'Pair',
                         {tag = 'Keys',
                          {'hoge', tag = 'String' }},
                         {'fuge', tag = 'Name' }}}},
                      {tag = 'Pair',
                       {tag = 'Keys',
                        {'foo', tag = 'String' },
                        {'bar', tag = 'Name' },
                        {'baz', tag = 'Name' }},
                       {tag = 'Object',
                        {tag = 'Pair',
                         {tag = 'Keys',
                          {'hogera', tag = 'Name' }},
                         {'fugera', tag = 'String' }}}}},
            get_ast([[
foo "bar" baz { "hoge" = fuge }
"foo" bar baz { hogera = "fugera" }
]]))
   end)

   it("parses nested assignment with object", function()
         assert.same({tag = 'Object',
 {tag = 'Pair',
  {tag = 'Keys',
   {'foo', tag = 'Name' }},
  {'6', tag = 'Number' }},
 {tag = 'Pair',
  {tag = 'Keys',
   {'foo', tag = 'Name' },
   {'bar', tag = 'String' }},
  {tag = 'Object' ,
   {tag = 'Pair',
    {tag = 'Keys',
     {'hoge', tag = 'Name' }},
    {'piyo', tag = 'String' }}}}},
         get_ast([[
foo = 6
foo "bar" { hoge = "piyo" }
]]))
   end)

   it("parses comment group", function()
         assert.same({tag = "Object"}, get_ast("# Hello\n# World\n"))
         assert.same({tag = "Object"}, get_ast("# Hello\r\n# Windows"))
   end)

   it("parses comment after line", function()
         assert.same({tag = "Object", {tag = "Pair",
                                       {tag = "Keys",
                                        {"x", tag = "Name"}},
                                       {"1", tag = "Number"}}},
            get_ast("x = 1 # hogehoge"))
   end)

   it("parses official HCL tests", function()
         local files = {
            {"assign_colon.hcl", {line = 2,
                                  column = 7,
                                  end_column = 7,
                                  msg = "found invalid token when parsing object keys near ':'"}},
            {"comment.hcl", nil},
            {"comment_crlf.hcl", nil},
            {"comment_lastline.hcl", nil},
            {"comment_single.hcl", nil},
            {"empty.hcl", nil},
            {"list_comma.hcl", nil},
            {"multiple.hcl", nil},
            {"object_list_comma.hcl", nil},
            {"structure.hcl", nil},
            {"structure_basic.hcl", nil},
            {"structure_empty.hcl", nil},
            {"complex.hcl", nil},
            {"complex_crlf.hcl", nil},
            {"types.hcl", nil},
            {"array_comment.hcl", nil},
            {"array_comment_2.hcl", {line = 4,
                                     column = 5,
                                     end_column = 47,
                                     msg = "error parsing list, expected comma or list end near '\"${path.module}/scripts/install-haproxy.sh\"'"}},
            {"missing_braces.hcl", {line = 3,
                                    column = 22,
                                    end_column = 22,
                                    msg = "found invalid token when parsing object keys near '$'"}},
            {"unterminated_object.hcl", {line = 3,
                                         column = 1,
                                         end_column = 1,
                                         msg = "expected end of object list near <eof>"}},
            {"unterminated_object_2.hcl", {line = 7,
                                           column = 1,
                                           end_column = 1,
                                           msg = "expected end of object list near <eof>"}},
            {"key_without_value.hcl", {line = 2,
                                       column = 1,
                                       end_column = 1,
                                       msg = "end of file reached near <eof>"}},
            {"object_key_without_value.hcl", {line = 3,
                                              column = 1,
                                              end_column = 1,
                                              msg = "found invalid token when parsing object keys near '}'"}},
            {"object_key_assign_without_value.hcl", {line = 3,
                                                     column = 1,
                                                     end_column = 1,
                                                     msg = "Unknown token near '}'"}},
            {"object_key_assign_without_value2.hcl", {line = 4,
                                                      column = 1,
                                                      end_column = 1,
                                                      msg = "Unknown token near '}'"}},
            {"object_key_assign_without_value3.hcl", {line = 3,
                                                      column = 7,
                                                      end_column = 7,
                                                      msg = "expected to find at least one object key near '='"}},
            {"git_crypt.hcl", {line = 1,
                               column = 1,
                               end_column = 1,
                               msg = "found invalid token when parsing object keys near '\\0'"}}}

         local function read_all(file)
            local f = assert(io.open(file, "rb"))
            local content = f:read("*all")
            f:close()
            return content
         end

         for _, pair in pairs(files) do
            local filename, should_fail = table.unpack(pair)
            local src = read_all("spec/test_fixtures/parser/" .. filename)
            local ok, err = pcall(Parser.parse, src)
            if ok then
               err = nil
            end
            assert.same(should_fail, err, "Expected objects to be the same: " .. filename)
         end
   end)
end)

