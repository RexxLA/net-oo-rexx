call header "Deliver ooRexx test trunk"

signal on syntax name error

parse source . how .
cache = .nil; delivery = .nil
if how \== "COMMAND" then use strict arg cache=.NIL, delivery=.NIL
call assert .SysCArgs~items <= 2, 93.900, "0..2 argument(s) expected: [cache [delivery]]"

call pushd
cache = setupCache(cache, .SysCArgs[1], /*okToCreate:*/.false)
delivery = setupDelivery(delivery, .SysCArgs[2])

-- rsync is perfect regarding the mirroring and the deletion of extra dirs and files.
-- robocopy insists to report the extra dirs and files, and it's painful.
-- Workaround: try to rename "bin" to "framework before the mirroring, don't raise error in case of failure.
call tryRenameDirectory delivery"/packages/testsuite/bin", delivery"/packages/testsuite/framework"
-- mirrorDirC copies the directory contents (as opposed to mirrorDirD, which copies the directory itself)
call mirrorDirC cache"/oorexx/test/trunk", delivery"/packages/testsuite"
-- "framework" is renamed "bin" in the delivery.
call renameDirectory delivery"/packages/testsuite/framework", delivery"/packages/testsuite/bin"

call popd
call footer "Delivery done."
exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
