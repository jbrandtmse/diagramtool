##ObjectScript Debugging Instructions

ObjectScript can be debugged using globals by adding statements to the class:

Add the the following statement to your class file to clear the debug global: SET ^ClineDebug = ""
Each line in your class file where you want to add a debug statement use: SET ^ClineDebug = ^ClineDebug_"The information you want included; "
Execute the portion of the system you are testing, which will collect the debug information in ^ClineDebug
To read the debug information that has been captured while running the code, use the get_global tool to retrieve ^ClineDebug
Other things to keep in mind:

The excute_command tool can only be used with very simple commands. Instead of creating a complex commands, create a helper class method and use the execute_classmethod tool
To debug instance methods, create a temporary class method that calls the instance method. You can use ^ClineDebug within the class method if desired.
Make sure you clean up any temporary classes after you are finished with them.