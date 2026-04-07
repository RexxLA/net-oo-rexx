====================================================================
Portable Zip Archive ("Stick") Version for Open Object Rexx (ooRexx)
====================================================================

ooRexx (open object Rexx) is an easy-to-learn, dynamically typed, caseless, and
powerful programming language. ooRexx implements the message paradigm that
makes it easy to interact with any type of system.

ooRexx is an open-source project governed by the non-profit, international
special interest group named "Rexx Language Association" (RexxLA).

This version of ooRexx allows you to install several versions of ooRexx on the
same computer in parallel, and choose which version is used on a program-by-
program basis.  It also allows you to install one or more versions in a
removable drive (e.g., in an external USB stick, hence the name "portable")
and carry it along, using it on different machines.

Links:

   ooRexx Project:  https://sourceforge.net/projects/oorexx/
   RexxLA Homepage: http://www.rexxla.org


-------------------------------------
Creating the Portable Scripts (Setup)
-------------------------------------

After unzipping the portable zip archive (using "unzip" or "7z") and changing
into the created subdirectory run

       Windows:                   Unix:
       --------                   -----
       setup.cmd                  ./setup.sh  (Unix)

which will run "setup.rex" using the Rexx interpreter from its "bin"
subdirectory (i.e., "bin/rexx setup.rex").

This will create two shell scripts:

      Windows:                    Unix:
      --------                    -----
      run.cmd                     run
      setenv.cmd                  setenv

If the location of the script's home directory has changed simply rerun the
"setup.cmd" (Windows) or "setup.sh" (Unix) script to recreate the two shell
scripts picking up the new location.


----------------------------------------------------------------------------
Purpose and usage of the script "run.cmd" (Windows) or "run" (Unix):
temporarily change PATH to find the portable version of ooRexx first
----------------------------------------------------------------------------

   This script will temporarily set up the environment. It expects 'rexx'
   followed by the name of a Rexx program and optionally followed by any
   arguments for the Rexx program, e.g.

       run rexx testoorexx.rex        (Windows)
       ./run rexx testoorexx.rex      (Unix)

   In case "ooRexx packages with oorexxshell" is installed (a subdirectory
   'packages' exists) then oorexxshell can be run as well:

       run oorexxshell                (Windows)
       ./run oorexxshell              (Unix)

      -> oorexxshell explanations/demos:
           https://jlfaucher.github.io/executor.master/demos/index.html

   Upon return from the "run" process the shell's environment is unchanged.


----------------------------------------------------------------------------
Purpose and usage of the script "setenv.cmd" (Windows) or "setenv" (Unix):
allow to change the environment permanently in a shell to find the portable
version of ooRexx first
----------------------------------------------------------------------------

   This script will permanently set up the environment in the current terminal
   shell:

       setenv                     (Windows)
       source ./setenv            (Unix, you MUST use the "source" command)

   After executing the script the environment gets changed such that the
   portable version of rexx.exe/rexx will be found first for the duration of
   the terminal session. To use it use "rexx" to run Rexx programs, e.g.:

       rexx testoorexx.rex

   In case "ooRexx packages with oorexxshell" is installed (a subdirectory
   'packages' exists) then oorexxshell can be run as well:

       oorexxshell                      (both Windows and Unix)

   To locate the Rexx directory being used by the generated scripts inspect
   the environment variables REXX_HOME, OOREXX_HOME and PATH, e.g.

       echo %REXX_HOME%                 (Windows)
       echo %OOREXX_HOME%               (Windows)
       echo %PORTABLE_HOME%             (Windows)
       echo %PACKAGES_HOME%             (Windows)
       echo %PATH%                      (Windows)

       echo $REXX_HOME                  (Unix, usually not set)
       echo $OOREXX_HOME                (Unix)
       echo $PORTABLE_HOME              (Unix)
       echo $PACKAGES_HOME              (Unix)
       echo $PATH                       (Unix)


----------------
as of 2026-01-17, rgf
