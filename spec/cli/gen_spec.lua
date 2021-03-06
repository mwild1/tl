local util = require("spec.util")

describe("tl gen", function()
   describe("on .tl files", function()
      it("reports 0 errors and code 0 on success", function()
         local name = util.write_tmp_file(finally, "add.tl", [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add(10, 20))
         ]])
         local pd = io.popen("./tl gen " .. name, "r")
         local output = pd:read("*a")
         util.assert_popen_close(true, "exit", 0, pd:close())
         local lua_name = name:gsub("%.tl$", ".lua")
         assert.match("Wrote: " .. lua_name, output, 1, true)
         util.assert_line_by_line([[
            local function add(a, b)
               return a + b
            end

            print(add(10, 20))
         ]], util.read_file(lua_name))
      end)

      it("ignores type errors", function()
         local name = util.write_tmp_file(finally, "add.tl", [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add("string", 20))
            print(add(10, true))
         ]])
         local pd = io.popen("./tl gen " .. name .. " 2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(true, "exit", 0, pd:close())
         assert.same("", output)
         local lua_name = name:gsub("%.tl$", ".lua")
         util.assert_line_by_line([[
            local function add(a, b)
               return a + b
            end

            print(add("string", 20))
            print(add(10, true))
         ]], util.read_file(lua_name))
      end)

      it("reports number of errors in stderr and code 1 on syntax errors", function()
         local name = util.write_tmp_file(finally, "add.tl", [[
            print(add("string", 20))))))
         ]])
         local pd = io.popen("./tl gen " .. name .. " 2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(nil, "exit", 1, pd:close())
         assert.match("1 syntax error:", output, 1, true)
      end)

      it("ignores unknowns code 0 if no errors", function()
         local name = util.write_tmp_file(finally, "add.tl", [[
            local function unk(x, y): number, number
               return a + b
            end
         ]])
         local pd = io.popen("./tl gen " .. name .. " 2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(true, "exit", 0, pd:close())
         assert.same("", output)
         local lua_name = name:gsub("%.tl$", ".lua")
         util.assert_line_by_line([[
            local function unk(x, y)
               return a + b
            end
         ]], util.read_file(lua_name))
      end)
   end)
end)
