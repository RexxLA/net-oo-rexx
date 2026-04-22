call header "Deliver ooRexxDebugger"

signal on syntax name error

use arg not_used -- only .SysCArgs is used
call assert .SysCArgs~items <= 2, 93.900, "0..2 argument(s) expected: [cache [delivery]]"

call pushd
cache = setupCache(.SysCArgs[1], /*okToCreate:*/.false)
delivery = setupDelivery(.SysCArgs[2])

-- Not sure why it's delivered under the name "rexxdebugger" instead of "ooRexxDebugger".
-- I keep the name currently used in net-oo-rexx: "rexxdebugger".
-- mirrorDirC copies the directory contents (as opposed to mirrorDirD, which copies the directory itself)
call mirrorDirC cache"/ooRexxDebugger", delivery"/packages/rexxdebugger"

call popd
call footer "Delivery done."
exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
