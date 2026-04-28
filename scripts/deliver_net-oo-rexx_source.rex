call header "Deliver net-oo-rexx source"

signal on syntax name error

parse source . how .
cache = .nil; delivery = .nil
if how \== "COMMAND" then use strict arg cache=.NIL, delivery=.NIL
call assert .SysCArgs~items <= 2, 93.900, "0..2 argument(s) expected: [cache [delivery]]"

call pushd
-- cache not used
localClone = setupLocalClone() -- local clone of net-oo-rexx
delivery = setupDelivery(delivery, .SysCArgs[2])

-- Don't use mirrorDirC! The mirroring would delete ALL the other components in delivery
-- copyDirC copies the directory contents (as opposed to copyDirD, which copies the directory itself)
call copyDirC localClone"/source", delivery

call popd
call footer "Delivery done."
exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
