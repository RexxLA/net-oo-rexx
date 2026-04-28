call header "Deliver ooRexx incubator regex"

signal on syntax name error

parse source . how .
cache = .nil; delivery = .nil
if how \== "COMMAND" then use strict arg cache=.NIL, delivery=.NIL
call assert .SysCArgs~items <= 2, 93.900, "0..2 argument(s) expected: [cache [delivery]]"

call pushd
cache = setupCache(cache, .SysCArgs[1], /*okToCreate:*/.false)
delivery = setupDelivery(delivery, .SysCArgs[2])

call copyFile cache"/oorexx/incubator/regex/regex.cls",        delivery"/packages/regex"
call copyFile cache"/oorexx/incubator/regex/Parser.testGroup", delivery"/packages/regex/testunit"
call copyFile cache"/oorexx/incubator/regex/regex.testGroup",  delivery"/packages/regex/testunit"

call popd
call footer "Delivery done."
exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
