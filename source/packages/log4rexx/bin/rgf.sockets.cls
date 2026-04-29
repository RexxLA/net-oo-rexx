#!/usr/bin/rexx
/*
	program:          log4rexx_logger.cls
	type:             Open Object Rexx  (ooRexx)
   language level:   6.01 (ooRexx version 3.1.2 and up)

	purpose:          Defines the socket classes .rgf.Socket and .rgf.ServerSocket.

                     Created from scratch in order to get a cleanly licensable
                     implementation of sockets for ooRexx, needed for creating
                     socket-based appenders for the log4rexx project like the
                     .TelnetAppender.

                     If the 'log4rexx' framework is available, then it is being used
                     for logging purposes. This module's logger name is: "rgf.sockets".
                     If 'log4r' is not available then this module uses a signature
                     compatible "emergency" implementation of the Log class, allowing
                     these classes to be used without the 'log4r' framework.

                     In any case the logger object is made available via the
                     environment symbol: ".rgf.sockets.logger".

	version:          1.1.0
   license:          Choice of  Apache License Version 2.0 or Common Public License 1.0
	date:             2007-04-11
	author:           Rony G. Flatscher, Wirtschaftsuniversit&auml;t Wien, Vienna, Austria, Europe
   changes:          2007-04-18, ---rgf, made "connect" method more flexible, allows now hostnames
                                         in addition to IP addresses
                     2007-04-19, ---rgf, added environment symbol which control how logging gets
                                         initialized (".rgf.sockets.processLogs={.false | .true}",
                                         ".rgf.sockets.defaultLogLevel={OFF | ALL | TRACE | DEBUG | INFO | WARN | ERROR | FATAL }")
                     2007-05-17, ---rgf: changed name of files and framework from "log4r" to
                                 "log4rexx" ("log4r" has been taken by a Ruby implementation alreday)

	needs:	         optionally the 'log4rexx' framework

	usage:            ::REQUIRES rgf.sockets.cls
                        or
                     CALL rgf.sockets.cls

	returns:          ---
*/


if RxFuncQuery("SockLoadFuncs") then   -- do we need to load the Socket function package?
do
  call RxFuncAdd "SockLoadFuncs", "rxsock", "SockLoadFuncs"
  call SockLoadFuncs
  .rgf.Socket~socketLibraryVersion=SockVersion() -- get and save version of socket function library
end

.local~sock.listen.backlog=20          -- define default backlog queue size
.local~sock.timeOut=100                -- default timeout for receiving in msec

   -- define logLevel to use: ALL, TRACE, DEBUG, INFO, WARN, ERROR, WARN, FATAL, OFF
-- .rgf.sockets.logger~logLevel="OFF"

if .rgf.sockets.logger~isInfoEnabled then -- if logging INFO level is enabled
do
   parse source s                      -- source infos
   parse version v                     -- version infos
   logLevel=.rgf.sockets.logger~logLevel~string       -- get actual logLevel
   .rgf.sockets.logger~info("Finished intializing:" s, v "|" SysVersion() "| LogLevel:" .log4rexx~entry(.rgf.sockets.logger~logLevel) "("logLevel")")
end


   -- the following code allows this module to be used without the "log4r" package, but also without it
-->>  -->>  -->> --->>> BEGIN: checking/supplying EmergencyLogger' <<< ---------------------
/* ------------------------------------------------------------------------------------ */
/* ------------------------------------------------------------------------------------ */
/* ------------------------------------------------------------------------------------ */


/* This class must be the first one listed in this module to make sure that
   logging is possible under all circumstances.

   Reason: as of ooRexx 3.1.1 an ooRexx program gets syntax-checked, then all directives
           get carried out in the following sequence: REQURIES-directives, ROUTINE-directives
           and then METHOD and CLASS directives in the order found in the file; after all
           directives have been carried out successfully, the program will get started with
           the statement in line # 1

           having this class directive as the first class directive causes it to be
           constructed first by the runtime system; if it contains a class constructor, then
           it will be run after construction of the class has finished. The constructor will
           check for the existence of "LOG4REXX"; if
           log4rexx is not available, then it will either construct a NoLogger or a sort of
           a SimpleLogger depending on the received arguments. In either case all logging
           via ".log4rexx.Log" will be possible and hence all such logging statements in this
           program can be carried out without errors.
*/

::class "MakeSureThatLoggingIsAvailable"
::method init class


/* As this module depends on log4r, we need to supply an "EmergencyLogger" in case
   log4rexx has not been running.

   There are two environment variables that influence setting up the "rgf.sockets.logger":

      .rgf.sockets.defaultLogLevel  ... determines the logLevel to set the logger to
      .rgf.sockets.processLogs      ... .true/.false: only used, if an emergency logger has
                                        to be created dynamically:
                                        .true  ... create a logger that processes (outputs) the log messages
                                        .false ... create a NoOp logger that does not process the log messages at all

   After this routine ran, you can set the desired level by issuing:

      .rgf.sockets.logger~logLevel=.log4rexx~entry( {ALL | TRACE | DEBUG | INFO | WARN | ERROR | FATAL | OFF} )

   if log4rexx is not available, a replacement logger is created:

   - if "bShowLogs" is .false, then a NoLogger will be created
   - "logLevel" indicates the log level at which logging output starts to be shown (default: TRACE)
*/

      -- try to get the defaultLogLevel if any
   logLevel=.local~entry("rgf.sockets.defaultLogLevel")
   if .nil=logLevel then         -- no entry, hence default to no logging at all
      logLevel="OFF"

      -- default to .false, i.e. create an emergency NoOp logger, if 'log4r' is not available
   bProcessLogs=(.local~entry("rgf.sockets.processLogs")=.true)

      -- the following code allows this module to be used without the "log4r" package, but also with it
   ------------------------ >>> CREATE 'EmergencyLogger', if necessary
   if \.local~hasEntry("LOGMANAGER") then    -- .LogManager not available, hence no log4rexx there
   do
      if \.local~hasEntry("LOG4REXX") then
      do
            -- define the .log4rexx constants
         .local~log4rexx  =.directory~new
         .local~log4r=.log4rexx     -- allow access to the directory via this shorter name

         .log4rexx~all    =   0; .log4rexx~   0="ALL"     -- will log all
         .log4rexx~lowest =   0;

         .log4rexx~trace  =1000; .log4rexx~1000="TRACE"
         .log4rexx~debug  =2000; .log4rexx~2000="DEBUG"
         .log4rexx~info   =3000; .log4rexx~3000="INFO"
         .log4rexx~warn   =4000; .log4rexx~4000="WARN"
         .log4rexx~error  =5000; .log4rexx~5000="ERROR"
         .log4rexx~fatal  =6000; .log4rexx~6000="FATAL"

         .log4rexx~none   =7000; .log4rexx~7000="OFF"     -- will not log any
         .log4rexx~off    =7000;
         .log4rexx~highest=7000;
      end

      el=.object~subclass("EmergencyLogger")    -- define class
      if \bProcessLogs then      -- define just an unknown method which does nothing but return .false
      do
         el~define("UNKNOWN", "RETURN .false")  -- generically return .false (to cater for "is%LEVEL%Enabled")
      end
      else
      do
         nl="0a"x
         el~define("INIT",      "EXPOSE logLevel; self~logLevel='DEBUG' -- default logLevel          " )

         el~define("LOGLEVEL=", "EXPOSE logLevel; parse arg newLogLevel .                             ; "  -
                                "/*                                                                     "  -
                                ".error~say( '---> newLlogLevel['newlogLevel']')                      ; "  -
                                ".error~say( '---> ---> ['.log4rexx~entry(newLogLevel)~string']')        ; "  -
                                "*/                                                                     "  -
                                "if .log4rexx~hasentry(newLogLevel) then   /* valid logLevel value? */   ; "  -
                                "do                                                                   ; "  -
                                "   if datatype(newLogLevel, 'W') then  /* numeric value already */   ; "  -
                                "      logLevel=newLogLevel                                           ; "  -
                                "   else  /* get and assign the numeric value */                      ; "  -
                                "      logLevel=.log4rexx~entry(newlogLevel)                             ; "  -
                                "end                                                                  ; "  -
                                )

         el~define("LOGLEVEL" , "EXPOSE logLevel; if arg(1,'e') then self~logLevel=arg(1); return logLevel")

            -- now create code with needle to be replaced per log type
         logCode="expose logLevel                                                             ; " -
                 "if logLevel>%LEVEL_VALUE% then return                                       ; " -
                 "tmpStr=''                                                                   ; " -
                 "if arg(2,'e') then tmpStr=' 'arg(2)~string' -'                              ; " -
                 ".error~say('%LEVEL%'~left(5) '-' date('S',,,'-') time('L')':'||tmpStr arg(1)~string); "

         logCode2="expose logLevel                ; " -
                  "return logLevel<=%LEVEL_VALUE% ; " -


         do level over .list~of("Trace", "Debug", "Info", "Warn", "Error", "Fatal")
            el~define(level, logCode~changestr("%LEVEL%", level)~changestr("%LEVEL_VALUE%",.log4rexx~entry(level)))
            el~define("is"level"Enabled", logCode2~changestr("%LEVEL%", level)~changestr("%LEVEL_VALUE%",.log4rexx~entry(level)))
         end
      end

      .local~rgf.sockets.logger=el~new             -- create the replacement logger and store it in .local
      .local~rgf.sockets.logger~logLevel=logLevel  -- set logLevel explicitly
   end
   else    -- the 'log4r' framework is available, create a logger using it
   do
      .local~rgf.sockets.logger=.LogManager~getLogger("rgf.sockets")
      .rgf.sockets.logger~logLevel=logLevel
   end

/*--------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------*/
------------------------ >>> END   EmergencyLogger' <<< ----------------------------------------





/*--------------------------------------------------------------------------*/
/* Switches: 1 ... getHostName      ... returns name or ""
             2 ... getAddress       ... returns dotted address or .nil
             3 ... getHostAliases   ... returns array
             4 ... getHostAddresses ... returns array

   if no host is given, then localhost is used instead
*/
::routine getHostInfos
  parse arg host, switch

  .rgf.sockets.logger~trace("getHostInfos()")
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("getHostInfos()"  "| host=["host"], switch=["switch"]", formatObject(self) )

  if host="" then                      -- no host given
  do
     host=SockGetHostId()              -- get local hostID, returns dotted address
     if switch=2 then
        return host
  end
                                       -- if last component is a number, we assume dotted address
  bDottedAddress=(datatype(substr(host, lastpos(".",host)+1), "W"))
  if bDottedAddress then
     res=SockGetHostByAddr(host, "socket.")
  else
     res=SockGetHostByName(host, "socket.")


  if res=0 then                        -- unsuccessful function invocation
  do
     return .nil
  end

  if switch=1 then
     return socket.name
  else if switch=2 then
     return socket.addr
  else                                 -- return array of aliases/addresses of given host
  do
     if switch=3 then idx="ALIAS"
                 else idx="ADDR"

     a=.array~new                      -- create array
     do i=1 to socket.idx.0            -- iterate over appropriate (sub) stem
        a[i]=socket.idx.i              -- assign value to array
     end
     return a                          -- return array
  end


/*--------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------*/

::routine escapeString     public   -- escape non-printable characters in string
  parse arg str

  .rgf.sockets.logger~trace("escapeString()")

   chars.NonPrintable=xrange("00"x, "1F"x) || "FF"x  -- define non-printable chars

  tmpStr=.mutableBuffer~new

  do forever while str<>""
     start=verify(str, chars.nonPrintable, "Match")
     if start>0 then    -- non-printing char found, look for printable char after it
     do
            -- find non-matching position, deduct one to point to last non-printable chars in string
        end=verify(str, chars.nonPrintable, "Nomatch", start)-1
        if end=-1 then   -- no non-matching (=ending) position found: rest is non-printable
           end=length(str)

        if start>1 then -- printable chars before section with non-printable chars ?
        do
           chunk=enQuote(substr(str, 1, start-1))
           if tmpStr~length<>0 then tmpStr~~append(" || ")~~append(chunk)
                               else tmpStr~append(chunk)
        end

            -- extract non-printable chars, encode them as a Rexx hex string
        chunk=enQuote(substr(str, start, end-start+1)~c2x) || "x"

        if tmpStr~length<>0 then tmpStr~~append(" || ")~~append(chunk)
                            else tmpStr~append(chunk)

            -- extract non-processed part of string
        str=substr(str, end+1)   -- get remaining string
     end
     else   -- only printable chars available respectively left
     do
        if tmpStr~length<>0 then tmpStr~~append(" || ")~~append(enquote(str))
                            else tmpStr~append(str)
        leave         -- str=""
     end
  end
  return tmpStr~string

-- enQuote: procedure
enQuote: procedure
  return '"' || arg(1) || '"'

/*--------------------------------------------------------------------------*/





/*--------------------------------------------------------------------------*/

::routine formatObject public
  use arg o

/* pre 3.1.2
  bIsClass=o~isInstanceOf(.class)      -- do we have a class object?
  bIsClass=(o~class=.class)
  if \bIsClass then bIsClass=o~hasmethod("QUERYMIXINCLASS")

  if bIsClass then                     -- class object in hand?
*/

  if o~isInstanceOf(.class) then       -- class object in hand? (needs ooRexx 3.1.2 or higher)
  do
     s="The" o~id "class"
  end
  else
  do
     id=o~class~id
     tmpStr="a"
     if pos(id~left(1)~translate, "AEIOU")>0 then tmpStr="an"
     s=tmpStr id
  end

  return "(" || s":" o~"=="~c2x || ")"


/*--------------------------------------------------------------------------*/





/* ooRexx Socket implementation. */
::class "Rgf.Socket"           public
   /* ================================ class methods ================================== */

::method init              class
  expose socketOptionNames


  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Class Socket.init", formatObject(self))

   -- define available socket options
   -- the options: "SO_BROADCAST SO_RCVLOWAT SO_SNDLOWAT SO_USELOOPBACK" may not be gettable
  socketOptionNames=.array~of("SO_BROADCAST", "SO_DEBUG",    "SO_DONTROUTE", "SO_ERROR",   -
                              "SO_KEEPALIVE", "SO_LINGER",   "SO_OOBINLINE", "SO_RCVBUF",  -
                              "SO_RCVLOWAT",  "SO_RCVTIMEO", "SO_REUSEADDR", "SO_SNDBUF",  -
                              "SO_SNDLOWAT",  "SO_SNDTIMEO", "SO_TYPE",      "SO_USELOOPBACK" )

::method socketLibraryVersion attribute class

::method socketOptionNames    attribute class


::method getHostName       class       -- get and return hostname for received IP address
  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.getHostName", formatObject(self))
  return getHostInfos(arg(1), 1)

::method getHostAddress    class       -- get and return IP address for received IP address
  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.getHostAddress", formatObject(self))
  return getHostInfos(arg(1), 2)

::method getHostAliases    class       -- return directory of aliases the host possesses
  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.getHostAliases", formatObject(self))
  return getHostInfos(arg(1), 3)

::method getHostAddresses  class       -- return directory of addresses the host possesses
  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.getHostAddresses", formatObject(self))
  return getHostInfos(arg(1), 4)


   /* ================================ instance methods =============================== */
::method init                          -- constructor
  expose socketDescriptor nonBlockingMode        -
         receiveTimeout receiveBufferSize        -
         sendTimeout    sendBufferSize           -
         checkInterval  bClosed

  parse arg type, socketDescriptor     -- retrieve socket descriptor

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.init", formatObject(self))

  if .rgf.sockets.logger~isDebugEnabled then
     .rgf.sockets.logger~debug("Socket.init" "| type=["type"], socketDescriptor=["socketDescriptor"]", formatObject(self) )

  self~clearLastErrors                 -- make sure last_ERRNO and last_H_ERRNO have an empty value

  nonBlockingMode=.false               -- by default socket starts out in blocking mode
  bClosed        =.false

  checkInterval=100                    -- sleeping time before attempting accept()/connect() again
                                       -- checkInterval is measured in msec

  receiveBufferSize=-1                 -- indicate not yet known
  sendBufferSize   =-1                 -- indicate not yet known
  receiveTimeout   =-1                 -- indicate not yet known
  sendTimeout      =-1                 -- indicate not yet known


  if socketDescriptor<>"" then         -- socket already created (probably from accept-method)!
  do
     if .rgf.sockets.logger~isDebugEnabled then
        .rgf.sockets.logger~debug("Socket.init" "| not initializing socket as existing socketDescriptor=["socketDescriptor"]", formatObject(self) )
     return
  end

  pos=pos(type~left(1), "SDR")         -- determine desired socket type
  if pos=0 then pos=1                  -- default to stream socket
  type=word("SOCK_STREAM SOCK_DGRAM SOCK_RAW", pos)

  domain  ="AF_INET"                   -- only domain available
  protocol=0
  socketDescriptor=SockSocket(domain, type, protocol)
  if socketDescriptor=-1 then
  do
     socketDescriptor=.nil
     self~setLastErrors(errno, h_errno, "SockSocket") -- make ERRNO and H_ERRNO available for retrieval
     call SockPSock_Errno "SockSocket" "error: ["errno"]" "h_errno: ["h_errno"]"
     RAISE syntax 93.964 array (self~class~id "- init(): could not create socket")
  end

  if .rgf.sockets.logger~isDebugEnabled then
     .rgf.sockets.logger~debug("Socket.init"  "| socketDescriptor=["socketDescriptor"]", formatObject(self))


::method uninit                        -- destructor
  expose socketDescriptor
  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.uninit", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.uninit" "| socketDescriptor=["socketDescriptor"]", formatObject(self))
  self~close                           -- make sure the socket gets closed



::method bind                          -- bind port to socket
  expose socketDescriptor
  parse arg port

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.bind", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.bind" "| port=["port"]", formatObject(self) )

  socket.port  =port
  socket.family="AF_INET"
  socket.addr  ="INADDR_ANY"

  if SockBind(socketDescriptor, "socket.")=-1 then
  do
     self~setLastErrors(errno, h_errno, "SockBind")   -- make ERRNO and H_ERRNO available for retrieval
     return .false                     -- indicate failure
  end
  return .true                         -- indicate success



::method checkInterval     unguarded   -- getter
  expose checkInterval
  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("ServerSocket.checkInterval", formatObject(self))

  if arg()=1 then                      -- used as a setter ?
     self~checkInterval=arg(1)         -- set the new value first

  return checkInterval



::method "checkInterval="  unguarded   -- setter
  expose checkInterval
  parse arg newValue
  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("ServerSocket.checkInterval=", formatObject(self))

  if \datatype(newValue, "W") & newValue>=0 then
  do
     if .rgf.sockets.logger~isErrorEnabled then
        .rgf.sockets.logger~error("ServerSocket.checkInterval= | illegal argument["newValue"], leaving checkInterval ["checkInterval"] in place.", formatObject(self))
     return checkInterval
  end

  guard on                             -- critical section, guard it
  checkInterval=newValue
  guard off
  return checkInterval




::method clearLastErrors               -- clears last_ERRNO and last_H_ERRNO
  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.clearLastErrors", formatObject(self))
  self~setLastErrors("", "", "")


   -- makes sure that a socket gets closed once only (important, at least under WindowsXP!)
::method close                         -- shutdown & close socket
  expose socketDescriptor bClosed

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.close", formatObject(self))
  -- if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.close" "| socketDescriptor=["socketDescriptor"], bClosed=["||bClosed"]", formatObject(self))

  if bClosed=.true then    -- make sure socket is not closed more than once (costed me 14hrs to figure it out on Windows!)
    return .true

  bClosed=.true                        -- remember that this socket got closed already!

  if SockClose(socketDescriptor)=-1 then
  do
     self~setLastErrors(errno, h_errno, "SockClose")   -- make ERRNO and H_ERRNO available for retrieval
     return .false                     -- indicate error
  end

  return .true                         -- indicate success



   /* One can only use a stream socket only *once* for connecting (then it is "exhausted")! */
::method connect                       -- connect to server
  expose socketDescriptor
  parse arg address, port

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.connect", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.connect" "| received address=["address"], port=["port"]", formatObject(self))

  if \datatype(port, "W") | port<1 then         -- mandatory argument not given !
     RAISE SYNTAX 93.907 array("2 ('port')", port) -- not a positive, whole number


  addr2=self~class~getHostAddress(address)      -- make sure we can access/get host address
  if .nil=addr2 then                   -- no address found
  do
     RAISE SYNTAX 93.900 array("'"address~string"' cannot be resolved!") -- not a positive, whole number
  end
  else if addr2<>address then          -- IP address differs from received address, could have been a name, use IP address
  do
     socket.addr  =addr2               -- use the retrieved IP address
     if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.connect" "| new address retrieved=["addr2"] using it to connect.")
  end
  else
  do
     socket.addr  =address
  end

  socket.port  =port
  socket.family="AF_INET"

  if SockConnect(socketDescriptor, "socket.")=-1 then
  do
     self~setLastErrors(errno, h_errno, "SockConnect")   -- make ERRNO and H_ERRNO available for retrieval
     return .false                     -- indicate error
  end
  return .true                         -- indicate success



::method getSocketOption                       -- getter
  expose socketDescriptor
  parse upper arg so_option

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.getSocketOption", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.getSocketOption"  "| so_option=["so_option"]", formatObject(self))

      -- get socket option, save its current value in variable "RES"
  r=SockGetSockOpt(socketDescriptor, 'SOL_SOCKET', so_option, 'RES')
  if r=-1 then
  do
     self~setLastErrors(errno, h_errno, "SockGetSockOpt")   -- make ERRNO and H_ERRNO available for retrieval
     return .nil                       -- indicate no value
  end
  return res                           -- return current setting


::method getSocketOptionS              -- returns a directory of

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.getSocketOptions", formatObject(self))

  d=.directory~new
  do option over self~class~socketOptionNames  -- iterate over all options
     val=self~getSocketOption(option)
     if .nil<>val then                 -- entry available
        d~setentry(option, val)
  end
  return d



::method localAddress                     -- socket's IP address
  expose socketDescriptor

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.localAddress", formatObject(self))
  if SockGetSockName(socketDescriptor, "socket.")=-1 then
  do
     self~setLastErrors(errno, h_errno, "SockGetSockName")   -- make ERRNO and H_ERRNO available for retrieval
     return .nil -- return ""
  end
  return socket.addr


::method localHostName                 -- socket's hostname
  expose socketDescriptor

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.localHostName", formatObject(self))

  if SockGetSockName(socketDescriptor, "socket.")=-1 then
  do
     self~setLastErrors(errno, h_errno, "SockGetSockName")   -- make ERRNO and H_ERRNO available for retrieval
     return .nil
  end

  if SockGetHostByAddr(socket.addr, "socket.")=0 then -- use received address
  do
     self~setLastErrors(errno, h_errno, "SockGetHostByAddr")   -- make ERRNO and H_ERRNO available for retrieval
     return .nil -- return ""
  end
  return socket.name


::method localPort                     -- socket's hostname
  expose socketDescriptor

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.port", formatObject(self))

  if SockGetSockName(socketDescriptor, "socket.")=-1 then
  do
     self~setLastErrors(errno, h_errno, "SockGetSockName")   -- make ERRNO and H_ERRNO available for retrieval
     return .nil
  end
  return socket.port




::method listen                        -- listen for clients
  expose socketDescriptor
  parse arg maxConnectionQueue         -- determines maximum parallel clients ("backlog")

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.listen", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.listen"  "| maxConnectionQueue=["maxConnectionQueue"]", formatObject(self))

  if \datatype(maxConnectionQueue, "W") then   -- backlog queue size not given?
     maxConnectionQueue=.sock.listen.backlog

  if SockListen(socketDescriptor, maxConnectionQueue)=1 then
  do
     self~setLastErrors(errno, h_errno, "SockListen")   -- make ERRNO and H_ERRNO available for retrieval
     return .false                     -- indicate error
  end
  return .true                         -- indicate success



::method last_ERRNO           attribute   -- indicates ERRNO value of latest error, if any
::method last_H_ERRNO         attribute   -- indicates H_ERRNO value of latest error, if any
::method last_SocketAction    attribute   -- indicates the SocketAction that led to the latest error



::method nonBlockingMode               -- getter
  expose nonBlockingMode
  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.nonBlockingMode", formatObject(self))

  if arg()=1 then                      -- argument given?
     self~nonBlockingMode=arg(1)

  return nonBlockingMode


::method "nonBlockingMode="            -- setter
  expose nonBlockingMode
  parse arg newValue

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.nonBlockingMode=", formatObject(self))

  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.nonBlockingMode= | newValue=["newValue"]", formatObject(self))
  if Pos(newValue,"01")>0 & newValue<>nonBlockingMode then  -- o.k., new logical (Boolean) value in hand
  do
      self~socketIOCTL("FIONBIO", newValue)  -- set to new value
      nonBlockingMode=newValue         -- use value after the setting attempt
  end



/* This method has two modes:
   - blocking receiving mode (standard)
   - non-blocking receiving mode which times out and returns whatever got
     received until the timeout; it can be combined with a supplied
     minimum amount of bytes to receive and will return upon reaching or
     surpassing that amount of data or a timeout, whatever comes first

   if "size" is positive, then up to "size" bytes are received; in non-blocking
   mode (timeout given) it is attempted to receive exactly "size" bytes, unless
   there are fewer bytes to be received
*/
::method receive                       -- receive data and return it
  expose socketDescriptor receiveBufferSize receiveTimeOut
  parse arg size, timeout, flag        -- allow determining number of bytes to read; -1 indicates to read all data

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.receive", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.receive"  "| size=["size"], timeout=["timeout"], flag=["flag"]", formatObject(self))


  if receiveBufferSize<1 then          -- receive buffer size not yet set/queried
     self~receiveBufferSize            -- force setting it

  if receiveTimeOut<0 then             -- receive timeout not yet set/queried
     self~receiveTimeout               -- force setting it

  if size="" then                      -- no size given, receive one buffer maximum
     size=receiveBufferSize

  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.receive"  "| receiveBufferSize=["receiveBufferSize"], receiveTimeOut=["receiveTimeout"]", formatObject(self))

      /*  size=-1          ... read all receivable data (until timeout occurs)
          timeout          ... timeout in msecs
          receiveTimeout>0 ... timeout on socket already set for reading
      */
  if size=-1 | timeout<>"" | receiveTimeout>0 then -- timeout needed
  do
     oldValue=receiveTimeout           -- save current setting
     if \datatype(timeout, "W") | timeout<0 then   -- default to .sock.timeOut msecs
     do
        if receiveTimeout=0 then       -- only set default timeout, if socket is blocking at the moment
           timeout=.sock.timeOut
        else                           -- no explicit timeout given, use the one on socket
           timeout=receiveTimeout
     end

     if timeout<>receiveTimeout then   -- set new timeout
        self~receiveTimeout=timeout    -- this will immediately change the object variable "receiveTimeout"
  end

  if flag<>"" then
  do
     if wordpos(flag~translate, "MSG_OOB MSG_DONTROUTE")=0 then   -- illegal flag?
        flag=""
  end

  if size=-1 | timeout<>"" then                  -- read chunks of data until timeout occurs
  do
     if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.receive"  "| NON-blocking-mode (timeout)", formatObject(self))
     m=.mutableBuffer~new              -- assume we get chunks of data
         -- define size of receive buffer
     if size<1 then bufSize=receiveBufferSize
               else bufSize=size
     tmpSize=0                         -- will contain sum of received bytes

         -- loop until timeout, no-data received or desired nr of bytes read by the end of the loop
     do i=1 until (size>0 & tmpSize>=size)
        if size>0 then     -- make sure that at most "size" number of bytes are read
        do
           if size-tmpSize<bufSize then
              bufSize=size-tmpSize
        end

/*
        if .rgf.sockets.logger~isDebugEnabled then
        do
           r.0=1
           r.1=socketDescriptor
           SockSelectRetVal=SockSelect("R.", "", "", 0)

           .rgf.sockets.logger~debug("Socket.receive" "| i="i", size="size", tmpSize="tmpSize", bufSize="||bufSize", SockSelect()="SockSelectRetVal, formatObject(self) )
        end
*/

           -- use Rexx variable named "PACKET" to store result, use maximum 4 KB buffer
        if flag="" then
           retVal=SockRecv(socketDescriptor, "PACKET", bufSize)
        else
           retVal=SockRecv(socketDescriptor, "PACKET", bufSize, flag)

        if retVal=-1 then                 -- timeout/error, stop receiving
        do
           self~setLastErrors(errno, h_errno, "SockRecv")   -- make ERRNO and H_ERRNO available for retrieval
           leave
        end
        else if retVal>0 then             -- get received bytes, increase sum
        do
           tmpSize=tmpSize+retVal         -- add up size so far
           m~append(packet)               -- add packet to mutable buffer

           if size>0 & tmpSize>=size then   -- maximum number of bytes read already
              leave
        end
        else if retVal=0 then             -- nothing read, finished reading?
        do
           leave
        end
     end

     if timeout<>oldValue then            -- reset
        self~receiveTimeout=oldValue

     if m~length=0 & retVal=-1 then return .nil -- no data received

     return m~string                      -- return received bytes
  end

  else            -- just read data up to the given size
  do
     if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.receive"  "| blocking-mode", formatObject(self))
        -- use Rexx variable named "PACKET" to store result, use maximum 4 KB buffer
     if flag="" then
        retVal=SockRecv(socketDescriptor, "PACKET", size) -- blocking call
     else
        retVal=SockRecv(socketDescriptor, "PACKET", size, flag) -- blocking call

     if retVal=-1 then
     do
        self~setLastErrors(errno, h_errno, "SockReceive")   -- make ERRNO and H_ERRNO available for retrieval
        return .nil -- return ""
     end
     return packet                        -- return received data
  end



::method receiveBufferSize                -- getter
  expose receiveBufferSize

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.receiveBufferSize", formatObject(self))

  if arg()=1 then                         -- used as a setter
  do
     self~receiveBufferSize=arg(1)
  end
  else if receiveBufferSize<1 then        -- not yet retrieved, get value, if any
  do
     tmpValue=self~getSocketOption("SO_RCVBUF")    -- get buffer size
     if datatype(tmpValue, "W") then      -- returned value a number, use it
        receiveBufferSize=tmpValue        -- set value
  end
  return receiveBufferSize


::method "receiveBufferSize="             -- setter
  expose receiveBufferSize
  parse  arg newBufferSize

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.receiveBufferSize=", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.receiveBufferSize=" "| newBufferSize=["newBufferSize"]", formatObject(self) )

  if datatype(newBufferSize, "W") & newBufferSize>0 then
  do
     self~setSocketOption("SO_RCVBUF", newBufferSize) -- set new buffer size
     receiveBufferSize=newBufferSize
  end
  else
  do
     if .rgf.sockets.logger~isErrorEnabled then
        .rgf.sockets.logger~error("Socket.receiveBufferSize=" "| newBufferSize=["newBufferSize"] not numeric or larger than 0", formatObject(self) )
  end

   -- determines receive timeout in msec (effects receiving, but also listening, accepting, etc.)
::method receiveTimeout                   -- getter
  expose receiveTimeout

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.receiveTimeout", formatObject(self))

  if arg()=1 then                         -- used as a setter
  do
     self~receiveTimeout=arg(1)
  end
  else if receiveTimeout<0 then           -- not set yet
  do
     newValue=self~getSocketOption("SO_RCVTIMEO")  -- get default receive timeout
     if datatype(newValue, "W") then
        receiveTimeout=newValue
  end
  return receiveTimeout


   -- determines receive timeout in msec (effects receiving, but also listening, accepting, etc.)
::method "receiveTimeout="                -- setter
  expose receiveTimeout
  parse arg newTimeout

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.receiveTimeout=", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.receiveTimeout="  "| newTimeOut=["newTimeOut"]", formatObject(self))

  if datatype(newTimeout, "W") & newTimeout>=0 then
  do
     self~setSocketOption("SO_RCVTIMEO", newTimeout)  -- set new timeout value
     receiveTimeout=newTimeout
  end
  else
  do
     if .rgf.sockets.logger~isErrorEnabled then
        .rgf.sockets.logger~error("Socket.receiveTimeout="  "| newTimeOut=["newTimeOut"] negative or not numeric", formatObject(self))
  end



::method remoteAddress                 -- socket peer's IP address
  expose socketDescriptor

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.remoteAddress", formatObject(self))

  if SockGetPeerName(socketDescriptor, "socket.")=-1 then
  do
     self~setLastErrors(errno, h_errno, "SockGetPeerName")   -- make ERRNO and H_ERRNO available for retrieval
     return .nil
  end
  return socket.addr




::method remoteHostName                -- socket peer's hostname
  expose socketDescriptor

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.remoteHostName", formatObject(self))

  if SockGetPeerName(socketDescriptor, "socket.")=-1 then
  do
     self~setLastErrors(errno, h_errno, "SockGetPeerName")   -- make ERRNO and H_ERRNO available for retrieval
     return .nil -- return ""
  end
  if SockGetHostByAddr(socket.addr, "socket.")=0 then -- use received address
  do
     self~setLastErrors(errno, h_errno, "SockGetHostByAddr")   -- make ERRNO and H_ERRNO available for retrieval
     return .nil -- return ""
  end
  return socket.name


::method remotePort                    -- socket peer's hostname
  expose socketDescriptor

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.remotePort", formatObject(self))

  if SockGetPeerName(socketDescriptor, "socket.")=-1 then
  do
     self~setLastErrors(errno, h_errno, "SockGetPeerName")   -- make ERRNO and H_ERRNO available for retrieval
     return .nil
  end
  return socket.port




   -- returns nr of bytes sent, or "-1" if an error has occurred
::method send                          -- send data, return return nr of bytes sent
  expose socketDescriptor
  parse arg data, timeout, flag

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.send", formatObject(self))

   -- show first 16 Bytes of data, escape non-printable chars as Rexx hex-literals
  if .rgf.sockets.logger~isDebugEnabled then
  do
     if length(data)>16 then tmpStr=escapeString(data~left(16))"..."
                        else tmpStr=escapeString(data)

     if .rgf.sockets.logger~isDebugEnabled then
     do
        .rgf.sockets.logger~debug("Socket.send" "| data=["tmpStr"], timeout=["timeout"], flag=["flag"]", formatObject(self) )
        .rgf.sockets.logger~debug("Socket.send"  "| sendBufferSize=["self~sendBufferSize"], sendTimeOut=["self~sendTimeout"]", formatObject(self))
     end
  end

  if length(data)=0 then               -- nothing to send!
     return 0                          -- 0 bytes sent

  if flag<>"" then
  do
     if wordpos(flag~translate, "MSG_OOB MSG_DONTROUTE")=0 then   -- illegal flag?
        flag=""
  end

  if flag="" then
     retVal=SockSend(socketDescriptor, data)       -- either -1, or number of bytes sent
  else
     retVal=SockSend(socketDescriptor, data, flag) -- either -1, or number of bytes sent

  if retVal=-1 then
     self~setLastErrors(errno, h_errno, "SockSend")   -- make ERRNO and H_ERRNO available for retrieval

  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.send"  "| retVal=["retVal"] (# bytes sent)", formatObject(self))

  return retVal



::method sendBufferSize                -- getter
  expose sendBufferSize

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.sendBufferSize", formatObject(self))

  if arg()=1 then                      -- used as a setter
  do
     self~sendBufferSize=arg(1)
  end
  else if sendBufferSize<1 then        -- not yet retrieved
  do
     newValue=self~getSocketOption("SO_SNDBUF")    -- get buffer size
     if .nil<>newValue then sendBufferSize=newValue
  end
  return sendBufferSize


::method "sendBufferSize="             -- setter
  expose sendBufferSize
  parse  arg newBufferSize

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.sendBufferSize=", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.sendBufferSize="  "| newBufferSize=["newBufferSize"]", formatObject(self))

  if datatype(newBufferSize, "W") & newBufferSize>0 then
  do
     self~setSocketOption("SO_SNDBUF", newBufferSize) -- set new buffer size
     sendBufferSize=newBufferSize
  end
  else
  do
     if .rgf.sockets.logger~isErrorEnabled then
        .rgf.sockets.logger~error("Socket.sendBufferSize="  "| newBufferSize=["newBufferSize"] not numeric or larger than 0", formatObject(self))
  end



   -- determines send timeout in msec (effects sending, but also connecting? etc.)
::method sendTimeout                   -- getter
  expose sendTimeout

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.sendTimeout", formatObject(self))

  if arg()=1 then                      -- used as a setter
  do
     self~sendTimeout=arg(1)
  end
  else if sendTimeout<0 then           -- not set yet
  do
     newValue=self~getSocketOption("SO_SNDTIMEO")  -- get default send timeout
     sendTimeout=newValue
  end

  return sendTimeout


   -- determines send timeout in msec (effects sending, but also connecting? etc.)
::method "sendTimeout="                -- setter
  expose sendTimeout
  parse arg newTimeout

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.sendTimeout=", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.sendTimeout="  "| newTimeOut=["newTimeOut"]", formatObject(self))

  if datatype(newTimeout, "W") & newTimeout>=0 then
  do
     self~setSocketOption("SO_SNDTIMEO", newTimeout)  -- set new timeout value
     sendTimeout=newTimeout
  end
  else
  do
     if .rgf.sockets.logger~isErrorEnabled then
        .rgf.sockets.logger~error("Socket.sendTimeout="  "| newTimeOut=["newTimeOut"] negative or not numeric", formatObject(self))
  end


::method setLastErrors                 -- allows setting last_ERRNO and last_H_ERRNO
  expose last_ERRNO last_H_ERRNO last_SocketAction
  use arg last_ERRNO, last_H_ERRNO, last_SocketAction

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.setLastErrors", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.setLastErrors"  "| last_ERRNO=["last_ERRNO"], last_H_ERRNO=["last_H_ERRNO"], last_SocketAction=["last_SocketAction"]", formatObject(self))



::method  setSocketOption              -- setter
  expose socketDescriptor
  parse upper arg so_option, value

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.setSocketOption", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.setSocketOption"  "| so_option=["so_option"], value=["value"]", formatObject(self))

      -- set socket option
  r=SockSetSockOpt(socketDescriptor, 'SOL_SOCKET', so_option, value)
  if r=-1 then
  do
     self~setLastErrors(errno, h_errno, "SockSetSockOpt")   -- make ERRNO and H_ERRNO available for retrieval
     return .false                     -- indicate error
  end
  return .true                         -- indicate success



::method shutdown             unguarded   -- allow to shutdown read (0), write (1) or both modes (2)
  expose socketDescriptor
  parse arg mode .                     -- "0" (read), "1" (write), "2" (read & write)

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.shutdown", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.shutdown"  "| mode=["mode"]", formatObject(self))

  mode=mode~left(1)
  if pos(mode, "012")=0 then        -- default to shutdown read & write
     mode=2

  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.shutdown"  "| mode=["mode"]", formatObject(self))

  if SockShutDown(socketDescriptor, mode)=-1 then
  do
     self~setLastErrors(errno, h_errno, "SockShutDown")   -- make ERRNO and H_ERRNO available for retrieval
     if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.shutdown"  "| errno=["errno"], returning from error branch.", formatObject(self))
     return .false                  -- indicate error
  end
  return .true                         -- indicate success



::method socketDescriptor     unguarded   -- getter method
  expose socketDescriptor

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.socketDescriptor", formatObject(self))
  return socketDescriptor


::method "socketDescriptor="  private  -- setter method
  expose  socketDescriptor
  parse arg socketDescriptor

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.socketDescriptor=", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.socketDescriptor="  "| socketDescriptor=["socketDescriptor"]", formatObject(self))


::method SocketIOCTL                   -- make socket I/O control interface available
  expose socketDescriptor
  parse arg ioctlCmd, ioctlData        -- icoctlCmd: "FIONBIO" (non-blocking-mode), "FIONREAD" (nr. bytes ready to read)

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.socketIOCTL", formatObject(self))

  r=SockIOctl(socketDescriptor, ioctlCmd, ioctlData)
  if r=-1 then
  do
     self~setLastErrors(errno, h_errno, "SockIOctl")   -- make ERRNO and H_ERRNO available for retrieval
     return .nil                       -- indicates error
  end

  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.socketIOCTL | returning ioctlData=["ioctlData"]", formatObject(self))
  return ioctlData                     -- return whatever is in ioctlData (assuming it contains the result value)



::method socketType                    -- determine and return stream type ("STREAM", "DGRAM", "RAW", "UNKNOWN")
  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.socketType", formatObject(self))
  return self~getSocketOption("SO_TYPE")



::method string
  expose socketDescriptor

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.string", formatObject(self))

  return "a" self~class~id"={"                                        || -
                        "descriptor="check(socketDescriptor         ) || -
                       ",type="check(self~socketType                ) || -
                       ",localHostName="check(self~localHostName    ) || -
                       ",localAddress="check(self~localAddress      ) || -
                       ",localPort="check(self~localPort            ) || -
                       ",RCVBUF="check(self~receiveBufferSize       ) || -
                       ",RCVTIMEO="check(self~receiveTimeOut        ) || -
                       ",SNDBUF="check(self~sendBufferSize          ) || -
                       ",SNDTIMEO="check(self~sendTimeOut           ) || -
                       ",remoteHostName="check(self~remoteHostName  ) || -
                       ",remoteAddress="check(self~remoteAddress    ) || -
                       ",remotePort="check(self~remotePort          ) || -
                     "}"

check: procedure
   use arg a
   if .nil=a then return ".nil"
   return a


/* Use SockSelect() to wait for receive to be successful, optionally supply a timeout
   value in whole seconds. If no timeout is given the invocation will block.
   Returns "1", if socket has become available, "0" if not, "-1" if an error has occurred.
*/
::method waitForReceive       unguarded
  expose socketDescriptor
  parse arg timeout

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.waitForReceive", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.waitForReceive"  "| timeout=["timeout"]", formatObject(self))

  r.0=1
  r.1=socketDescriptor

  retVal=SockSelect("R.", "", "", timeout)
  if retVal<0 then
     self~setLastErrors(errno, h_errno, "SockSelect (receive)")   -- make ERRNO and H_ERRNO available for retrieval

  return retVal


/* Use SockSelect() to wait for send to be successful, optionally supply a timeout
   value in whole seconds. If no timeout is given the invocation will block.
   Returns "1", if socket has become available, "0" if not, "-1" if an error has occurred.
*/
::method waitForSend          unguarded
  expose socketDescriptor
  parse arg timeout

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.waitForSend", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.waitForSend"  "| timeout=["timeout"]", formatObject(self))

  s.0=1
  s.1=socketDescriptor

  retVal=SockSelect("", "S.", "", timeout)
  if retVal<0 then
     self~setLastErrors(errno, h_errno, "SockSelect (send)")   -- make ERRNO and H_ERRNO available for retrieval

  return retVal


/* Use SockSelect() to wait for exception on socket, optionally supply a timeout
   value in whole seconds. If no timeout is given the invocation will block.
   Returns "1", if socket has become available, "0" if not, "-1" if an error has occurred.
*/
::method waitForException     unguarded
  expose socketDescriptor checkInterval
  parse arg timeout

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("Socket.waitForException", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("Socket.waitForException"  "| timeout=["timeout"]", formatObject(self))

  e.0=1
  e.1=socketDescriptor

  retVal=SockSelect("", "", "E.", timeout)
  if retVal<0 then
     self~setLastErrors(errno, h_errno, "SockSelect (exception)")   -- make ERRNO and H_ERRNO available for retrieval

  return retVal



/*--------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------*/

::class "Rgf.ServerSocket"        subclass rgf.socket   public   -- server socket, a specialized socket

::method init                          -- constructor
  expose isAccepting serverPort bListenAlreadyInvoked
  parse arg serverPort                 -- retrieve port

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("ServerSocket.init", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("ServerSocket.init"  "| serverPort=["serverPort"]", formatObject(self))

  self~init:super                      -- let superclass create the socket, do not supply args!

  isAccepting=.false                   -- indicate that not accepting at the moment
  if \datatype(serverPort, "W") then
     serverPort=0                      -- indicate no port defined as of yet

  bListenAlreadyInvoked=.false         -- indicate that listen has not been invoked yet
  self~setSocketOption("SO_REUSEADDR", .true) -- allow reusing address/port




/* allows optional socket type: S[tream]=default, D[atagram], R[aw]  */
::method accept            UNGUARDED   -- accept client
  expose serverPort isAccepting checkInterval bListenAlreadyInvoked
  parse arg socket_type       -- optional: timeout (in seconds), STREAM (default), DATAGRAM, RAW

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("ServerSocket.accept", formatObject(self))

      -- let method "nonBlockingAccept" deal with this request
  if arg()=2 | datatype(socket_type, "W") then     -- timeout value given?
  do
     if .rgf.sockets.logger~isDebugEnabled then
     do
        tmpString='| forwarding to message "nonBlockingAccept", arg()=['arg()'], arg(1)=['arg(1)"]"
        if arg()=2 then tmpString=tmpString', arg(2)=['arg(2)"]"
        if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("ServerSocket.accept" tmpString, formatObject(self))
     end
     forward message ("nonBlockingAccept")
  end

  self~bind(serverPort)                -- bind to port
  self~listen                          -- put socket into listening mode

  guard on                             -- critical section, guard it
  bListenAlreadyInvoked=.true
  isAccepting=.true
  guard off

  conn=SockAccept(self~socketDescriptor)    -- wait for client
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("ServerSocket.accept | clientSocketDescriptor=["conn"]", formatObject(self))

  if conn=-1 then
  do
     self~setLastErrors(errno, h_errno, "SockAccept")   -- make ERRNO and H_ERRNO available for retrieval
     return .nil
  end
  return .rgf.socket~new(socket_type, conn, .true)      -- return a socket proxy for connection, indicate it is open



/*  This version of accept() is interruptible. Use "stopAccepting()" to stop accepting clients.
    allows optional timeout, socket type: S[tream]=default, D[atagram], R[aw]
    timeout: in msecs
*/
::method nonBlockingAccept UNGUARDED   -- accept client
  expose serverPort isAccepting bListenAlreadyInvoked
  parse arg timeout, socket_type       -- optional: timeout (in seconds), STREAM (default), DATAGRAM, RAW

  if .rgf.sockets.logger~isTraceEnabled then
     .rgf.sockets.logger~trace("ServerSocket.nonBlockingAccept", formatObject(self))

  if .rgf.sockets.logger~isDebugEnabled then
     .rgf.sockets.logger~debug("ServerSocket.nonBlockingAccept | serverPort=["serverPort"], timeout=["timeout"], socket_type=["socket_type"]", formatObject(self))

  self~bind(serverPort)                -- bind to port
  self~listen                          -- put socket into listening mode

  checkInterval=self~checkInterval     -- get timespan to sleep between attempts
  self~nonBlockingMode(.true)          -- put socket into non-blocking mode; allows us to
                                       -- stop accepting gracefully under program control

  if \datatype(timeout,"W") | timeout<=0 then  -- set timeout to 0
     timeout=0

  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("ServerSocket.nonBlockingAccept | timeout=["timeout"], socket_type=["socket_type"], self~socketType=["self~socketType"]", formatObject(self))

  guard on                             -- critical section, guard it
  bListenAlreadyInvoked=.true
  isAccepting=.true
  guard off

  do while isAccepting                 -- loop as long as isAccepting is .true
     conn=SockAccept(self~socketDescriptor)    -- wait for client

     if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("ServerSocket.nonBlockingAccept | clientSocketDescriptor=["conn"]", formatObject(self))

     if conn=-1 then
     do
        self~setLastErrors(errno, h_errno, "SockAccept (non-blocking)")   -- make ERRNO and H_ERRNO available for retrieval

         -- either no timeout given or timeout not reached yet: sleep and re-conn
        if (timeout=0 & errno="EWOULDBLOCK") | (timeout>0 & (time("E")*1000)<timeout) then
        do
           if timeout>0 then
           do
              if .rgf.sockets.logger~isDebugEnabled then
                .rgf.sockets.logger~debug("ServerSocket.nonBlockingAccept | sleeping 'min(checkInterval,timeout)/1000': ["min(checkInterval,timeout)/1000"]", formatObject(self))
              call SysSleep min(checkInterval,timeout)/1000 -- sleep checkInterval seconds
           end
           else
           do
              if .rgf.sockets.logger~isDebugEnabled then
                .rgf.sockets.logger~debug("ServerSocket.nonBlockingAccept | sleeping 'checkInterval/1000': ["checkInterval/1000"]", formatObject(self))
              call SysSleep checkInterval/1000 -- sleep checkInterval seconds
           end

        end
        else                           -- something unexpected went wrong, return
        do
           if .rgf.sockets.logger~isErrorEnabled then
              .rgf.sockets.logger~error("ServerSocket.nonBlockingAccept | errno="errno", h_errno="h_errno, formatObject(self))
           self~nonBlockingMode(.false)-- reset socket to blocking mode
           return .nil
        end
     end
     else
     do
        self~nonBlockingMode(.false)   -- reset socket to blocking mode
        return .rgf.socket~new(socket_type, conn, .true)      -- return a socket proxy for connection, indicate it is open
     end
  end
  self~nonBlockingMode(.false)         -- reset socket to blocking mode
  return .nil



::method close             unguarded
  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("ServerSocket.close", formatObject(self))

  self~stopAccepting                   -- make sure that no more clients are accepted
  forward class (super)



::method isAccepting       unguarded   -- getter method
  expose isAccepting
  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("ServerSocket.isAccepting", formatObject(self))
  return isAccepting



::method serverPort        unguarded   -- allow changing serverPort for next startAccepting() ...
  expose serverPort
  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("ServerSocket.serverPort", formatObject(self))
  return serverPort



::method "serverPort="     unguarded   -- allow changing serverPort for next startAccepting() ...
  expose serverPort
  parse arg port
  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("ServerSocket.serverPort=", formatObject(self))
  if .rgf.sockets.logger~isDebugEnabled then .rgf.sockets.logger~debug("ServerSocket.serverPort="  "| port=["port"]", formatObject(self))

  if \datatype(port,"W") | port<1 then   -- don't change the value
  do
     .rgf.sockets.logger~error("ServerSocket.serverPort="  "| port=["port"] not numeric or smaller than 1", formatObject(self))
     return
  end

  guard on                             -- critical section, guard it
  serverPort=port
  guard off



::method stopAccepting     unguarded
  expose isAccepting

  if .rgf.sockets.logger~isTraceEnabled then .rgf.sockets.logger~trace("ServerSocket.stopAccepting", formatObject(self))

  if isAccepting<>.false then
  do
     guard on
     isAccepting=.false
     guard off
  end




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
