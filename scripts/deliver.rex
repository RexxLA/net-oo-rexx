signal on syntax name error

use arg not_used -- only .SysCArgs is used
call assert .SysCArgs~items <= 2, 93.900, "0..2 argument(s) expected: [cache [delivery]]"

call pushd
cache = setupCache(.SysCArgs[1], /*okToCreate:*/.false)
delivery = setupDelivery(.SysCArgs[2])

call "deliver_bsf4oorexx850.rex"                    ; if result \== 0 then exit result
call "deliver_executor_incubator_oorexxshell.rex"   ; if result \== 0 then exit result
call "deliver_executor_incubator_scripts.rex"       ; if result \== 0 then exit result
call "deliver_executor_sandbox_jlf_packages.rex"    ; if result \== 0 then exit result
call "deliver_netrexx.rex"                          ; if result \== 0 then exit result
call "deliver_oorexx_incubator_regex.rex"           ; if result \== 0 then exit result
call "deliver_oorexx_test_trunk.rex"                ; if result \== 0 then exit result
call "deliver_oorexxdebugger.rex"                   ; if result \== 0 then exit result
call "deliver_rexx-parser.rex"                      ; if result \== 0 then exit result
call "deliver_tutor.rex"                            ; if result \== 0 then exit result

--Do it last! Otherwise, some files may be removed by components delivered afterward
call "deliver_net-oo-rexx_source.rex"               ; if result \== 0 then exit result

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
