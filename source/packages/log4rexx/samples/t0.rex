say ' The beginning: '~center(50, "-") /* draw a line    */

p=.person~new("Peedin", "Lee", 250000) /* create a person*/
say "p="p~string           /* show the person's state    */
p~increaseSalary(12345.67) /* increase salary            */
p~increaseSalary("abc")    /* provoke an error           */
p~increaseSalary(-1000)    /* decrease salary            */

say ' The end. '~center(50, "-") /* draw a line          */

/* ============================================================== */
::class person          /* class "PERSON"                */

/* ----------------------------------------------------- */
::method init           /* method "INIT" (constructor)   */
  expose familyName firstName salary
  use arg familyName, firstName, salary

::method familyName     attribute
::method firstName      attribute
::method salary         attribute

/* ----------------------------------------------------- */
::method string         /* create a string rendering of a person  */
  expose familyName firstName salary
  return familyName"," firstName":" salary

/* ----------------------------------------------------- */
::method increaseSalary /* method to increase the salary */
  expose salary
  parse arg raise

  signal on syntax      /* in case arithmetic creates a condition */
  salary=salary+raise
  return

syntax:                 /* just there to let the program continue */

/* ----------------------------------------------------- */
::method uninit         /* optional destructor method    */

