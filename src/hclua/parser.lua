local Lexer = require "hclua.lexer"

local Parser = {}

function Parser.new_state(src)
   return {
      lexer = Lexer.new_state(src),
      code_lines = {}, -- Set of line numbers containing code.
      line_endings = {}, -- Maps line numbers to "comment", "string", or nil based on whether
                         -- the line ending is within a token.
      comments = {}, -- Array of {comment = string, location = location}.
      hanging_semicolons = {} -- Array of locations of semicolons not following a statement.
   }
end

local function location(state)
   return {
      line = state.line,
      column = state.column,
      offset = state.offset
   }
end

function Parser.syntax_error(loc, end_column, msg, prev_loc, prev_end_column)
   error(loc .. " " ..  end_column .. " " ..  msg .. " " ..  prev_loc .. " " ..  prev_end_column)
end

function Parser.token_body_or_line(state)
   return state.lexer.src:sub(state.offset, state.lexer.offset - 1):match("^[^\r\n]*")
end

function Parser.mark_line_endings(state, first_line, last_line, token_type)
   for line = first_line, last_line - 1 do
      state.line_endings[line] = token_type
   end
end

function Parser.skip_token(state)
   while true do
      local err_end_column
      state.token, state.token_value, state.line,
         state.column, state.offset, err_end_column = Lexer.next_token(state.lexer)

      if not state.token then
         Parser.syntax_error(state, err_end_column, state.token_value)
      elseif state.token == "comment" then
         state.comments[#state.comments+1] = {
            contents = state.token_value,
            location = location(state),
            end_column = state.column + #Parser.token_body_or_line(state) - 1
         }

         Parser.mark_line_endings(state, state.line, state.lexer.line, "comment")
      else
         if state.token ~= "eof" then
            Parser.mark_line_endings(state, state.line, state.lexer.line, "string")
            state.code_lines[state.line] = true
            state.code_lines[state.lexer.line] = true
         end

         break
      end
   end
end

return Parser
