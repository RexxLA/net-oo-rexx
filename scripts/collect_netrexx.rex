call header "Collect NetRexx"

signal on syntax name error

use arg not_used -- only .SysCArgs is used
call assert .SysCArgs~items <= 1, 93.900, "0..1 argument expected: [cache]"

call pushd
cache = setupCache(.SysCArgs[1])

call zipCollect -
    "https://www.netrexx.org/files/NetRexx-5.10-GA.zip", -
    cache, -
    "netrexx"

call popd
call footer "Collect done."
exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
