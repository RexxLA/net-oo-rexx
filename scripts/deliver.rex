signal on syntax name error

use arg not_used -- only .SysCArgs is used
call assert .SysCArgs~items <= 2, 93.900, "0..2 argument(s) expected: [cache [, delivery]]"

call setupCache .SysCArgs[1], /*okToCreate:*/.false
call setupDelivery(.SysCArgs[2])

call "deliver_executor_incubator_oorexxshell.rex"   ; if result \== 0 then exit result
call "deliver_executor_incubator_scripts.rex"       ; if result \== 0 then exit result
call "deliver_executor_sandbox_jlf_packages.rex"    ; if result \== 0 then exit result
call "deliver_oorexx_incubator_regex.rex"           ; if result \== 0 then exit result
call "deliver_oorexx_test_trunk.rex"                ; if result \== 0 then exit result
call "deliver_oorexxdebugger.rex"                   ; if result \== 0 then exit result
call "deliver_rexx-parser.rex"                      ; if result \== 0 then exit result
call "deliver_tutor.rex"                            ; if result \== 0 then exit result

--Do it last! Otherwise, some files may be removed by components delivered afterward
call "deliver_net-oo-rexx_source.rex"               ; if result \== 0 then exit result

exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
