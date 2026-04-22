#!/usr/bin/rexx
/*
   program:          log4rexx_filter.cls
   type:             Open Object Rexx  (ooRexx)
   language level:   6.01 (ooRexx version 3.1.2 and up)

   purpose:          Defines the filter classes: .Filter, .LevelMatchFilter,
                     .LevelRangeFilter, .StringMatchFilter, .DateRangeFilter,
                     .TimeRangeFilter, .WeekdayRangeFilter, .MonthRangeFilter

                     The 'log4rexx' framework was modelled after Apache's 'log4j', which
                     can be located at <http://jakarta.apache.org/commons/logging/>,
                     but incorporates a enhancements, most notably in the properties
                     file, where filters and layouts can be named in addition to loggers
                     and appenders.

   version:          1.1.0
   license:          Choice of  Apache License Version 2.0 or Common Public License 1.0
	date:             2007-04-11
   author:           Rony G. Flatscher, Wirtschaftsuniversit&auml;t Wien, Vienna, Austria, Europe
   changes:          2007-05-17, ---rgf: changed name of files and framework from "log4r" to
                                 "log4rexx" ("log4r" has been taken by a Ruby implementation alreday)
                     2009-10-29, ---rgf: adjust for new "::requires"-behaviour in ooRexx 4.0 (not
                                         reprocessing required files each time a requires is found
                                         anymore) and the missing, undocumented ".static_requires"

   needs:	         the 'log4rexx' framework

   usage:            ::REQUIRES log4rexx_filter.cls

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
else     -- ooRexx 4.0 or higher, do a dynamic requires of "log4rexx_init.cls" in order to get at its public routines
do
   .context~package~loadPackage("log4rexx_init.cls")
end

.LogLog~debug("in" pp(req_file) "...")

    -- initialize (further?)
if \.local~hasindex("LOG4REXX") then
do
   .local~log4rexx=.directory~new
end
if \.log4rexx~hasindex("FILTER.DENY") then
do
   .log4rexx~filter.deny=0
   .log4rexx~filter.accept=1
   .log4rexx~filter.neutral=2
end



/* ------------------------------------------------------------------------------ */
/* ------------------------------------------------------------------------------ */
/* ------------------------------------------------------------------------------ */
   -- cf. <org.apache.log4j.spi.Filter>
::class "Filter"  public
::method init
  expose acceptOnMatch name
  parse arg name
  acceptOnMatch=.true         -- by default matching means "ACCEPT"

  .LogLog~debug(pp("Filter")", *** 'init' for" pp(a_or_an(self~class~id)":" name))


::method acceptOnMatch        -- getter
  expose acceptOnMatch
  return acceptOnMatch

::method "acceptOnMatch="     -- setter
  expose acceptOnMatch
  parse arg newValue          -- must be 0, 1, true, .true, false, .false

  logicalValue=getLogicalValue(newValue)
  if .nil=logicalValue then  -- not a logical value?
  do
     .LogLog~error(pp("Filter")", 'acceptOnMatch=' for" pp(a_or_an(self~class~id)":" self~name)": argument not logical, received:" pp(newValue))
     return
  end
  acceptOnMatch=logicalValue


::method configure
  expose acceptOnMatch name
  use arg properties          -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  val=properties~getPropertyValue("log4rexx.FILTER."name".acceptOnMatch", acceptOnMatch)
-- say "Filter.configure; name:" pp(name) pp("a[n]" self~class~id) "'acceptOnMatch':" pp(acceptOnMatch) "name:" pp(name) properties~entry("log4rexx.FILTER."name".acceptOnMatch")
  val=val~strip
  if acceptOnMatch<>val then
     self~acceptOnMatch=val


::method decide               -- default implementation
  return .log4rexx~filter.neutral

::method name              attribute


::method string               -- create default string value
  expose name acceptOnMatch
  return a_or_an(self~class~id)": name="name", acceptOnMatch="acceptOnMatch


::method unknown
  expose name
  use arg msgName, args

  strArgs=""
  if .nil<>args then
  do
     strArgs="with" args~items "supplied argument(s)"
     if args~items>0 then
     do
        strArgs=strArgs": "
        bComma=.false
        do item over args
           if bComma then
              strArgs=strArgs", "
           else
              bComma=.true
           strArgs=strArgs || pp(item)
        end
     end
  end

  if name="" then
     tmpStr=self~string
  else
     tmpStr=a_or_an(self~class~id)":" name

  tmpStr=pp(self~class~id) "UNKNOWN message" pp(msgName) strArgs "received for" pp(tmpStr) "!"
  .LogLog~error(tmpStr)



/* ------------------------------------------------------------------------------ */
   -- cf. <org.apache.log4j.varia.DenyAllFilter>
::class "DenyAllFilter"    subclass Filter   public

::method configure         -- does nothing

::method decide
  return .log4rexx~filter.deny

::method string            -- create default string value
  return a_or_an(self~class~id)": name="self~name


/* ------------------------------------------------------------------------------ */
   -- cf. <org.apache.log4j.spi.varia.LevelMatchFilter>
::class "LevelMatchFilter" subclass Filter   public
::method init
  expose logLevelToMatch
  logLevelToMatch =.log4rexx~logLevel.all    -- default
  forward class (super)


::method configure                  -- configure this instance of a Log-Logger
  expose logLevelToMatch
  use arg properties                -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  forward class (super) continue    -- let first superclass configure
  name=self~name

  val=properties~getPropertyValue("log4rexx.FILTER."name".logLevelToMatch", logLevelToMatch)
  val=val~strip
  if logLevelToMatch<>val then
     self~logLevelToMatch=val


::method decide
  expose logLevelToMatch
  use arg loggingEvent              -- a directory object

  if logLevelToMatch<>loggingEvent~logLevel then
     return .log4rexx~filter.neutral

  if self~acceptOnMatch=.true then
     return .log4rexx~filter.accept

  return .log4rexx~filter.deny


::method logLevelToMatch      -- getter
  expose logLevelToMatch
  return logLevelToMatch

::method "logLevelToMatch="   -- setter
  expose logLevelToMatch
  -- parse arg newValue

  tmpVal=getLogLevelAsNumber(arg(1))
  if .nil=tmpVal then
  do
     .LogLog~error(pp("LevelMatchFilter")", 'logLevelToMatch=' for" pp(a_or_an(self~class~id)":" self~name)": illegal argument, received:" pp(arg(1)))
     return
  end
  logLevelToMatch=tmpVal                  -- assign new logLevel value


::method string
  expose logLevelToMatch
  return self~string:super || ", logLevelToMatch="getLogLevelAsString(logLevelToMatch)



/* ------------------------------------------------------------------------------ */
   -- cf. <org.apache.log4j.spi.varia.LevelRangeFilter>
::class "LevelRangeFilter" subclass Filter   public
::method init
  expose logLevelMin logLevelMax
  logLevelMin     =.log4rexx~logLevel.lowest    -- default: 0
  logLevelMax     =.log4rexx~logLevel.highest   -- default: maximum (7000)
  forward class (super)



::method configure                  -- configure this instance of a Log-Logger
  expose logLevelMin logLevelMax
  use arg properties                -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  forward class (super) continue    -- let first superclass configure
  name=self~name

  val=properties~getPropertyValue("log4rexx.FILTER."name".logLevelMin", logLevelMin)
  val=val~strip
  if logLevelMin<>val then
     self~logLevelMin=val

  val=properties~getPropertyValue("log4rexx.FILTER."name".logLevelMax", logLevelMax)
  val=val~strip
  if logLevelMax<>val then
     self~logLevelMax=val



::method decide
  expose logLevelMin logLevelMax
  use arg loggingEvent              -- a directory object

  level=loggingEvent~logLevel          -- get level of log message
  if level<logLevelMin | level>logLevelMax then
     return .log4rexx~filter.deny

  if self~acceptOnMatch=.true then
     return .log4rexx~filter.accept

  return .log4rexx~filter.neutral


::method logLevelMin       -- getter
  expose logLevelMin
  return logLevelMin

::method "logLevelMin="    -- setter
  expose logLevelMin

  tmpVal=getLogLevelAsNumber(arg(1))
  if .nil=tmpVal then
  do
     .LogLog~error(pp("LevelRangeFilter")", 'logLevelMin=' for" pp(a_or_an(self~class~id)":" self~name)": illegal argument, received:" pp(arg(1)))
     return
  end
  logLevelMin=tmpVal                  -- assign new logLevel value


::method logLevelMax       -- getter
  expose logLevelMax
  return logLevelMax

::method "logLevelMax="    -- setter
  expose logLevelMax

  tmpVal=getLogLevelAsNumber(arg(1))
  if .nil=tmpVal then
  do
     .LogLog~error(pp("LevelRangeFilter")", 'logLevelMax=' for" pp(a_or_an(self~class~id)":" self~name)": illegal argument, received:" pp(arg(1)))
     return
  end
  logLevelMax=tmpVal                  -- assign new logLevel value


::method string
  expose logLevelMin logLevelMax
  return self~string:super                                  || -
           ", logLevelMin="getLogLevelAsString(logLevelMin) || -
           ", logLevelMax="getLogLevelAsString(logLevelMax)


/* ------------------------------------------------------------------------------ */
   -- cf. <org.apache.log4j.spi.varia.StringMatchFilter>
::class "StringMatchFilter"   subclass Filter   public
::method init
  expose stringToMatch ignoreCase
  stringToMatch=""
  ignoreCase=.false

  forward class (super)

::method configure                  -- configure this instance of a Log-Logger
  expose stringToMatch ignoreCase
  use arg properties                -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  forward class (super) continue    -- let first superclass configure
  name=self~name

  val=properties~getPropertyValue("log4rexx.FILTER."name".stringToMatch", stringToMatch)
  -- no STRIPping, leading and trailing blanks are regarded to be significant!
  if stringToMatch<>val then
     self~stringToMatch=val

  val=properties~getPropertyValue("log4rexx.FILTER."name".ignoreCase", ignoreCase)
  val=val~strip
  if ignoreCase<>val then
     self~ignoreCase=val


::method decide
  expose stringToMatch ignoreCase
  use arg loggingEvent              -- a directory object

  if stringToMatch="" then
     return .log4rexx~filter.neutral

  msg=loggingEvent~message          -- get message
  if .nil=msg | ""=msg then
     return .log4rexx~filter.neutral

  if ignoreCase=.true then
     bFound=(pos(stringToMatch~translate, msg~translate)>0)
  else
     bFound=(pos(stringToMatch, msg)>0)

  if bFound then                       -- match was found, now decide
  do
     if self~acceptOnMatch=.true  then
        return .log4rexx~filter.accept
     else
        return .log4rexx~filter.deny
  end

  return .log4rexx~filter.neutral


::method ignoreCase           -- getter
  expose ignoreCase
  return ignoreCase

::method "ignoreCase="        -- setter
  expose ignoreCase
  parse arg newValue          -- must be 0, 1, true, .true, false, .false

  logicalValue=getLogicalValue(newValue)
  if .nil=logicalValue then  -- not a logical value?
  do
     .LogLog~error(pp("StringMatchFilter")", 'ignoreCase=' for" pp(a_or_an(self~class~id)":" self~name)": argument not logical, received:" pp(newValue))
     return
  end
  ignoreCase=logicalValue


::method stringToMatch        -- getter
  expose stringToMatch
  return stringToMatch

::method "stringToMatch="     -- setter
  expose stringToMatch
  parse arg stringToMatch     -- forces string value



::method string
  expose stringToMatch ignoreCase
  return self~string:super || ", stringToMatch="stringToMatch || ", ignoreCase="ignoreCase



/* ------------------------------------------------------------------------------ */
/* This filter compares the actual date with the given range.

   Decision: - if wrong setup (dateMax<dateMin) returns: neutral
             - if date outside of given date range and acceptOnMatch=.true: denial
             - if date within given date range and acceptOnMatch=.false: denial
             - neutral else

   Date has to be given in the form YYYYMMDD, where non-digit delimiters may divide the
   fields of the date portion.
*/
::class "DateRangeFilter" subclass Filter   public
::method init
  expose dateMin dateMax
  dateMin   = 00010101  -- default: January, 1st, 0001
  dateMax   = 99991231  -- default: December, 31st, 9999
  forward class (super)


/* Check the argument whether it can be regarded as a valid sorted date.   */
::method checkDate
  parse arg newDate

  signal on syntax name any
  dec="0123456789"         -- decimal numbers
  if verify(newDate, dec)>0 then -- oops, not a number, create a canonical sorted date
  do
     tmpDate=translate(newDate,dec,dec||xrange("00"x,"FF"x))      -- keep decimal chars only
     parse var tmpDate y m d     -- get year, month, day
     newDate=y~right(4,0) || m~right(2,0) || d~right(2,0)   -- create sorted date
  end
  if newDate<>date("S",newDate,"S") | \datatype(newDate,"W") then
     return .nil           -- indicate an error

  return newDate

any:                       -- indicate an exception has occurred
  return .nil


::method configure                  -- configure this instance of a Log-Logger
  expose dateMin dateMax
  use arg properties                -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  forward class (super) continue    -- let first superclass configure
  name=self~name

  val=properties~getPropertyValue("log4rexx.FILTER."name".dateMin", dateMin)
  val=val~strip
  if dateMin<>val then
     self~dateMin=val

  val=properties~getPropertyValue("log4rexx.FILTER."name".dateMax", dateMax)
  val=val~strip
  if dateMax<>val then
     self~dateMax=val



   -- "Deny-only filter: if not "acceptOnMatch" and date in range, then deny, otherwise neutral
::method decide
  expose dateMin dateMax

  if (dateMax<dateMin) then         -- filter in error, does not decide anything
     return .log4rexx~filter.neutral

  use arg loggingEvent              -- a directory object
  -- parse value loggingEvent~dateTime with date .
  date=loggingEvent~date

  if date>=dateMin & date<=dateMax then
  do
     if self~acceptOnMatch=.false then -- deny if date in date range
        return .log4rexx~filter.deny

     return .log4rexx~filter.neutral   -- o.k. so far, let next filter do its work
  end

  if self~acceptOnMatch=.true then  -- not in given range, deny!
     return .log4rexx~filter.deny

  return .log4rexx~filter.neutral      -- o.k. so far, let next filter do its work



::method dateMax           -- getter
  expose dateMax
  if arg()>0 then          -- used as a setter?
     self~"dateMax="(arg(1))
  return dateMax


::method "dateMax="      -- setter
  expose dateMax
  parse arg newDate

  res=self~checkDate(newDate)   -- check date, retrieve result
  if .nil=res then         -- .nil indicates not a valid date
  do
     .LogLog~error(pp("DateRangeFilter")", 'dateMax=' for" pp(a_or_an(self~class~id)":" self~name)": argument not a sorted date, received:" pp(newDate))
     return
  end
  dateMax=res



::method dateMin         -- getter
  expose dateMin
  if arg()>0 then          -- used as a setter?
     self~"dateMin="(arg(1))
  return dateMin


::method "dateMin="      -- setter
  expose dateMin dateMax
  parse arg newDate

  res=self~checkDate(newDate)   -- check date, retrieve result
  if .nil=res then         -- .nil indicates not a valid date
  do
     .LogLog~error(pp("DateRangeFilter")", 'dateMin=' for" pp(a_or_an(self~class~id)":" self~name)": argument not a sorted date, received:" pp(newDate))
     return
  end
  dateMin=res


::method string
   expose dateMin dateMax
   return self~string:super || ", dateMin="dateMin || ", dateMax="dateMax



/* ------------------------------------------------------------------------------ */
/* This filter compares the actual time with the given range.

   Decision: - if time outside of given time range and acceptOnMatch=.true: denial
             - if time within given time range and acceptOnMatch=.false: denial
             - neutral else

   Time has to be given in the military (24hour) format: hh:mm, ranging 00:00 through 23:59
*/
::class "TimeRangeFilter" subclass Filter   public

::method init
  expose timeMin timeMax
  timeMin    = "00:00"   -- default
  timeMax      = "23:59"   -- default
  forward class (super)


/* Check the argument whether it can be regarded as a valid sorted Time.   */
::method checkTime
  parse arg newTime 1 h . ":" m

  signal on syntax name any
  if \datatype(h,"W") | h<0 | h>23 | \datatype(m,"W") | m<0 | m>60 then
     return .nil

  return h~right(2,0)":"m~right(2,0)

any:                       -- indicate an exception has occurred
  return .nil


::method configure                  -- configure this instance of a Log-Logger
  expose timeMin timeMax
  use arg properties                -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  forward class (super) continue    -- let first superclass configure
  name=self~name

  val=properties~getPropertyValue("log4rexx.FILTER."name".timeMin", timeMin)
  val=val~strip
  if timeMin<>val then
     self~timeMin=val

  val=properties~getPropertyValue("log4rexx.FILTER."name".timeMax", timeMax)
  val=val~strip
  if timeMax<>val then
     self~timeMax=val


   -- "Deny-only filter: if not "acceptOnMatch" and Time in range, then deny, otherwise neutral
::method decide
  expose timeMin timeMax

  use arg loggingEvent              -- a directory object

  time=loggingEvent~time~left(5)    -- get only HH:MM portion, such that max=23:59

  if time>=timeMin & time<=timeMax then
  do
     if self~acceptOnMatch=.false then -- deny if time in Time range
        return .log4rexx~filter.deny

     return .log4rexx~filter.neutral   -- let next filter do its work
  end

  if self~acceptOnMatch=.true then  -- not in given range, deny!
     return .log4rexx~filter.deny

  return .log4rexx~filter.neutral      -- o.k. so far, let next filter do its work



::method timeMax           -- getter
  expose timeMax
  if arg()>0 then          -- used as a setter?
     self~"timeMax="(arg(1))
  return timeMax


::method "timeMax="      -- setter
  expose timeMax
  parse arg newTime

  res=self~checkTime(newTime)   -- check Time, retrieve result
  if .nil=res then         -- .nil indicates not a valid Time
  do
     .LogLog~error(pp("TimeRangeFilter")", 'timeMax=' for" pp(a_or_an(self~class~id)":" self~name)": argument not a vaild time, received:" pp(newTime))
     return
  end
  timeMax=res


::method timeMin         -- getter
  expose timeMin
  if arg()>0 then          -- used as a setter?
     self~"timeMin="(arg(1))
  return timeMin


::method "timeMin="      -- setter
  expose timeMin
  parse arg newTime

  res=self~checkTime(newTime)   -- check Time, retrieve result
  if .nil=res then         -- .nil indicates not a valid Time
  do
     .LogLog~error(pp("TimeRangeFilter")", 'timeMin=' for" pp(a_or_an(self~class~id)":" self~name)": argument not a vaild time, received:" pp(newTime))
     return
  end
  timeMin=res


::method string
   expose timeMin timeMax
   return self~string:super || ", timeMin="timeMin || ", timeMax="timeMax



/* ------------------------------------------------------------------------------ */
/* This filter compares the actual weekday with the given range.

   Decision: - if date outside of given weekday range and acceptOnMatch=.true: denial
             - if date within given weekday range and acceptOnMatch=.false: denial
             - neutral else

   weekdays can be given either as integers 1 (Monday) ... 7 (Sunday), or
   as words (can be abbreviated to the least significant letters)
*/
::class "WeekdayRangeFilter" subclass Filter   public

::method init
  expose weekdayMin weekdayMax weekDays
  weekdayMin   = 1               -- default: Monday
  weekdayMax   = 7               -- default: Sunday
  weekDays=.directory~new        -- directory containing valid weekdays
  weekDays~mo=1; weekDays~m=1;   -- Monday
  weekDays~tu=2;                 -- Tuesday
  weekDays~we=3; weekDays~w=3;   -- Wednesday
  weekDays~th=4;                 -- Thursday
  weekDays~fr=5; weekDays~f=5;   -- Friday
  weekDays~sa=6;                 -- Saturday
  weekDays~su=7;                 -- Sunday

  forward class (super)


/* Check the argument whether it can be regarded as a valid sorted Weekday.   */
::method checkWeekday
  expose weekDays
  parse arg newWeekday .

  if datatype(newWeekday, "W") then -- a whole number?
  do
     if newWeekday>0 & newWeekday<8 then  -- within range?
        return newWeekday

     return .nil                 -- indicate an error
  end
  return weekDays~entry(newWeekday~left(2)~strip)  -- return the weekday's index (or .nil, if not present)


::method configure               -- configure this instance of a Log-Logger
  expose weekdayMin weekdayMax
  use arg properties             -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  forward class (super) continue -- let first superclass configure
  name=self~name

  val=properties~getPropertyValue("log4rexx.FILTER."name".weekdayMin", weekdayMin)
  val=val~strip
  if weekdayMin<>val then
     self~weekdayMin=val

  val=properties~getPropertyValue("log4rexx.FILTER."name".weekdayMax", weekdayMax)
  val=val~strip
  if weekdayMax<>val then
     self~weekdayMax=val


   -- "Deny-only filter: if not "acceptOnMatch" and Weekday in range, then deny, otherwise neutral
::method decide
  expose weekdayMin weekdayMax
  use arg loggingEvent              -- a directory object

  date=loggingEvent~date

  weekday=date("B", date, "S")//7+1    -- get weekday: 1...Monday through 7...Sunday

  if weekday>=weekdayMin & weekday<=weekdayMax then
  do
     if self~acceptOnMatch=.false then -- deny if weekday in Weekday range
        return .log4rexx~filter.deny

     return .log4rexx~filter.neutral   -- let next filter do its work
  end

  if weekdayMax<weekdayMin then      -- spanning weekend?
  do
     if weekday>=weekdayMin | weekday<=weekdayMax then -- we are within range
     do
        if self~acceptOnMatch=.false then -- deny if weekday in Weekday range
           return .log4rexx~filter.deny

        return .log4rexx~filter.neutral   -- let next filter do its work
     end
  end

  if self~acceptOnMatch=.true then  -- not in given range, deny!
     return .log4rexx~filter.deny

  return .log4rexx~filter.neutral      -- o.k. so far, let next filter do its work


::method weekdayMax           -- getter
  expose weekdayMax
  if arg()>0 then          -- used as a setter?
     self~"weekdayMax="(arg(1))
  return weekdayMax


::method "weekdayMax="      -- setter
  expose weekdayMax
  parse arg newWeekday

  res=self~checkWeekday(newWeekday)   -- check Weekday, retrieve result
  if .nil=res then         -- .nil indicates not a valid Weekday
  do
     .LogLog~error(pp("WeekdayRangeFilter")", 'weekdayMax=' for" pp(a_or_an(self~class~id)":" self~name)": argument not a vaild weekday, received:" pp(newWeekday))
     return
  end
  weekdayMax=res


::method weekdayMin         -- getter
  expose weekdayMin
  if arg()>0 then          -- used as a setter?
     self~"weekdayMin="(arg(1))
  return weekdayMin


::method "weekdayMin="      -- setter
  expose weekdayMin
  parse arg newWeekday

  res=self~checkWeekday(newWeekday) -- check Weekday, retrieve result
  if .nil=res then         -- .nil indicates not a valid Weekday
  do
     .LogLog~error(pp("WeekdayRangeFilter")", 'weekdayMin=' for" pp(a_or_an(self~class~id)":" self~name)": argument not a vaild weekday, received:" pp(newWeekday))
     return
  end
  weekdayMin=res


::method string
   expose weekdayMin weekdayMax
   return self~string:super || ", weekdayMin="weekdayMin || ", weekdayMax="weekdayMax




/* ------------------------------------------------------------------------------ */
/* This filter compares the actual weekday with the given range.

   Decision: - if date outside of given month range and acceptOnMatch=.true: denial
             - if date within given month range and acceptOnMatch=.false: denial
             - neutral else

   weekdays can be given either as integers 1 (Monday) ... 7 (Sunday), or
   as words (can be abbreviated to the least significant letter(s))
*/
::class "MonthRangeFilter" subclass Filter   public

::method init
  expose monthMin monthMax months
  monthMin  = 1            -- default: Monday
  monthMax  = 12           -- default: Sunday
  months=.directory~new    -- directory containing valid weekdays
  months~jan= 1;  months~ja=1;                  -- January
  months~feb= 2;  months~fe=2;   months~f=2;    -- February
  months~mar= 3;                                -- March
  months~apr= 4;  months~ap=4;                  -- April
  months~may= 5;                                -- May
  months~jun= 6;                                -- June
  months~jul= 7;                                -- July
  months~aug= 8;  months~au=8;                  -- August
  months~sep= 9;  months~se=9;   months~s=9;    -- September
  months~oct=10;  months~oc=10;  months~o=10;   -- October
  months~nov=11;  months~no=11;  months~n=11;   -- November
  months~dec=12;  months~de=12;  months~d=12;   -- December

  forward class (super)


/* Check the argument whether it can be regarded as a valid sorted Month.   */
::method checkMonth
  expose months
  parse arg newMonth .

  if datatype(newMonth, "W") then -- a whole number?
  do
     if newMonth>0 & newMonth<13 then  -- within range?
        return newMonth

     return .nil                 -- indicate an error
  end
  return months~entry(newMonth~left(3)~strip)  -- return the weekday's index (or .nil, if not present)


::method configure               -- configure this instance of a Log-Logger
  expose monthMin monthMax
  use arg properties             -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  forward class (super) continue -- let first superclass configure
  name=self~name

  val=properties~getPropertyValue("log4rexx.FILTER."name".monthMin", monthMin)
  val=val~strip
  if monthMin<>val then
     self~monthMin=val

  val=properties~getPropertyValue("log4rexx.FILTER."name".monthMax", monthMax)
  val=val~strip
  if monthMax<>val then
     self~monthMax=val



   -- "Deny-only filter: if not "acceptOnMatch" and Month in range, then deny, otherwise neutral
::method decide
  expose monthMin monthMax
  use arg loggingEvent              -- a directory object

  parse value loggingEvent~date with . +4 month +2 . -- extract month

  if (month>=monthMin | monthMin="") & (month<=monthMax | monthMax="") then
  do
     if self~acceptOnMatch=.false then -- deny if month in Month range
        return .log4rexx~filter.deny

     return .log4rexx~filter.neutral   -- let next filter do its work
  end

  if monthMax<monthMin then       -- spanning year?
  do
     if month>=monthMin | month<=monthMax then -- we are within range
     do
        if self~acceptOnMatch=.false then -- deny if month in Month range
           return .log4rexx~filter.deny

        return .log4rexx~filter.neutral   -- let next filter do its work
     end
  end

  if self~acceptOnMatch=.true then  -- not in given range, deny!
     return .log4rexx~filter.deny

  return .log4rexx~filter.neutral      -- o.k. so far, let next filter do its work



::method monthMax           -- getter
  expose monthMax
  if arg()>0 then          -- used as a setter?
     self~"monthMax="(arg(1))
  return monthMax


::method "monthMax="      -- setter
  expose monthMax
  parse arg newMonth

  res=self~checkMonth(newMonth)   -- check Month, retrieve result
  if .nil=res then         -- .nil indicates not a valid Month
  do
     .LogLog~error(pp("MonthRangeFilter")", 'monthMax=' for" pp(a_or_an(self~class~id)":" self~name)": argument not a vaild month, received:" pp(newMonth))
     return
  end
  monthMax=res


::method monthMin         -- getter
  expose monthMin
  if arg()>0 then          -- used as a setter?
     self~"monthMin="(arg(1))
  return monthMin


::method "monthMin="      -- setter
  expose monthMin
  parse arg newMonth

  res=self~checkMonth(newMonth) -- check Month, retrieve result
  if .nil=res then         -- .nil indicates not a valid Month
  do
     .LogLog~error(pp("MonthRangeFilter")", 'monthMin=' for" pp(a_or_an(self~class~id)":" self~name)": argument not a vaild month, received:" pp(newMonth))
     return
  end
  monthMin=res


::method string
   expose monthMin monthMax
   return self~string:super || ", monthMin="monthMin || ", monthMax="monthMax


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
