call header "Deliver BSF4ooRexx850"

signal on syntax name error

use arg not_used -- only .SysCArgs is used
call assert .SysCArgs~items <= 2, 93.900, "0..2 argument(s) expected: [cache [delivery]]"

call pushd
cache = setupCache(.SysCArgs[1], /*okToCreate:*/.false)
delivery = setupDelivery(.SysCArgs[2])

-- Do it first because the mirroring will delete extra files
-- copyDirC copies the directory contents (as opposed to copyDirD, which copies the directory itself)
call mirrorDirC cache"/BSF4ooRexx850/bsf4oorexx", delivery"/packages/bsf4oorexx/bin", /*recursive:*/ .false

call mirrorDirC cache"/BSF4ooRexx850/bsf4oorexx/utilities", delivery"/packages/bsf4oorexx/bin/utilities"

call mirrorDirC cache"/BSF4ooRexx850/bsf4oorexx/information", delivery"/packages/bsf4oorexx/doc"

-- Do it before copying the dynamic libraries because the mirroring will delete extra files
-- Thanks to the mirroring, no need to specify the exact jar filename
call mirrorDirC cache"/BSF4ooRexx850/bsf4oorexx/lib", delivery"/packages/bsf4oorexx/lib"

call copyFile cache"/BSF4ooRexx850/bsf4oorexx/install/lib/BSF4ooRexx850.dll-64-amd64", delivery"/packages/bsf4oorexx/lib", "BSF4ooRexx850.dll"
call copyFile cache"/BSF4ooRexx850/bsf4oorexx/install/lib/libBSF4ooRexx850.dylib-universal", delivery"/packages/bsf4oorexx/lib", "libBSF4ooRexx850.dylib"
call copyFile cache"/BSF4ooRexx850/bsf4oorexx/install/lib/libBSF4ooRexx850.so-64-amd64", delivery"/packages/bsf4oorexx/lib", "libBSF4ooRexx850.so"

call mirrorDirC cache"/BSF4ooRexx850/bsf4oorexx/samples", delivery"/packages/bsf4oorexx/samples"

call copyFile cache"/BSF4ooRexx850/bsf4oorexx.dev/source_cc/BSF4ooRexx.cc", delivery"/packages/bsf4oorexx/src"
call copyFile cache"/BSF4ooRexx850/bsf4oorexx.dev/source_cc/CMakeLists.txt", delivery"/packages/bsf4oorexx/src"
call copyFile cache"/BSF4ooRexx850/bsf4oorexx.dev/source_cc/org_rexxla_bsf_engines_rexx_RexxAndJava.h", delivery"/packages/bsf4oorexx/src"
call copyFile cache"/BSF4ooRexx850/bsf4oorexx.dev/source_cc/org_rexxla_bsf_engines_rexx_RexxCleanupRef.h", delivery"/packages/bsf4oorexx/src"

call popd
call footer "Delivery done."
exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
