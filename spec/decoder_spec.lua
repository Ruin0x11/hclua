local Decoder = require "hclua.decoder"
local Parser = require "hclua.parser"
local Util = require "hclua.util"

local function get(src)
   local ast = Parser.parse(src)
   assert.is_table(ast)
   local decoded = Decoder.decode(ast)
   assert.is_table(decoded)
   return decoded
end

local function get_from_file(filename)
   print("Decoding file: " .. filename)
   return get(Util.read_to_string("spec/test_fixtures/decoder/" .. filename))
end

describe("Decoder", function()
   assert:set_parameter("TableFormatLevel", 99)

   it("decodes empty", function()
       assert.same({}, get(""))
   end)

   it("decodes comments", function()
       assert.same({}, get([[
# hogehoge
# fuga hoge
]]))
   end)

   it("decodes bool", function()
       assert.same({x = true, y = false}, get([[
x = true
y = false
]]))
   end)

   it("decodes int", function()
       assert.same({x = 1, y = 0, z = -1}, get([[
x = 1
y = 0
z = -1
]]))
   end)

   it("decodes float", function()
       assert.same({x = 1.0, y = 0.5, z = -124.12, w = -0.524}, get([[
x = 1.0
y = .5
z = -124.12
w = -0.524
]]))
   end)

   it("decodes empty double quoted string", function()
       assert.same({x = ""}, get([[
x = ""
]]))
   end)

   it("decodes double quoted string", function()
       assert.same({x = "hoge", y = "hoge \"fuga\" hoge", z = "??"}, get([[
x = "hoge"
y = "hoge \"fuga\" hoge"
z = "\u003F\U0000003F"
]]))
   end)

   it("decodes halfwidth katakana string", function()
         assert.same({x = "ｴｰﾃﾙ病"}, get([[
x = "ｴｰﾃﾙ病"
]]))
   end)

   it("decodes identifiers", function()
         assert.same({x = "hoge", y = "hoge.fuga", z = "_000.hoge::fuga-piyo"}, get([[
x = hoge
y = hoge.fuga
z = _000.hoge::fuga-piyo
]]))
   end)

   it("decodes HIL", function()
         assert.same({x = "${hoge}", y = "${hoge {\"fuga\"} hoge}", z = "${name(hoge)}"}, get([[
x = "${hoge}"
y = "${hoge {\"fuga\"} hoge}"
z = "${name(hoge)}"
]]))
   end)

   it("decodes heredocs", function()
         assert.same({hoge = "Hello\nWorld\n"}, get("hoge = <<EOF\nHello\nWorld\nEOF"))
         assert.same({fuga = "\thoge\n\tfuga\n"}, get("fuga = <<FOO123\n\thoge\n\tfuga\nFOO123\n"))
         assert.same({piyo = "Outer text\n\tIndented text\n"},
            get("piyo = <<-EOF\n\t\t\tOuter text\n\t\t\t\tIndented text\n\t\t\tEOF\n"))
   end)

   it("decodes indented heredoc", function()
         assert.same({hoge = "Hello\n  World\n"}, get("hoge = <<-EOF\n    Hello\n      World\n    EOF\n"))
   end)

   it("decodes empty single quoted string", function()
         assert.same({x = ""}, get("x = ''"))
   end)

   it("decodes single quoted string", function()
         assert.same({x = "foo bar \"foo bar\""}, get("x = 'foo bar \"foo bar\"'"))
   end)

   it("decodes list", function()
         assert.same({x = {1, 2, 3},
                      y = {},
                      z = {"", ""},
                      w = {1, "string", "heredoc contents\n"}},
            get([[
x = [1, 2, 3]
y = []
z = ["", "", ]
w = [1, "string", <<EOF
heredoc contents
EOF]
]]))
   end)

   it("decodes list of maps", function()
         assert.same({foo = {{key = "hoge"}, {key = "fuga", key2 = "piyo"}}},
         get([[
foo = [
  {key = "hoge"},
  {key = "fuga", key2 = "piyo"},
]
]]))
   end)

   it("decodes leading comment in list", function()
         assert.same({foo = {1, 2, 3}}, get([[
foo = [
1,
# bar
2,
3,
],
]]))
   end)

   it("decodes comment in list", function()
         assert.same({foo = {1, 2, 3}}, get([[
foo = [
1,
2, # bar
3,
],
]]))
   end)

   it("decodes empty object type", function()
         assert.same({foo = {}}, get([[
foo = {}
]]))
   end)

   it("decodes simple object type", function()
         assert.same({foo = {bar = "hoge"}}, get([[
foo = {
    bar = "hoge"
}
]]))
   end)

   it("decodes object type with two fields", function()
         assert.same({foo = {bar = "hoge", baz = {"piyo"}}}, get([[
foo = {
    bar = "hoge"
    baz = ["piyo"]
}
]]))
   end)

   it("decodes object type nested empty map", function()
         assert.same({foo = {bar = {}}}, get([[
foo = {
    bar = {}
}
]]))
   end)

   it("decodes object type nested empty map and value", function()
         assert.same({foo = {bar = {}, foo = true}}, get([[
foo = {
    bar = {}
    foo = true
}
]]))
   end)

   it("decodes object keys", function()
         assert.same({foo = {}}, get([[foo {}]]))
         assert.same({foo = {}}, get([[foo = {}]]))
         assert.same({foo = "bar"}, get([[foo = bar]]))
         assert.same({foo = 123}, get([[foo = 123]]))
         assert.same({foo = "${var.bar}"}, get([[foo = "${var.bar}]]))
         assert.same({foo = {}}, get([["foo" {}]]))
         assert.same({foo = {}}, get([["foo" = {}]]))
         assert.same({foo = "${var.bar}"}, get([["foo" = "${var.bar}"]]))
         assert.same({foo = {bar = {}}}, get([[foo bar {}]]))
         assert.same({foo = {bar = {}}}, get([[foo "bar" {}]]))
         assert.same({foo = {bar = {}}}, get([["foo" bar {}]]))
         assert.same({foo = {bar = {baz = {}}}}, get([[foo bar baz {}]]))
   end)

   it("decodes nested keys", function()
         assert.same({foo = {bar = {baz = {hoge = "piyo"}}}}, get([[foo "bar" baz { hoge = "piyo" }]]))
   end)

-- TODO nested merging
--    it("decodes multiple same nested keys", function()
--          assert.same({foo = {bar = {
--                                 {hoge = "piyo", hogera = "fugera"},
--                                 {hoge = "fuge"},
--                                 {hoge = "baz"}}}},
--             get([[
-- foo bar { hoge = "piyo", hogera = "fugera" }
-- foo bar { hoge = "fuge" }
-- foo bar { hoge = "baz" }
-- ]]))
--          assert.same({foo = {bar = {baz = {hoge = "piyo", hogera = "fugera", baz = "quux"}}}},
--             get([[
-- foo bar { hoge = "piyo", hogera = "fugera" }
-- foo bar { baz = "quux" }
-- ]]))
--    end)

   it("decodes multiple nested keys", function()
         assert.same({foo = {
                         {bar = {baz = {hoge = "piyo"}}},
                         {bar = {hoge = "piyo"}},
                         {hoge = "piyo"},
                         {hogera = {hoge = "piyo"}}}},
            get([[
foo "bar" baz { hoge = "piyo" }
foo "bar" { hoge = "piyo" }
foo { hoge = "piyo" }
foo hogera { hoge = "piyo" }
]]))
   end)

   it("decodes nested assignment to string and ident", function()
         assert.same({foo = {
                         {bar = {baz = {hoge = "fuge"}}},
                         {bar = {baz = {hogera = "fugera"}}}}},
            get([[
foo "bar" baz { "hoge" = fuge }
"foo" bar baz { hogera = "fugera" }
]]))
   end)

   it("decodes nested assignment with object", function()
         assert.same({foo = {6, {bar = {hoge = "piyo"}}}},
            get([[
foo = 6
foo "bar" { hoge = "piyo" }
]]))
   end)

   it("decodes non-ident keys", function()
       assert.same({["本"] = "foo"}, get([[
"本" = foo
]]))
   end)

   it("decodes official HCL tests", function()
            assert.same({foo = "bar", bar = "${file(\"bing/bong.txt\")}"},
             get_from_file("basic.hcl"))
            assert.same({foo = "bar", bar =  "${file(\"bing/bong.txt\")}", ["foo-bar"] = "baz"},
             get_from_file("basic_squish.hcl"))
            assert.same({resource = {foo = {}}},
             get_from_file("empty.hcl"))
            assert.same({regularvar = "Should work", ["map.key1"] = "Value", ["map.key2"] = "Other value"},
             get_from_file("tfvars.hcl"))
            assert.same({foo = "bar\"baz\\n",
              qux = "back\\slash",
              bar = "new\nline",
              qax = "slash\\:colon",
              nested = "${HH\\:mm\\:ss}",
              nestedquotes = "${\"\"stringwrappedinquotes\"\"}"},
             get_from_file("escape.hcl"))
            assert.same({a = 1.02, b = 2},
             get_from_file("float.hcl"))
            assert.same({multiline_literal_with_hil = "${hello\n  world}"},
             get_from_file("multiline_literal_with_hil.hcl"))
            assert.same({foo = "bar\nbaz\n"},
             get_from_file("multiline.hcl"))
            assert.same({foo = "  bar\n  baz\n"},
             get_from_file("multiline_indented.hcl"))
            assert.same({foo = "  baz\n    bar\n      foo\n"},
             get_from_file("multiline_no_hanging_indent.hcl"))
            assert.same({foo = "bar\nbaz\n", key = "value"},
             get_from_file("multiline_no_eof.hcl"))
            assert.same({a = 1e-10, b = 1e+10, c = 1e10, d = 1.2e-10, e = 1.2e+10, f = 1.2e10},
             get_from_file("scientific.hcl"))
            assert.same({name = "terraform-test-app", config_vars = {FOO = "bar"}},
             get_from_file("terraform_heroku.hcl"))
            assert.same({foo = {bar = {key = 12}, baz = {key = 7}}},
             get_from_file("structure_multi.hcl"))
            assert.same({foo = {{"foo"}, {"bar"}}},
             get_from_file("list_of_lists.hcl"))
            assert.same({foo = {
                 {somekey1 = "someval1"},
                 {somekey2 = "someval2", someextrakey = "someextraval"}}},
             get_from_file("list_of_maps.hcl"))
            assert.same({resource = {{foo = {{bar = {}}}}}},
             get_from_file("assign_deep.hcl"))
            assert.same({bar = "value"},
             get_from_file("nested_block_comment.hcl"))
            assert.same({output = {one = [[${replace(var.sub_domain, ".", "\.")}]],
                        two = [[${replace(var.sub_domain, ".", "\\.")}]],
                        many = [[${replace(var.sub_domain, ".", "\\\\.")}]],
             }},
             get_from_file("escape_backslash.hcl"))
            assert.same({path = {policy = "write", permissions = {bool = {false}}}},
             get_from_file("object_with_bool.hcl"))
            assert.same({variable = {{foo = {default = "bar", description = "bar"},
                           amis = {default = {east = "foo"}}},
                 {foo = {hoge = "fuga"}}}},
             get_from_file("list_of_nested_object_lists.hcl"))
-- TODO nested merging
--            assert.same({resource = {
--                            aws_db_instance = {
--                                  mysqldb = {
--                                     allocated_storage = 100,
--                                     identifier = "${var.environment}-mysqldb"
--                                  },
--                                  ["mysqldb-readonly"] = {
--                                     allocated_storage = 100,
--                                     identifier = "${var.environment}-mysqldb-readonly"
--                                  }
--                        }}},
--               get_from_file("multiple_resources.hcl"))
            assert.same({bar = {{a = "alpha", b = "bravo"}, {a = "alpha", b = "bravo"}}},
               get_from_file("merge_objects.hcl"))
            assert.same({bar = {a = "alpha", b = "bravo", c = "charlie",
                                x = "x-ray", y = "yankee", z = "zulu"}},
               get_from_file("merge_objects2.hcl"))
            assert.same({top = {{a = "a", b = "b"}, {b = "b", c = "c"}}},
               get_from_file("structure_list2.hcl"))
            assert.same({foo = "bar\nbaz\n"},
               get_from_file("tab_heredoc.hcl"))
            assert.same({version = 1,
                         variable = {
                            {one = {a = 1, b = 2}},
                            {one = {a = 3, b = 4}},
                            {two = {bw = {"big", "array"}, hk = 12}}
                        }},
               get_from_file("multiple_merge.hcl"))
   end)
end)
