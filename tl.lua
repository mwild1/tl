local assert = require('compat53.module').assert or assert; local io = require('compat53.module').io or io; local ipairs = require('compat53.module').ipairs or ipairs; local load = require('compat53.module').load or load; local math = require('compat53.module').math or math; local os = require('compat53.module').os or os; local package = require('compat53.module').package or package; local pairs = require('compat53.module').pairs or pairs; local string = require('compat53.module').string or string; local table = require('compat53.module').table or table; local _tl_table_unpack = unpack or table.unpack; local tl = {
   ["process"] = nil,
   ["type_check"] = nil,
}







local inspect = function(x)
   return tostring(x)
end

local keywords = {
   ["and"] = true,
   ["break"] = true,
   ["do"] = true,
   ["else"] = true,
   ["elseif"] = true,
   ["end"] = true,
   ["false"] = true,
   ["for"] = true,
   ["function"] = true,
   ["goto"] = true,
   ["if"] = true,
   ["in"] = true,
   ["local"] = true,
   ["nil"] = true,
   ["not"] = true,
   ["or"] = true,
   ["repeat"] = true,
   ["return"] = true,
   ["then"] = true,
   ["true"] = true,
   ["until"] = true,
   ["while"] = true,


}

local TokenKind = {}











local Token = {}







local lex_word_start = {}
for c = string.byte("a"), string.byte("z") do
   lex_word_start[string.char(c)] = true
end
for c = string.byte("A"), string.byte("Z") do
   lex_word_start[string.char(c)] = true
end
lex_word_start["_"] = true

local lex_word = {}
for c = string.byte("a"), string.byte("z") do
   lex_word[string.char(c)] = true
end
for c = string.byte("A"), string.byte("Z") do
   lex_word[string.char(c)] = true
end
for c = string.byte("0"), string.byte("9") do
   lex_word[string.char(c)] = true
end
lex_word["_"] = true

local lex_decimal_start = {}
for c = string.byte("1"), string.byte("9") do
   lex_decimal_start[string.char(c)] = true
end

local lex_decimals = {}
for c = string.byte("0"), string.byte("9") do
   lex_decimals[string.char(c)] = true
end

local lex_hexadecimals = {}
for c = string.byte("0"), string.byte("9") do
   lex_hexadecimals[string.char(c)] = true
end
for c = string.byte("a"), string.byte("f") do
   lex_hexadecimals[string.char(c)] = true
end
for c = string.byte("A"), string.byte("F") do
   lex_hexadecimals[string.char(c)] = true
end

local lex_char_symbols = {}
for _, c in ipairs({ [1] = "[", [2] = "]", [3] = "(", [4] = ")", [5] = "{", [6] = "}", [7] = ",", [8] = ":", [9] = "#", [10] = "`", [11] = ";", }) do
   lex_char_symbols[c] = true
end

local lex_op_start = {}
for _, c in ipairs({ [1] = "+", [2] = "*", [3] = "/", [4] = "|", [5] = "&", [6] = "%", [7] = "^", }) do
   lex_op_start[c] = true
end

local lex_space = {}
for _, c in ipairs({ [1] = " ", [2] = "\t", [3] = "\v", [4] = "\n", [5] = "\r", }) do
   lex_space[c] = true
end

local LexState = {}































function tl.lex(input)
   local tokens = {}

   local state = "start"
   local fwd = true
   local y = 1
   local x = 0
   local i = 0
   local lc_open_lvl = 0
   local lc_close_lvl = 0
   local ls_open_lvl = 0
   local ls_close_lvl = 0
   local errs = {}

   local tx
   local ty
   local ti
   local in_token = false

   local function begin_token()
      tx = x
      ty = y
      ti = i
      in_token = true
   end

   local function end_token(kind, last, t)
      local tk = t or input:sub(ti, last or i) or ""
      if keywords[tk] then
         kind = "keyword"
      end
      table.insert(tokens, {
         ["x"] = tx,
         ["y"] = ty,
         ["i"] = ti,
         ["tk"] = tk,
         ["kind"] = kind,
      })
      in_token = false
   end

   local function drop_token()
      in_token = false
   end

   while i <= #input do
      if fwd then
         i = i + 1
         if i > #input then
            break
         end
      end

      local c = input:sub(i, i)

      if fwd then
         if c == "\n" then
            y = y + 1
            x = 0
         else
            x = x + 1
         end
      else
         fwd = true
      end

      if state == "start" then
         if input:sub(1, 2) == "#!" then
            i = input:find("\n")
            if not i then
               break
            end
            c = "\n"
            y = 2
            x = 0
         end
         state = "any"
      end

      if state == "any" then
         if c == "-" then
            state = "maybecomment"
            begin_token()
         elseif c == "." then
            state = "maybedotdot"
            begin_token()
         elseif c == "\"" then
            state = "dblquote_string"
            begin_token()
         elseif c == "'" then
            state = "singlequote_string"
            begin_token()
         elseif lex_word_start[c] then
            state = "identifier"
            begin_token()
         elseif c == "0" then
            state = "decimal_or_hex"
            begin_token()
         elseif lex_decimal_start[c] then
            state = "decimal_number"
            begin_token()
         elseif c == "<" then
            state = "lt"
            begin_token()
         elseif c == ">" then
            state = "gt"
            begin_token()
         elseif c == "=" or c == "~" then
            state = "maybeequals"
            begin_token()
         elseif c == "[" then
            state = "maybelongstring"
            begin_token()
         elseif lex_char_symbols[c] then
            begin_token()
            end_token(c)
         elseif lex_op_start[c] then
            begin_token()
            end_token("op")
         elseif lex_space[c] then

 else
            begin_token()
            end_token("$invalid$")
            table.insert(errs, tokens[#tokens])
         end
      elseif state == "maybecomment" then
         if c == "-" then
            state = "maybecomment2"
         else
            end_token("op", nil, "-")
            fwd = false
            state = "any"
         end
      elseif state == "maybecomment2" then
         if c == "[" then
            state = "maybelongcomment"
         else
            fwd = false
            state = "comment"
            drop_token()
         end
      elseif state == "maybelongcomment" then
         if c == "[" then
            state = "longcomment"
         elseif c == "=" then
            lc_open_lvl = lc_open_lvl + 1
         else
            fwd = false
            state = "comment"
            drop_token()
            lc_open_lvl = 0
         end
      elseif state == "longcomment" then
         if c == "]" then
            state = "maybelongcommentend"
         end
      elseif state == "maybelongcommentend" then
         if c == "]" and lc_close_lvl == lc_open_lvl then
            drop_token()
            state = "any"
            lc_open_lvl = 0
            lc_close_lvl = 0
         elseif c == "=" then
            lc_close_lvl = lc_close_lvl + 1
         else
            state = "longcomment"
            lc_close_lvl = 0
         end
      elseif state == "dblquote_string" then
         if c == "\\" then
            state = "escape_dblquote_string"
         elseif c == "\"" then
            end_token("string")
            state = "any"
         end
      elseif state == "escape_dblquote_string" then
         state = "dblquote_string"
      elseif state == "singlequote_string" then
         if c == "\\" then
            state = "escape_singlequote_string"
         elseif c == "'" then
            end_token("string")
            state = "any"
         end
      elseif state == "escape_singlequote_string" then
         state = "singlequote_string"
      elseif state == "maybeequals" then
         if c == "=" then
            end_token("op")
            state = "any"
         else
            end_token("op", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "lt" then
         if c == "=" or c == "<" then
            end_token("op")
            state = "any"
         else
            end_token("op", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "gt" then
         if c == "=" or c == ">" then
            end_token("op")
            state = "any"
         else
            end_token("op", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "maybelongstring" then
         if c == "[" then
            state = "longstring"
         elseif c == "=" then
            ls_open_lvl = ls_open_lvl + 1
         else
            end_token("[", i - 1)
            fwd = false
            state = "any"
            ls_open_lvl = 0
         end
      elseif state == "longstring" then
         if c == "]" then
            state = "maybelongstringend"
         end
      elseif state == "maybelongstringend" then
         if c == "]" and ls_close_lvl == ls_open_lvl then
            end_token("string")
            state = "any"
            ls_open_lvl = 0
            ls_close_lvl = 0
         elseif c == "=" then
            ls_close_lvl = ls_close_lvl + 1
         else
            state = "longstring"
            ls_close_lvl = 0
         end
      elseif state == "maybedotdot" then
         if c == "." then
            state = "maybedotdotdot"
         elseif lex_decimals[c] then
            state = "decimal_float"
         else
            end_token(".", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "maybedotdotdot" then
         if c == "." then
            end_token("...")
            state = "any"
         else
            end_token("op", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "comment" then
         if c == "\n" then
            state = "any"
         end
      elseif state == "identifier" then
         if not lex_word[c] then
            end_token("identifier", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "decimal_or_hex" then
         if c == "x" or c == "X" then
            state = "hex_number"
         elseif c == "e" or c == "E" then
            state = "power_sign"
         elseif lex_decimals[c] then
            state = "decimal_number"
         elseif c == "." then
            state = "decimal_float"
         else
            end_token("number", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "hex_number" then
         if c == "." then
            state = "hex_float"
         elseif c == "p" or c == "P" then
            state = "power_sign"
         elseif not lex_hexadecimals[c] then
            end_token("number", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "hex_float" then
         if c == "p" or c == "P" then
            state = "power_sign"
         elseif not lex_hexadecimals[c] then
            end_token("number", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "decimal_number" then
         if c == "." then
            state = "decimal_float"
         elseif c == "e" or c == "E" then
            state = "power_sign"
         elseif not lex_decimals[c] then
            end_token("number", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "decimal_float" then
         if c == "e" or c == "E" then
            state = "power_sign"
         elseif not lex_decimals[c] then
            end_token("number", i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "power_sign" then
         if c == "-" or c == "+" then
            state = "power"
         elseif lex_decimals[c] then
            state = "power"
         else
            end_token("$invalid$")
            table.insert(errs, tokens[#tokens])
            state = "any"
         end
      elseif state == "power" then
         if not lex_decimals[c] then
            end_token("number", i - 1)
            fwd = false
            state = "any"
         end
      end
   end

   local terminals = {
      ["identifier"] = "identifier",
      ["decimal_or_hex"] = "number",
      ["decimal_number"] = "number",
      ["decimal_float"] = "number",
      ["hex_number"] = "number",
      ["hex_float"] = "number",
      ["power"] = "number",
   }

   if in_token then
      if terminals[state] then
         end_token(terminals[state], i - 1)
      else
         drop_token()
      end
   end

   return tokens, (#errs > 0) and errs
end





local add_space = {
   ["word:keyword"] = true,
   ["word:word"] = true,
   ["word:string"] = true,
   ["word:="] = true,
   ["word:op"] = true,

   ["keyword:word"] = true,
   ["keyword:keyword"] = true,
   ["keyword:string"] = true,
   ["keyword:number"] = true,
   ["keyword:="] = true,
   ["keyword:op"] = true,
   ["keyword:{"] = true,
   ["keyword:("] = true,
   ["keyword:#"] = true,

   ["=:word"] = true,
   ["=:keyword"] = true,
   ["=:string"] = true,
   ["=:number"] = true,
   ["=:{"] = true,
   ["=:("] = true,
   ["op:("] = true,
   ["op:{"] = true,
   ["op:#"] = true,

   [",:word"] = true,
   [",:keyword"] = true,
   [",:string"] = true,
   [",:{"] = true,

   ["):op"] = true,
   ["):word"] = true,
   ["):keyword"] = true,

   ["op:string"] = true,
   ["op:number"] = true,
   ["op:word"] = true,
   ["op:keyword"] = true,

   ["]:word"] = true,
   ["]:keyword"] = true,
   ["]:="] = true,
   ["]:op"] = true,

   ["string:op"] = true,
   ["string:word"] = true,
   ["string:keyword"] = true,

   ["number:word"] = true,
   ["number:keyword"] = true,
}

local should_unindent = {
   ["end"] = true,
   ["elseif"] = true,
   ["else"] = true,
   ["}"] = true,
}

local should_indent = {
   ["{"] = true,
   ["for"] = true,
   ["if"] = true,
   ["while"] = true,
   ["elseif"] = true,
   ["else"] = true,
   ["function"] = true,
}

function tl.pretty_print_tokens(tokens)
   local y = 1
   local out = {}
   local indent = 0
   local newline = false
   local kind = ""
   for _, t in ipairs(tokens) do
      while t.y > y do
         table.insert(out, "\n")
         y = y + 1
         newline = true
         kind = ""
      end
      if should_unindent[t.tk] then
         indent = indent - 1
         if indent < 0 then
            indent = 0
         end
      end
      if newline then
         for _ = 1, indent do
            table.insert(out, "   ")
         end
         newline = false
      end
      if should_indent[t.tk] then
         indent = indent + 1
      end
      if add_space[(kind or "") .. ":" .. t.kind] then
         table.insert(out, " ")
      end
      table.insert(out, t.tk)
      kind = t.kind or ""
   end
   return table.concat(out)
end





local ParseError = {}






local TypeKind = {}






local TypeName = {}

























local Type = {}































































local Operator = {}







local NodeKind = {}







































local Node = {}























































local parse_expression
local parse_statements
local parse_type_list
local parse_argument_list
local parse_argument_type_list
local parse_type


local function fail(tokens, i, errs, msg)
   if not tokens[i] then
      local eof = tokens[#tokens]
      table.insert(errs, { ["y"] = eof.y, ["x"] = eof.x, ["msg"] = msg or "unexpected end of file", })
      return #tokens
   end
   table.insert(errs, { ["y"] = tokens[i].y, ["x"] = tokens[i].x, ["msg"] = msg or "syntax error", })
   return math.min(#tokens, i + 1)
end

local function verify_tk(tokens, i, errs, tk)
   if tokens[i].tk == tk then
      return i + 1
   end
   return fail(tokens, i, errs, "syntax error, expected '" .. tk .. "'")
end

local function new_node(tokens, i, kind)
   local t = tokens[i]
   return { ["y"] = t.y, ["x"] = t.x, ["tk"] = t.tk, ["kind"] = kind or t.kind, }
end

local function new_type(tokens, i, kind)
   local t = tokens[i]
   return { ["y"] = t.y, ["x"] = t.x, ["tk"] = t.tk, ["kind"] = kind or t.kind, }
end

local function verify_kind(tokens, i, errs, kind, node_kind)
   if tokens[i].kind == kind then
      return i + 1, new_node(tokens, i, node_kind)
   end
   return fail(tokens, i, errs, "syntax error, expected " .. kind)
end

local function parse_table_item(tokens, i, errs, n)
   local node = new_node(tokens, i, "table_item")
   if tokens[i].kind == "$EOF$" then
      return fail(tokens, i, errs)
   end

   if tokens[i].tk == "[" then
      i = i + 1
      i, node.key = parse_expression(tokens, i, errs)
      i = verify_tk(tokens, i, errs, "]")
      i = verify_tk(tokens, i, errs, "=")
      i, node.value = parse_expression(tokens, i, errs)
      return i, node, n
   elseif tokens[i].kind == "identifier" and tokens[i + 1].tk == "=" then
      i, node.key = verify_kind(tokens, i, errs, "identifier", "string")
      node.key.conststr = node.key.tk
      node.key.tk = '"' .. node.key.tk .. '"'
      i = verify_tk(tokens, i, errs, "=")
      i, node.value = parse_expression(tokens, i, errs)
      return i, node, n
   elseif tokens[i].kind == "identifier" and tokens[i + 1].tk == ":" then
      local orig_i = i
      local try_errs = {}
      i, node.key = verify_kind(tokens, i, try_errs, "identifier", "string")
      node.key.conststr = node.key.tk
      node.key.tk = '"' .. node.key.tk .. '"'
      i = verify_tk(tokens, i, try_errs, ":")
      i, node.decltype = parse_type(tokens, i, try_errs)
      if node.decltype and tokens[i].tk == "=" then
         i = verify_tk(tokens, i, try_errs, "=")
         i, node.value = parse_expression(tokens, i, try_errs)
         if node.value then
            for _, e in ipairs(try_errs) do
               table.insert(errs, e)
            end
            return i, node, n
         end
      end

      node.decltype = nil
      i = orig_i
   end

   node.key = new_node(tokens, i, "number")
   node.key.constnum = n
   node.key.tk = tostring(n)
   i, node.value = parse_expression(tokens, i, errs)
   return i, node, n + 1
end

local ParseItem = {}

local function parse_list(tokens, i, errs, list, close, is_sep, parse_item)
   local n = 1
   while tokens[i].kind ~= "$EOF$" do
      if close[tokens[i].tk] then
         (list).yend = tokens[i].y
         break
      end
      local item
      i, item, n = parse_item(tokens, i, errs, n)
      table.insert(list, item)
      if tokens[i].tk == "," then
         i = i + 1
         if is_sep and close[tokens[i].tk] then
            return fail(tokens, i, errs)
         end
      end
   end
   return i, list
end

local function parse_bracket_list(tokens, i, errs, list, open, close, is_sep, parse_item)
   i = verify_tk(tokens, i, errs, open)
   i = parse_list(tokens, i, errs, list, { [close] = true, }, is_sep, parse_item)
   i = verify_tk(tokens, i, errs, close)
   return i, list
end

local function parse_table_literal(tokens, i, errs)
   local node = new_node(tokens, i, "table_literal")
   return parse_bracket_list(tokens, i, errs, node, "{", "}", false, parse_table_item)
end

local function parse_trying_list(tokens, i, errs, list, parse_item)
   local tryerrs = {}
   local tryi, item = parse_item(tokens, i, tryerrs)
   if not item then
      return i, list
   end
   for _, e in ipairs(tryerrs) do
      table.insert(errs, e)
   end
   i = tryi
   table.insert(list, item)
   if tokens[i].tk == "," then
      while tokens[i].tk == "," do
         i = i + 1
         i, item = parse_item(tokens, i, errs)
         table.insert(list, item)
      end
   end
   return i, list
end

local function parse_function_type(tokens, i, errs)
   i = i + 1
   local node = {
      ["y"] = tokens[i - 1].y,
      ["x"] = tokens[i - 1].x,
      ["kind"] = "typedecl",
      ["typename"] = "function",
      ["args"] = {},
      ["rets"] = {},
   }
   if tokens[i].tk == "(" then
      i, node.args = parse_argument_type_list(tokens, i, errs)
      i, node.rets = parse_type_list(tokens, i, errs)
   else
      node.args = { [1] = { ["typename"] = "any", ["is_va"] = true, }, }
      node.rets = { [1] = { ["typename"] = "any", ["is_va"] = true, }, }
   end
   return i, node
end

local function parse_typevar_type(tokens, i, errs)
   i = i + 1
   i = verify_kind(tokens, i, errs, "identifier")
   return i, {
      ["y"] = tokens[i - 2].y,
      ["x"] = tokens[i - 2].x,
      ["kind"] = "typedecl",
      ["typename"] = "typevar",
      ["typevar"] = "`" .. tokens[i - 1].tk,
   }
end

local function parse_typevar_list(tokens, i, errs)
   local typ = new_type(tokens, i, "typevar_list")
   return parse_bracket_list(tokens, i, errs, typ, "<", ">", true, parse_typevar_type)
end

local function parse_typeval_list(tokens, i, errs)
   local typ = new_type(tokens, i, "typeval_list")
   return parse_bracket_list(tokens, i, errs, typ, "<", ">", true, parse_type)
end

parse_type = function(tokens, i, errs)
   if tokens[i].tk == "string" or
      tokens[i].tk == "boolean" or
      tokens[i].tk == "nil" or
      tokens[i].tk == "number" then
      return i + 1, {
         ["y"] = tokens[i].y,
         ["x"] = tokens[i].x,
         ["kind"] = "typedecl",
         ["typename"] = tokens[i].tk,
      }
   elseif tokens[i].tk == "table" then
      local typ = new_type(tokens, i, "typedecl")
      typ.typename = "map"
      typ.keys = { ["typename"] = "any", }
      typ.values = { ["typename"] = "any", }
      return i + 1, typ
   elseif tokens[i].tk == "function" then
      return parse_function_type(tokens, i, errs)
   elseif tokens[i].tk == "{" then
      i = i + 1
      local decl = new_type(tokens, i, "typedecl")
      local t
      i, t = parse_type(tokens, i, errs)
      if tokens[i].tk == "}" then
         decl.typename = "array"
         decl.elements = t
         decl.yend = tokens[i].y
         i = verify_tk(tokens, i, errs, "}")
      elseif tokens[i].tk == ":" then
         decl.typename = "map"
         i = i + 1
         decl.keys = t
         i, decl.values = parse_type(tokens, i, errs)
         decl.yend = tokens[i].y
         i = verify_tk(tokens, i, errs, "}")
      end
      return i, decl
   elseif tokens[i].tk == "`" then
      return parse_typevar_type(tokens, i, errs)
   elseif tokens[i].kind == "identifier" then
      local typ = new_type(tokens, i, "typedecl")
      typ.typename = "nominal"
      typ.name = tokens[i].tk
      i = i + 1
      if tokens[i].tk == "<" then
         i, typ.typevals = parse_typeval_list(tokens, i, errs)
      end
      return i, typ
   end
   return fail(tokens, i, errs)
end

parse_type_list = function(tokens, i, errs, open)
   local list = new_type(tokens, i, "type_list")
   if tokens[i].tk == (open or ":") then
      i = i + 1
      local optional_paren = false
      if tokens[i - 1].tk == ":" then
         if tokens[i].tk == "(" then
            optional_paren = true
            i = i + 1
         end
      end
      i = parse_trying_list(tokens, i, errs, list, parse_type)
      if optional_paren then
         i = verify_tk(tokens, i, errs, ")")
      end
   end
   return i, list
end

local function parse_function_args_rets_body(tokens, i, errs, node)
   i, node.args = parse_argument_list(tokens, i, errs)
   i, node.rets = parse_type_list(tokens, i, errs)
   i, node.body = parse_statements(tokens, i, errs)
   node.yend = tokens[i].y
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_function_value(tokens, i, errs)
   local node = new_node(tokens, i, "function")
   i = verify_tk(tokens, i, errs, "function")
   return parse_function_args_rets_body(tokens, i, errs, node)
end

local function unquote(str)
   local f = str:sub(1, 1)
   if f == '"' or f == "'" then
      return str:sub(2, -2)
   end
   f = str:match("^%[=*%[")
   local l = #f + 1
   return str:sub(l, -l)
end

local function parse_literal(tokens, i, errs)
   if tokens[i].tk == "{" then
      return parse_table_literal(tokens, i, errs)
   elseif tokens[i].kind == "..." then
      return verify_kind(tokens, i, errs, "...")
   elseif tokens[i].kind == "string" then
      local tk = unquote(tokens[i].tk)
      local node
      i, node = verify_kind(tokens, i, errs, "string")
      node.conststr = tk
      return i, node
   elseif tokens[i].kind == "identifier" then
      return verify_kind(tokens, i, errs, "identifier", "variable")
   elseif tokens[i].kind == "number" then
      local n = tonumber(tokens[i].tk)
      local node
      i, node = verify_kind(tokens, i, errs, "number")
      node.constnum = n
      return i, node
   elseif tokens[i].tk == "true" then
      return verify_kind(tokens, i, errs, "keyword", "boolean")
   elseif tokens[i].tk == "false" then
      return verify_kind(tokens, i, errs, "keyword", "boolean")
   elseif tokens[i].tk == "nil" then
      return verify_kind(tokens, i, errs, "keyword", "nil")
   elseif tokens[i].tk == "function" then
      return parse_function_value(tokens, i, errs)
   end
   return fail(tokens, i, errs)
end

do
   local precedences = {
      [1] = {
         ["not"] = 11,
         ["#"] = 11,
         ["-"] = 11,
         ["~"] = 11,
      },
      [2] = {
         ["or"] = 1,
         ["and"] = 2,
         ["<"] = 3,
         [">"] = 3,
         ["<="] = 3,
         [">="] = 3,
         ["~="] = 3,
         ["=="] = 3,
         ["|"] = 4,
         ["~"] = 5,
         ["&"] = 6,
         ["<<"] = 7,
         [">>"] = 7,
         [".."] = 8,
         ["+"] = 8,
         ["-"] = 9,
         ["*"] = 10,
         ["/"] = 10,
         ["//"] = 10,
         ["%"] = 10,
         ["^"] = 12,
         ["as"] = 50,
         ["@funcall"] = 100,
         ["@index"] = 100,
         ["."] = 100,
         [":"] = 100,
      },
   }

   local is_right_assoc = {
      ["^"] = true,
      [".."] = true,
   }

   local function new_operator(tk, arity, op)
      op = op or tk.tk
      return { ["y"] = tk.y, ["x"] = tk.x, ["arity"] = arity, ["op"] = op, ["prec"] = precedences[arity][op], }
   end

   local E

   local function P(tokens, i, errs)
      if tokens[i].kind == "$EOF$" then
         return i
      end
      local e1
      local t1 = tokens[i]
      if precedences[1][tokens[i].tk] ~= nil then
         local op = new_operator(tokens[i], 1)
         i = i + 1
         i, e1 = P(tokens, i, errs)
         e1 = { ["y"] = t1.y, ["x"] = t1.x, ["kind"] = "op", ["op"] = op, ["e1"] = e1, }
      elseif tokens[i].tk == "(" then
         i = i + 1
         i, e1 = parse_expression(tokens, i, errs)
         e1 = { ["y"] = t1.y, ["x"] = t1.x, ["kind"] = "paren", ["e1"] = e1, }
         i = verify_tk(tokens, i, errs, ")")
      else
         i, e1 = parse_literal(tokens, i, errs)
      end

      while true do
         if tokens[i].kind == "string" or tokens[i].kind == "{" then
            local op = new_operator(tokens[i], 2, "@funcall")
            local args = new_node(tokens, i, "expression_list")
            local arg
            if tokens[i].kind == "string" then
               arg = new_node(tokens, i)
               arg.conststr = unquote(tokens[i].tk)
               i = i + 1
            else
               i, arg = parse_table_literal(tokens, i, errs)
            end
            table.insert(args, arg)
            e1 = { ["y"] = t1.y, ["x"] = t1.x, ["kind"] = "op", ["op"] = op, ["e1"] = e1, ["e2"] = args, }
         elseif tokens[i].tk == "(" then
            local op = new_operator(tokens[i], 2, "@funcall")

            local args = new_node(tokens, i, "expression_list")
            i, args = parse_bracket_list(tokens, i, errs, args, "(", ")", true, parse_expression)

            e1 = { ["y"] = t1.y, ["x"] = t1.x, ["kind"] = "op", ["op"] = op, ["e1"] = e1, ["e2"] = args, }
         elseif tokens[i].tk == "[" then
            local op = new_operator(tokens[i], 2, "@index")

            local idx
            i = i + 1
            i, idx = parse_expression(tokens, i, errs)
            i = verify_tk(tokens, i, errs, "]")

            e1 = { ["y"] = t1.y, ["x"] = t1.x, ["kind"] = "op", ["op"] = op, ["e1"] = e1, ["e2"] = idx, }
         elseif tokens[i].tk == "." or tokens[i].tk == ":" then
            local op = new_operator(tokens[i], 2)

            local key
            i = i + 1
            i, key = verify_kind(tokens, i, errs, "identifier")

            e1 = { ["y"] = t1.y, ["x"] = t1.x, ["kind"] = "op", ["op"] = op, ["e1"] = e1, ["e2"] = key, }
         elseif tokens[i].tk == "as" then
            local op = new_operator(tokens[i], 2, "as")

            i = i + 1
            local cast = new_node(tokens, i, "cast")
            i, cast.casttype = parse_type(tokens, i, errs)
            e1 = { ["y"] = t1.y, ["x"] = t1.x, ["kind"] = "op", ["op"] = op, ["e1"] = e1, ["e2"] = cast, ["conststr"] = e1.conststr, }
         else
            break
         end
      end

      return i, e1
   end

   local function E(tokens, i, errs, lhs, min_precedence)
      local lookahead = tokens[i].tk
      while precedences[2][lookahead] and precedences[2][lookahead] >= min_precedence do
         local t1 = tokens[i]
         local op = new_operator(t1, 2)
         i = i + 1
         local rhs
         i, rhs = P(tokens, i, errs)
         lookahead = tokens[i].tk
         while precedences[2][lookahead] and ((precedences[2][lookahead] > (precedences[2][op.op])) or
            (is_right_assoc[lookahead] and (precedences[2][lookahead] == precedences[2][op.op]))) do
            i, rhs = E(tokens, i, errs, rhs, precedences[2][lookahead])
            lookahead = tokens[i].tk
         end
         lhs = { ["y"] = t1.y, ["x"] = t1.x, ["kind"] = "op", ["op"] = op, ["e1"] = lhs, ["e2"] = rhs, }
      end
      return i, lhs
   end

   parse_expression = function(tokens, i, errs)
      local lhs
      i, lhs = P(tokens, i, errs)
      i, lhs = E(tokens, i, errs, lhs, 0)
      return i, lhs, 0
   end
end

local function parse_variable(tokens, i, errs)
   if tokens[i].tk == "..." then
      return verify_kind(tokens, i, errs, "...")
   end
   return verify_kind(tokens, i, errs, "identifier", "variable")
end

local function parse_variable_name(tokens, i, errs)
   local is_const = false
   local node
   i, node = verify_kind(tokens, i, errs, "identifier")
   if not node then
      return i
   end
   if tokens[i].tk == "<" then
      i = i + 1
      local annotation
      i, annotation = verify_kind(tokens, i, errs, "identifier")
      if annotation and annotation.tk == "const" then
         is_const = true
      end
      i = verify_tk(tokens, i, errs, ">")
   end
   node.is_const = is_const
   return i, node
end

local function parse_argument(tokens, i, errs)
   local node
   if tokens[i].tk == "..." then
      i, node = verify_kind(tokens, i, errs, "...")
   else
      i, node = verify_kind(tokens, i, errs, "identifier", "argument")
   end
   if tokens[i].tk == ":" then
      i = i + 1
      i, node.decltype = parse_type(tokens, i, errs)
   end
   return i, node, 0
end

parse_argument_list = function(tokens, i, errs)
   local node = new_node(tokens, i, "argument_list")
   return parse_bracket_list(tokens, i, errs, node, "(", ")", true, parse_argument)
end

local function parse_argument_type(tokens, i, errs)
   local is_va = false
   if tokens[i].kind == "identifier" and tokens[i + 1].tk == ":" then
      i = i + 2
   elseif tokens[i].tk == "..." then
      if tokens[i + 1].tk == ":" then
         i = i + 2
         is_va = true
      else
         return fail(tokens, i, errs, "cannot have untyped '...' when declaring the type of an argument")
      end
   end

   local i, typ = parse_type(tokens, i, errs)
   if typ then
      typ.is_va = is_va
   end

   return i, typ, 0
end

parse_argument_type_list = function(tokens, i, errs)
   local list = new_type(tokens, i, "type_list")
   return parse_bracket_list(tokens, i, errs, list, "(", ")", true, parse_argument_type)
end

local function parse_local_function(tokens, i, errs)
   local node = new_node(tokens, i, "local_function")
   i = verify_tk(tokens, i, errs, "local")
   i = verify_tk(tokens, i, errs, "function")
   i, node.name = verify_kind(tokens, i, errs, "identifier")
   return parse_function_args_rets_body(tokens, i, errs, node)
end

local function parse_function(tokens, i, errs)
   local orig_i = i
   local fn = new_node(tokens, i, "global_function")
   local node = fn
   i = verify_tk(tokens, i, errs, "function")
   local names = {}
   i, names[1] = verify_kind(tokens, i, errs, "identifier", "variable")
   while tokens[i].tk == "." do
      i = i + 1
      i, names[#names + 1] = verify_kind(tokens, i, errs, "identifier")
   end
   if tokens[i].tk == ":" then
      i = i + 1
      i, names[#names + 1] = verify_kind(tokens, i, errs, "identifier")
      fn.is_method = true
   end

   if #names > 1 then
      fn.kind = "record_function"
      local owner = names[1]
      for i = 2, #names - 1 do
         local dot = { ["y"] = names[i].y, ["x"] = names[i].x - 1, ["arity"] = 2, ["op"] = ".", }
         names[i].kind = "identifier"
         local op = { ["y"] = names[i].y, ["x"] = names[i].x, ["kind"] = "op", ["op"] = dot, ["e1"] = owner, ["e2"] = names[i], }
         owner = op
      end
      fn.fn_owner = owner
   end
   fn.name = names[#names]

   local selfx, selfy = tokens[i].x, tokens[i].y
   i = parse_function_args_rets_body(tokens, i, errs, fn)
   if fn.is_method then
      table.insert(fn.args, 1, { ["x"] = selfx, ["y"] = selfy, ["tk"] = "self", ["kind"] = "variable", })
   end

   if not fn.name then
      return orig_i
   end

   return i, node
end

local function parse_if(tokens, i, errs)
   local node = new_node(tokens, i, "if")
   i = verify_tk(tokens, i, errs, "if")
   i, node.exp = parse_expression(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "then")
   i, node.thenpart = parse_statements(tokens, i, errs)
   node.elseifs = {}
   while tokens[i].tk == "elseif" do
      local subnode = new_node(tokens, i, "elseif")
      i = i + 1
      i, subnode.exp = parse_expression(tokens, i, errs)
      i = verify_tk(tokens, i, errs, "then")
      i, subnode.thenpart = parse_statements(tokens, i, errs)
      table.insert(node.elseifs, subnode)
   end
   if tokens[i].tk == "else" then
      local subnode = new_node(tokens, i, "else")
      i = i + 1
      i, subnode.elsepart = parse_statements(tokens, i, errs)
      node.elsepart = subnode
   end
   node.yend = tokens[i].y
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_while(tokens, i, errs)
   local node = new_node(tokens, i, "while")
   i = verify_tk(tokens, i, errs, "while")
   i, node.exp = parse_expression(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "do")
   i, node.body = parse_statements(tokens, i, errs)
   node.yend = tokens[i].y
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_fornum(tokens, i, errs)
   local node = new_node(tokens, i, "fornum")
   i = i + 1
   i, node.var = verify_kind(tokens, i, errs, "identifier")
   i = verify_tk(tokens, i, errs, "=")
   i, node.from = parse_expression(tokens, i, errs)
   i = verify_tk(tokens, i, errs, ",")
   i, node.to = parse_expression(tokens, i, errs)
   if tokens[i].tk == "," then
      i = i + 1
      i, node.step = parse_expression(tokens, i, errs)
   end
   i = verify_tk(tokens, i, errs, "do")
   i, node.body = parse_statements(tokens, i, errs)
   node.yend = tokens[i].y
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_forin(tokens, i, errs)
   local node = new_node(tokens, i, "forin")
   i = i + 1
   node.vars = new_node(tokens, i, "variables")
   i, node.vars = parse_list(tokens, i, errs, node.vars, { ["in"] = true, }, true, parse_variable_name)
   i = verify_tk(tokens, i, errs, "in")
   node.exps = new_node(tokens, i, "expression_list")
   i = parse_list(tokens, i, errs, node.exps, { ["do"] = true, }, true, parse_expression)
   if #node.exps < 1 then
      return fail(tokens, i, errs, "missing iterator expression in generic for")
   elseif #node.exps > 3 then
      return fail(tokens, i, errs, "too many expressions in generic for")
   end
   i = verify_tk(tokens, i, errs, "do")
   i, node.body = parse_statements(tokens, i, errs)
   node.yend = tokens[i].y
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_for(tokens, i, errs)
   if tokens[i + 1].kind == "identifier" and tokens[i + 2].tk == "=" then
      return parse_fornum(tokens, i, errs)
   else
      return parse_forin(tokens, i, errs)
   end
end

local function parse_repeat(tokens, i, errs)
   local node = new_node(tokens, i, "repeat")
   i = verify_tk(tokens, i, errs, "repeat")
   i, node.body = parse_statements(tokens, i, errs)
   node.yend = tokens[i].y
   i = verify_tk(tokens, i, errs, "until")
   i, node.exp = parse_expression(tokens, i, errs)
   return i, node
end

local function parse_do(tokens, i, errs)
   local node = new_node(tokens, i, "do")
   i = verify_tk(tokens, i, errs, "do")
   i, node.body = parse_statements(tokens, i, errs)
   node.yend = tokens[i].y
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end

local function parse_break(tokens, i, errs)
   local node = new_node(tokens, i, "break")
   i = verify_tk(tokens, i, errs, "break")
   return i, node
end

local stop_statement_list = {
   ["end"] = true,
   ["else"] = true,
   ["elseif"] = true,
   ["until"] = true,
}

local stop_return_list = {
   [";"] = true,
}

for k, v in pairs(stop_statement_list) do
   stop_return_list[k] = v
end

local function parse_return(tokens, i, errs)
   local node = new_node(tokens, i, "return")
   i = verify_tk(tokens, i, errs, "return")
   node.exps = new_node(tokens, i, "expression_list")
   i = parse_list(tokens, i, errs, node.exps, stop_return_list, true, parse_expression)
   if tokens[i].kind == ";" then
      i = i + 1
   end
   return i, node
end

local function parse_newtype(tokens, i, errs)
   local node = new_node(tokens, i, "newtype")
   node.newtype = new_type(tokens, i, "typedecl")
   node.newtype.typename = "typetype"
   if tokens[i].tk == "record" then
      local def = new_type(tokens, i, "typedecl")
      node.newtype.def = def
      def.typename = "record"
      def.fields = {}
      def.field_order = {}
      i = i + 1
      if tokens[i].tk == "<" then
         i, def.typevars = parse_typevar_list(tokens, i, errs)
      end
      while not ((not tokens[i]) or tokens[i].tk == "end") do
         if tokens[i].tk == "{" then
            if def.typename == "arrayrecord" then
               return fail(tokens, i, errs, "duplicated declaration of array element type in record")
            end
            i = i + 1
            local t
            i, t = parse_type(tokens, i, errs)
            if tokens[i].tk == "}" then
               node.yend = tokens[i].y
               i = verify_tk(tokens, i, errs, "}")
            else
               return fail(tokens, i, errs, "expected an array declaration")
            end
            def.typename = "arrayrecord"
            def.elements = t
         else
            local v
            i, v = verify_kind(tokens, i, errs, "identifier", "variable")
            if not v then
               return fail(tokens, i, errs, "expected a variable name")
            end
            i = verify_tk(tokens, i, errs, ":")
            local t
            i, t = parse_type(tokens, i, errs)
            if not t then
               return fail(tokens, i, errs, "expected a type")
            end
            if not def.fields[v.tk] then
               def.fields[v.tk] = t
               table.insert(def.field_order, v.tk)
            else
               local prev_t = def.fields[v.tk]
               if t.typename == "function" and prev_t.typename == "function" then
                  def.fields[v.tk] = {
                     ["y"] = v.y,
                     ["x"] = v.x,
                     ["typename"] = "poly",
                     ["poly"] = { [1] = prev_t, [2] = t, },
                  }
               elseif t.typename == "function" and prev_t.typename == "poly" then
                  table.insert(prev_t.poly, t)
               else
                  return fail(tokens, i, errs, "attempt to redeclare field '" .. v.tk .. "' (only functions can be overloaded)")
               end
            end
         end
      end
      node.yend = tokens[i].y
      i = verify_tk(tokens, i, errs, "end")
      return i, node
   elseif tokens[i].tk == "enum" then
      local def = new_type(tokens, i, "typedecl")
      node.newtype.def = def
      def.typename = "enum"
      def.enumset = {}
      i = i + 1
      while not ((not tokens[i]) or tokens[i].tk == "end") do
         local item
         i, item = verify_kind(tokens, i, errs, "string", "enum_item")
         table.insert(node, item)
         def.enumset[unquote(item.tk)] = true
      end
      node.yend = tokens[i].y
      i = verify_tk(tokens, i, errs, "end")
      return i, node
   elseif tokens[i].tk == "functiontype" then
      local typevars
      i = i + 1
      if tokens[i].tk == "<" then
         i, typevars = parse_typevar_list(tokens, i, errs)
      end
      i = i - 1
      i, node.newtype.def = parse_function_type(tokens, i, errs)
      if typevars then
         node.newtype.def.typevars = typevars
      end
      return i, node
   end
   return fail(tokens, i, errs)
end

local is_newtype = {
   ["enum"] = true,
   ["record"] = true,
   ["functiontype"] = true,
}

local function parse_call_or_assignment(tokens, i, errs)
   local asgn = new_node(tokens, i, "assignment")

   asgn.vars = new_node(tokens, i, "variables")
   i = parse_trying_list(tokens, i, errs, asgn.vars, parse_expression)
   if #asgn.vars < 1 then
      return fail(tokens, i, errs)
   end
   local lhs = asgn.vars[1]

   if tokens[i].tk == "=" then
      asgn.exps = new_node(tokens, i, "values")
      repeat
         i = i + 1
         local val
         if is_newtype[tokens[i].tk] then
            if #asgn.vars > 1 then
               return fail(tokens, i, errs, "cannot perform multiple assignment of type definitions")
            end
            i, val = parse_newtype(tokens, i, errs)
         else
            i, val = parse_expression(tokens, i, errs)
         end
         table.insert(asgn.exps, val)
      until tokens[i].tk ~= ","
      return i, asgn
   end
   if lhs.op and lhs.op.op == "@funcall" then
      return i, lhs
   end
   return fail(tokens, i, errs)
end

local function parse_variable_declarations(tokens, i, errs, node_name)
   local asgn = new_node(tokens, i, node_name)

   asgn.vars = new_node(tokens, i, "variables")
   i = parse_trying_list(tokens, i, errs, asgn.vars, parse_variable_name)
   if #asgn.vars == 0 then
      return fail(tokens, i, errs, "expected a local variable definition")
   end
   local lhs = asgn.vars[1]

   i, asgn.decltype = parse_type_list(tokens, i, errs)

   if tokens[i].tk == "=" then
      asgn.exps = new_node(tokens, i, "values")
      local v = 1
      repeat
         i = i + 1
         local val
         if is_newtype[tokens[i].tk] then
            if #asgn.vars > 1 then
               return fail(tokens, i, errs, "cannot perform multiple assignment of type definitions")
            end
            i, val = parse_newtype(tokens, i, errs)
            if val then
               val.newtype.def.name = asgn.vars[v].tk
            else
               return i, val
            end
         else
            i, val = parse_expression(tokens, i, errs)
         end
         table.insert(asgn.exps, val)
         v = v + 1
      until tokens[i].tk ~= ","
   end
   return i, asgn
end

local function parse_statement(tokens, i, errs)
   if tokens[i].tk == "local" then
      if tokens[i + 1].tk == "function" then
         return parse_local_function(tokens, i, errs)
      else
         i = i + 1
         return parse_variable_declarations(tokens, i, errs, "local_declaration")
      end
   elseif tokens[i].tk == "global" then
      i = i + 1
      return parse_variable_declarations(tokens, i, errs, "global_declaration")
   elseif tokens[i].tk == "function" then
      return parse_function(tokens, i, errs)
   elseif tokens[i].tk == "if" then
      return parse_if(tokens, i, errs)
   elseif tokens[i].tk == "while" then
      return parse_while(tokens, i, errs)
   elseif tokens[i].tk == "repeat" then
      return parse_repeat(tokens, i, errs)
   elseif tokens[i].tk == "for" then
      return parse_for(tokens, i, errs)
   elseif tokens[i].tk == "do" then
      return parse_do(tokens, i, errs)
   elseif tokens[i].tk == "break" then
      return parse_break(tokens, i, errs)
   elseif tokens[i].tk == "return" then
      return parse_return(tokens, i, errs)
   else
      return parse_call_or_assignment(tokens, i, errs)
   end
   return fail(tokens, i, errs)
end

parse_statements = function(tokens, i, errs, filename)
   local node = new_node(tokens, i, "statements")
   while true do
      while tokens[i].kind == ";" do
         i = i + 1
      end
      if tokens[i].kind == "$EOF$" then
         break
      end
      if stop_statement_list[tokens[i].tk] then
         break
      end
      local item
      i, item = parse_statement(tokens, i, errs)
      if filename then
         for j = 1, #errs do
            if not errs[j].filename then
               errs[j].filename = filename
            end
         end
      end
      if not item then
         break
      end
      table.insert(node, item)
   end
   return i, node
end

function tl.parse_program(tokens, errs, filename)
   errs = errs or {}
   local last = tokens[#tokens] or { ["y"] = 1, ["x"] = 1, ["tk"] = "", }
   table.insert(tokens, { ["y"] = last.y, ["x"] = last.x + #last.tk, ["tk"] = "$EOF$", ["kind"] = "$EOF$", })
   return parse_statements(tokens, 1, errs, filename)
end





local VisitorCallbacks = {}






local Visitor = {}




local function visit_before(ast, kind, visit)
   assert(visit.cbs[kind], "no visitor for " .. (kind))
   if visit.cbs[kind].before then
      visit.cbs[kind].before(ast)
   end
end

local function visit_after(ast, kind, visit, xs)
   if visit.after and visit.after.before then
      visit.after.before(ast, xs)
   end
   local ret
   if visit.cbs[kind].after then
      ret = visit.cbs[kind].after(ast, xs)
   end
   if visit.after and visit.after.after then
      ret = visit.after.after(ast, xs, ret)
   end
   return ret
end

local function recurse_type(ast, visit)
   visit_before(ast, ast.kind, visit)
   local xs = {}
   if ast.kind == "type_list" then
      for i, child in ipairs(ast) do
         xs[i] = recurse_type(child, visit)
      end
   elseif ast.kind == "typedecl" then
 else
      if not ast.kind then
         error("wat: " .. inspect(ast))
      end
      error("unknown node kind " .. ast.kind)
   end
   return visit_after(ast, ast.kind, visit, xs)
end

local function recurse_node(ast,
visit_node,
visit_type)
   if not ast then

      return
   end
   visit_before(ast, ast.kind, visit_node)
   local xs = {}
   if ast.kind == "statements" or
      ast.kind == "variables" or
      ast.kind == "values" or
      ast.kind == "argument_list" or
      ast.kind == "expression_list" or
      ast.kind == "table_literal" then
      for i, child in ipairs(ast) do
         xs[i] = recurse_node(child, visit_node, visit_type)
      end
   elseif ast.kind == "local_declaration" or
      ast.kind == "global_declaration" or
      ast.kind == "assignment" then
      xs[1] = recurse_node(ast.vars, visit_node, visit_type)
      if ast.exps then
         xs[2] = recurse_node(ast.exps, visit_node, visit_type)
      end
   elseif ast.kind == "table_item" then
      xs[1] = recurse_node(ast.key, visit_node, visit_type)
      xs[2] = recurse_node(ast.value, visit_node, visit_type)
   elseif ast.kind == "if" then
      xs[1] = recurse_node(ast.exp, visit_node, visit_type)
      if visit_node.cbs["if"].before_statements then
         visit_node.cbs["if"].before_statements(ast, xs)
      end
      xs[2] = recurse_node(ast.thenpart, visit_node, visit_type)
      for i, e in ipairs(ast.elseifs) do
         table.insert(xs, recurse_node(e, visit_node, visit_type))
      end
      if ast.elsepart then
         if visit_node.cbs["if"].before_else then
            visit_node.cbs["if"].before_else(ast, xs)
         end
         table.insert(xs, recurse_node(ast.elsepart, visit_node, visit_type))
      end
   elseif ast.kind == "while" then
      xs[1] = recurse_node(ast.exp, visit_node, visit_type)
      xs[2] = recurse_node(ast.body, visit_node, visit_type)
   elseif ast.kind == "repeat" then
      xs[1] = recurse_node(ast.body, visit_node, visit_type)
      xs[2] = recurse_node(ast.exp, visit_node, visit_type)
   elseif ast.kind == "function" then
      xs[1] = recurse_node(ast.args, visit_node, visit_type)
      xs[2] = recurse_type(ast.rets, visit_type)
      xs[3] = recurse_node(ast.body, visit_node, visit_type)
   elseif ast.kind == "forin" then
      xs[1] = recurse_node(ast.vars, visit_node, visit_type)
      xs[2] = recurse_node(ast.exps, visit_node, visit_type)
      if visit_node.cbs["forin"].before_statements then
         visit_node.cbs["forin"].before_statements(ast)
      end
      xs[3] = recurse_node(ast.body, visit_node, visit_type)
   elseif ast.kind == "fornum" then
      xs[1] = recurse_node(ast.var, visit_node, visit_type)
      xs[2] = recurse_node(ast.from, visit_node, visit_type)
      xs[3] = recurse_node(ast.to, visit_node, visit_type)
      xs[4] = ast.step and recurse_node(ast.step, visit_node, visit_type)
      xs[5] = recurse_node(ast.body, visit_node, visit_type)
   elseif ast.kind == "elseif" then
      xs[1] = recurse_node(ast.exp, visit_node, visit_type)
      if visit_node.cbs["elseif"].before_statements then
         visit_node.cbs["elseif"].before_statements(ast, xs)
      end
      xs[2] = recurse_node(ast.thenpart, visit_node, visit_type)
   elseif ast.kind == "else" then
      xs[1] = recurse_node(ast.elsepart, visit_node, visit_type)
   elseif ast.kind == "return" then
      xs[1] = recurse_node(ast.exps, visit_node, visit_type)
   elseif ast.kind == "do" then
      xs[1] = recurse_node(ast.body, visit_node, visit_type)
   elseif ast.kind == "cast" then
 elseif ast.kind == "local_function" or
      ast.kind == "global_function" then
      xs[1] = recurse_node(ast.name, visit_node, visit_type)
      xs[2] = recurse_node(ast.args, visit_node, visit_type)
      xs[3] = recurse_type(ast.rets, visit_type)
      xs[4] = recurse_node(ast.body, visit_node, visit_type)
   elseif ast.kind == "record_function" then
      xs[1] = recurse_node(ast.fn_owner, visit_node, visit_type)
      xs[2] = recurse_node(ast.name, visit_node, visit_type)
      xs[3] = recurse_node(ast.args, visit_node, visit_type)
      xs[4] = recurse_type(ast.rets, visit_type)
      if visit_node.cbs["record_function"].before_statements then
         visit_node.cbs["record_function"].before_statements(ast, xs)
      end
      xs[5] = recurse_node(ast.body, visit_node, visit_type)
   elseif ast.kind == "paren" then
      xs[1] = recurse_node(ast.e1, visit_node, visit_type)
   elseif ast.kind == "op" then
      xs[1] = recurse_node(ast.e1, visit_node, visit_type)
      local p1 = ast.e1.op and ast.e1.op.prec or nil
      if ast.op.op == ":" and ast.e1.kind == "string" then
         p1 = -999
      end
      xs[2] = p1
      if ast.op.arity == 2 then
         xs[3] = recurse_node(ast.e2, visit_node, visit_type)
         xs[4] = ast.e2.op and ast.e2.op.prec
      end
   elseif ast.kind == "newtype" then
      xs[1] = recurse_type(ast.newtype, visit_type)
   elseif ast.kind == "variable" or
      ast.kind == "argument" or
      ast.kind == "identifier" or
      ast.kind == "string" or
      ast.kind == "number" or
      ast.kind == "break" or
      ast.kind == "nil" or
      ast.kind == "..." or
      ast.kind == "boolean" then
      if ast.decltype then
         xs[1] = recurse_type(ast.decltype, visit_type)
      end
   else
      if not ast.kind then
         error("wat: " .. inspect(ast))
      end
      error("unknown node kind " .. ast.kind)
   end
   return visit_after(ast, ast.kind, visit_node, xs)
end





local tight_op = {
   [1] = {
      ["-"] = true,
      ["~"] = true,
      ["#"] = true,
   },
   [2] = {
      ["."] = true,
      [":"] = true,
   },
}

local spaced_op = {
   [1] = {
      ["not"] = true,
   },
   [2] = {
      ["or"] = true,
      ["and"] = true,
      ["<"] = true,
      [">"] = true,
      ["<="] = true,
      [">="] = true,
      ["~="] = true,
      ["=="] = true,
      ["|"] = true,
      ["~"] = true,
      ["&"] = true,
      ["<<"] = true,
      [">>"] = true,
      [".."] = true,
      ["+"] = true,
      ["-"] = true,
      ["*"] = true,
      ["/"] = true,
      ["//"] = true,
      ["%"] = true,
      ["^"] = true,
   },
}

function tl.pretty_print_ast(ast, fast)
   local indent = 0

   local Output = {}





   local function increment_indent()
      indent = indent + 1
   end

   if fast then
      increment_indent = nil
   end

   local function add(out, s)
      table.insert(out, s)
   end

   local function add_string(out, s)
      table.insert(out, s)
      if string.find(s, "\n", 1, true) then
         for nl in s:gmatch("\n") do
            out.h = out.h + 1
         end
      end
   end

   local function add_child(out, child, space, indent)
      if child.y < out.y then
         out.y = child.y
      end

      if child.y > out.y + out.h then
         local delta = child.y - (out.y + out.h)
         out.h = out.h + delta
         table.insert(out, ("\n"):rep(delta))
      else
         if space then
            table.insert(out, space)
            indent = nil
         end
      end
      if indent and (not fast) then
         table.insert(out, ("   "):rep(indent))
      end
      table.insert(out, child)
      out.h = out.h + child.h
   end

   local function concat_output(out)
      for i, s in ipairs(out) do
         if type(s) == "table" then
            out[i] = concat_output(s)
         end
      end
      return table.concat(out)
   end

   local visit_node = {}

   visit_node.cbs = {
      ["statements"] = {
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            local space
            for i, child in ipairs(children) do
               add_child(out, children[i], space, indent)
               space = "; "
            end
            return out
         end,
      },
      ["local_declaration"] = {
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            table.insert(out, "local")
            add_child(out, children[1], " ")
            if children[2] then
               table.insert(out, " =")
               add_child(out, children[2], " ")
            end
            return out
         end,
      },
      ["global_declaration"] = {
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            if children[2] then
               add_child(out, children[1], " ")
               table.insert(out, " =")
               add_child(out, children[2], " ")
            end
            return out
         end,
      },
      ["assignment"] = {
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            add_child(out, children[1])
            table.insert(out, " =")
            add_child(out, children[2], " ")
            return out
         end,
      },
      ["if"] = {
         ["before"] = increment_indent,
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            table.insert(out, "if")
            add_child(out, children[1], " ")
            table.insert(out, " then")
            add_child(out, children[2], " ")
            indent = indent - 1
            for i = 3, #children do
               add_child(out, children[i], " ", indent)
            end
            add_child(out, { ["y"] = node.yend, ["h"] = 0, [1] = "end", }, " ", indent)
            return out
         end,
      },
      ["while"] = {
         ["before"] = increment_indent,
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            table.insert(out, "while")
            add_child(out, children[1], " ")
            table.insert(out, " do")
            add_child(out, children[2], " ")
            indent = indent - 1
            add_child(out, { ["y"] = node.yend, ["h"] = 0, [1] = "end", }, " ", indent)
            return out
         end,
      },
      ["repeat"] = {
         ["before"] = increment_indent,
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            table.insert(out, "repeat")
            add_child(out, children[1], " ")
            if not fast then
               indent = indent - 1
            end
            add_child(out, { ["y"] = node.yend, ["h"] = 0, [1] = "until ", }, " ", indent)
            add_child(out, children[2])
            return out
         end,
      },
      ["do"] = {
         ["before"] = increment_indent,
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            table.insert(out, "do")
            add_child(out, children[1], " ")
            indent = indent - 1
            add_child(out, { ["y"] = node.yend, ["h"] = 0, [1] = "end", }, " ", indent)
            return out
         end,
      },
      ["forin"] = {
         ["before"] = increment_indent,
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            table.insert(out, "for")
            add_child(out, children[1], " ")
            table.insert(out, " in")
            add_child(out, children[2], " ")
            table.insert(out, " do")
            add_child(out, children[3], " ")
            indent = indent - 1
            add_child(out, { ["y"] = node.yend, ["h"] = 0, [1] = "end", }, " ", indent)
            return out
         end,
      },
      ["fornum"] = {
         ["before"] = increment_indent,
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            table.insert(out, "for")
            add_child(out, children[1], " ")
            table.insert(out, " =")
            add_child(out, children[2], " ")
            table.insert(out, ",")
            add_child(out, children[3], " ")
            if children[4] then
               table.insert(out, ",")
               add_child(out, children[4], " ")
            end
            table.insert(out, " do")
            add_child(out, children[5], " ")
            indent = indent - 1
            add_child(out, { ["y"] = node.yend, ["h"] = 0, [1] = "end", }, " ", indent)
            return out
         end,
      },
      ["return"] = {
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            table.insert(out, "return")
            if #children[1] > 0 then
               add_child(out, children[1], " ")
            end
            return out
         end,
      },
      ["break"] = {
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            table.insert(out, "break")
            return out
         end,
      },
      ["elseif"] = {
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            table.insert(out, "elseif")
            add_child(out, children[1], " ")
            table.insert(out, " then")
            add_child(out, children[2], " ")
            return out
         end,
      },
      ["else"] = {
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            table.insert(out, "else")
            add_child(out, children[1], " ")
            return out
         end,
      },
      ["variables"] = {
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            local space
            for i, child in ipairs(children) do
               if i > 1 then
                  table.insert(out, ",")
                  space = " "
               end
               add_child(out, child, space)
            end
            return out
         end,
      },
      ["table_literal"] = {
         ["before"] = increment_indent,
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            if #children == 0 then
               indent = indent - 1
               table.insert(out, "{}")
               return out
            end
            table.insert(out, "{")
            for i, child in ipairs(children) do
               add_child(out, child, " ", child.y ~= node.y and indent)
               table.insert(out, ",")
            end
            indent = indent - 1
            add_child(out, { ["y"] = node.yend, ["h"] = 0, [1] = "}", }, " ", indent)
            return out
         end,
      },
      ["table_item"] = {
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            table.insert(out, "[")
            add_child(out, children[1])
            table.insert(out, "] = ")
            add_child(out, children[2])
            return out
         end,
      },
      ["local_function"] = {
         ["before"] = increment_indent,
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            table.insert(out, "local function")
            add_child(out, children[1], " ")
            table.insert(out, "(")
            add_child(out, children[2])
            table.insert(out, ")")
            add_child(out, children[4], " ")
            indent = indent - 1
            add_child(out, { ["y"] = node.yend, ["h"] = 0, [1] = "end", }, " ", indent)
            return out
         end,
      },
      ["global_function"] = {
         ["before"] = increment_indent,
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            table.insert(out, "function")
            add_child(out, children[1], " ")
            table.insert(out, "(")
            add_child(out, children[2])
            table.insert(out, ")")
            add_child(out, children[4], " ")
            indent = indent - 1
            add_child(out, { ["y"] = node.yend, ["h"] = 0, [1] = "end", }, " ", indent)
            return out
         end,
      },
      ["record_function"] = {
         ["before"] = increment_indent,
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            table.insert(out, "function")
            add_child(out, children[1], " ")
            table.insert(out, node.is_method and ":" or ".")
            add_child(out, children[2])
            table.insert(out, "(")
            if node.is_method then

               table.remove(children[3], 1)
               if children[3][1] == "," then
                  table.remove(children[3], 1)
                  table.remove(children[3], 1)
               end
            end
            add_child(out, children[3])
            table.insert(out, ")")
            add_child(out, children[5], " ")
            indent = indent - 1
            add_child(out, { ["y"] = node.yend, ["h"] = 0, [1] = "end", }, " ", indent)
            return out
         end,
      },
      ["function"] = {
         ["before"] = increment_indent,
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            table.insert(out, "function(")
            add_child(out, children[1])
            table.insert(out, ")")
            add_child(out, children[3], " ")
            indent = indent - 1
            add_child(out, { ["y"] = node.yend, ["h"] = 0, [1] = "end", }, " ", indent)
            return out
         end,
      },
      ["cast"] = {},

      ["paren"] = {
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            table.insert(out, "(")
            add_child(out, children[1], "", indent)
            table.insert(out, ")")
            return out
         end,
      },
      ["op"] = {
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            if node.op.op == "@funcall" then
               add_child(out, children[1], "", indent)
               table.insert(out, "(")
               add_child(out, children[3], "", indent)
               table.insert(out, ")")
            elseif node.op.op == "@index" then
               add_child(out, children[1], "", indent)
               table.insert(out, "[")
               add_child(out, children[3], "", indent)
               table.insert(out, "]")
            elseif node.op.op == "as" then
               add_child(out, children[1], "", indent)
            elseif spaced_op[node.op.arity][node.op.op] or tight_op[node.op.arity][node.op.op] then
               local space = spaced_op[node.op.arity][node.op.op] and " " or ""
               if children[2] and node.op.prec > tonumber(children[2]) then
                  table.insert(children[1], 1, "(")
                  table.insert(children[1], ")")
               end
               if node.op.arity == 1 then
                  table.insert(out, node.op.op)
                  add_child(out, children[1], space, indent)
               elseif node.op.arity == 2 then
                  add_child(out, children[1], "", indent)
                  if space == " " then
                     table.insert(out, " ")
                  end
                  table.insert(out, node.op.op)
                  if children[4] and node.op.prec > tonumber(children[4]) then
                     table.insert(children[3], 1, "(")
                     table.insert(children[3], ")")
                  end
                  add_child(out, children[3], space, indent)
               end
            else
               error("unknown node op " .. node.op.op)
            end
            return out
         end,
      },
      ["variable"] = {
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            add_string(out, node.tk)
            return out
         end,
      },
      ["newtype"] = {
         ["after"] = function(node, children)
            local out = { ["y"] = node.y, ["h"] = 0, }
            table.insert(out, "{}")
            return out
         end,
      },
   }

   local visit_type = {}
   visit_type.cbs = {
      ["type_list"] = {
         ["after"] = function(typ, children)
            local out = { ["y"] = typ.y, ["h"] = 0, }
            return out
         end,
      },
   }

   visit_node.cbs["values"] = visit_node.cbs["variables"]
   visit_node.cbs["expression_list"] = visit_node.cbs["variables"]
   visit_node.cbs["argument_list"] = visit_node.cbs["variables"]
   visit_node.cbs["identifier"] = visit_node.cbs["variable"]
   visit_node.cbs["string"] = visit_node.cbs["variable"]
   visit_node.cbs["number"] = visit_node.cbs["variable"]
   visit_node.cbs["nil"] = visit_node.cbs["variable"]
   visit_node.cbs["boolean"] = visit_node.cbs["variable"]
   visit_node.cbs["..."] = visit_node.cbs["variable"]
   visit_node.cbs["argument"] = visit_node.cbs["variable"]

   visit_type.cbs["typedecl"] = visit_type.cbs["type_list"]

   local out = recurse_node(ast, visit_node, visit_type)
   return concat_output(out)
end





local ANY = { ["typename"] = "any", }
local NIL = { ["typename"] = "nil", }
local NUMBER = { ["typename"] = "number", }
local STRING = { ["typename"] = "string", }
local VARARG_ANY = { ["typename"] = "any", ["is_va"] = true, }
local VARARG_STRING = { ["typename"] = "string", ["is_va"] = true, }
local VARARG_NUMBER = { ["typename"] = "number", ["is_va"] = true, }
local BOOLEAN = { ["typename"] = "boolean", }
local ALPHA = { ["typename"] = "typevar", ["typevar"] = "`a", }
local BETA = { ["typename"] = "typevar", ["typevar"] = "`b", }
local ARRAY_OF_ANY = { ["typename"] = "array", ["elements"] = ANY, }
local ARRAY_OF_STRING = { ["typename"] = "array", ["elements"] = STRING, }
local ARRAY_OF_ALPHA = { ["typename"] = "array", ["elements"] = ALPHA, }
local MAP_OF_ALPHA_TO_BETA = { ["typename"] = "map", ["keys"] = ALPHA, ["values"] = BETA, }
local TABLE = { ["typename"] = "map", ["keys"] = ANY, ["values"] = ANY, }
local FUNCTION = { ["typename"] = "function", ["args"] = { [1] = { ["typename"] = "any", ["is_va"] = true, }, }, ["rets"] = { [1] = { ["typename"] = "any", ["is_va"] = true, }, }, }
local INVALID = { ["typename"] = "invalid", }
local UNKNOWN = { ["typename"] = "unknown", }
local NOMINAL_FILE = { ["typename"] = "nominal", ["name"] = "FILE", }
local METATABLE = { ["typename"] = "nominal", ["name"] = "METATABLE", }

local numeric_binop = {
   ["number"] = {
      ["number"] = NUMBER,
   },
}

local relational_binop = {
   ["number"] = {
      ["number"] = BOOLEAN,
   },
   ["string"] = {
      ["string"] = BOOLEAN,
   },
   ["boolean"] = {
      ["boolean"] = BOOLEAN,
   },
}

local equality_binop = {
   ["number"] = {
      ["number"] = BOOLEAN,
      ["nil"] = BOOLEAN,
   },
   ["string"] = {
      ["string"] = BOOLEAN,
      ["nil"] = BOOLEAN,
   },
   ["boolean"] = {
      ["boolean"] = BOOLEAN,
      ["nil"] = BOOLEAN,
   },
   ["record"] = {
      ["emptytable"] = BOOLEAN,
      ["arrayrecord"] = BOOLEAN,
      ["record"] = BOOLEAN,
      ["nil"] = BOOLEAN,
   },
   ["array"] = {
      ["emptytable"] = BOOLEAN,
      ["arrayrecord"] = BOOLEAN,
      ["array"] = BOOLEAN,
      ["nil"] = BOOLEAN,
   },
   ["arrayrecord"] = {
      ["emptytable"] = BOOLEAN,
      ["arrayrecord"] = BOOLEAN,
      ["record"] = BOOLEAN,
      ["array"] = BOOLEAN,
      ["nil"] = BOOLEAN,
   },
   ["map"] = {
      ["emptytable"] = BOOLEAN,
      ["map"] = BOOLEAN,
      ["nil"] = BOOLEAN,
   },
}

local unop_types = {
   ["#"] = {
      ["arrayrecord"] = NUMBER,
      ["string"] = NUMBER,
      ["array"] = NUMBER,
      ["map"] = NUMBER,
      ["emptytable"] = NUMBER,
   },
   ["-"] = {
      ["number"] = NUMBER,
   },
   ["not"] = {
      ["string"] = BOOLEAN,
      ["number"] = BOOLEAN,
      ["boolean"] = BOOLEAN,
      ["record"] = BOOLEAN,
      ["arrayrecord"] = BOOLEAN,
      ["array"] = BOOLEAN,
      ["map"] = BOOLEAN,
      ["emptytable"] = BOOLEAN,
   },
}

local binop_types = {
   ["+"] = numeric_binop,
   ["-"] = {
      ["number"] = {
         ["number"] = NUMBER,
      },
   },
   ["*"] = numeric_binop,
   ["%"] = numeric_binop,
   ["/"] = numeric_binop,
   ["^"] = numeric_binop,
   ["&"] = numeric_binop,
   ["|"] = numeric_binop,
   ["<<"] = numeric_binop,
   [">>"] = numeric_binop,
   ["=="] = equality_binop,
   ["~="] = equality_binop,
   ["<="] = relational_binop,
   [">="] = relational_binop,
   ["<"] = relational_binop,
   [">"] = relational_binop,
   ["or"] = {
      ["boolean"] = {
         ["boolean"] = BOOLEAN,
         ["function"] = FUNCTION,
      },
      ["number"] = {
         ["number"] = NUMBER,
         ["boolean"] = BOOLEAN,
      },
      ["string"] = {
         ["string"] = STRING,
         ["boolean"] = BOOLEAN,
         ["enum"] = STRING,
      },
      ["function"] = {
         ["function"] = FUNCTION,
         ["boolean"] = BOOLEAN,
      },
      ["array"] = {
         ["boolean"] = BOOLEAN,
      },
      ["record"] = {
         ["boolean"] = BOOLEAN,
      },
      ["arrayrecord"] = {
         ["boolean"] = BOOLEAN,
      },
      ["map"] = {
         ["boolean"] = BOOLEAN,
      },
      ["enum"] = {
         ["string"] = STRING,
      },
   },
   [".."] = {
      ["string"] = {
         ["string"] = STRING,
         ["enum"] = STRING,
         ["number"] = STRING,
      },
      ["number"] = {
         ["number"] = STRING,
         ["string"] = STRING,
         ["enum"] = STRING,
      },
      ["enum"] = {
         ["number"] = STRING,
         ["string"] = STRING,
         ["enum"] = STRING,
      },
   },
}

local show_type

local function copy_type(t, seen)
   seen = seen or {}
   local copy = {}
   seen[t] = copy
   for k, v in pairs(t) do
      if type(v) == "table" then
         if seen[v] then
            copy[k] = seen[v]
         else
            copy[k] = copy_type(v, seen)
         end
      else
         copy[k] = v
      end
   end
   return copy
end

local function resolve_typevars(t, typevars, seen)
   seen = seen or {}
   if seen[t] then
      return seen[t]
   end

   local orig_t = t
   if t.typename == "typevar" and typevars[t.typevar] then
      t = typevars[t.typevar]
   end

   local copy = {}
   seen[orig_t] = copy

   for k, v in pairs(t) do
      local cp = copy
      if type(v) == "table" then
         cp[k] = resolve_typevars(v, typevars, seen)
      else
         cp[k] = v
      end
   end

   copy.tk = nil

   return copy
end

local function is_unknown(t)
   return t.typename == "unknown" or
   t.typename == "unknown_emptytable_value"
end

local show_type

local function show_type_base(t, typevars)
   if typevars then
      t = resolve_typevars(t, typevars)
   end
   if t.typename == "nominal" then
      if t.typevals then
         local out = { [1] = t.name, [2] = "<", }
         local vals = {}
         for _, v in ipairs(t.typevals) do
            table.insert(vals, show_type(v))
         end
         table.insert(out, table.concat(vals, ", "))
         table.insert(out, ">")
         return table.concat(out)
      else
         return t.name
      end
   elseif t.typename == "tuple" then
      local out = {}
      for _, v in ipairs(t) do
         table.insert(out, show_type(v))
      end
      return "(" .. table.concat(out, ", ") .. ")"
   elseif t.typename == "poly" then
      local out = {}
      for _, v in ipairs(t.poly) do
         table.insert(out, show_type(v))
      end
      return table.concat(out, " or ")
   elseif t.typename == "emptytable" then
      return "{}"
   elseif t.typename == "map" then
      return "{" .. show_type(t.keys) .. " : " .. show_type(t.values) .. "}"
   elseif t.typename == "array" then
      return "{" .. show_type(t.elements) .. "}"
   elseif t.typename == "record" then
      local out = {}
      for _, k in ipairs(t.field_order) do
         local v = t.fields[k]
         table.insert(out, k .. ": " .. show_type(v))
      end
      return "{" .. table.concat(out, ", ") .. "}"
   elseif t.typename == "function" then
      local out = {}
      table.insert(out, "function(")
      local args = {}
      if t.is_method then
         table.insert(args, "self")
      end
      for i, v in ipairs(t.args) do
         if not t.is_method or i > 1 then
            table.insert(args, show_type(v))
         end
      end
      table.insert(out, table.concat(args, ","))
      table.insert(out, ")")
      if #t.rets > 0 then
         table.insert(out, ":")
         local rets = {}
         for _, v in ipairs(t.rets) do
            table.insert(rets, show_type(v))
         end
         table.insert(out, table.concat(rets, ","))
      end
      return table.concat(out)
   elseif t.typename == "number" or
      t.typename == "boolean" then
      return t.typename
   elseif t.typename == "string" then
      return t.typename ..
      (t.tk and " " .. t.tk or "")
   elseif t.typename == "typevar" then
      return t.typevar
   elseif is_unknown(t) then
      return "<unknown type>"
   elseif t.typename == "invalid" then
      return "<invalid type>"
   elseif t.typename == "any" then
      return "<any type>"
   elseif t.typename == "nil" then
      return "nil"
   elseif t.typename == "typetype" then
      return "type " .. show_type(t.def)
   elseif t.typename == "bad_nominal" then
      return t.name .. " (an unknown type)"
   else
      return inspect(t)
   end
end

show_type = function(t, typevars)
   local ret = show_type_base(t, typevars)
   if t.inferred_at then
      ret = ret .. " (inferred at " .. t.inferred_at_file .. ":" .. t.inferred_at.y .. ":" .. t.inferred_at.x .. ": )"
   end
   return ret
end

local Error = {}






local Result = {}







function tl.search_module(module_name, search_dtl)
   local found
   local fd
   local tried = {}
   local path = os.getenv("TL_PATH") or package.path
   for entry in path:gmatch("[^;]+") do
      local slash_name = module_name:gsub("%.", "/")
      local filename = entry:gsub("?", slash_name)
      local tl_filename = filename:gsub("%.lua$", ".tl")
      if tl_filename ~= filename then
         fd = io.open(tl_filename, "r")
         if fd then
            found = tl_filename
            break
         end
         table.insert(tried, "no file '" .. tl_filename .. "'")
      end
      if search_dtl then
         local dtl_filename = filename:gsub("%.lua$", ".d.tl")
         if dtl_filename ~= filename then
            fd = io.open(dtl_filename, "r")
            if fd then
               found = dtl_filename
               break
            end
            table.insert(tried, "no file '" .. dtl_filename .. "'")
         end
      end
      fd = io.open(filename, "r")
      if fd then
         found = filename
         break
      end
      table.insert(tried, "no file '" .. filename .. "'")
   end
   return found, fd, tried
end

local Variable = {}





local function fill_field_order(t)
   if t.typename == "record" then
      t.field_order = {}
      for k, v in pairs(t.fields) do
         table.insert(t.field_order, k)
      end
      table.sort(t.field_order)
   end
end

local function require_module(module_name, lax, modules, result, globals)
   if modules[module_name] then
      return modules[module_name]
   end
   modules[module_name] = UNKNOWN

   local found, fd, tried = tl.search_module(module_name, true)
   if found and (lax or found:match("tl$")) then
      fd:close()
      local _result, err = tl.process(found, modules, result, globals)
      assert(_result, err)

      return _result.type
   end

   return UNKNOWN
end

local standard_library = {
   ["..."] = { ["typename"] = "tuple", [1] = STRING, [2] = STRING, [3] = STRING, [4] = STRING, [5] = STRING, },
   ["@return"] = { ["typename"] = "tuple", [1] = ANY, },
   ["any"] = { ["typename"] = "typetype", ["def"] = ANY, },
   ["arg"] = ARRAY_OF_STRING,
   ["require"] = { ["typename"] = "function", ["args"] = { [1] = STRING, }, ["rets"] = {}, },
   ["setmetatable"] = { ["typename"] = "function", ["args"] = { [1] = ALPHA, [2] = METATABLE, }, ["rets"] = { [1] = ALPHA, }, },
   ["getmetatable"] = { ["typename"] = "function", ["args"] = { [1] = ANY, }, ["rets"] = { [1] = METATABLE, }, },
   ["rawget"] = { ["typename"] = "function", ["args"] = { [1] = TABLE, [2] = ANY, }, ["rets"] = { [1] = ANY, }, },
   ["rawset"] = {
      ["typename"] = "poly",
      ["poly"] = {
         [1] = { ["typename"] = "function", ["args"] = { [1] = MAP_OF_ALPHA_TO_BETA, [2] = ALPHA, [3] = BETA, }, ["rets"] = {}, },
         [2] = { ["typename"] = "function", ["args"] = { [1] = ARRAY_OF_ALPHA, [2] = NUMBER, [3] = ALPHA, }, ["rets"] = {}, },
         [3] = { ["typename"] = "function", ["args"] = { [1] = TABLE, [2] = ANY, [3] = ANY, }, ["rets"] = {}, },
      },
   },
   ["next"] = {
      ["typename"] = "poly",
      ["poly"] = {
         [1] = { ["typename"] = "function", ["args"] = { [1] = MAP_OF_ALPHA_TO_BETA, }, ["rets"] = { [1] = ALPHA, [2] = BETA, }, },
         [2] = { ["typename"] = "function", ["args"] = { [1] = MAP_OF_ALPHA_TO_BETA, [2] = ALPHA, }, ["rets"] = { [1] = ALPHA, [2] = BETA, }, },
         [3] = { ["typename"] = "function", ["args"] = { [1] = ARRAY_OF_ALPHA, }, ["rets"] = { [1] = NUMBER, [2] = ALPHA, }, },
         [4] = { ["typename"] = "function", ["args"] = { [1] = ARRAY_OF_ALPHA, [2] = ALPHA, }, ["rets"] = { [1] = NUMBER, [2] = ALPHA, }, },
      },
   },
   ["load"] = {
      ["typename"] = "poly",
      ["poly"] = {
         [1] = { ["typename"] = "function", ["args"] = { [1] = STRING, }, ["rets"] = { [1] = FUNCTION, }, },
         [2] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = STRING, }, ["rets"] = { [1] = FUNCTION, }, },
      },
   },
   ["FILE"] = {
      ["typename"] = "typetype",
      ["def"] = {
         ["typename"] = "record",
         ["fields"] = {
            ["read"] = {
               ["typename"] = "poly",
               ["poly"] = {
                  [1] = { ["typename"] = "function", ["args"] = { [1] = NOMINAL_FILE, [2] = STRING, }, ["rets"] = { [1] = STRING, [2] = STRING, }, },
                  [2] = { ["typename"] = "function", ["args"] = { [1] = NOMINAL_FILE, [2] = NUMBER, }, ["rets"] = { [1] = STRING, [2] = STRING, }, },
               },
            },
            ["write"] = { ["typename"] = "function", ["args"] = { [1] = NOMINAL_FILE, [2] = VARARG_STRING, }, ["rets"] = { [1] = NOMINAL_FILE, [2] = STRING, }, },
            ["close"] = { ["typename"] = "function", ["args"] = { [1] = NOMINAL_FILE, }, ["rets"] = { [1] = BOOLEAN, [2] = STRING, }, },
            ["flush"] = { ["typename"] = "function", ["args"] = { [1] = NOMINAL_FILE, }, ["rets"] = {}, },

         },
      },
   },
   ["METATABLE"] = {
      ["typename"] = "typetype",
      ["def"] = {
         ["typename"] = "record",
         ["fields"] = {
            ["__index"] = ANY,
            ["__newindex"] = ANY,
            ["__tostring"] = { ["typename"] = "function", ["args"] = { [1] = ANY, }, ["rets"] = { [1] = STRING, }, },
            ["__mode"] = { ["typename"] = "enum", ["enumset"] = { ["k"] = true, ["v"] = true, ["kv"] = true, }, },
            ["__call"] = FUNCTION,
            ["__gc"] = { ["typename"] = "function", ["args"] = { [1] = ANY, }, ["rets"] = {}, },
            ["__len"] = { ["typename"] = "function", ["args"] = { [1] = ANY, }, ["rets"] = { [1] = NUMBER, }, },
            ["__pairs"] = { ["typename"] = "function", ["args"] = { [1] = { ["typename"] = "map", ["keys"] = ALPHA, ["values"] = BETA, }, }, ["rets"] = {
                  [1] = { ["typename"] = "function", ["args"] = {}, ["rets"] = { [1] = ALPHA, [2] = BETA, }, },
               }, },

         },
      },
   },
   ["io"] = {
      ["typename"] = "record",
      ["fields"] = {
         ["stderr"] = NOMINAL_FILE,
         ["stdout"] = NOMINAL_FILE,
         ["open"] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = STRING, }, ["rets"] = { [1] = NOMINAL_FILE, [2] = STRING, }, },
         ["popen"] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = STRING, }, ["rets"] = { [1] = NOMINAL_FILE, [2] = STRING, }, },
         ["write"] = { ["typename"] = "function", ["args"] = { [1] = VARARG_STRING, }, ["rets"] = { [1] = NOMINAL_FILE, [2] = STRING, }, },
         ["flush"] = { ["typename"] = "function", ["args"] = {}, ["rets"] = {}, },
         ["type"] = { ["typename"] = "function", ["args"] = { [1] = ANY, }, ["rets"] = { [1] = STRING, }, },
      },
   },
   ["os"] = {
      ["typename"] = "record",
      ["fields"] = {
         ["getenv"] = { ["typename"] = "function", ["args"] = { [1] = STRING, }, ["rets"] = { [1] = STRING, }, },
         ["execute"] = { ["typename"] = "function", ["args"] = { [1] = STRING, }, ["rets"] = { [1] = BOOLEAN, [2] = STRING, [3] = NUMBER, }, },
         ["remove"] = { ["typename"] = "function", ["args"] = { [1] = STRING, }, ["rets"] = { [1] = BOOLEAN, [2] = STRING, }, },
         ["time"] = { ["typename"] = "function", ["args"] = {}, ["rets"] = { [1] = NUMBER, }, },
         ["clock"] = { ["typename"] = "function", ["args"] = {}, ["rets"] = { [1] = NUMBER, }, },
         ["exit"] = {
            ["typename"] = "poly",
            ["poly"] = {
               [1] = { ["typename"] = "function", ["args"] = { [1] = NUMBER, [2] = BOOLEAN, }, ["rets"] = {}, },
               [2] = { ["typename"] = "function", ["args"] = { [1] = BOOLEAN, [2] = BOOLEAN, }, ["rets"] = {}, },
            },
         },
      },
   },
   ["package"] = {
      ["typename"] = "record",
      ["fields"] = {
         ["path"] = STRING,
         ["config"] = STRING,
         ["loaded"] = {
            ["typename"] = "map",
            ["keys"] = STRING,
            ["values"] = ANY,
         },
         ["searchers"] = {
            ["typename"] = "array",
            ["elements"] = { ["typename"] = "function", ["args"] = { [1] = STRING, }, ["rets"] = { [1] = ANY, }, },
         },
         ["loaders"] = {
            ["typename"] = "array",
            ["elements"] = { ["typename"] = "function", ["args"] = { [1] = STRING, }, ["rets"] = { [1] = ANY, }, },
         },
      },
   },
   ["table"] = {
      ["typename"] = "record",
      ["fields"] = {
         ["pack"] = { ["typename"] = "function", ["args"] = { [1] = VARARG_ANY, }, ["rets"] = { [1] = TABLE, }, },
         ["unpack"] = {
            ["typename"] = "function",
            ["needs_compat53"] = true,
            ["args"] = { [1] = ARRAY_OF_ALPHA, [2] = NUMBER, [3] = NUMBER, },
            ["rets"] = { [1] = { ["typename"] = "typevar", ["typevar"] = "`a", ["is_va"] = true, },
            }, },
         ["move"] = {
            ["typename"] = "poly",
            ["poly"] = {
               [1] = { ["typename"] = "function", ["args"] = { [1] = ARRAY_OF_ALPHA, [2] = NUMBER, [3] = NUMBER, [4] = NUMBER, }, ["rets"] = { [1] = ARRAY_OF_ALPHA, }, },
               [2] = { ["typename"] = "function", ["args"] = { [1] = ARRAY_OF_ALPHA, [2] = NUMBER, [3] = NUMBER, [4] = NUMBER, [5] = ARRAY_OF_ALPHA, }, ["rets"] = { [1] = ARRAY_OF_ALPHA, }, },
            },
         },
         ["insert"] = {
            ["typename"] = "poly",
            ["poly"] = {
               [1] = { ["typename"] = "function", ["args"] = { [1] = ARRAY_OF_ALPHA, [2] = NUMBER, [3] = ALPHA, }, ["rets"] = {}, },
               [2] = { ["typename"] = "function", ["args"] = { [1] = ARRAY_OF_ALPHA, [2] = ALPHA, }, ["rets"] = {}, },
            },
         },
         ["remove"] = {
            ["typename"] = "poly",
            ["poly"] = {
               [1] = { ["typename"] = "function", ["args"] = { [1] = ARRAY_OF_ALPHA, [2] = NUMBER, }, ["rets"] = { [1] = ALPHA, }, },
               [2] = { ["typename"] = "function", ["args"] = { [1] = ARRAY_OF_ALPHA, }, ["rets"] = { [1] = ALPHA, }, },
            },
         },
         ["concat"] = {
            ["typename"] = "poly",
            ["poly"] = {
               [1] = { ["typename"] = "function", ["args"] = { [1] = ARRAY_OF_STRING, [2] = STRING, }, ["rets"] = { [1] = STRING, }, },
               [2] = { ["typename"] = "function", ["args"] = { [1] = ARRAY_OF_STRING, }, ["rets"] = { [1] = STRING, }, },
            },
         },
         ["sort"] = {
            ["typename"] = "poly",
            ["poly"] = {
               [1] = { ["typename"] = "function", ["args"] = { [1] = ARRAY_OF_ALPHA, }, ["rets"] = {}, },
               [2] = { ["typename"] = "function", ["args"] = { [1] = ARRAY_OF_ALPHA, [2] = { ["typename"] = "function", ["args"] = { [1] = ALPHA, [2] = ALPHA, }, ["rets"] = { [1] = BOOLEAN, }, }, }, ["rets"] = {}, },
            },
         },
      },
   },
   ["string"] = {
      ["typename"] = "record",
      ["fields"] = {
         ["sub"] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = NUMBER, [3] = NUMBER, }, ["rets"] = { [1] = STRING, }, },
         ["match"] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = STRING, }, ["rets"] = { [1] = VARARG_STRING, }, },
         ["rep"] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = NUMBER, }, ["rets"] = { [1] = STRING, }, },
         ["lower"] = { ["typename"] = "function", ["args"] = { [1] = STRING, }, ["rets"] = { [1] = STRING, }, },
         ["upper"] = { ["typename"] = "function", ["args"] = { [1] = STRING, }, ["rets"] = { [1] = STRING, }, },
         ["gsub"] = {
            ["typename"] = "poly",
            ["poly"] = {
               [1] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = STRING, [3] = STRING, [4] = NUMBER, }, ["rets"] = { [1] = STRING, [2] = NUMBER, }, },
               [2] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = STRING, [3] = { ["typename"] = "map", ["keys"] = STRING, ["values"] = STRING, }, [4] = NUMBER, }, ["rets"] = { [1] = STRING, [2] = NUMBER, }, },
               [3] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = STRING, [3] = { ["typename"] = "function", ["args"] = { [1] = VARARG_STRING, }, ["rets"] = { [1] = STRING, }, }, }, ["rets"] = { [1] = STRING, [2] = NUMBER, }, },

            },
         },
         ["gmatch"] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = STRING, }, ["rets"] = {
               [1] = { ["typename"] = "function", ["args"] = {}, ["rets"] = { [1] = STRING, }, },
            }, },
         ["find"] = {
            ["typename"] = "poly",
            ["poly"] = {
               [1] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = STRING, }, ["rets"] = { [1] = NUMBER, [2] = NUMBER, [3] = VARARG_STRING, }, },
               [2] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = STRING, [3] = NUMBER, }, ["rets"] = { [1] = NUMBER, [2] = NUMBER, [3] = VARARG_STRING, }, },
               [3] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = STRING, [3] = NUMBER, [4] = BOOLEAN, }, ["rets"] = { [1] = NUMBER, [2] = NUMBER, [3] = VARARG_STRING, }, },

            },
         },
         ["char"] = { ["typename"] = "function", ["args"] = { [1] = VARARG_NUMBER, }, ["rets"] = { [1] = STRING, }, },
         ["byte"] = {
            ["typename"] = "poly",
            ["poly"] = {
               [1] = { ["typename"] = "function", ["args"] = { [1] = STRING, }, ["rets"] = { [1] = NUMBER, }, },
               [2] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = NUMBER, }, ["rets"] = { [1] = NUMBER, }, },
               [3] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = NUMBER, [3] = NUMBER, }, ["rets"] = { [1] = VARARG_NUMBER, }, },
            },
         },
         ["format"] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = VARARG_ANY, }, ["rets"] = { [1] = STRING, }, },
      },
   },
   ["math"] = {
      ["typename"] = "record",
      ["fields"] = {
         ["max"] = { ["typename"] = "function", ["args"] = { [1] = NUMBER, [2] = NUMBER, }, ["rets"] = { [1] = NUMBER, }, },
         ["min"] = { ["typename"] = "function", ["args"] = { [1] = NUMBER, [2] = NUMBER, }, ["rets"] = { [1] = NUMBER, }, },
         ["floor"] = { ["typename"] = "function", ["args"] = { [1] = NUMBER, }, ["rets"] = { [1] = NUMBER, }, },
         ["randomseed"] = { ["typename"] = "function", ["args"] = { [1] = NUMBER, }, ["rets"] = {}, },
         ["huge"] = NUMBER,
      },
   },
   ["type"] = { ["typename"] = "function", ["args"] = { [1] = ANY, }, ["rets"] = { [1] = STRING, }, },
   ["utf8"] = {
      ["typename"] = "record",
      ["fields"] = {
         ["len"] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = NUMBER, [3] = NUMBER, }, ["rets"] = { [1] = NUMBER, }, },
         ["offset"] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = NUMBER, [3] = NUMBER, }, ["rets"] = { [1] = NUMBER, }, },
      },
   },
   ["ipairs"] = { ["typename"] = "function", ["args"] = { [1] = ARRAY_OF_ALPHA, }, ["rets"] = {
         [1] = { ["typename"] = "function", ["args"] = {}, ["rets"] = { [1] = NUMBER, [2] = ALPHA, }, },
      }, },
   ["pairs"] = { ["typename"] = "function", ["args"] = { [1] = { ["typename"] = "map", ["keys"] = ALPHA, ["values"] = BETA, }, }, ["rets"] = {
         [1] = { ["typename"] = "function", ["args"] = {}, ["rets"] = { [1] = ALPHA, [2] = BETA, }, },
      }, },
   ["pcall"] = { ["typename"] = "function", ["args"] = { [1] = VARARG_ANY, }, ["rets"] = { [1] = BOOLEAN, [2] = ANY, }, },
   ["assert"] = {
      ["typename"] = "poly",
      ["poly"] = {
         [1] = { ["typename"] = "function", ["args"] = { [1] = ALPHA, }, ["rets"] = { [1] = ALPHA, }, },
         [2] = { ["typename"] = "function", ["args"] = { [1] = ALPHA, [2] = BETA, }, ["rets"] = { [1] = ALPHA, }, },
      },
   },
   ["select"] = {
      ["typename"] = "poly",
      ["poly"] = {
         [1] = { ["typename"] = "function", ["args"] = { [1] = NUMBER, [2] = ALPHA, }, ["rets"] = { [1] = ALPHA, }, },
         [2] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = VARARG_ANY, }, ["rets"] = { [1] = NUMBER, }, },
      },
   },
   ["print"] = {
      ["typename"] = "poly",
      ["poly"] = {
         [1] = { ["typename"] = "function", ["args"] = { [1] = ANY, }, ["rets"] = {}, },
         [2] = { ["typename"] = "function", ["args"] = { [1] = ANY, [2] = ANY, }, ["rets"] = {}, },
         [3] = { ["typename"] = "function", ["args"] = { [1] = ANY, [2] = ANY, [3] = ANY, }, ["rets"] = {}, },
         [4] = { ["typename"] = "function", ["args"] = { [1] = ANY, [2] = ANY, [3] = ANY, [4] = ANY, }, ["rets"] = {}, },
         [5] = { ["typename"] = "function", ["args"] = { [1] = ANY, [2] = ANY, [3] = ANY, [4] = ANY, [5] = ANY, }, ["rets"] = {}, },
      },
   },
   ["tostring"] = { ["typename"] = "function", ["args"] = { [1] = ANY, }, ["rets"] = { [1] = STRING, }, },
   ["tonumber"] = { ["typename"] = "function", ["args"] = { [1] = ANY, [2] = NUMBER, }, ["rets"] = { [1] = NUMBER, }, },
   ["error"] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = NUMBER, }, ["rets"] = {}, },
   ["debug"] = {
      ["typename"] = "record",
      ["fields"] = {
         ["traceback"] = { ["typename"] = "function", ["args"] = { [1] = STRING, [2] = NUMBER, }, ["rets"] = { [1] = STRING, }, },
      },
   },
}

for _, t in pairs(standard_library) do
   fill_field_order(t)
   if t.typename == "typetype" then
      fill_field_order(t.def)
   end
end

local compat53_code_cache = {}

local function add_compat53_entries(program, used_set)
   if not next(used_set) then
      return
   end

   local used_list = {}
   for name, _ in pairs(used_set) do
      table.insert(used_list, name)
   end
   table.sort(used_list)

   for i, name in ipairs(used_list) do
      local mod, fn = name:match("([^.]*)%.(.*)")
      local errs = {}
      local text
      local code = compat53_code_cache[name]
      if not code then

         if name == "table.unpack" then
            text = "local _tl_table_unpack = unpack or table.unpack"
         else
            text = ("local $NAME = require('compat53.module').$NAME or $NAME"):gsub("$NAME", name)
         end
         local tokens = tl.lex(text)
         local _
         _, code = tl.parse_program(tokens, {}, "@internal")
         tl.type_check(code, nil, nil, nil, nil, nil, true)
         code = code[1]
         compat53_code_cache[name] = code
      end
      table.insert(program, i, code)
   end
   program.y = 1
end

local function get_stdlib_compat53(lax)
   if lax then
      return {
         ["utf8"] = true,
      }
   else
      return {
         ["io"] = true,
         ["math"] = true,
         ["string"] = true,
         ["table"] = true,
         ["utf8"] = true,
         ["coroutine"] = true,
         ["os"] = true,
         ["package"] = true,
         ["debug"] = true,
         ["load"] = true,
         ["loadfile"] = true,
         ["assert"] = true,
         ["pairs"] = true,
         ["ipairs"] = true,
         ["pcall"] = true,
         ["xpcall"] = true,
         ["rawlen"] = true,
      }
   end
end

local function init_globals(lax)
   local globals = {}
   local stdlib_compat53 = get_stdlib_compat53(lax)

   for name, typ in pairs(standard_library) do
      globals[name] = { ["t"] = typ, ["needs_compat53"] = stdlib_compat53[name], ["is_const"] = true, }
   end

   return globals
end

function tl.type_check(ast, lax, filename, modules, result, globals, skip_compat53)
   modules = modules or {}
   result = result or {
      ["syntax_errors"] = {},
      ["type_errors"] = {},
      ["unknowns"] = {},
   }
   globals = globals or init_globals()

   local stdlib_compat53 = get_stdlib_compat53(lax)

   local st = { [1] = globals, }

   local all_needs_compat53 = {}

   local errors = result.type_errors or {}
   local unknowns = result.unknowns or {}
   local module_type

   local function find_var(name)
      if name == "_G" then

         local globals = {}
         for k, v in pairs(st[1]) do
            globals[k] = v.t
         end
         local field_order = {}
         for k, _ in pairs(globals) do
            table.insert(field_order, k)
         end
         return {
            ["typename"] = "record",
            ["field_order"] = field_order,
            ["fields"] = globals,
         }, false
      end
      for i = #st, 1, -1 do
         local scope = st[i]
         if scope[name] then
            if i == 1 and scope[name].needs_compat53 then
               all_needs_compat53[name] = true
            end
            local typ = scope[name].t

            return typ, scope[name].is_const
         end
      end
   end

   local function infer_var(emptytable, t, node)
      local is_global = (emptytable.declared_at and emptytable.declared_at.kind == "global_declaration")
      local nst = is_global and 1 or #st
      for i = nst, 1, -1 do
         local scope = st[i]
         if scope[emptytable.assigned_to] then
            scope[emptytable.assigned_to] = {
               ["t"] = t,
               ["is_const"] = false,
            }
            t.inferred_at = node
            t.inferred_at_file = filename
         end
      end
   end

   local function find_global(name)
      local scope = st[1]
      if scope[name] then
         return scope[name].t, scope[name].is_const
      end
   end

   local function resolve_tuple(t)
      if t.typename == "tuple" then
         t = t[1]
      end
      if t == nil then
         return NIL
      end
      return t
   end

   local function error_in_type(t, msg, ...)
      local n = select("#", ...)
      if n > 0 then
         local showt = {}
         for i = 1, n do
            local t = select(i, ...)
            if t.typename == "invalid" then
               return nil
            end
            showt[i] = show_type(t)
         end
         msg = msg:format(_tl_table_unpack(showt))
      end

      return {
         ["y"] = t.y,
         ["x"] = t.x,
         ["msg"] = msg,
         ["filename"] = filename,
      }
   end

   local function type_error(t, msg, ...)
      local e = error_in_type(t, msg, ...)
      if e then
         table.insert(errors, e)
         return true
      else
         return false
      end
   end

   local function node_error(node, msg, ...)
      local ok = type_error(node, msg, ...)
      node.type = INVALID
      return node.type
   end

   local function resolve_nominal(t, typevars)
      local typetype = find_var(t.name)
      if not typetype then
         type_error(t, "unknown type " .. t.name)
         return { ["typename"] = "bad_nominal", ["name"] = t.name, }
      end
      if typetype.typename == "typetype" then
         local def = typetype.def
         if t.typevals and def.typevars then
            if #t.typevals ~= #def.typevars then
               type_error(t, "mismatch in number of type arguments")
               return { ["typename"] = "bad_nominal", ["name"] = t.name, }
            end

            local newtypevars = {}
            for k, v in pairs(typevars or {}) do
               newtypevars[k] = v
            end
            for i, tt in ipairs(t.typevals) do
               newtypevars[def.typevars[i].typevar] = tt
            end
            return resolve_typevars(def, newtypevars)
         elseif t.typevals then
            type_error(t, "spurious type arguments")
         elseif def.typevars then
            type_error(t, "missing type arguments in %s", def)
         end
         return def
      else
         type_error(t, t.name .. " is not a type")
         return { ["typename"] = "bad_nominal", ["name"] = t.name, }
      end
   end

   local function resolve_unary(t, typevars)
      t = resolve_tuple(t)
      if t.typename == "nominal" then
         return resolve_nominal(t, typevars)
      end
      return t
   end

   local function terr(t, s, ...)
      return { [1] = error_in_type(t, s, ...), }
   end

   local CompareTypes = {}

   local function compare_typevars(t1, t2, typevars, comp)
      if t1.typevar == t2.typevar then
         if not typevars then
            return true
         end
         local has_t1 = not not typevars[t1.typevar]
         local has_t2 = not not typevars[t2.typevar]
         if has_t1 == has_t2 then
            return true
         end
      end
      if not typevars then
         return false, terr(t1, "got %s, expected %s", t1, t2)
      end
      local function cmp(k, v, a, b)
         if typevars[k] then
            return comp(a, b, typevars)
         else
            typevars[k] = resolve_typevars(v, typevars)
            return true
         end
      end
      if t2.typename == "typevar" then
         return cmp(t2.typevar, t1, t1, typevars[t2.typevar])
      else
         return cmp(t1.typevar, t2, typevars[t1.typevar], t2)
      end
   end

   local function add_errs_prefixing(src, dst, prefix, node)
      if not src then
         return
      end
      for i, err in ipairs(src) do
         err.msg = prefix .. err.msg

         if node and node.y and (not err.y or (node.y > err.y or (node.y == err.y and node.x > err.x))) then
            err.y = node.y
            err.x = node.x
         end
         table.insert(dst, err)
      end
   end

   local is_a

   local TypeGetter = {}

   local function match_record_fields(t1, t2, typevars, cmp)
      cmp = cmp or is_a
      local fielderrs = {}
      for _, k in ipairs(t1.field_order) do
         local f = t1.fields[k]
         local t2k = t2(k)
         if t2k == nil then
            if not lax then
               table.insert(fielderrs, error_in_type(f, "unknown field " .. k))
            end
         else
            local match, errs = is_a(f, t2k, typevars)
            add_errs_prefixing(errs, fielderrs, "record field doesn't match: " .. k .. ": ")
         end
      end
      if #fielderrs > 0 then
         return false, fielderrs
      end
      return true
   end

   local function match_fields_to_record(t1, t2, typevars, cmp)
      return match_record_fields(t1, function(k)          return t2.fields[k] end, typevars, cmp)
   end

   local function match_fields_to_map(t1, t2, typevars)
      if not match_record_fields(t1, function(_)             return t2.values end, typevars) then
         return false, { [1] = error_in_type(t1, "not all fields have type %s", t2.values), }
      end
      return true
   end

   local function arg_check(cmp, a, b, typevars, at, n, errs)
      local matches, match_errs = cmp(a, b, typevars)
      if not matches then
         add_errs_prefixing(match_errs, errs, "argument " .. n .. ": ", at)
         return false
      end
      return true
   end

   local function same_type(t1, t2, typevars)
      assert(type(t1) == "table")
      assert(type(t2) == "table")

      if t1.typename == "typevar" or t2.typename == "typevar" then
         return compare_typevars(t1, t2, typevars, same_type)
      end

      if t1.typename ~= t2.typename then
         return false, terr(t1, "got %s, expected %s", t1, t2)
      end
      if t1.typename == "array" then
         return same_type(t1.elements, t2.elements)
      elseif t1.typename == "map" then
         return same_type(t1.keys, t2.keys) and same_type(t1.values, t2.values)
      elseif t1.typename == "nominal" then
         return t1.name == t2.name
      elseif t1.typename == "record" then
         return match_fields_to_record(t1, t2, typevars, same_type)
      elseif t1.typename == "function" then
         if #t1.args ~= #t2.args then
            return false, terr(t1, "different number of input arguments: got " .. #t1.args .. ", expected " .. #t2.args)
         end
         if #t1.rets ~= #t2.rets then
            return false, terr(t1, "different number of return values: got " .. #t1.args .. ", expected " .. #t2.args)
         end
         local all_errs = {}
         for i = 1, #t1.args do
            arg_check(same_type, t1.args[i], t2.args[i], typevars, t1, i, all_errs)
         end
         for i = 1, #t1.rets do
            local ok, errs = same_type(t1.rets[i], t2.rets[i])
            add_errs_prefixing(errs, all_errs, "return " .. i, t1)
         end
         if #all_errs == 0 then
            return true
         else
            return false, all_errs
         end
      elseif t1.typename == "arrayrecord" then
         local ok, errs = same_type(t1.elements, t2.elements)
         if not ok then
            return ok, errs
         end
         return match_fields_to_record(t1, t2, typevars, same_type)
      end
      return true
   end

   local function is_vararg(t)
      return t.args and #t.args > 0 and t.args[#t.args].is_va
   end

   local function combine_errs(...)
      local errs
      for i = 1, select("#", ...) do
         local e = select(i, ...)
         if e then
            errs = errs or {}
            for _, err in ipairs(e) do
               table.insert(errs, err)
            end
         end
      end
      if not errs then
         return true
      else
         return false, errs
      end
   end

   is_a = function(t1, t2, typevars, for_equality)
      assert(type(t1) == "table")
      assert(type(t2) == "table")

      if lax and (is_unknown(t1) or is_unknown(t2)) then
         return true
      end

      if t1.typename == "nil" then
         return true
      end

      if t2.typename ~= "tuple" then
         t1 = resolve_tuple(t1)
      end
      if t2.typename == "tuple" and t1.typename ~= "tuple" then
         t1 = {
            ["typename"] = "tuple",
            [1] = t1,
         }
      end

      if t1.typename == "typevar" or t2.typename == "typevar" then
         return compare_typevars(t1, t2, typevars, is_a)
      end

      if t2.typename == "any" then
         return true
      elseif t2.typename == "poly" then
         for _, t in ipairs(t2.poly) do
            if is_a(t1, t, typevars, for_equality) then
               return true
            end
         end
         return false, terr(t1, "no match with poly")
      elseif t1.typename == "poly" then
         for _, t in ipairs(t1.poly) do
            if is_a(t, t2, typevars, for_equality) then
               return true
            end
         end
         return false, terr(t1, "poly has no match")
      elseif t1.typename == "nominal" and t2.typename == "nominal" and t2.name == "any" then
         return true
      elseif t1.typename == "nominal" and t2.typename == "nominal" then
         if t1.name == t2.name then
            if t1.typevals == nil and t2.typevals == nil then
               return true
            elseif t1.typevals and t2.typevals and #t1.typevals == #t2.typevals then
               local all_errs = {}
               for i = 1, #t1.typevals do
                  local ok, errs = same_type(t2.typevals[i], t1.typevals[i], typevars)
                  add_errs_prefixing(errs, all_errs, "type parameter <" .. show_type(t1.typevals[i]) .. ">: ", t1)
               end
               if #all_errs == 0 then
                  return true
               else
                  return false, all_errs
               end
            end
         end
         return false, terr(t1, t1.name .. " is not a " .. t2.name)
      elseif t1.typename == "enum" and t2.typename == "string" then
         local ok = (for_equality) and
         (t2.tk and t1.enumset[unquote(t2.tk)]) or
         true
         if ok then
            return true
         else
            return false, terr(t1, "enum is incompatible with %s", t2)
         end
      elseif t1.typename == "string" and t2.typename == "enum" then
         local ok = t1.tk and t2.enumset[unquote(t1.tk)]
         if ok then
            return true
         else
            return false, terr(t1, "%s is not a member of " .. t2.name, t1)
         end
      elseif t1.typename == "nominal" or t2.typename == "nominal" then
         local t1u = resolve_unary(t1, typevars)
         local t2u = resolve_unary(t2, typevars)
         local ok, errs = is_a(t1u, t2u, typevars)
         if errs and #errs == 1 then
            if errs[1].msg:match("^got ") then


               errs = terr(t1, "got %s, expected %s", t1, t2)
            end
         end
         return ok, errs
      elseif t1.typename == "emptytable" and (t2.typename == "array" or t2.typename == "map" or t2.typename == "record" or t2.typename == "arrayrecord") then
         return true
      elseif t2.typename == "array" then
         if t1.typename == "array" or t1.typename == "arrayrecord" then
            return is_a(t1.elements, t2.elements, typevars)
         elseif t1.typename == "map" then
            local _, errs_keys = is_a(t1.keys, NUMBER, typevars)
            local _, errs_values = is_a(t1.values, t2.elements, typevars)
            return combine_errs(errs_keys, errs_values)
         end
      elseif t2.typename == "record" then
         if t1.typename == "record" or t1.typename == "arrayrecord" then
            return match_fields_to_record(t1, t2, typevars)
         elseif t1.typename == "map" then
            if not is_a(t1.keys, STRING, typevars) then
               return false, terr(t1, "map has non-string keys")
            end
            for _, fname in ipairs(t2.field_order) do
               local ftype = t2.fields[fname]
               if not is_a(t1.values, ftype, typevars) then
                  return false, terr(t1, "field " .. fname .. " is of type %s", ftype)
               end
            end
            return true
         end
      elseif t2.typename == "arrayrecord" then
         if t1.typename == "array" then
            return is_a(t1.elements, t2.elements, typevars)
         elseif t1.typename == "record" then
            return match_fields_to_record(t1, t2, typevars)
         elseif t1.typename == "arrayrecord" then
            if not is_a(t1.elements, t2.elements, typevars) then
               return false, terr(t1, "array parts have incompatible element types")
            end
            return match_fields_to_record(t1, t2, typevars)
         end
      elseif t2.typename == "map" then
         if t1.typename == "map" then
            local _, errs_keys = is_a(t1.keys, t2.keys, typevars)
            local _, errs_values = is_a(t2.values, t1.values, typevars)
            if t2.values.typename == "any" then
               errs_values = {}
            end
            return combine_errs(errs_keys, errs_values)
         elseif t1.typename == "array" then
            local _, errs_keys = is_a(NUMBER, t2.keys, typevars)
            local _, errs_values = is_a(t1.elements, t2.values, typevars)
            return combine_errs(errs_keys, errs_values)
         elseif t1.typename == "record" or t1.typename == "arrayrecord" then
            if not is_a(t2.keys, STRING, typevars) then
               return false, terr(t1, "can't match a record to a map with non-string keys")
            end
            if t2.keys.typename == "enum" then
               for _, k in ipairs(t1.field_order) do
                  if not t2.keys.enumset[k] then
                     return false, terr(t1, "key is not an enum value: " .. k)
                  end
               end
            end
            return match_fields_to_map(t1, t2, typevars)
         end
      elseif t1.typename == "function" and t2.typename == "function" then
         local all_errs = {}
         if (not is_vararg(t2)) and #t1.args > #t2.args then
            table.insert(all_errs, error_in_type(t1, "incompatible number of arguments"))
         else
            for i = (t1.is_method and 2 or 1), #t1.args do
               arg_check(is_a, t1.args[i], t2.args[i] or ANY, typevars, nil, i, all_errs)
            end
         end
         local diff_by_va = #t2.rets - #t1.rets == 1 and t2.rets[#t2.rets].is_va
         if #t1.rets < #t2.rets and not diff_by_va then
            table.insert(all_errs, error_in_type(t1, "incompatible number of returns"))
         else
            local nrets = #t2.rets
            if diff_by_va then
               nrets = nrets - 1
            end
            for i = 1, nrets do
               local ok, errs = is_a(t1.rets[i], t2.rets[i], typevars)
               add_errs_prefixing(errs, all_errs, "return " .. i .. ": ")
            end
         end
         if #all_errs == 0 then
            return true
         else
            return false, all_errs
         end
      elseif lax and ((not for_equality) and t2.typename == "boolean") then

         return true
      elseif t1.typename == t2.typename then
         return true
      end
      return false, terr(t1, "got %s, expected %s", t1, t2)
   end

   local function assert_is_a(node, t1, t2, typevars, context, name)
      t1 = resolve_tuple(t1)
      t2 = resolve_tuple(t2)
      if lax and (is_unknown(t1) or is_unknown(t2)) then
         return
      end

      if t2.typename == "unknown_emptytable_value" then
         if same_type(t2.emptytable_type.keys, NUMBER) then
            infer_var(t2.emptytable_type, { ["typename"] = "array", ["elements"] = t1, }, node)
         else
            infer_var(t2.emptytable_type, { ["typename"] = "map", ["keys"] = t2.emptytable_type.keys, ["values"] = t1, }, node)
         end
         return
      elseif t2.typename == "emptytable" then
         if t1.typename == "array" or t1.typename == "map" or t1.typename == "record" or t1.typename == "arrayrecord" then
            infer_var(t2, t1, node)
         elseif t1.typename ~= "emptytable" then
            node_error(node, "in " .. context .. ": " .. (name and (name .. ": ") or "") .. "assigning %s to a variable declared with {}", t1)
         end
         return
      end

      local match, match_errs = is_a(t1, t2, typevars)
      add_errs_prefixing(match_errs, errors, "in " .. context .. ": " .. (name and (name .. ": ") or ""), node)
   end

   local type_check_function_call
   do
      local function try_match_func_args(node, f, args, is_method, argdelta)
         local ok = true
         local typevars = {}
         local errs = {}

         if is_method then
            argdelta = -1
         elseif not argdelta then
            argdelta = 0
         end

         if f.is_method and not is_method and not is_a(args[1], f.args[1], typevars) then
            table.insert(errs, { ["y"] = node.y, ["x"] = node.x, ["msg"] = "invoked method as a regular function: use ':' instead of '.'", ["filename"] = filename, })
            return nil, errs
         end

         local va = is_vararg(f)
         local nargs = va and
         math.max(#args, #f.args) or
         math.min(#args, #f.args)

         for a = 1, nargs do
            local arg = args[a]
            local farg = f.args[a] or (va and f.args[#f.args])
            if arg == nil then
               if farg.is_va then
                  break
               end
               if not lax then
                  ok = false
                  table.insert(errs, { ["y"] = node.y, ["x"] = node.x, ["msg"] = "error in argument " .. (a + argdelta) .. ": missing argument of type " .. show_type(farg, typevars), ["filename"] = filename, })
               end
            else
               local at = node.e2 and node.e2[a] or node
               if not arg_check(is_a, arg, farg, typevars, at, (a + argdelta), errs) then
                  ok = false
                  break
               end
            end
         end
         if ok == true then
            f.rets.typename = "tuple"
            return resolve_typevars(f.rets, typevars)
         end
         return nil, errs
      end

      type_check_function_call = function(node, func, args, is_method, argdelta)
         assert(type(func) == "table")
         assert(type(args) == "table")

         func = resolve_unary(func, {})

         args = args or {}
         local poly = func.typename == "poly" and func or { ["poly"] = { [1] = func, }, }
         local first_errs
         local expects = {}

         for _, f in ipairs(poly.poly) do
            if f.typename ~= "function" then
               if lax and is_unknown(f) then
                  return UNKNOWN
               end
               return node_error(node, "not a function: %s", f)
            end
            table.insert(expects, tostring(#f.args or 0))
            local va = is_vararg(f)
            if #args == (#f.args or 0) or (va and #args > #f.args) then
               local matched, errs = try_match_func_args(node, f, args, is_method, argdelta)
               if matched then
                  return matched
               end
               first_errs = first_errs or errs
            end
         end

         for _, f in ipairs(poly.poly) do
            if #args < (#f.args or 0) then
               local matched, errs = try_match_func_args(node, f, args, is_method, argdelta)
               if matched then
                  return matched
               end
               first_errs = first_errs or errs
            end
         end

         for _, f in ipairs(poly.poly) do
            if is_vararg(f) and #args > (#f.args or 0) then
               local matched, errs = try_match_func_args(node, f, args, is_method, argdelta)
               if matched then
                  return matched
               end
               first_errs = first_errs or errs
            end
         end

         if not first_errs then
            node_error(node, "wrong number of arguments (given " .. #args .. ", expects " .. table.concat(expects, " or ") .. ")")
         else
            for _, err in ipairs(first_errs) do
               table.insert(errors, err)
            end
         end

         poly.poly[1].rets.typename = "tuple"
         return poly.poly[1].rets
      end
   end

   local unknown_dots = {}

   local function add_unknown(node, name)
      table.insert(unknowns, { ["y"] = node.y, ["x"] = node.x, ["msg"] = name, ["filename"] = filename, })
   end

   local function add_unknown_dot(node, name)
      if not unknown_dots[name] then
         unknown_dots[name] = true
         add_unknown(node, name)
      end
   end

   local function get_self_type(t)
      if t.typename == "typetype" then
         return t.def
      else
         return t
      end
   end

   local function match_record_key(node, tbl, key, orig_tbl)
      assert(type(tbl) == "table")
      assert(type(key) == "table")

      tbl = resolve_unary(tbl)
      local type_description = tbl.typename
      if tbl.typename == "string" then
         tbl = find_var("string")
      end

      if lax and (is_unknown(tbl) or tbl.typename == "typevar") then
         if node.e1.kind == "variable" and node.op.op ~= "@funcall" then
            add_unknown_dot(node, node.e1.tk .. "." .. key.tk)
         end
         return UNKNOWN
      end

      tbl = get_self_type(tbl)

      if tbl.typename == "emptytable" then
 elseif tbl.typename == "record" or tbl.typename == "arrayrecord" then
         assert(tbl.fields, "record has no fields!?")

         if key.typename == "string" or key.kind == "identifier" then
            if tbl.fields[key.tk] then
               return tbl.fields[key.tk]
            end
         end
      else
         node_error(node, "cannot index something that is not a record: %s", tbl)
         return INVALID
      end

      if lax then
         if node.e1.kind == "variable" and node.op.op ~= "@funcall" then
            add_unknown_dot(node, node.e1.tk .. "." .. key.tk)
         end
         return UNKNOWN
      end

      local description
      if node.e1.kind == "variable" then
         description = type_description .. " '" .. node.e1.tk .. "'"
      else
         description = "type " .. show_type(resolve_tuple(orig_tbl))
      end

      return node_error(node, "invalid key '" .. key.tk .. "' in " .. description)
   end

   local function add_var(var, valtype, is_const)
      st[#st][var] = { ["t"] = valtype, ["is_const"] = is_const, }
   end

   local function add_global(var, valtype, is_const)
      st[1][var] = { ["t"] = valtype, ["is_const"] = is_const, }
   end

   local function begin_function_scope(node, recurse)
      table.insert(st, {})
      local args = {}
      for i, arg in ipairs(node.args) do
         local t = arg.decltype
         if not t then
            t = { ["typename"] = "unknown", }
            if lax and (not (i == 1 and arg.tk == "self")) then
               add_unknown(arg, arg.tk)
            end
         end
         if arg.tk == "..." then
            t.is_va = true
            if i ~= #node.args then
               node_error(node, "'...' can only be last argument")
            end
         end
         table.insert(args, t)
         add_var(arg.tk, t)
      end
      add_var("@return", node.rets or { ["typename"] = "tuple", })
      if recurse then
         add_var(node.name.tk, {
            ["typename"] = "function",
            ["args"] = args,
            ["rets"] = node.rets,
         })
      end
   end

   local function end_function_scope()
      table.remove(st)
   end

   local function flatten_list(list)
      local exps = {}
      for i = 1, #list - 1 do
         table.insert(exps, resolve_unary(list[i]))
      end
      if #list > 0 then
         local last = list[#list]
         if last.typename == "tuple" then
            for _, val in ipairs(last) do
               table.insert(exps, val)
            end
         else
            table.insert(exps, last)
         end
      end
      return exps
   end

   local function get_assignment_values(vals, wanted)
      local ret = {}
      if vals == nil then
         return ret
      end

      for i = 1, #vals - 1 do
         ret[i] = vals[i]
      end
      local last = vals[#vals]

      if last.typename == "tuple" then
         for _, v in ipairs(last) do
            table.insert(ret, v)
         end

      elseif last.is_va and #ret < wanted then
         while #ret < wanted do
            table.insert(ret, last)
         end

      else
         table.insert(ret, last)
      end
      return ret
   end

   local function get_rets(rets)
      if lax and (#rets == 0) then
         return { [1] = { ["typename"] = "unknown", ["is_va"] = true, }, }
      end
      return rets
   end

   local function match_all_record_field_names(node, a, field_names, errmsg)
      local t
      local typevars = {}
      for _, k in ipairs(field_names) do
         local f = a.fields[k]
         if not t then
            t = f
         else
            if not same_type(f, t, typevars) then
               t = nil
               break
            end
         end
      end
      if t then
         return t
      else
         return node_error(node, errmsg)
      end
   end

   local function type_check_index(node, idxnode, a, b)
      local orig_a = a
      local orig_b = b
      a = resolve_unary(a)
      b = resolve_unary(b)

      if a.typename == "array" or a.typename == "arrayrecord" and is_a(b, NUMBER) then
         return a.elements
      elseif a.typename == "emptytable" then
         if a.keys == nil then
            a.keys = b
            a.keys_inferred_at = node
            a.keys_inferred_at_file = filename
         else
            if not is_a(b, a.keys) then
               local inferred = " (type of keys inferred at " .. a.keys_inferred_at_file .. ":" .. a.keys_inferred_at.y .. ":" .. a.keys_inferred_at.x .. ": )"
               return node_error(idxnode, "inconsistent index type: %s, expected %s" .. inferred, b, a.keys)
            end
         end
         return { ["y"] = node.y, ["x"] = node.x, ["typename"] = "unknown_emptytable_value", ["emptytable_type"] = a, }
      elseif a.typename == "map" then
         if is_a(b, a.keys) then
            return a.values
         else
            return node_error(idxnode, "wrong index type: %s, expected %s", orig_b, a.keys)
         end
      elseif node.e2.kind == "string" then
         return match_record_key(node, a, { ["typename"] = "string", ["tk"] = assert(node.e2.conststr), }, orig_a)
      elseif (a.typename == "record" or a.typename == "arrayrecord") and b.typename == "enum" then
         local field_names = {}
         for k, _ in pairs(b.enumset) do
            table.insert(field_names, k)
         end
         table.sort(field_names)
         for _, k in ipairs(field_names) do
            if not a.fields[k] then
               return node_error(idxnode, "enum value '" .. k .. "' is not a field in %s", a)
            end
         end
         return match_all_record_field_names(idxnode, a, field_names,
"cannot index, not all enum values map to record fields of the same type")
      elseif (a.typename == "record" or a.typename == "arrayrecord") and is_a(b, STRING) then
         return match_all_record_field_names(idxnode, a, a.field_order,
"cannot index, not all fields in record have the same type")
      elseif lax and is_unknown(a) then
         return UNKNOWN
      else
         return node_error(idxnode, "cannot index object of type %s with %s", orig_a, orig_b)
      end
   end

   local function expand_type(old, new)
      if not old then
         return new
      else
         if not is_a(new, old) then
            if old.typename == "poly" then
               table.insert(old.poly, new)
            else
               return {
                  ["typename"] = "poly",
                  ["poly"] = {
                     [1] = old,
                     [2] = new,
                  },
               }
            end
         end
      end
      return old
   end

   local function find_in_scope(exp)
      if exp.kind == "variable" then
         local name = exp.tk
         local parent_scope = st[#st - 1]
         local type_in_scope = parent_scope[name] and parent_scope[name].t
         if type_in_scope and type_in_scope.typename == "typetype" then
            type_in_scope = type_in_scope.def
         end
         return type_in_scope
      elseif exp.kind == "op" and exp.op.op == "." then
         local t = find_in_scope(exp.e1)
         if not t then
            return nil
         end
         while exp.e2.kind == "op" and exp.e2.op.op == "." do
            t = t.fields[exp.e2.e1.tk]
            if not t then
               return nil
            end
            exp = exp.e2
         end
         t = t.fields[exp.e2.tk]
         return t
      end
   end

   local visit_node = {}

   visit_node.cbs = {
      ["statements"] = {
         ["before"] = function()
            table.insert(st, {})
         end,
         ["after"] = function(node, children)
            table.remove(st)

            node.type = { ["typename"] = "none", }
         end,
      },
      ["local_declaration"] = {
         ["after"] = function(node, children)
            local vals = get_assignment_values(children[2], #node.vars)
            for i, var in ipairs(node.vars) do
               local decltype = node.decltype and node.decltype[i]
               local infertype = vals and vals[i]
               if lax and infertype and infertype.typename == "nil" then
                  infertype = nil
               end
               if decltype and infertype then
                  assert_is_a(node.vars[i], infertype, decltype, {}, "local declaration", var.tk)
               end
               local t = decltype or infertype
               if t == nil then
                  t = { ["typename"] = "unknown", }
                  if lax then
                     add_unknown(node, var.tk)
                  else
                     if node.exps then
                        node_error(node.vars[i], "assignment in declaration did not produce an initial value for variable '" .. var.tk .. "'")
                     else
                        node_error(node.vars[i], "variable '" .. var.tk .. "' has no type or initial value")
                     end
                  end
               elseif t.typename == "emptytable" then
                  t.declared_at = node
                  t.assigned_to = var.tk
               end
               add_var(var.tk, t, var.is_const)
            end
            node.type = { ["typename"] = "none", }
         end,
      },
      ["global_declaration"] = {
         ["after"] = function(node, children)
            local vals = get_assignment_values(children[2], #node.vars)
            for i, var in ipairs(node.vars) do
               local decltype = node.decltype and node.decltype[i]
               local infertype = vals and vals[i]
               if lax and infertype and infertype.typename == "nil" then
                  infertype = nil
               end
               if decltype and infertype then
                  assert_is_a(node.vars[i], infertype, decltype, {}, "global declaration", var.tk)
               end
               local t = decltype or infertype
               local existing, existing_is_const = find_global(var.tk)
               if existing then
                  if infertype and existing_is_const then
                     node_error(var, "cannot reassign to <const> global: " .. var.tk)
                  end
                  if existing_is_const == true and not var.is_const then
                     node_error(var, "global was previously declared as <const>: " .. var.tk)
                  end
                  if existing_is_const == false and var.is_const then
                     node_error(var, "global was previously declared as not <const>: " .. var.tk)
                  end
                  if not same_type(existing, t) then
                     node_error(var, "cannot redeclare global with a different type: previous type of " .. var.tk .. " is %s", existing)
                  end
               else
                  if t == nil then
                     t = { ["typename"] = "unknown", }
                     if lax then
                        add_unknown(node, var.tk)
                     end
                  elseif t.typename == "emptytable" then
                     t.declared_at = node
                     t.assigned_to = var.tk
                  end
                  add_global(var.tk, t, var.is_const)
               end
            end
            node.type = { ["typename"] = "none", }
         end,
      },
      ["assignment"] = {
         ["after"] = function(node, children)
            local vals = get_assignment_values(children[2], #children[1])
            local exps = flatten_list(vals)
            for i, vartype in ipairs(children[1]) do
               local varnode = node.vars[i]
               if varnode.is_const then
                  node_error(varnode, "cannot assign to <const> variable")
               end
               if vartype then
                  local val = exps[i]
                  if val then
                     assert_is_a(varnode, val, vartype, {}, "assignment")
                  else
                     node_error(varnode, "variable is not being assigned a value")
                  end
               else
                  node_error(varnode, "unknown variable")
               end
            end
            node.type = { ["typename"] = "none", }
         end,
      },
      ["if"] = {
         ["after"] = function(node, children)
            node.type = { ["typename"] = "none", }
         end,
      },
      ["forin"] = {
         ["before"] = function()
            table.insert(st, {})
         end,
         ["before_statements"] = function(node)
            local exp1 = node.exps[1]
            local exp1type = resolve_tuple(exp1.type)
            if exp1type.typename == "function" then
               add_var(node.vars[1].tk, exp1type.rets[1])
               if node.vars[2] then
                  add_var(node.vars[2].tk, exp1type.rets[2])
               end

               if exp1.op and exp1.op.op == "@funcall" then
                  local t = resolve_unary(exp1.e2.type)
                  if exp1.e1.tk == "pairs" and not (t.typename == "map" or t.typename == "record") then
                     if not (lax and is_unknown(t)) then
                        node_error(exp1, "attempting pairs loop on something that's not a map or record: %s", exp1.e2.type)
                     end
                  elseif exp1.e1.tk == "ipairs" and not (t.typename == "array" or t.typename == "arrayrecord") then
                     if not (lax and (is_unknown(t) or t.typename == "emptytable")) then
                        node_error(exp1, "attempting ipairs loop on something that's not an array: %s", exp1.e2.type)
                     end
                  end
               end
            else
               if not (lax and is_unknown(exp1type)) then
                  node_error(exp1, "expression in for loop does not return an iterator")
               end
            end
         end,
         ["after"] = function(node, children)
            table.remove(st)
            node.type = { ["typename"] = "none", }
         end,
      },
      ["fornum"] = {
         ["before"] = function(node)
            table.insert(st, {})
            add_var(node.var.tk, NUMBER)
         end,
         ["after"] = function(node, children)
            table.remove(st)
            node.type = { ["typename"] = "none", }
         end,
      },
      ["return"] = {
         ["after"] = function(node, children)
            local rets = assert(find_var("@return"))
            if #children[1] > #rets and not lax then
               node_error(node, "excess return values, expected " .. #rets .. " got " .. #children[1])
            end
            for i = 1, math.min(#children[1], #rets) do
               assert_is_a(node.exps[i], children[1][i], rets[i], nil, "return value")
            end


            if #st == 2 then
               module_type = resolve_unary(children[1])
            end

            node.type = { ["typename"] = "none", }
         end,
      },
      ["variables"] = {
         ["after"] = function(node, children)
            node.type = children


            local n = #children
            if n > 0 and children[n].typename == "tuple" then
               local tuple = children[n]
               for i, c in ipairs(tuple) do
                  children[n + i - 1] = c
               end
            end

            node.type.typename = "tuple"
         end,
      },
      ["table_literal"] = {
         ["after"] = function(node, children)
            node.type = {
               ["y"] = node.y,
               ["x"] = node.x,
               ["typename"] = "emptytable",
            }
            local is_record = false
            local is_array = false
            local is_map = false
            for _, child in ipairs(children) do
               assert(child.typename == "table_item")
               if child.kname then
                  is_record = true
                  if not node.type.fields then
                     node.type.fields = {}
                     node.type.field_order = {}
                  end
                  node.type.fields[child.kname] = child.vtype
                  table.insert(node.type.field_order, child.kname)
               elseif child.ktype.typename == "number" then
                  is_array = true
                  node.type.elements = expand_type(node.type.elements, child.vtype)
               else
                  is_map = true
                  node.type.keys = expand_type(node.type.keys, child.ktype)
                  node.type.values = expand_type(node.type.values, child.vtype)
               end
            end
            if is_array and is_map then
               node_error(node, "cannot determine type of table literal")
            elseif is_record and is_array then
               node.type.typename = "arrayrecord"
            elseif is_record and is_map then
               if node.type.keys.typename == "string" then
                  node.type.typename = "map"
                  for _, ftype in pairs(node.type.fields) do
                     node.type.values = expand_type(node.type.values, ftype)
                  end
                  node.type.fields = nil
                  node.type.field_order = nil
               else
                  node_error(node, "cannot determine type of table literal")
               end
            elseif is_array then
               node.type.typename = "array"
            elseif is_record then
               node.type.typename = "record"
            elseif is_map then
               node.type.typename = "map"
            end
         end,
      },
      ["table_item"] = {
         ["after"] = function(node, children)
            local kname = node.key.conststr
            local ktype = children[1]
            local vtype = children[2]
            if node.decltype then
               vtype = node.decltype
               assert_is_a(node.value, children[2], node.decltype, {}, "table item")
            end
            node.type = {
               ["y"] = node.y,
               ["x"] = node.x,
               ["typename"] = "table_item",
               ["kname"] = kname,
               ["ktype"] = ktype,
               ["vtype"] = vtype,
            }
         end,
      },
      ["local_function"] = {
         ["before"] = function(node)
            begin_function_scope(node, true)
         end,
         ["after"] = function(node, children)
            end_function_scope()
            add_var(node.name.tk, {
               ["typename"] = "function",
               ["args"] = children[2],
               ["rets"] = get_rets(children[3]),
            })
            node.type = { ["typename"] = "none", }
         end,
      },
      ["global_function"] = {
         ["before"] = function(node)
            begin_function_scope(node, true)
         end,
         ["after"] = function(node, children)
            end_function_scope()
            add_global(node.name.tk, {
               ["typename"] = "function",
               ["args"] = children[2],
               ["rets"] = get_rets(children[3]),
            })
            node.type = { ["typename"] = "none", }
         end,
      },
      ["record_function"] = {
         ["before"] = function(node)
            begin_function_scope(node)
         end,
         ["before_statements"] = function(node, children)
            if node.is_method then
               local rtype = get_self_type(children[1])
               children[3][1] = rtype
               add_var("self", rtype)
            end

            local rtype = resolve_unary(get_self_type(children[1]))
            if rtype.typename == "emptytable" then
               rtype.typename = "record"
            end
            if (rtype.typename == "record" or rtype.typename == "arrayrecord") then
               local fn_type = {
                  ["y"] = node.y,
                  ["x"] = node.x,
                  ["typename"] = "function",
                  ["is_method"] = node.is_method,
                  ["args"] = children[3],
                  ["rets"] = get_rets(children[4]),
               }

               local ok = false
               if lax then
                  ok = true
               elseif rtype.fields and rtype.fields[node.name.tk] and is_a(fn_type, rtype.fields[node.name.tk]) then
                  ok = true
               elseif find_in_scope(node.fn_owner) == rtype then
                  ok = true
               end

               if ok then
                  rtype.fields = rtype.fields or {}
                  rtype.field_order = rtype.field_order or {}
                  rtype.fields[node.name.tk] = fn_type
                  table.insert(rtype.field_order, node.name.tk)
               else
                  local name = tl.pretty_print_ast(node.fn_owner)
                  node_error(node, "cannot add undeclared function '" .. node.name.tk .. "' outside of the scope where '" .. name .. "' was originally declared")
               end
            else
               node_error(node, "not a module: %s", rtype)
            end
         end,
         ["after"] = function(node, children)
            end_function_scope()

            node.type = { ["typename"] = "none", }
         end,
      },
      ["function"] = {
         ["before"] = function(node)
            begin_function_scope(node)
         end,
         ["after"] = function(node, children)
            end_function_scope()


            node.type = {
               ["y"] = node.y,
               ["x"] = node.x,
               ["typename"] = "function",
               ["args"] = children[1],
               ["rets"] = children[2],
            }
         end,
      },
      ["cast"] = {
         ["after"] = function(node, children)
            node.type = node.casttype
         end,
      },
      ["paren"] = {
         ["after"] = function(node, children)
            node.type = resolve_unary(children[1])
         end,
      },
      ["op"] = {
         ["after"] = function(node, children)
            local a = children[1]
            local b = children[3]
            local orig_a = a
            local orig_b = b
            if node.op.op == "@funcall" then
               if node.e1.tk == "rawget" then
                  if #b == 2 then
                     local b1 = resolve_unary(b[1], {})
                     local b2 = resolve_unary(b[2], {})
                     if b1.typename == "record" and node.e2[2].conststr then
                        node.type = match_record_key(node, b1, { ["typename"] = "string", ["tk"] = assert(node.e2[2].conststr), }, b1)
                     else
                        node.type = type_check_index(node, node.e2[2], b1, b2)
                     end
                  else
                     node_error(node, "rawget expects two arguments")
                  end
               elseif node.e1.tk == "require" then
                  if #b == 1 then
                     if node.e2[1].kind == "string" then
                        local module_name = assert(node.e2[1].conststr)
                        node.type = require_module(module_name, lax, modules, result, st[1])
                        if not node.type then
                           node.type = BOOLEAN
                        end
                        modules[module_name] = node.type
                     else
                        node.type = UNKNOWN
                     end
                  else
                     node_error(node, "require expects one literal argument")
                  end
               elseif node.e1.tk == "pcall" then
                  local ftype = table.remove(b, 1)
                  local rets = type_check_function_call(node, ftype, b, false, 1)
                  if rets.typename ~= "tuple" then
                     rets = { ["typename"] = "tuple", [1] = rets, }
                  end
                  table.insert(rets, 1, BOOLEAN)
                  node.type = rets
               elseif node.e1.op and node.e1.op.op == ":" then
                  local func = node.e1.type
                  if func.typename == "function" or func.typename == "poly" then
                     table.insert(b, 1, node.e1.e1.type)
                     node.type = type_check_function_call(node, func, b, true)
                  else
                     if lax and (is_unknown(func)) then
                        if node.e1.e1.kind == "variable" then
                           add_unknown_dot(node, node.e1.e1.tk .. "." .. node.e1.e2.tk)
                        end
                        node.type = UNKNOWN
                     else
                        node.type = INVALID
                     end
                  end
               else
                  node.type = type_check_function_call(node, a, b, false)
               end
            elseif node.op.op == "@index" then
               node.type = type_check_index(node, node.e2, a, b)
            elseif node.op.op == "as" then
               node.type = b
            elseif node.op.op == "." then
               a = resolve_unary(a, {})
               if a.typename == "map" then
                  if is_a(a.keys, STRING) or is_a(a.keys, ANY) then
                     node.type = a.values
                  else
                     node_error(node, "cannot use . index, expects keys of type %s", a.keys)
                  end
               else
                  node.type = match_record_key(node, a, { ["typename"] = "string", ["tk"] = node.e2.tk, }, orig_a)
                  if node.type.needs_compat53 and not skip_compat53 then
                     local key = node.e1.tk .. "." .. node.e2.tk
                     node.kind = "variable"
                     node.tk = "_tl_" .. node.e1.tk .. "_" .. node.e2.tk
                     all_needs_compat53[key] = true
                  end
               end
            elseif node.op.op == ":" then
               node.type = match_record_key(node, node.e1.type, node.e2, orig_a)
            elseif node.op.op == "not" then
               node.type = BOOLEAN
            elseif node.op.op == "and" then
               node.type = resolve_tuple(b)
            elseif node.op.op == "or" and b.typename == "emptytable" then
               node.type = resolve_tuple(a)
            elseif node.op.op == "or" and same_type(resolve_unary(a), resolve_unary(b)) then
               node.type = resolve_tuple(a)
            elseif node.op.op == "or" and b.typename == "nil" then
               node.type = resolve_tuple(a)
            elseif node.op.op == "or" and
               (a.typename == "nominal" or a.typename == "map") and
               (b.typename == "record" or b.typename == "arrayrecord") and
               is_a(b, a) then
               node.type = resolve_tuple(a)
            elseif node.op.op == "==" or node.op.op == "~=" then
               if is_a(a, b, {}, true) or is_a(b, a, {}, true) then
                  node.type = BOOLEAN
               else
                  if lax and (is_unknown(a) or is_unknown(b)) then
                     node.type = UNKNOWN
                  else
                     node_error(node, "types are not comparable for equality: %s and %s", a, b)
                  end
               end
            elseif node.op.arity == 1 and unop_types[node.op.op] then
               a = resolve_unary(a)
               local types_op = unop_types[node.op.op]
               node.type = types_op[a.typename]
               if not node.type then
                  if lax and is_unknown(a) then
                     node.type = UNKNOWN
                  else
                     node_error(node, "cannot use operator '" .. node.op.op:gsub("%%", "%%%%") .. "' on type %s", orig_a)
                  end
               end
            elseif node.op.arity == 2 and binop_types[node.op.op] then
               a = resolve_unary(a)
               b = resolve_unary(b)
               local types_op = binop_types[node.op.op]
               node.type = types_op[a.typename] and types_op[a.typename][b.typename]
               if not node.type then
                  if lax and (is_unknown(a) or is_unknown(b)) then
                     node.type = UNKNOWN
                  else
                     node_error(node, "cannot use operator '" .. node.op.op:gsub("%%", "%%%%") .. "' for types %s and %s", orig_a, orig_b)
                  end
               end
            else
               error("unknown node op " .. node.op.op)
            end
         end,
      },
      ["variable"] = {
         ["after"] = function(node, children)
            node.type, node.is_const = find_var(node.tk)
            if node.type == nil then
               node.type = { ["typename"] = "unknown", }
               if lax then
                  add_unknown(node, node.tk)
               else
                  node_error(node, "unknown variable: " .. node.tk)
               end
            end
         end,
      },
      ["identifier"] = {
         ["after"] = function(node, children)
            node.type = { ["typename"] = "none", }
         end,
      },
      ["newtype"] = {
         ["after"] = function(node, children)
            node.type = node.newtype
         end,
      },
   }

   visit_node.cbs["while"] = visit_node.cbs["if"]
   visit_node.cbs["repeat"] = visit_node.cbs["if"]
   visit_node.cbs["do"] = visit_node.cbs["if"]
   visit_node.cbs["break"] = visit_node.cbs["if"]
   visit_node.cbs["elseif"] = visit_node.cbs["if"]
   visit_node.cbs["else"] = visit_node.cbs["if"]

   visit_node.cbs["values"] = visit_node.cbs["variables"]
   visit_node.cbs["expression_list"] = visit_node.cbs["variables"]
   visit_node.cbs["argument_list"] = visit_node.cbs["variables"]
   visit_node.cbs["argument"] = visit_node.cbs["variable"]

   visit_node.cbs["string"] = {
      ["after"] = function(node, children)
         node.type = {
            ["y"] = node.y,
            ["x"] = node.x,
            ["typename"] = node.kind,
            ["tk"] = node.tk,
         }
         return node.type
      end,
   }
   visit_node.cbs["number"] = visit_node.cbs["string"]
   visit_node.cbs["nil"] = visit_node.cbs["string"]
   visit_node.cbs["boolean"] = visit_node.cbs["string"]
   visit_node.cbs["..."] = visit_node.cbs["variable"]

   visit_node.after = {
      ["after"] = function(node, children)
         assert(type(node.type) == "table", node.kind .. " did not produce a type")
         assert(type(node.type.typename) == "string", node.kind .. " type does not have a typename")
         return node.type
      end,
   }

   local visit_type = {
      ["cbs"] = {
         ["typedecl"] = {
            ["after"] = function(typ, children)
               if typ.typename == "nominal" then
                  if not find_var(typ.name) then
                     type_error(typ, "unknown type " .. typ.name)
                  end
               end
               return typ
            end,
         },
         ["type_list"] = {
            ["after"] = function(typ, children)
               local ret = children
               ret.typename = "tuple"
               return ret
            end,
         },
      },
      ["after"] = {
         ["after"] = function(typ, children, ret)
            assert(type(ret) == "table", typ.kind .. " did not produce a type")
            assert(type(ret.typename) == "string", typ.kind .. " type does not have a typename")
            return ret
         end,
      },
   }

   recurse_node(ast, visit_node, visit_type)

   local redundant = {}
   local lastx, lasty = 0, 0
   table.sort(errors, function(a, b)
      return (a.y < b.y) or (a.y == b.y and a.x < b.x)
   end)
   for i, err in ipairs(errors) do
      if err.x == lastx and err.y == lasty then
         table.insert(redundant, i)
      end
      lastx, lasty = err.x, err.y
   end
   for i = #redundant, 1, -1 do
      table.remove(errors, redundant[i])
   end

   if not skip_compat53 then
      add_compat53_entries(ast, all_needs_compat53)
   end

   return errors, unknowns, module_type
end

local function init_modules()
   local modules = {
      ["tl"] = {
         ["typename"] = "record",
         ["fields"] = {
            ["loader"] = { ["typename"] = "function", ["args"] = {}, ["rets"] = {}, },
         },
      },
   }
   fill_field_order(modules["tl"])
   for k, m in pairs(standard_library) do
      if m.typename == "record" then
         modules[k] = m
      end
   end
   return modules
end

function tl.process(filename, modules, result, globals, preload_modules)
   local fd, err = io.open(filename, "r")
   if not fd then
      return nil, "could not open " .. filename .. ": " .. err
   end

   local input, err = fd:read("*a")
   if not input then
      fd:close()
      return nil, "could not read " .. filename .. ": " .. err
   end

   local extension = filename:match("%.([a-z]+)$")
   extension = extension and extension:lower()

   local is_lua
   if extension == "tl" then
      is_lua = false
   elseif extension == "lua" then
      is_lua = true
   else
      is_lua = input:match("^#![^\n]*lua[^\n]*\n")
   end

   modules = modules or init_modules()
   result = result or {
      ["syntax_errors"] = {},
      ["type_errors"] = {},
      ["unknowns"] = {},
   }
   globals = globals or init_globals(is_lua)
   preload_modules = preload_modules or {}

   local tokens, errs = tl.lex(input)
   if errs then
      for i, err in ipairs(errs) do
         table.insert(result.syntax_errors, {
            ["y"] = err.y,
            ["x"] = err.x,
            ["msg"] = "invalid token '" .. err.tk .. "'",
            ["filename"] = filename,
         })
      end
   end

   local i, program = tl.parse_program(tokens, result.syntax_errors, filename)
   if #result.syntax_errors > 0 then
      return result
   end


   for _, module_name in ipairs(preload_modules) do
      local module_type = require_module(module_name, is_lua, modules, result, globals)

      if module_type == UNKNOWN then
         return nil, string.format("Error: could not preload module '%s'", module_name)
      end

      if not module_type then
         module_type = BOOLEAN
      end

      modules[module_name] = module_type
   end

   local error, unknown
   error, unknown, result.type = tl.type_check(program, is_lua, filename, modules, result, globals)

   result.ast = program

   return result
end

local function tl_package_loader(module_name)
   local found_filename, fd, tried = tl.search_module(module_name, false)
   if found_filename then
      local input = fd:read("*a")
      fd:close()
      local tokens = tl.lex(input)
      local errs = {}
      local i, program = tl.parse_program(tokens, errs, found_filename)
      local code = tl.pretty_print_ast(program, true)
      local chunk = load(code, found_filename)
      if chunk then
         return function()
            local ret = chunk()
            package.loaded[module_name] = ret
            return ret
         end
      end
   end
   return table.concat(tried, "\n\t")
end

function tl.loader()
   if package.searchers then
      table.insert(package.searchers, 2, tl_package_loader)
   else
      table.insert(package.loaders, 2, tl_package_loader)
   end
end

return tl