call header "Deliver ooRexx incubator regex"

signal on syntax name error

use arg not_used -- only .SysCArgs is used
call assert .SysCArgs~items <= 2, 93.900, "0..2 argument(s) expected: [cache [delivery]]"

call pushd
cache = setupCache(.SysCArgs[1], /*okToCreate:*/.false)
delivery = setupDelivery(.SysCArgs[2])

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
