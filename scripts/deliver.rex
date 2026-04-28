call header "Deliver"

signal on syntax name error

parse source . how .
cache = .nil; delivery = .nil
if how \== "COMMAND" then use strict arg cache=.NIL, delivery=.NIL
call assert .SysCArgs~items <= 2, 93.900, "0..2 argument(s) expected: [cache [delivery]]"

call pushd
cache = setupCache(cache, .SysCArgs[1], /*okToCreate:*/.false)
delivery = setupDelivery(delivery, .SysCArgs[2])

call "deliver_bsf4oorexx850.rex" cache, delivery                    ; if result \== 0 then exit result
call "deliver_executor_incubator_oorexxshell.rex" cache, delivery   ; if result \== 0 then exit result
call "deliver_executor_incubator_scripts.rex" cache, delivery       ; if result \== 0 then exit result
call "deliver_executor_sandbox_jlf_packages.rex" cache, delivery    ; if result \== 0 then exit result
call "deliver_netrexx.rex" cache, delivery                          ; if result \== 0 then exit result
call "deliver_oorexx_incubator_regex.rex" cache, delivery           ; if result \== 0 then exit result
call "deliver_oorexx_test_trunk.rex" cache, delivery                ; if result \== 0 then exit result
call "deliver_oorexxdebugger.rex" cache, delivery                   ; if result \== 0 then exit result
call "deliver_rexx-parser.rex" cache, delivery                      ; if result \== 0 then exit result
call "deliver_tutor.rex" cache, delivery                            ; if result \== 0 then exit result

--Do it last! Otherwise, some files may be removed by components delivered afterward
call "deliver_net-oo-rexx_source.rex" cache, delivery               ; if result \== 0 then exit result

call header "Set executable bit"
if .RexxInfo~platform~caselessEquals("WINDOWSNT") then do
    .traceOutput~say("Warning: the executable bit for Linux and macOS is not set")
end
else do
    call changeDirectory delivery, /*verbose:*/ .true
    call system "./makeAllExecutable.sh", /*verbose:*/ .true
end

call popd
exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
