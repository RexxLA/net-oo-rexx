say ' The beginning: '~center(50, "-") /* draw a line    */
call load_log4rexx      /* load the 'log4rexx' framework    */

l=.logManager~getLogger("rgf.test") /* get/create a logger named 'rgf.test'   */

parse arg logLevel
if logLevel="" then l~logLevel="OFF"      /* do not show any log messages     */
               else l~logLevel=logLevel   /* set logLevel to argument's value */

l~debug("just created a logger named 'rgf.test':" pp(l~string))

parse source s          /* get source information        */
l~trace("source:" pp(s))

p=.person~new("Peedin", "Lee", 250000) /* create a person*/
say "p="pp(p~string)    /* pp() defined in 'log4rexx' framework   */
p~increaseSalary(12345.67) /* increase salary            */
p~increaseSalary("abc")    /* provoke an error           */
p~increaseSalary(-1000)    /* decrease salary            */

say ' The end. '~center(50, "-") /* draw a line          */
l~trace("end of program.")

/* ================================================================= */
::class person          /* class "PERSON"                */

/* ----------------------------------------------------- */
::method init           /* method "INIT" (constructor)   */
  expose familyName firstName salary

  l=.logManager~getLogger("rgf.test")     /* get logger  */
  l~trace("method 'init'")

  use arg familyName, firstName, salary
  l~debug("method 'init' - created the following person:" pp(self~string))

  if salary>10000 then  -- warn about something
     l~warn("method 'init' - salary quite high:" salary)


::method familyName     attribute
::method firstName      attribute
::method salary         attribute

/* ----------------------------------------------------- */
::method string
  expose familyName firstName salary

  .logManager~getLogger("rgf.test")~trace("method 'string'")
  return familyName"," firstName":" salary

/* ----------------------------------------------------- */
::method increaseSalary /* method to increase the salary */
  expose salary

  l=.logManager~getLogger("rgf.test")
  l~trace("method 'increaseSalary'")

  parse arg raise
  l~debug("method 'increaseSalary', received="pp(raise))

  signal on syntax      /* in case arithmetic creates a condition    */
  salary=salary+raise
  l~debug("method 'increaseSalary', new salary="pp(salary))
  return

syntax:
  l~error("method 'increaseSalary', exception has occurred!", condition("O"))

/* ----------------------------------------------------- */
::method uninit
  .logManager~getLogger("rgf.test")~trace("method 'uninit'")
  .logManager~getLogger("rgf.test")~debug("method 'uninit' running for person:" pp(self))


