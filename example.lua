local U = require "ukanren"

local empty_env, call_fresh = U.empty_env, U.call_fresh
local eq, conj, disj = U.eq, U.conj, U.disj

-- Basic example: unify Q with 5.
local res = (call_fresh(function(q)
                            return eq(q, 5)
                        end)(empty_env))
print(res) -- ((((#(0) . 5)) . 1))

-- Unify A with 5 or 6, using logical disjunction.
res = (call_fresh(function(a) 
                     return disj(eq(a, 5),
                                 eq(a, 6))
                 end)(empty_env))
print(res) -- ((((#(0) . 5)) . 1) . ((((#(0) . 6)) . 1)))

-- Unify A with 7 and B with 5 or 6.
local a_and_b =
    conj(call_fresh(function(a) return eq(a, 7) end),
         call_fresh(function(b) return disj(eq(b, 5),
                                            eq(b, 6)) end))

-- ((((#(1) . 5) . ((#(0) . 7))) . 2) . ((((#(1) . 6) . ((#(0) . 7))) . 2)))
res = a_and_b(empty_env)
print(res)
