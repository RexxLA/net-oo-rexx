call header "Deliver NetRexx"

signal on syntax name error

parse source . how .
cache = .nil; delivery = .nil
if how \== "COMMAND" then use strict arg cache=.NIL, delivery=.NIL
call assert .SysCArgs~items <= 2, 93.900, "0..2 argument(s) expected: [cache [delivery]]"

call pushd
cache = setupCache(cache, .SysCArgs[1], /*okToCreate:*/.false)
delivery = setupDelivery(delivery, .SysCArgs[2])

-- mirrorDirD copies the directory itself (as opposed to mirrorDirC, which copies its contents)
call mirrorDirD cache"/netrexx", delivery

call popd
call footer "Delivery done."
exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
