#!/usr/bin/rexx
/*
	program:          log4rexx.cls
	type:             Open Object Rexx  (ooRexx)
   language level:   6.01 (ooRexx version 3.1.2 and up)

	purpose:          Core file of the 'log4rexx' framework, which sets up the framework
                     and supplies the central (configuration) services through the
                     .LogManager class.

                     The 'log4rexx' framework was modelled after Apache's 'log4j', which
                     can be located at <http://jakarta.apache.org/commons/logging/>,
                     but incorporates a enhancements, most notably in the properties
                     file, where filters and layouts can be named in addition to loggers
                     and appenders.

	version:          1.2.0
   license:          Choice of  Apache License Version 2.0 or Common Public License 1.0
	date:             2007-04-11, ---rgf
	author:           Rony G. Flatscher, Wirtschaftsuniversit&auml;t Wien, Vienna, Austria, Europe
   changes:          2007-04-17, ---rgf, fixed wrong (reverse) order for looking up directories
                                         for "log4rexx.properties" and "simplelog4rexx.properties"
                     2007-05-17, ---rgf: changed name of files and framework from "log4r" to
                                 "log4rexx" ("log4r" has been taken by a Ruby implementation alreday)
                     2009-10-29, ---rgf: adjust for new "::requires"-behaviour in ooRexx 4.0 (not
                                         reprocessing required files each time a requires is found
                                         anymore) and the missing, undocumented ".static_requires"
                     2009-10-30, ---rgf, using the filespec()-BIF according to the operating system platform

	needs:	         the 'log4rexx' framework, directly requires 'log4rexx_logger.cls'

	usage:            CALL log4rexx.cls
                          or:
                     ::REQUIRES log4rexx.cls


	returns:          ---
*/

PARSE SOURCE . . REQ_FILE

parse version "_" v "("    -- get version number, e.g. "4.0.0"
if v<4 then                -- only available prior to ooRexx 4.0.0 (language level < 6.02)
do
      /* the following statement makes sure that this module is loaded only once,
         no matter how many times it got required (but note: if CALLing this file,
         each call will work and re-setup everything) */
   .STATIC_REQUIRES~put(time("C"), REQ_FILE~translate)
end

.LogLog~debug("in" pp(req_file) "...")


/* If this module is required, due to using the "static_requires" feature,
   public classes are not put into .environment, hence we need to do that
   ourselves (then, we could also store a reference in .local as well).
*/



::requires "log4rexx_logger.cls"


/* ------------------------------------------------------------------------------ */
/* ------------------------------------------------------------------------------ */
/* ------------------------------------------------------------------------------ */
/*
   Manager of the 'log4r' framework:
   - configures
   - creates & sets up loggers, appenders and filters
   - returns (if necessary creates) loggers, appenders, filters by name
*/
::class "LogManager"    public

::method init           class
  expose appenderDir filterDir layoutDir loggerDir             -
         configFileName configFileTimeStamp                    -
         configuration newConfiguration startUpDateTime alarm


   -- make sure that this class object is available via .local !
   -- (if used with static requires, class object is *not* put into .local, even if public)
  .local~LogManager=self

  alarm        =.nil             -- indicate no alarm as of yet
  configuration=.nil             -- indicate no properties as of yet
  newConfiguration=.nil          -- indicate no new properties as of yet
  configFileName=""              -- indicate no config file name
  configFileTimeStamp=""         -- indicate no timestamp as of yet

  appenderDir  = .directory~new  -- directory of named appenders
  filterDir    = .directory~new  -- directory of named filters
  layoutDir    = .directory~new  -- directory of named layouts
  loggerDir    = .directory~new  -- directory of named loggers

  startUpDateTime = date('S', , , '-') time('L') date('B') time('S')

  self~configure                 -- get configuration
  self~resetConfiguration        -- activate configuration

  time2Sleep=.log4rexx.config.configFileWatchInterval
  if datatype(time2sleep, "W") & configFileName<>"" then
  do
     if time2sleep>0 then
     do
        alarm=.alarm~new(time2sleep, .message~new(self, "configureAndWatch"))
        .LogLog~debug(pp(self)", 'init': 'configureAndWatch' will be invoked in" pp(time2sleep) "sec(s)")
     end
  end


::method startDateTime  attribute   class

::method appenderDir    class       -- getter
  expose appenderDir
  return appenderDir~copy

::method filterDir      class       -- getter
  expose filterDir
  return filterDir~copy

::method layoutDir      class       -- getter
  expose layoutDir
  return layoutDir~copy

::method loggerDir      class       -- getter
  expose loggerDir
  return loggerDir~copy


::method configuration  class       -- getter
  expose configuration
  return configuration~copy



::method getAppender    class       -- getter
  expose appenderDir configuration
  parse arg name

   -- if not exists yet, create one, if second argument is a class object
  if \appenderDir~hasentry(name) then
  do
     clz=arg(2)                     -- get second argument
     if clz~isInstanceOf(.Class) then  -- a class object in hand?
     do
        newObj=clz~new(name)
        appenderDir~setEntry(name, newObj)
        .LogLog~debug(pp(self)", <--- 'getAppender': had to create" pp(newObj))
        return newObj~~configure(configuration)  -- let the object configure itself
     end
     return .nil                    -- indicate no object found
  end
  return appenderDir~entry(name)


::method getFilter      class       -- getter
  expose filterDir configuration
  parse arg name

   -- if not exists yet, create one, if second argument is a class object
  if \filterDir~hasentry(name) then
  do
     clz=arg(2)                     -- get second argument
     if clz~isInstanceOf(.Class) then  -- a class object in hand?
     do
        newObj=clz~new(name)
        filterDir~setEntry(name, newObj)
        .LogLog~debug(pp(self)", <--- 'getFilter': had to create" pp(newObj))
        return newObj~~configure(configuration)  -- let the object configure itself
     end
     return .nil                    -- indicate no object found
  end
  return filterDir~entry(name)


::method getLayout      class       -- getter
  expose layoutDir configuration
  parse arg name
   -- if not exists yet, create one, if second argument is a class object
  if \layoutDir~hasentry(name) then
  do
     clz=arg(2)                     -- get second argument
     if clz~isInstanceOf(.Class) then  -- a class object in hand?
     do
        newObj=clz~new(name)
        layoutDir~setEntry(name, newObj)
        .LogLog~debug(pp(self)", <--- 'getLayout': had to create" pp(newObj))
        return newObj~~configure(configuration)  -- let the object configure itself
     end
     return .nil                    -- indicate no object found
  end
  return layoutDir~entry(name)


   /* If log instance for given Name exists already, return it,
      otherwise return new Log instance.
   */
::method getLogger      class       -- getter, if necessary create requested logger
  expose loggerDir configuration
  parse arg loggerName

  if \loggerDir~hasentry(loggerName) then -- does not exist yet, hence create one
  do
     envSymbol="." || .log4rexx.config.LoggerFactoryClassName~string
     interpret "clz="envSymbol

     if envSymbol~translate=clz then      -- no class object ?
     do
        .LogLog~error(pp(self)", 'getLogger': cannot get logger class object:" pp(envSymbol))
        return .nil
     end
     else
     do
        newLog=clz~new(loggerName)
        newLog~setUpParent             -- make sure we point to parent (ultimately to rootLogger)
        loggerDir~setEntry(loggerName, newLog)
        .LogLog~debug(pp(self)", <--- 'getLogger': had to create" pp(newLog))
         -- TODO: any side-effects if configuring loggers here (e.g. rootLogger?)
        return newLog~~configure(configuration)  -- let the object configure itself
     end
  end
  return loggerDir~entry(loggerName)



::method putAppender    class
  expose appenderDir
  use arg name, o

  if \app~isInstanceOf(.Appender) then
  do
     str="Appender"
     .LogLog~error(pp(self)", 'put"str"': 2nd argument is not of type '."str"', hence ignoring it:" pp(o))
     return
  end

  name=name~string      -- make sure we have a string
  if appenderDir~hasentry(name) then
     .LogLog~warn(pp(self)", 'putAppender': replacing an existing entry named:" pp(name))

  appenderDir~put(o, name)          -- save supplied appender object


::method putFilter    class
  expose FilterDir
  use arg name, o

  if \app~isInstanceOf(.Filter) then
  do
     str="Filter"
     .LogLog~error(pp(self)", 'put"str"': 2nd argument is not of type '."str"', hence ignoring it:" pp(o))
     return
  end

  name=name~string      -- make sure we have a string
  if FilterDir~hasentry(name) then
     .LogLog~warn(pp(self)", 'putFilter': replacing an existing entry named:" pp(name))

  FilterDir~put(o, name)          -- save supplied Filter object


::method putLayout    class
  expose LayoutDir
  use arg name, o

  if \app~isInstanceOf(.Layout) then
  do
     str="Layout"
     .LogLog~error(pp(self)", 'put"str"': 2nd argument is not of type '."str"', hence ignoring it:" pp(o))
     return
  end

  name=name~string      -- make sure we have a string
  if LayoutDir~hasentry(name) then
     .LogLog~warn(pp(self)", 'putLayout': replacing an existing entry named:" pp(name))

  LayoutDir~put(o, name)          -- save supplied Layout object


::method putLogger    class
  expose LoggerDir
  use arg name, o

  if \app~isInstanceOf(.Logger) then
  do
     str="Logger"
     .LogLog~error(pp(self)", 'put"str"': 2nd argument is not of type '."str"', hence ignoring it:" pp(o))
     return
  end

  name=name~string      -- make sure we have a string
  if LoggerDir~hasentry(name) then
     .LogLog~warn(pp(self)", 'putLogger': replacing an existing entry named:" pp(name))

  LoggerDir~put(o, name)          -- save supplied Logger object


::method rootLogger  class          -- getter
  expose loggerDir
  return loggerDir~rootLogger


::method "rootLogger="  class private  -- setter
  expose loggerDir
  use arg log

  .LogLog~debug(pp(self)", 'rootLogger=':" pp(log))
  if loggerDir~rootLogger<>log then -- a new rootLogger, save it
  do
     loggerDir~rootLogger=log
     .local~log4rexx.rootLogger=log
      -- make sure that all now point to this new rootLogger
     do idx over loggerDir
        loggerDir[idx]~setUpParent
     end
  end


::method stopWatching   class       -- stop watching file for changes, re-start by sending "configureAndWatch"
  expose alarm
  if .nil<>alarm then               -- if alarm object, then just cancel it
     alarm~cancel


::method configure      class       -- find configuration file and read it (cf. log4j)
  expose configFileName configuration newConfiguration configFileTimeStamp
  .LogLog~debug(pp(self~string)", method 'configure'")

  factoryName="log4rexx.config.LoggerFactoryClassName"

  fileName=findConfigFile()     -- try to find config file
  .LogLog~debug(pp(self~string)", method 'configure', received 'fileName'="pp(fileName))
  if fileName<>"" then        -- file found, read & process it
  do
     .LogLog~debug(pp(self)", 'configure': using" pp(fileName) "for configuration")

     if .nil=configuration then     -- very first run, determine factoryLogClassName
     do
         needle="simplelog4rexx.properties"     -- use "SimpleLog" class
         if fileName~right(needle~length)=needle then
            factoryLogClassName="SimpleLog"
         else                                -- use "Log" class
            factoryLogClassName="Log"

         if .local~entry(factoryName)<>factoryLogClassName then   -- different than default?
         do
           .local~setEntry(factoryName, factoryLogClassName)
           .LogLog~debug(pp(self~string)", method 'configure':" pp("."factoryName) "set to:" pp(.local~entry(factoryName)))
         end
     end

     configFileName=fileName        -- save configuration file name
         -- read file, add possible missing configuration settings from environment
     envSettings=getLog4rSettingsFromEnvironment() -- get all log4rexx settings in .local
     newConfiguration=.log4rexx.properties~readPropertyFile(configFileName)~union(envSettings)
     configFileTimeStamp=stream(configFileName, "C", "QUERY TIMESTAMP")
     return .true                   -- indicate we processed a configuration from file
  end
  else if .nil=configuration then   -- no configuration at all yet, define default configuration
  do
     .LogLog~debug(pp(self~string)", 'configure': no configuration file found, using hard-coded defaults.")
     if \.local~hasEntry(factoryName) then      -- nothing set & found: do not display any logs
     do
        .local~setEntry(factoryName, "NoOpLog")
        .LogLog~debug(pp(self~string)", method 'configure':" pp("."factoryName) "set to:" pp(.local~entry(factoryName)))
     end

      -- define defaults:
     newConfiguration=.log4rexx.properties~new~union(getLog4rSettingsFromEnvironment())
  end
  return .false   -- indicate configuration is *NOT* from a file, ie. no new "newConfiguration"!


::method resetConfiguration class   -- make new configuration current (possibly "reset"ting an older one; cf. log4j)
  expose configFileName configuration newConfiguration configFileTimeStamp -
         appenderDir filterDir layoutDir loggerDir

      -- at setup time 'configuration' will be .nil
  if newConfiguration~same(configuration) then    -- identical, nothing has changed !
     return .false                  -- indicate that no configuration changes have occurred

   -- save newConfiguration
  configuration=newConfiguration

      -- set environment up
  envKeys=.array~of("log4rexx.config.asyncMode",               -
                    "log4rexx.config.configFile",              -
                    "log4rexx.config.configFileWatchInterval", -
                    "log4rexx.config.disable",                 -
                    "log4rexx.config.disableOverride",         -
                    "log4rexx.config.LoggerFactoryClassName",  -
                    "log4rexx.config.LogLog.debug",            -
                    "log4rexx.config.LogLog.quietMode")
   do key over envKeys
      if newConfiguration~hasentry(key) then
      do
         newVal=newConfiguration~entry(key)
         oldVal=.local~entry(key)
         if newVal<>oldVal then        -- if a change in value, carry it out
         do
            .local~setentry(key, newVal)
            .LogLog~debug(pp(self)", 'resetConfiguration': changed value of" pp("."key) -
                                  "from" pp(oldVal) "to" pp(newVal))
         end
      end
   end

      -- determine class object for creating loggers
      -- due to the static requires the class objects are not stored in .local, but
      -- either in .source or between .source and .local, hence we can get only
      -- access to them via environment symbols
   tmpStr=.log4rexx.config.LoggerFactoryClassName~translate

   interpret "loggerFactoryClassObject=." || .log4rexx.config.LoggerFactoryClassName~string

   if tmpStr="LOG" then
      loggerFactoryClassObject=.Log

   else if tmpStr="SIMPLELOG" then
      loggerFactoryClassObject=.SimpleLog
   else if tmpStr="NOOPLOG" then
      loggerFactoryClassObject=.NoOpLog
   else
      interpret "loggerFactoryClassObject=."tmpStr

   if loggerFactoryClassObject=.nil then
   do
      loggerFactoryClassObject=.Log
      .LogLog~error(pp(self)", 'resetConfiguration':" pp(.log4rexx.config.LoggerFactoryClassName) -
                    "does not exist, using 'Log' class instead!")
   end

   -- process categories that are referred to by name
   sConfig.=sortByIndex(newConfiguration)  -- sort by index, returns a sorted stem

      -- find first index for each of the following groups:
   s=.array~of("LOG4REXX.APPENDER.", "LOG4REXX.CONFIG.", "LOG4REXX.FILTER.", -
               "LOG4REXX.LAYOUT.",   "LOG4REXX.LOGGER.")
   sConfigStart=.directory~new
   do abbr over s
      sConfigStart~setEntry(abbr, 0)      -- create entry, indicate no begin found as of yet
      do i=1 to sConfig.0
         if abbrev(sConfig.i, abbr) then     -- found the abbreviation!
         do
            sConfigStart~setEntry(abbr, i)   -- save abbrev and index where abbrev starts
            leave
         end
      end
   end


      -- set the global 'simplelog' settings, if given
   sls=.list~of("defaultLogLevel", "showDateTime", "showLoggerName", "showShortName")

   do slOption over sls    -- loop over SimpleLog default settings
      key="log4rexx.config.simplelog." || slOption
      if newConfiguration~hasEntry(key) then
         .message~new(.SimpleLog, slOption"=", "I", newConfiguration~entry(key))~send
   end


      -- create filters
      -- create layouts
      -- create appenders (which may need to use filters, hence they should be already processed)
   stemNr=0
   do stem over .list~of("LOG4REXX.FILTER.", "LOG4REXX.LAYOUT.", "LOG4REXX.APPENDER.")
      stemNr=stemNr+1      -- increase stemNr
      start=sConfigStart~entry(stem)
      if start=0 then
      do
         .LogLog~debug(pp(self)", 'resetConfiguration': no configuration data for" pp(stem))
         iterate
      end

      parse var stem "LOG4REXX." type "."    -- extract type/class name
      do i=start to sConfig.0
         if \abbrev(sConfig.i, stem) then -- a new group ?
            leave

         parse var sConfig.i with (stem) name "." key
         if key="" then                   -- a new filter/layout/appender!
         do
            val=newConfiguration~entry(sConfig.i)~strip  -- get property value
            interpret "clz=."val          -- try to get class object

            if clz~isInstanceOf(.Class) then
            do
               if stemNr=3 then           -- appender
               do
                  bConfigure=appenderDir~hasentry(name)  -- if exists already, then reconfigure!
                  o=self~getAppender(name, clz)
               end
               else if stemNr=1 then      -- filter
               do
                  bConfigure=filterDir~hasentry(name)    -- if exists already, then reconfigure!
                  o=self~getFilter(name, clz)
               end
               else if stemNr=2 then      -- layout
               do
                  bConfigure=layoutDir~hasentry(name)    -- if exists already, then reconfigure!
                  o=self~getLayout(name, clz)
               end

               if bConfigure then
               do
                  o~configure(newConfiguration) -- let the object re-configure itself
               end
            end
            else
            do
               .LogLog~error(pp(self)", 'resetConfiguration': entry"  -
                    pp(sConfig.i) "denotes a non-existing class:" pp(val)"!")
            end
         end
      end
   end

      -- make sure we have a rootLogger
   if \loggerDir~hasentry("rootLogger") then    -- no root logger as of yet, create one
   do
         -- create a default rootLogger
      log=loggerFactoryClassObject~new("rootLogger")
      log~configure(newConfiguration)     -- let the logger configure itself
      if log~appenderQueue~items=0 then   -- no appender defined, then default to ConsoleAppender
      do
         if log~class~id<>"NoOpLog" then  -- make sure a ConsoleAppender if not a "NoOpLog" instance
            log~addAppender(.ConsoleAppender~new(""))
      end

      self~rootLogger=log                 -- store this logger as rootLogger
   end

      -- create and configure loggers
   stem="LOG4REXX.LOGGER."
   start=sConfigStart~entry(stem)
   do i=start to sConfig.0
      if \abbrev(sConfig.i, stem) then    -- a new group ?
         leave

      parse var sConfig.i with (stem) name .

      lastChunk=substr(name, lastpos(".", name)+1)~translate

      bConfigure= (loggerFactoryClassObject=.Log & lastChunk<>"ADDITIVITY") | -
                  (loggerFactoryClassObject=.SimpleLog & wordpos(lastChunk, "SHOWDATETIME SHOWLOGGERNAME SHOWSHORTNAME")=0)

      -- if substr(name, lastpos(name, ".")+1)~translate<>"ADDITITVITY" then    -- a new logger!
      if bConfigure then                  -- a new logger!
      do

         bConfigure=loggerDir~hasentry(name) -- if exists already, then reconfigure!
         logger=self~getLogger(name)      -- create a new logger or return existing one

         if bConfigure then               -- reconfigure, if necessary
            logger~configure(newConfiguration)
      end
   end


   -- monitor configuration file for changes?
::method configureAndWatch class    --
  expose configFileName configuration newConfiguration configFileTimeStamp alarm

  if configFileName="" & .nil=.log4rexx.config.configFile then   -- nothing to do ?
     return

  bReadFile=.false
  if configFileName<>"" then
     bReadFile=(configFileTimeStamp<>stream(configFileName,"C", "QUERY TIMESTAMP"))

  if bReadFile then                 -- read configuration from file
  do
     res=self~configure             -- get (new) configuration
     self~resetConfiguration        -- reset configuration
     if \res then                   -- file not found, hence do not watch
        return
  end

   -- now set a new alarm (which will cause this method to be invoked)
  time2Sleep=.log4rexx.config.configFileWatchInterval
  if datatype(time2sleep, "W") & configFileName<>"" then
  do
     if time2sleep>0 then           -- use an alarm object ?
        alarm=.alarm~new(time2sleep, .message~new(self, "configureAndWatch"))
  end




/* ------------------------------------------------------------------------------ */
::routine findConfigFile   -- try to locate configuration file, return filename, if found, "" else
/* Get configuration information, look for the files named:

   1) .log4rexx.config.configFile, if not found look for

   2) "log4rexx.properties", if found use ".Log" as default logger class
   3) "simplelog4rexx.properties", if found use ".SimpleLog" as default logger class

   in the following sequence:

   1) current directory
   2) directory log4rexx resides
   3) along PATH

   If not found, use ".NoOp" as default logger class,
   do *not* honor ".log4rexx.config.configFileWatchInterval".

   Then:

   - create "log4rexx.logger.rootLogger"
*/


  /* try to read a file named "simplelog.properties" to set the default
     logging options:
     - look for current directory first,
     - then for directory where this module resides.
   */

   .LogLog~debug(pp("findConfigFile()") "- just entered.")

   -- if .local~hasentry("log4rexx.CONFIG.configFile") then
   if .nil<>.log4rexx.CONFIG.configFile & .log4rexx.config.config.File<>'.log4rexx.CONFIG.CONFIGFILE' then
   do
      fn=.log4rexx.config.configFile
      if stream(fn, "C", "QUERY EXISTS")<>"" then  -- found!
      do
         .local~log4rexx.config.LoggerFactoryClassName="Log"   -- default to .Log class
         .LogLog~debug(pp("findConfigFile()") "- returning '.log4rexx.config.configFile':" pp(fn))
         .LogLog~debug(pp("findConfigFile()") "- '.log4rexx.config.LoggerFactoryClassName' set to:" pp(.log4rexx.config.LoggerFactoryClassName))
         return fn
      end
      .LogLog~warn("findConfigFile() - '.log4rexx.config.configFile':" pp(.log4rexx.config.configFile) "not found!")
   end

   fileSep=.log4rexx~file.sep       /* e.g. "/", "\"     */
   pathSep=.log4rexx~path.sep       /* e.g. ":", ";"     */

      /* search for properties files in current dir or log4rexx home dir   */
   parse source op_sys +1 . fullPath        -- get path to this file
   if op_sys="W" then   -- on Windows option "Drive" is available, so use it
      log4rexx.home=filespec("Drive", fullPath) || filespec("Path", fullPath)
   else
      log4rexx.home=filespec("Path", fullPath)

   -- paths=.queue~new~~push("."||fileSep) ~~push(log4rexx.home) -- add the first two directories
   paths=.queue~new~~queue("."||fileSep) ~~queue(log4rexx.home) -- add the first two directories
   fileNames=.list~of("log4rexx.properties", "simplelog4rexx.properties")
   fn=getPropFileName(fileNames, paths)
   if fn<>"" then                   -- found? if so, return fully qualified path
   do
      if left(fn,1)="." then
         tmpStr="in the current" pp('.') "directory"
      else
         tmpStr="in the 'log4rexx.cls' directory"

      propFN=substr(fn, fn~lastpos(fileSep)+1) -- get name of property file
      .LogLog~debug(pp("findConfigFile()") "- found a properties file" pp(propFN) tmpStr":" pp(fn))

      if propFN~left(1)~translate="L" then
         .local~log4rexx.config.LoggerFactoryClassName="Log"         -- default to .Log class
      else
         .local~log4rexx.config.LoggerFactoryClassName="SimpleLog"   -- default to .SimpleLog class

      .LogLog~debug(pp("findConfigFile()") "- '.log4rexx.config.LoggerFactoryClassName' set to:" pp(.log4rexx.config.LoggerFactoryClassName))

      return fn
   end

      /* search for properties files along the PATH   */
   opsysPath=value("PATH", , "ENVIRONMENT")  -- get value of PATH
   paths=.queue~new
   do while opsysPath<>""           -- extract directories one by one
      parse var opsysPath p (path.sep) opsysPath

      if right(p,1)<>file.sep then   -- does path end in slash (e.g. root), if not, add it
         p=p || fileSep
   end

   fn=getPropFileName(fileNames, paths)
   if fn<>"" then                   -- found? if so, return fully qualified path
   do
      .LogLog~debug(pp("findConfigFile()") "- found a properties file searching 'PATH':" pp(fn))
      return fn
   end

   .LogLog~warn(pp("findConfigFile()") "- could not find a properties file.")

   return ""


getPropFileName: procedure          -- process given path and look for given files
   use arg fileNames, paths

   do f over fileNames
      do p over paths
         fn=p || f
         if stream(fn, "C", "QUERY EXISTS")<>"" then
            return fn
      end
   end
   return ""


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
