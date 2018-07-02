local Lexer = require "hclua.lexer"

local function get_tokens(source)
   local lexer_state = Lexer.new_state(source)
   local tokens = {}

   repeat
      local token = {}
      token.token, token.token_value, token.line, token.column, token.offset = Lexer.next_token(lexer_state)
      tokens[#tokens+1] = token
   until token.token == "eof"

   return tokens
end

local function get_token_from_state(state)
   local token = {}
   token.token, token.token_value = Lexer.next_token(state)
   return token
end

local function get_token(source)
   local lexer_state = Lexer.new_state(source)
   return get_token_from_state(lexer_state)
end

local function maybe_error(lexer_state)
   local ok, err, line, column, _, end_column = Lexer.next_token(lexer_state)
   return not ok and {msg = err, line = line, column = column, end_column = end_column}
end

local function get_error(source)
   return maybe_error(Lexer.new_state(source))
end

local function get_last_error(source)
   local lexer_state = Lexer.new_state(source)
   local err

   repeat
      err = maybe_error(lexer_state)
   until err

   return err
end

local f100 = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

describe("Lexer", function()
   it("parses operators correctly", function()
      assert.same({ token = "[", token_value = nil }, get_token("["))
      assert.same({ token = "{", token_value = nil }, get_token("{"))
      assert.same({ token = ",", token_value = nil }, get_token(","))
      assert.same({ token = ".", token_value = nil }, get_token("."))
      assert.same({ token = "]", token_value = nil }, get_token("]"))
      assert.same({ token = "}", token_value = nil }, get_token("}"))
      assert.same({ token = "=", token_value = nil }, get_token("="))
      assert.same({ token = "+", token_value = nil }, get_token("+"))
      assert.same({ token = "-", token_value = nil }, get_token("-"))
   end)
   it("parses booleans correctly", function()
      assert.same({ token = "bool", token_value = "true" }, get_token("true"))
      assert.same({ token = "bool", token_value = "false" }, get_token("false"))
   end)
   it("parses identifiers correctly", function()
      assert.same({ token = "name", token_value = "a" }, get_token("a"))
      assert.same({ token = "name", token_value = "a0" }, get_token("a0"))
      assert.same({ token = "name", token_value = "foobar" }, get_token("foobar"))
      assert.same({ token = "name", token_value = "foo-bar" }, get_token("foo-bar"))
      assert.same({ token = "name", token_value = "foo.bar" }, get_token("foo.bar"))
      assert.same({ token = "name", token_value = "abc123" }, get_token("abc123"))
      assert.same({ token = "name", token_value = "LGTM" }, get_token("LGTM"))
      assert.same({ token = "name", token_value = "_" }, get_token("_"))
      assert.same({ token = "name", token_value = "_abc123" }, get_token("_abc123"))
      assert.same({ token = "name", token_value = "abc123_" }, get_token("abc123_"))
      assert.same({ token = "name", token_value = "_äöü" }, get_token("_äöü"))
      assert.same({ token = "name", token_value = "_本" }, get_token("_本"))
      assert.same({ token = "name", token_value = "a۰۱۸" }, get_token("a۰۱۸"))
      assert.same({ token = "name", token_value = "foo६४" }, get_token("foo६४"))
      assert.same({ token = "name", token_value = "bar９８７６" }, get_token("bar９８７６"))
   end)
   it("parses heredocs correctly", function()
      assert.same({ token = "heredoc", token_value = "<<EOF\nhello\nworld\nEOF" }, get_token("<<EOF\nhello\nworld\nEOF"))
      assert.same({ token = "heredoc", token_value = "<<EOF123\nhello\nworld\nEOF123" }, get_token("<<EOF123\nhello\nworld\nEOF123"))

      assert.same({line = 1, column = 1, end_column = 1, msg = "heredoc anchor not found"}, get_error("<<EOF"))
   end)
   it("parses strings correctly", function()
      assert.same({ token = "string", token_value = " " }, get_token("\" \")"))
      assert.same({ token = "string", token_value = "a" }, get_token("\"a\")"))
      assert.same({ token = "string", token_value = "本" }, get_token("\"本\")"))
      assert.same({ token = "string", token_value = "\a" }, get_token("\"\\a\")"))
      assert.same({ token = "string", token_value = "\b" }, get_token("\"\\b\")"))
      assert.same({ token = "string", token_value = "\f" }, get_token("\"\\f\")"))
      assert.same({ token = "string", token_value = "\n" }, get_token("\"\\n\")"))
      assert.same({ token = "string", token_value = "\r" }, get_token("\"\\r\")"))
      assert.same({ token = "string", token_value = "\t" }, get_token("\"\\t\")"))
      assert.same({ token = "string", token_value = "\v" }, get_token("\"\\v\")"))
      assert.same({ token = "string", token_value = "\"" }, get_token("\"\\\"\")"))
      --assert.same({ token = "string", token_value = "\000" }, get_token("\"\\000\")"))
      --assert.same({ token = "string", token_value = "\\777" }, get_token("\"\\777\")"))
      assert.same({ token = "string", token_value = "\x00" }, get_token("\"\\x00\")"))
      assert.same({ token = "string", token_value = "\xff" }, get_token("\"\\xff\")"))
      assert.same({ token = "string", token_value = "\u{0000}" }, get_token("\"\\u0000\")"))
      assert.same({ token = "string", token_value = "\u{fA16}" }, get_token("\"\\ufA16\")"))
      assert.same({ token = "string", token_value = "\u{0000}" }, get_token("\"\\U00000000\")"))
      assert.same({ token = "string", token_value = "\u{ffAB}" }, get_token("\"\\U0000ffAB\")"))
      assert.same({ token = "string", token_value = f100 }, get_token("\"" .. f100 ..  "\""))
   end)
   it("parses HIL correctly", function()
      assert.same({ token = "hil", token_value = '${file("foo")}'}, get_token('"${file("foo")}"'))
      assert.same({ token = "hil", token_value = '${file(\"foo\")}'}, get_token('"${file(\"foo\")}"'))
      assert.same({ token = "hil", token_value = '${file(\"{foo}\")}'}, get_token('"${file(\"{foo}\")}"'))
   end)
   it("parses integers correctly", function()
      assert.same({ token = "number", token_value = "0" }, get_token("0"))
      assert.same({ token = "number", token_value = "1" }, get_token("1"))
      assert.same({ token = "number", token_value = "9" }, get_token("9"))
      assert.same({ token = "number", token_value = "42" }, get_token("42"))
      assert.same({ token = "number", token_value = "1234567890" }, get_token("1234567890"))
      assert.same({ token = "number", token_value = "00" }, get_token("00"))
      assert.same({ token = "number", token_value = "01" }, get_token("01"))
      assert.same({ token = "number", token_value = "07" }, get_token("07"))
      assert.same({ token = "number", token_value = "042" }, get_token("042"))
      assert.same({ token = "number", token_value = "01234567" }, get_token("01234567"))
      assert.same({ token = "number", token_value = "0x0" }, get_token("0x0"))
      assert.same({ token = "number", token_value = "0x1" }, get_token("0x1"))
      assert.same({ token = "number", token_value = "0xf" }, get_token("0xf"))
      assert.same({ token = "number", token_value = "0x42" }, get_token("0x42"))
      assert.same({ token = "number", token_value = "0x123456789abcDEF" }, get_token("0x123456789abcDEF"))
      assert.same({ token = "number", token_value = "0x" .. f100 }, get_token("0x" .. f100))
      assert.same({ token = "number", token_value = "0X0" }, get_token("0X0"))
      assert.same({ token = "number", token_value = "0X1" }, get_token("0X1"))
      assert.same({ token = "number", token_value = "0XF" }, get_token("0XF"))
      assert.same({ token = "number", token_value = "0X42" }, get_token("0X42"))
      assert.same({ token = "number", token_value = "0X123456789abcDEF" }, get_token("0X123456789abcDEF"))
      assert.same({ token = "number", token_value = "0X" .. f100 }, get_token("0X" .. f100))
      assert.same({ token = "number", token_value = "-0" }, get_token("-0"))
      assert.same({ token = "number", token_value = "-1" }, get_token("-1"))
      assert.same({ token = "number", token_value = "-9" }, get_token("-9"))
      assert.same({ token = "number", token_value = "-42" }, get_token("-42"))
      assert.same({ token = "number", token_value = "-1234567890" }, get_token("-1234567890"))
      assert.same({ token = "number", token_value = "-00" }, get_token("-00"))
      assert.same({ token = "number", token_value = "-01" }, get_token("-01"))
      assert.same({ token = "number", token_value = "-07" }, get_token("-07"))
      assert.same({ token = "number", token_value = "-29" }, get_token("-29"))
      assert.same({ token = "number", token_value = "-042" }, get_token("-042"))
      assert.same({ token = "number", token_value = "-01234567" }, get_token("-01234567"))
      assert.same({ token = "number", token_value = "-0x0" }, get_token("-0x0"))
      assert.same({ token = "number", token_value = "-0x1" }, get_token("-0x1"))
      assert.same({ token = "number", token_value = "-0xf" }, get_token("-0xf"))
      assert.same({ token = "number", token_value = "-0x42" }, get_token("-0x42"))
      assert.same({ token = "number", token_value = "-0x123456789abcDEF" }, get_token("-0x123456789abcDEF"))
      assert.same({ token = "number", token_value = "-0x" .. f100 }, get_token("-0x" .. f100))
      assert.same({ token = "number", token_value = "-0X0" }, get_token("-0X0"))
      assert.same({ token = "number", token_value = "-0X1" }, get_token("-0X1"))
      assert.same({ token = "number", token_value = "-0XF" }, get_token("-0XF"))
      assert.same({ token = "number", token_value = "-0X42" }, get_token("-0X42"))
      assert.same({ token = "number", token_value = "-0X123456789abcDEF" }, get_token("-0X123456789abcDEF"))

      assert.same({ line = 1, column = 1, end_column = 1, msg = "malformed number"}, get_last_error("-0X"))
   end)
   it("parses floats correctly", function()
      assert.same({ token = "float", token_value = "0." }, get_token("0."))
      assert.same({ token = "float", token_value = "1." }, get_token("1."))
      assert.same({ token = "float", token_value = "42." }, get_token("42."))
      assert.same({ token = "float", token_value = "01234567890." }, get_token("01234567890."))
      assert.same({ token = "float", token_value = ".0" }, get_token(".0"))
      assert.same({ token = "float", token_value = ".1" }, get_token(".1"))
      assert.same({ token = "float", token_value = ".42" }, get_token(".42"))
      assert.same({ token = "float", token_value = ".0123456789" }, get_token(".0123456789"))
      assert.same({ token = "float", token_value = "0.0" }, get_token("0.0"))
      assert.same({ token = "float", token_value = "1.0" }, get_token("1.0"))
      assert.same({ token = "float", token_value = "42.0" }, get_token("42.0"))
      assert.same({ token = "float", token_value = "01234567890.0" }, get_token("01234567890.0"))
      assert.same({ token = "float", token_value = "0e0" }, get_token("0e0"))
      assert.same({ token = "float", token_value = "1e0" }, get_token("1e0"))
      assert.same({ token = "float", token_value = "42e0" }, get_token("42e0"))
      assert.same({ token = "float", token_value = "01234567890e0" }, get_token("01234567890e0"))
      assert.same({ token = "float", token_value = "0E0" }, get_token("0E0"))
      assert.same({ token = "float", token_value = "1E0" }, get_token("1E0"))
      assert.same({ token = "float", token_value = "42E0" }, get_token("42E0"))
      assert.same({ token = "float", token_value = "01234567890E0" }, get_token("01234567890E0"))
      assert.same({ token = "float", token_value = "0e+10" }, get_token("0e+10"))
      assert.same({ token = "float", token_value = "1e-10" }, get_token("1e-10"))
      assert.same({ token = "float", token_value = "42e+10" }, get_token("42e+10"))
      assert.same({ token = "float", token_value = "01234567890e-10" }, get_token("01234567890e-10"))
      assert.same({ token = "float", token_value = "0E+10" }, get_token("0E+10"))
      assert.same({ token = "float", token_value = "1E-10" }, get_token("1E-10"))
      assert.same({ token = "float", token_value = "42E+10" }, get_token("42E+10"))
      assert.same({ token = "float", token_value = "01234567890E-10" }, get_token("01234567890E-10"))
      assert.same({ token = "float", token_value = "01.8e0" }, get_token("01.8e0"))
      assert.same({ token = "float", token_value = "1.4e0" }, get_token("1.4e0"))
      assert.same({ token = "float", token_value = "42.2e0" }, get_token("42.2e0"))
      assert.same({ token = "float", token_value = "01234567890.12e0" }, get_token("01234567890.12e0"))
      assert.same({ token = "float", token_value = "0.E0" }, get_token("0.E0"))
      assert.same({ token = "float", token_value = "1.12E0" }, get_token("1.12E0"))
      assert.same({ token = "float", token_value = "42.123E0" }, get_token("42.123E0"))
      assert.same({ token = "float", token_value = "01234567890.213E0" }, get_token("01234567890.213E0"))
      assert.same({ token = "float", token_value = "0.2e+10" }, get_token("0.2e+10"))
      assert.same({ token = "float", token_value = "1.2e-10" }, get_token("1.2e-10"))
      assert.same({ token = "float", token_value = "42.54e+10" }, get_token("42.54e+10"))
      assert.same({ token = "float", token_value = "01234567890.98e-10" }, get_token("01234567890.98e-10"))
      assert.same({ token = "float", token_value = "0.1E+10" }, get_token("0.1E+10"))
      assert.same({ token = "float", token_value = "1.1E-10" }, get_token("1.1E-10"))
      assert.same({ token = "float", token_value = "42.1E+10" }, get_token("42.1E+10"))
      assert.same({ token = "float", token_value = "01234567890.1E-10" }, get_token("01234567890.1E-10"))
      assert.same({ token = "float", token_value = "-0.0" }, get_token("-0.0"))
      assert.same({ token = "float", token_value = "-1.0" }, get_token("-1.0"))
      assert.same({ token = "float", token_value = "-42.0" }, get_token("-42.0"))
      assert.same({ token = "float", token_value = "-01234567890.0" }, get_token("-01234567890.0"))
      assert.same({ token = "float", token_value = "-0e0" }, get_token("-0e0"))
      assert.same({ token = "float", token_value = "-1e0" }, get_token("-1e0"))
      assert.same({ token = "float", token_value = "-42e0" }, get_token("-42e0"))
      assert.same({ token = "float", token_value = "-01234567890e0" }, get_token("-01234567890e0"))
      assert.same({ token = "float", token_value = "-0E0" }, get_token("-0E0"))
      assert.same({ token = "float", token_value = "-1E0" }, get_token("-1E0"))
      assert.same({ token = "float", token_value = "-42E0" }, get_token("-42E0"))
      assert.same({ token = "float", token_value = "-01234567890E0" }, get_token("-01234567890E0"))
      assert.same({ token = "float", token_value = "-0e+10" }, get_token("-0e+10"))
      assert.same({ token = "float", token_value = "-1e-10" }, get_token("-1e-10"))
      assert.same({ token = "float", token_value = "-42e+10" }, get_token("-42e+10"))
      assert.same({ token = "float", token_value = "-01234567890e-10" }, get_token("-01234567890e-10"))
      assert.same({ token = "float", token_value = "-0E+10" }, get_token("-0E+10"))
      assert.same({ token = "float", token_value = "-1E-10" }, get_token("-1E-10"))
      assert.same({ token = "float", token_value = "-42E+10" }, get_token("-42E+10"))
      assert.same({ token = "float", token_value = "-01234567890E-10" }, get_token("-01234567890E-10"))
      assert.same({ token = "float", token_value = "-01.8e0" }, get_token("-01.8e0"))
      assert.same({ token = "float", token_value = "-1.4e0" }, get_token("-1.4e0"))
      assert.same({ token = "float", token_value = "-42.2e0" }, get_token("-42.2e0"))
      assert.same({ token = "float", token_value = "-01234567890.12e0" }, get_token("-01234567890.12e0"))
      assert.same({ token = "float", token_value = "-0.E0" }, get_token("-0.E0"))
      assert.same({ token = "float", token_value = "-1.12E0" }, get_token("-1.12E0"))
      assert.same({ token = "float", token_value = "-42.123E0" }, get_token("-42.123E0"))
      assert.same({ token = "float", token_value = "-01234567890.213E0" }, get_token("-01234567890.213E0"))
      assert.same({ token = "float", token_value = "-0.2e+10" }, get_token("-0.2e+10"))
      assert.same({ token = "float", token_value = "-1.2e-10" }, get_token("-1.2e-10"))
      assert.same({ token = "float", token_value = "-42.54e+10" }, get_token("-42.54e+10"))
      assert.same({ token = "float", token_value = "-01234567890.98e-10" }, get_token("-01234567890.98e-10"))
      assert.same({ token = "float", token_value = "-0.1E+10" }, get_token("-0.1E+10"))
      assert.same({ token = "float", token_value = "-1.1E-10" }, get_token("-1.1E-10"))
      assert.same({ token = "float", token_value = "-42.1E+10" }, get_token("-42.1E+10"))
      assert.same({ token = "float", token_value = "-01234567890.1E-10" }, get_token("-01234567890.1E-10"))
   end)

   it("parses a real world example", function()
      local source = [[# This comes from Terraform, as a test
	variable "foo" {
	    default = "bar"
	    description = "bar"
	}

	provider "aws" {
	  access_key = "foo"
	  secret_key = "${replace(var.foo, ".", "\\.")}"
	}

	resource "aws_security_group" "firewall" {
	    count = 5
	}

	resource aws_instance "web" {
	    ami = "${var.foo}"
	    security_groups = [
	        "foo",
	        "${aws_security_group.firewall.foo}"
	    ]

	    network_interface {
	        device_index = 0
	        description = <<EOF
Main interface
EOF
	    }

		network_interface {
	        device_index = 1
	        description = <<-EOF
			Outer text
				Indented text
			EOF
		}
	}]]
   local state = Lexer.new_state(source)
   assert.same({token = "comment", token_value = " This comes from Terraform, as a test"}, get_token_from_state(state))
   assert.same({token = "name",    token_value = "variable"}, get_token_from_state(state))
   assert.same({token = "string",  token_value = "foo"}, get_token_from_state(state))
   assert.same({token = "{",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "name",    token_value = "default"}, get_token_from_state(state))
   assert.same({token = "=",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "string",  token_value = "bar"}, get_token_from_state(state))
   assert.same({token = "name",    token_value = "description"}, get_token_from_state(state))
   assert.same({token = "=",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "string",  token_value = "bar"}, get_token_from_state(state))
   assert.same({token = "}",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "name",    token_value = "provider"}, get_token_from_state(state))
   assert.same({token = "string",  token_value = "aws"}, get_token_from_state(state))
   assert.same({token = "{",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "name",    token_value = "access_key"}, get_token_from_state(state))
   assert.same({token = "=",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "string",  token_value = "foo"}, get_token_from_state(state))
   assert.same({token = "name",    token_value = "secret_key"}, get_token_from_state(state))
   assert.same({token = "=",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "hil",     token_value = "${replace(var.foo, \".\", \"\\.\")}"}, get_token_from_state(state))
   assert.same({token = "}",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "name",    token_value = "resource"}, get_token_from_state(state))
   assert.same({token = "string",  token_value = "aws_security_group"}, get_token_from_state(state))
   assert.same({token = "string",  token_value = "firewall"}, get_token_from_state(state))
   assert.same({token = "{",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "name",    token_value = "count"}, get_token_from_state(state))
   assert.same({token = "=",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "number",  token_value = "5"}, get_token_from_state(state))
   assert.same({token = "}",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "name",    token_value = "resource"}, get_token_from_state(state))
   assert.same({token = "name",    token_value = "aws_instance"}, get_token_from_state(state))
   assert.same({token = "string",  token_value = "web"}, get_token_from_state(state))
   assert.same({token = "{",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "name",    token_value = "ami"}, get_token_from_state(state))
   assert.same({token = "=",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "hil",     token_value = "${var.foo}"}, get_token_from_state(state))
   assert.same({token = "name",    token_value = "security_groups"}, get_token_from_state(state))
   assert.same({token = "=",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "[",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "string",  token_value = "foo"}, get_token_from_state(state))
   assert.same({token = ",",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "hil",     token_value = "${aws_security_group.firewall.foo}"}, get_token_from_state(state))
   assert.same({token = "]",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "name",    token_value = "network_interface"}, get_token_from_state(state))
   assert.same({token = "{",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "name",    token_value = "device_index"}, get_token_from_state(state))
   assert.same({token = "=",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "number",  token_value = "0"}, get_token_from_state(state))
   assert.same({token = "name",    token_value = "description"}, get_token_from_state(state))
   assert.same({token = "=",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "heredoc", token_value = "<<EOF\nMain interface\nEOF\n"}, get_token_from_state(state))
   assert.same({token = "}",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "name",    token_value = "network_interface"}, get_token_from_state(state))
   assert.same({token = "{",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "name",    token_value = "device_index"}, get_token_from_state(state))
   assert.same({token = "=",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "number",  token_value = "1"}, get_token_from_state(state))
   assert.same({token = "name",    token_value = "description"}, get_token_from_state(state))
   assert.same({token = "=",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "heredoc", token_value = "<<-EOF\n\t\t\tOuter text\n\t\t\t\tIndented text\n\t\t\tEOF\n"}, get_token_from_state(state))
   assert.same({token = "}",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "}",       token_value = nil}, get_token_from_state(state))
   assert.same({token = "eof",     token_value = nil}, get_token_from_state(state))
   end)
end)
