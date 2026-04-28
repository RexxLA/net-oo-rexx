call header "Deliver Executor incubator scripts"

signal on syntax name error

parse source . how .
cache = .nil; delivery = .nil
if how \== "COMMAND" then use strict arg cache=.NIL, delivery=.NIL
call assert .SysCArgs~items <= 2, 93.900, "0..2 argument(s) expected: [cache [delivery]]"

call pushd
cache = setupCache(cache, .SysCArgs[1], /*okToCreate:*/.false)
delivery = setupDelivery(delivery, .SysCArgs[2])

-- mirrorDirD copies the directory itself (as opposed to mirrorDirC, which copies its contents)
call copyFile   cache"/executor/incubator/scripts/md2html4xtr.rex", delivery"/packages/executor"
call mirrorDirD cache"/executor/incubator/scripts/md2html4xtr",     delivery"/packages/executor"
call copyFile   cache"/executor/incubator/scripts/md2md.rex",       delivery"/packages/executor"
call copyFile   cache"/executor/incubator/scripts/text2html.rex",   delivery"/packages/executor"

call popd
call footer "Delivery done."
exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
