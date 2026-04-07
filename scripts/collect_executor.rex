call header "Collect Executor"

signal on syntax name error

use arg not_used -- only .SysCArgs is used
call assert .SysCArgs~items <= 1, 93.900, "0..1 argument expected: [cache]"

call pushd
cache = setupCache(.SysCArgs[1])

call gitSparseCollect -
    "https://github.com/jlfaucher/executor.git", -
    cache, -
    "executor", -
    ( -
        "incubator/ooRexxShell", -
        "incubator/scripts", -
        "sandbox/jlf/packages", -
    )

call popd
call footer "Collect done."
exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
