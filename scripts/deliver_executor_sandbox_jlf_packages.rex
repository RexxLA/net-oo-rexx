call header "Deliver Executor packages"

signal on syntax name error

parse source . how .
cache = .nil; delivery = .nil
if how \== "COMMAND" then use strict arg cache=.NIL, delivery=.NIL
call assert .SysCArgs~items <= 2, 93.900, "0..2 argument(s) expected: [cache [delivery]]"

call pushd
cache = setupCache(cache, .SysCArgs[1], /*okToCreate:*/.false)
delivery = setupDelivery(delivery, .SysCArgs[2])

-- mirrorDirD copies the directory itself (as opposed to mirrorDirC, which copies its contents)
call copyFile   cache"/executor/sandbox/jlf/packages/extension/callable_std.cls",       delivery"/packages/executor/extension"
call copyFile   cache"/executor/sandbox/jlf/packages/extension/extender_std.cls",       delivery"/packages/executor/extension"
call mirrorDirD cache"/executor/sandbox/jlf/packages/extension/std",                    delivery"/packages/executor/extension"
call copyFile   cache"/executor/sandbox/jlf/packages/extension/stringChunk.cls",        delivery"/packages/executor/extension"
call copyFile   cache"/executor/sandbox/jlf/packages/extension/stringChunkMatcher.cls", delivery"/packages/executor/extension"
call mirrorDirD cache"/executor/sandbox/jlf/packages/pipeline",                         delivery"/packages/executor"
call mirrorDirD cache"/executor/sandbox/jlf/packages/procedural",                       delivery"/packages/executor"
call mirrorDirD cache"/executor/sandbox/jlf/packages/profiling",                        delivery"/packages/executor"
call mirrorDirD cache"/executor/sandbox/jlf/packages/rgf_util2",                        delivery"/packages/executor"
call mirrorDirD cache"/executor/sandbox/jlf/packages/utilities",                        delivery"/packages/executor"

call popd
call footer "Delivery done."
exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
