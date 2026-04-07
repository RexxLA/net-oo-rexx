call header "Collect ooRexx"

signal on syntax name error

use arg not_used -- only .SysCArgs is used
call assert .SysCArgs~items <= 1, 93.900, "0..1 argument expected: [cache]"

call pushd
cache = setupCache(.SysCArgs[1])

call svnCollect -
    "https://svn.code.sf.net/p/oorexx/code-0/incubator/regex", -
    cache, -
    "oorexx/incubator/regex"

call svnCollect -
    "https://svn.code.sf.net/p/oorexx/code-0/test/trunk", -
    cache, -
    "oorexx/test/trunk"

call popd
call footer "Collect done."
exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
