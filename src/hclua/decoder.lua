local inspect = require "inspect"

local Decoder = {}

local sfind = string.find
local slen = string.len
local ssub = string.sub
local sgsub = string.gsub
local sgmatch = string.gmatch
local tinsert = table.insert

local function decode_error(ast_node, msg)
   error("decode error: " .. msg)
end

local function check_tag(ast_node, tag)
   if ast_node.tag ~= tag then
      decode_error(ast_node, "expected " .. tag)
   end
end

local decode_object, decode_value

local decode_handlers = {}

decode_handlers["Boolean"] = function(ast_node)
   local value = ast_node[1]

   if value == "true" then
      return true
   elseif value == "false" then
      return false
   end

   decode_error(ast_node, "Unknown boolean value: " .. value)
end

decode_handlers["Number"] = function(ast_node)
   local value = ast_node[1]
   return tonumber(value)
end

decode_handlers["Float"] = decode_handlers["Number"]

decode_handlers["String"] = function(ast_node)
   return ast_node[1]
end

decode_handlers["Name"] = decode_handlers["String"]
decode_handlers["HIL"] = decode_handlers["String"]
decode_handlers["List"] = function(ast_node)
   local list = {}

   for i=1,#ast_node do
      list[i] = decode_value(ast_node[i])
   end

   return list
end

local function join_strings(list, delimiter)
   local len = #list
   if len == 0 then
      return ""
   end
   local result = list[1]
   for i = 2, len do
      result = result .. delimiter .. list[i]
   end
   return result
end

decode_handlers["Heredoc"] = function(ast_node)
   local text = ast_node[1]

   -- We need to find the end of the marker
   local anchor_end = sfind(text, "\n")
   if anchor_end == nil then
      decode_error(ast_node, "heredoc doesn't contain newline")
   end

   local content_begin = anchor_end + 1
   local content_end = slen(text) - content_begin - (anchor_end - 2)

   local unindent = ssub(text, 3, 3) == "-"

   -- We can optimize if the heredoc isn't marked for indentation
   if not unindent then
      return ssub(text, content_begin, content_begin + content_end)
   end

   -- We need to unindent each line based on the indentation level of the marker
   local content = ssub(text, content_begin, content_begin + content_end + 1)
   local lines = {}
   for line in sgmatch(content, "([^\n]*)\n?") do
      tinsert(lines, line)
   end

   local whitespace_prefix = lines[#lines]
   print("Text: '" .. content .. "'")
   print("Prefix: '" .. whitespace_prefix .. "'")

   local indented = true
   for _, line in pairs(lines) do
      if slen(whitespace_prefix) > slen(line) then
         indented = false
         break
      end

      local prefix_found = sfind(line, "^(" .. whitespace_prefix .. ")") ~= nil

      if not prefix_found then
         indented = false
         break
      end
   end

   -- If all lines are not at least as indented as the terminating mark, return the
   -- heredoc as is, but trim the leading space from the marker on the final line.
   if not indented then
      local function trim_right(str) return sgmatch(str, "(.-)%s*$") end
      return trim_right(content)
   end

   local unindented_lines = {}
   for i=1, #lines do
      if i == #lines then
         unindented_lines[i] = ""
         break
      end

      local line = lines[i]
      unindented_lines[i] = sgsub(line, "^(" .. whitespace_prefix .. ")", "")
      print("Line: '" .. unindented_lines[i] .. "'")
   end

   return join_strings(unindented_lines, "\n")
end

decode_handlers["Object"] = function(ast_node)
   return decode_object(ast_node)
end

function decode_value(ast_node)
   local decode_handler = decode_handlers[ast_node.tag]

   if not decode_handler then
      decode_error(ast_node, "Unknown literal: " .. ast_node.tag)
   end

   return decode_handler(ast_node)
end

local function is_list(state)
   return state[1] ~= nil
end

local function decode_object_pair(ast_node, object)
   check_tag(ast_node, "Pair")
   local value = decode_value(ast_node[2])

   local keys = ast_node[1]
   check_tag(keys, "Keys")
   local nested = {}
   if #keys > 1 then
      for i=2,#keys-1 do
         local key = keys[i][1]
         nested[key] = {}
         nested = nested[key]
      end
      nested[keys[#keys][1]] = value
      value = nested
   end

   local first_key = keys[1][1]
   local existing = object[first_key]

   if existing then
   else
      object[first_key] = value
   end
end

function decode_object(ast_node)
   local object = {}

   for i=1,#ast_node do
      local pair = ast_node[i]
      decode_object_pair(pair, object)
   end

   return object
end

function Decoder.decode(ast)
   check_tag(ast, "Object")
   return decode_object(ast)
end

return Decoder
