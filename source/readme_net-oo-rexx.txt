"net-oo-rexx packages"
======================

This is the readme file for "net-oo-rexx", a bundling ready to use that
gives immediate access to a number of Rexx packages (stored in the subdirectory
"packages"), like:

- bsf4oorexx (ooRexx-Java bridge for all operating systems)
- dbus4oorexx (ooRexx-DBus bridge for Linux)
- executor packages (useful utilities, used by oorexxshell below)
- log4rexx (logging for ooRexx)
- oorexx (open object Rexx)
- oorexxshell (a rexxtry.rex kind of shell for ooRexx, POWERFUL stuff)
- regex (powerful regular expression implementation in ooRexx)
- rexx-parser (cf. International Rexx Symposium 2025, beginning of May)
- rexxdebugger (an ooRexx debugger, exploits the Java bindings on Unix)
- testsuite (the ooRexx test suite, can be used for your purposes)
- TUTOR (cf. International Rexx Symposium 2025, beginning of May)
- wip ("work in progress", may be empty)

To learn more about the packages lookup their content which usually has the
respective documentation.


========================
Directions in a nutshell
========================

- download the latest "NetRexx, ooRexx with packages with oorexxshell"
  (net-oo-rexx-packages) zip archive from
  https://wi.wu.ac.at/rgf/rexx/tmp/net-oo-rexx-packages/

- de-quarantine the zip archive BEFORE unzipping (see NOTE # 1 below)

- unzip the archive with the "unzip" or "7z" command

- change into the unzipped directory and enter in the system shell

  Windows                  Unix                    Comment
  -------                  ----                    +------
  setup.cmd                ./setup.sh              | creates two scripts

  This will create the two scripts:

  run.cmd                  run                     | allows to run net-oo-rexx programs
  setenv.cmd               setenv                  | allows to set environment to net-oo-rexx in Terminal

  ----------------------------------------------------------------------------------------

  ---> use the generated 'run.cmd/run' script

  Windows                  Unix                       Comment
  -------                  ----                       +------
  run oorexxshell          ./run oorexxshell          | runs oorexxshell (a script)

  run rexx testoorexx.rex  ./run rexx testoorexx.rex  | use portable ooRexx to run testoorexx.rex
  run rexx which_rexx.rex                             | use portable ooRexx to run which_rexx.rex

  run rexxdebugger packages/rexxdebugger/tutorial.rex | use portable ooRexx to run the rexxdebugger with its tutorial.rex

  run nrc -exec which_rexx.rex                        | use NetRexx to run which_rexx.rex


  ----------------------------------------------------------------------------------------
  ---> use the generated 'setenv.cmd/setenv' script

  Windows                  Unix                    Comment
  -------                  ----                    +------
   setenv.cmd              source ./setenv         | sets the environment in the Terminal to net-oo-rexx

   the following commands will work on Windows as well as on Unix:

   oorexxshell                                     | runs oorexxshell (a script)

   rexx testoorexx.rex                             | use portable ooRexx to run testoorexx.rex
   rexx which_rexx.rex                             | use portable ooRexx to run which_rexx.rex

   rexxdebugger packages/rexxdebugger/tutorial.rex | use portable ooRexx to run the rexxdebugger with its tutorial.rex

   nrc -exec which_rexx.rex                        | use NetRexx to run which_rexx.rex

   nrc which_rexx.rex                              | use NetRexx to compile which_rexx.rex to which_rexx.class
   java which_rexx                                 | use Java to run which_rexx.class (note: no ".class" extension!)



======================
Additional information
======================

To learn about the functionality of oorexxshell, take a few minutes and see the
asciinema demos at [4].

First feedback
--------------

 - "install this bundle, you run a small, trivial setup program, and, poof,
   you have immediate access to a real trove of packages -- no additional
   installation needed"
   (JMB)

 - "I even was able to load the JDOR handler, then "address JDOR", and then
   construct one of the JDOR samples step-by-step, by manually writing the
   (quoted) JDOR commands.  This is very impressive, and very useful too,
   from a pedagogical point of view, since it provides immediate incremental
   visual feedback for the JDOR commands.  You just have to move the Java
   window besides the command window and you have a fantastic experience."
   (JMB)

-------------------------------------------------------------------------------

=====
NOTES
=====

---------------------------------------
NOTE # 1: Microsoft and Apple do not allow programs from the Internet to run
          if they are not signed using their fee-based service citing "security
          reasons".

      Therefore, BEFORE INSTALLING or UNZIPPING open source projects you need
      to "de-quarantine" (remove the respective attributes) the zip archives
      BEFORE unzipping.

      Windows: after downloading, open with a right-mouse click the property
               menu, mark the "unblock" check mark and click "apply".
               Thereafter you can install or unzip the file.
               Alternatively, open a command line window and run (change 'filename'
               to the name of the downloaded file):

                powershell Unblock-File filename

             e.g.,

                powershell Unblock-File net-oo-rexx.windows.x86_64-portable-release-20250402.zip
                powershell Unblock-File *

      macOS: after downloading, open a Terminal window and run "xattr filename"
             to see the extended attributes of the downloaded file (replace
             'filename' with the name of the zip archive), then issue  (again,
             change 'filename' to the name of the downloaded file):

                xattr -d com.apple.quarantine filename

             e.g.,

                xattr -d com.apple.quarantine net-oo-rexx.macos.x86_64-portable-release-20250402.zip
                xattr -d com.apple.quarantine *

---------------------------------------
NOTE # 2 for Unix versions.

      In case the execution bit of shell scripts and executables got removed,
      run the supplied script makeAllExecutable.sh from the unzipped
      directory:

	       sh ./makeAllExecutable.sh

---------------------------------------
NOTE # 3: Dual Installations (Linux & Windows)

          You can use the same set of installed files to run the net-oo-rexx
          bundle under both Windows and Linux, including the Windows Subsystem
          for Linux (WSL2) and other mechanisms like VirtualBox shared folders.

          Once you have run the necessary initializer scripts (setup.cmd under
          Windows, and ./setup under Linux/WSL), you will be able to use the
          other scripts (run/setenv) under both operating systems.  For example,
          you can test a program under Windows, then use the "wsl" command to
          switch to Ubuntu, and test the same program under Ubuntu, while sharing
          the same net-oo-rexx installation.

          About WSL, cf. <https://learn.microsoft.com/en-us/windows/wsl/about>

---------------------------------------
NOTE # 4: rerun the "setup.cmd" (Windows)/"setup" (Unix) script each time the
          portable files get relocated or, if on a USB stick, each time you
          plug in the USB stick. This will recreate on Windows the "run.cmd"
          and "setenv.cmd"  scripts, on Unix the "run" and "setenv" scripts,
          thereby adjusting them to their new location.

---------------------------------------
NOTE # 5: bsf4oorexx (ooRexx-Java bridge)

          In order to load and run bsf4oorexx programs you need to have
          Java/OpenJDK on your computer and either have PATH point to the
          directory where the binary file java.exe (Windows)/java (Unix) can be
          found or set the environment variable JAVA_HOME to point to the Java
          home directory in which the Java subdirectories 'bin', 'lib' and the
          like are located.

          You can download Java/OpenJDK from the Internet (usually for free),
          e.g., from Amazon, azul, bellsoft, IBM, Microsoft, ORACLE, SAP, and
          many more sites (all distributions use the same Java/OpenJDK source
          code).

          Please make sure to pay attention to the following two important
          points:

          - download the "full version" respectively the version that includes
            "JavaFX", otherwise the interesting bsf4oorexx JavaFX samples cannot
            run

          - download the Java/OpenJDK version matching your operating system
            and the machine type of your computer, e.g., a 64-bit Intel (machine
            type "x86_64") Windows version download the "x86_64" (Intel, AMD)
            Windows Java/OpenJDK installation package or zip archive. If you
            use macOS or Linux then download the respective full Java/OpenJDK
            versions.

          It is possible to have different versions of Java/OpenJDK present on
          your computer at the same time. The environment variable JAVA_HOME
          can then be used to point to the Java/OpenJDK directory that you wish
          to use in your current session/terminal/command line window. This way
          you can develop and test bsf4oorexx programs for different versions
          of Java/OpenJDK on the same computer.

          To see what becomes possible with bsf4oorexx, check out the samples
          in packages/bsf4oorexx/samples which all get briefly described in the
          index.html file located there as well.

          bsf4oorexx programs can be executed directly with rexx[.exe] or via
          Java using the shell scripts "rexxjh.cmd" (Windows)/"rexxjh.sh" (Unix),
          e.g.,

             cd packages/bsf4oorexx/samples

             rexxjh.cmd 1-040_list_charsets.rxj    -- Windows: Java loads ooRexx to run script
             rexxjh.sh  1-040_list_charsets.rxj    -- Unix: Java loads ooRexx to run script

             rexx       1-040_list_charsets.rxj    -- Rexx loads Java to run script

           Apple users please note: if running any bsf4oorexx script that creates a GUI, then
           you MUST use the scripts rexxjh.sh to run them.

---


If you have any questions or comments please communicate via the RexxLA member's
mailing list (cf. https://www.RexxLA.org).

Alternatively, communicate via the ooRexx developer list (cf. [2], [3]).

[1] Portable ooRexx 5.2.0: <https://sourceforge.net/projects/oorexx/files/oorexx/5.2.0beta/portable/>

[2] ooRexx mailing list subscription page: <https://sourceforge.net/p/oorexx/mailman/>

[3] ooRexx web mail interface to the developer mailing list:
    <https://sourceforge.net/p/oorexx/mailman/oorexx-devel/>

[4] Jean Louis Faucher's asciinema demos, at the top the demos for ooRexxShell:
    <https://jlfaucher.github.io/executor.master/demos/index.html>.
    Please note that these demos may use experimental extensions of Jean Louis
    executor (a special version based on ooRexx 4.2) which are not present
    in the regular versions of ooRexx.

----------------
as of 2026-01-17, rgf
