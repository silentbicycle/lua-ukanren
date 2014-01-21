-- Copyright (c) 2014 Scott Vokes <vokes.s@gmail.com>
-- 
-- Permission to use, copy, modify, and/or distribute this software for any
-- purpose with or without fee is hereby granted, provided that the above
-- copyright notice and this permission notice appear in all copies.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
-- WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
-- MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
-- ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
-- WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
-- ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
-- OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

-- Lua port of microKanren, a minimal logic programming engine.
-- See the README for a link to the paper with the details.


-- Logic variables
local Var = {}
Var.__tostring = function(v) return table.concat{"#(", v[1], ")"} end
Var.__eq = function(x1, x2) return x1[1] == x2[1] end
local function var(c) return setmetatable({c}, Var) end
local function is_var(x) return getmetatable(x) == Var end

-- Sentinel for environment
local mzero = setmetatable({}, {__tostring=function() return "(mzero)" end})

-- Cons cells
local Cons = {}
local function cons(x, y)
    assert(x, "bad car")
    assert(y, "bad cdr")
    return setmetatable({x, y}, Cons)
end
local function car(x) return x[1] end
local function cdr(x) return x[2] end
local function is_pair(x) return getmetatable(x) == Cons end

-- Prettyprint cons cells, Scheme-style
Cons.__tostring = function(c)
                      local buf = {}
                      buf[1] = "("
                      buf[2] = tostring(car(c))
                      if cdr(c) ~= mzero then
                          buf[3] = " . "
                          buf[4] = tostring(cdr(c))
                      end
                      buf[#buf+1] = ")"
                      return table.concat(buf)
                  end

-- a-list search, by predicate. (An R6RS Scheme built-in.)
local function assp(p, l)
    if l then
        local hd = car(l)
        if hd then
            return p(hd) and hd or assp(p, cdr(l))
        end
    end
end

-- Walk environment S and look up value of U, if present.
local function walk(u, s)
    if is_var(u) then
        local pr = assp(function(v) return u == v end, s)
        if pr then return walk(cdr(pr), s) else return u end
    else
        return u
    end
end

-- Extend environment S with (x . v).
local function ext_s(x, v, s)
    return cons(cons(x, v), s)
end

-- Return `(,s_c . mzero).
local function unit(s_c)
    -- s_c: (substitution environment, count) pair.
    return cons(s_c, mzero)
end

-- Unify U with V in environment S.
local function unify(u, v, s)
    local u = walk(u, s)
    local v = walk(v, s)
    if is_var(u) and is_var(v) and u == v then return s
    elseif is_var(u) then return ext_s(u, v, s)
    elseif is_var(v) then return ext_s(v, u, s)
    elseif is_pair(u) and is_pair(v) then
        local s = unify(car(u), car(v), s)
        return s and unify(cdr(u), cdr(v), s)
    elseif u == v then return s
    end
end

-- Constrain U to be equal to V.
local function eq(u, v)
    return function(s_c)
               local s = unify(u, v, car(s_c))
               return s and unit(cons(s, cdr(s_c))) or mzero
           end
end

-- Call function F with a fresh variable.
local function call_fresh(f)
    return function(s_c)
               local c = cdr(s_c)
               return (f(var(c)))(cons(car(s_c), c + 1))
           end
end

local function mplus(d1, d2)
    if d1 == nil then
        return d2
    elseif d1 == mzero then
        return d2
    elseif type(d1) == "function" then
        return function() return mplus(d2, d1()) end
    else
        return cons(car(d1), mplus(cdr(d1), d2))
    end
end

local function bind(d, g)
    if d == nil then
        return mzero
    elseif d == mzero then
        return mzero
    elseif type(d) == "function" then
        return function() return bind(d(), g) end
    else
        return mplus(g(car(d)), bind(cdr(d), g))
    end
end

local function disj(g1, g2)
    return function(s_c)
               return mplus(g1(s_c), g2(s_c))
           end
end

local function conj(g1, g2)
    return function(s_c)
               return bind(g1(s_c), g2)
           end
end

local empty_env = cons(mzero, 0)

-- Exported interface
return {
    cons=cons, car=car, cdr=cdr,
    eq=eq,
    call_fresh=call_fresh,
    conj=conj, disj=disj,
    empty_env=empty_env,
}
