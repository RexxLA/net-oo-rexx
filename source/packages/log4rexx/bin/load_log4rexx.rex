#!/usr/bin/rexx
/*
	program:          load_log4rexx.rex
	type:             Open Object Rexx (ooRexx)
   language level:   6.01 (ooRexx version 3.1.2 and up)
	purpose:          Allows a program to setup .log4r-environment entries to be honored, before
                     loading the 'log4rexx' framework using the keyword instruction 'CALL'.

                     Of course, using the "REQUIRES" directive will work as well, but a requires
                     will be resolved before your own program which contains that directive
                     has finished initializing, hence not allowing you to set the following
                     settings upfront.

                     The 'log4rexx' framework was modelled after Apache's 'log4j', which
                     can be located at <http://jakarta.apache.org/commons/logging/>,
                     but incorporates a enhancements, most notably in the properties
                     file, where filters and layouts can be named in addition to loggers
                     and appenders.

	version:          1.1.0

   license:          Choice of  Apache License Version 2.0 or Common Public License 1.0
	date:             2007-04-10, ---rgf, released
   changes:          2007-05-17, ---rgf: changed name of files and framework from "log4r" to
                                 "log4rexx" ("log4r" has been taken by a Ruby implementation alreday)
	author:           Rony G. Flatscher, Wirtschaftsuniversit&auml;t Wien, Vienna, Austria, Europe

	needs:	         'log4rexx.cls' from the 'log4rexx' framework

	usage:            CALL load_log4rexx.rex

	returns:          ---
*/


/* Environment variables that can be set, before CALLing this program:

   Settable .local entries that control overall features of the 'log4rexx' framework,
   which you may set *before* calling this program (all are set to "save defaults"):

      -- controls whether log-messages are processed synchroneously (default)
   .local~log4rexx.config.asyncMode=.false


      -- allows determining which properties file to use; if not given
         'log4rexx.properties' and 'simplelog4rexx.properties' are searched in
         current dir, 'log4r' dir, then along the PATH
   .local~log4rexx.config.configFile=configFileName

      -- allows indicating the seconds to sleep between checking whether
         config-file has changed; if it changes, it gets re-read and
         processed; if activated (>0) you can stop this using the statement
         ".LogManager~stopWatching"
         a value of '0' seconds means no checking
   .local~log4rexx.config.configFileWatchInterval=0


      -- if given, *globally* (for all loggers and appenders) disables
         the processing of log messages with a level equal to or smaller
         than the one given here (e.g. for production could be set to 'WARN',
         which will cause to only process logLevels 'ERROR' and 'FATAL')
   .local~log4rexx.config.disable=logLevel

      -- allows to (temporarily) override (ignore) the '.log4rexx.config.disable' setting
   .local~log4rexx.config.disableOverride=.false

      -- determines which class to use to create loggers: if no properties file can
         be found 'log4rexx' will set it to "NoOpLog", if only a 'simplelog4rexx.properties'
         is found it will get set to 'SimpleLog', otherwise to 'Log'
   .local~log4rexx.config.LoggerFactoryClassName=Log|SimpleLog|NoOpLog


      -- controls whether 'log4rexx' framework issues debug messages itself using .LogLog
   .local~log4rexx.config.LogLog.debug=.false

      -- controls whether 'log4rexx' framework logs at level DEBUG, WARN and ERROR sent
         to .LogLog get displayed or not
   .local~log4rexx.config.LogLog.quietMode=.false

*/




/* note: using "REQUIRES" instead of "call log4r_logger.cls" makes sure, that
         the required modules are initialized only once, as they have been
         defined to be "static requires"; otherwise "log4rexx.cls" itself
         would be initialized each time it gets called (but not its statically
         required modules)
*/
::requires "log4rexx.cls"




/*

Choice of:

------------------------ Apache Version 2.0 license -------------------------
   Copyright 2007 Rony G. Flatscher

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-----------------------------------------------------------------------------

or:

------------------------ Common Public License 1.0 --------------------------
   Copyright 2007 Rony G. Flatscher

   This program and the accompanying materials are made available under the
   terms of the Common Public License v1.0 which accompanies this distribution.

   It may also be viewed at: http://www.opensource.org/licenses/cpl1.0.php
-----------------------------------------------------------------------------

See also accompanying license files for full text.

*/
