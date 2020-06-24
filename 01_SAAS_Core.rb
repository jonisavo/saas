#==============================================================================#
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■ SHELL AS A SERVICE ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ #
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■ CORE FUNCTIONALITY ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ #
#==============================================================================#
# Written by Savordez
# Marin's Utilities are required!
# Special thanks to Marin (utilities script & input_to_args code) and Roza (mkxp-z)
# Marin's Utilities: https://reliccastle.com/resources/165/
# mkxp-z: https://github.com/inori-z/mkxp-z

# The version of Shell as a Service.
SHELL_VERSION = "0.8.0" + ($MKXP ? "-mkxpz" : "-essentials")
# The height of a single line in the console window.
CONSOLE_LINE_HEIGHT = 22
# The default font of the console.
CONSOLE_DEFAULT_FONT = "Courier New"
# The default font size of the console.
CONSOLE_FONT_SIZE = 20

# In the shell, all arguments are strings. Functions in this
# module are designed to validate and convert those strings
# into other types like integers and booleans.
module CommandValidation
  # Attempts to convert the given string to the specified type.
  # Returns the converted object, or raises a ConsoleError if
  # an error occurs.
  # @param type [String] specified type
  #   'i'   Integer
  #   'b'   Boolean
  #   'f'   Float
  # @param value [String] string to convert
  # @return [Integer, Boolean, Float, String] converted object
  # @raise [ConsoleError] raised if:
  #   - value is nil
  #   - value can not be converted to specified type
  # @raise [ArgumentError] raised if an invalid type is passed
  def validate_value(type,value)
    raise ConsoleError, _INTL('too few arguments') if value.nil?
    case type
    when 'i'
      unless value_is_integer?(value)
        raise ConsoleError, _INTL('{1} is not an integer',value)
      end
      value = value.to_i
    when 'b'
      unless value_is_boolean?(value)
        raise ConsoleError, _INTL('{1} is not a boolean',value)
      end
      value = %w[true yes y].include?(value)
    when 'f'
      unless value_is_float?(value)
        raise ConsoleError, _INTL('{1} is not a float',value)
      end
      left, right = value.split('.')
      value = eval("#{left}.#{right}")
    else
      raise ArgumentError, "Unknown type #{type.inspect}"
    end
    return value
  end
  
  # Returns whether the given string can be safely converted to an integer.
  # @param string [String] string to check
  # @return [Boolean] string can be converted to integer?
  def value_is_integer?(string)
    return string.strip.numeric?
  end
  
  # Returns whether the given string can be safely converted to a boolean.
  # @param string [String] string to check
  # @return [Boolean] string can be converted to boolean?
  def value_is_boolean?(string)
    return %w[true false yes no y n].include?(string.downcase)
  end
  
  # Returns whether the given string can be safely converted to a float.
  # @param string [String] string to check
  # @return [Boolean] string can be converted to float?
  def value_is_float?(string)
    return false if string.scan(/\./).length != 1
    sides = string.split('.')
    return sides[0].numeric? && sides[1].numeric? && sides[1].to_i >= 0
  end
  
  # Checks whether the given integers are members of the specified range.
  # Raises a ConsoleError if a check fails.
  # @param range [Range] range for integers
  # @param integers [Integer] integer(s) to check
  # @raise [ConsoleError] raised if a check fails
  def validate_range(range, *integers)
    for int in integers
      unless range.member?(int)
        raise ConsoleError, _INTL(
          '{1} not between {2} and {3}',int,range.begin,range.end
        )
      end
    end
  end
  
  # Returns the name of the given type.
  # @param type [String] type
  #   'i'   Integer
  #   'b'   Boolean
  #   'f'   Float
  #   's'   String
  # @return [String] type name
  def type_name(type)
    case type
    when 'i'
      return _INTL('int')
    when 'b'
      return _INTL('bool')
    when 'f'
      return _INTL('float')
    when 's'
      return _INTL('str')
    else
      return _INTL('arg')
    end
  end
end

# Exception raised when the user presses CTRL + C
class ConsoleInterrupt < Exception
end

# Exception raised when the an error occurs in the shell
class ConsoleError < Exception
end

# Exception raised when the user calls exit
class ConsoleExit < Exception
end

# The CommandArgument class stores information about a command's arguments.
# At the moment, it is only used when creating a manual description for the
# command and is not used for validating passed arguments. Maybe that
# functionality could be moved here.
class CommandArgument
  include CommandValidation

  # Returns the argument's type.
  # @return [String, NilClass] argument type (nil or 'x' if flag)
  attr_reader :type
  # Returns the argument's description.
  # @return [String] argument description
  attr_reader :description
  
  # Creates a new CommandArgument object.
  # @param description [String] argument description
  # @param type [String, NilClass] argument type (nil or 'x' if flag)
  # @param flags [Array<Symbol>] options for the argument
  #     :optional - Argument is optional
  def initialize(description,type,flags)
    @description = description
    @vararg = type.include? '*'
    type.delete!('*')
    @type = type
    @flags = flags
  end
  
  # Builds a manual description for the argument.
  # @return [String] manual description
  def manual_description
    txt = (@flags.include?(:optional) ? '<' : '[') + @description
    if @type && @type != 'x'
      txt += _INTL(': {1}',@vararg ? '*'+type_name(@type) : type_name(@type))
    end
    txt += @flags.include?(:optional) ? '>' : ']'
    return txt
  end
end

# Much like the CommandArgument class, CommandSubcommand stores information
# about a command's subcommands.
class CommandSubcommand
  # Returns the name of the subcommand.
  # @return [String] subcommand name
  attr_reader :name
  # Returns the description of the subcommand.
  # @return [String] subcommand description
  attr_reader  :description
  # Returns a symbol of the function to call.
  # @return [Symbol] function to call (symbol)
  attr_reader :function

  # Creates a new CommandSubcommand object.
  # @param name [String] subcommand name
  # @param description [String] subcommand description
  # @param function [Symbol] function to call
  def initialize(name,description,function)
    @name = name
    @description = description
    @function = function
  end
  
  # Builds a manual description for the subcommand.
  # @return [String] manual description
  def manual_description
    return _INTL('\t{1}: {2}',@name, @description)
  end
end

# CommandOption stores information about a command's options.
class CommandOption
  include CommandValidation

  # Returns the symbol of the instance variable to set a value to.
  # @return [Symbol] instance variable to set a value to
  attr_reader :var
  # Returns the option's type.
  # @return [String, NilClass] option type (nil or 'x' if flag)
  attr_reader :type
  # Returns an array of names for the option.
  # @return [Array<String>] list of names for the option
  attr_reader :names
  # Returns the option's description.
  # @return [String] option description
  attr_reader :description
  
  # Creates a new CommandOption object.
  # @param names [Array<String>] list of names for the option
  # @param description [String] option description
  # @param var [Symbol] instance variable to set a value to
  # @param type [String, NilClass] option type (nil or 'x' if flag)
  def initialize(names,description,var,type)
    @names = names
    @description = description
    @var = var
    @type = type
  end
  
  # Returns whether the option requires a value.
  # @return [Boolean] option requires a value?
  def value?
    return !self.flag?
  end
  
  # Returns whether the option is a flag and doesn't require a value.
  # @return [Boolean] option is a flag?
  def flag?
    return @type == 'x' || @type.nil?
  end
  
  # Builds a manual description for the option and returns it.
  # @return [String] manual description
  def manual_description
    txt = '\t' + @names.join(", ") + (@type && @type != 'x' ? ' ' : ': ')
    txt += _INTL('({1}): ',type_name(@type)) if @type && @type != 'x'
    txt += @description
    return txt
  end
end

# The CommandBase class contains some rudimentary functions like print, error 
# and process, as well as all functions from the CommandValidation module. 
# ConsoleCommand inherits this class.
class CommandBase
  include CommandValidation
  
  # Creates a new ConsoleBase object.
  # @param session [ConsoleSession] associated session
  def initialize(session)
    @session = session
  end
  
  # Runs the command with the given arguments. Returns an exit code.
  # @param args [Array<String>] arguments
  # @return [Integer] exit code (0: success, 1: failure)
  def run(args)
    @session.change_context(self)
    ret = 1
    begin
      ret = self.main(parse_args(args))
    rescue ConsoleInterrupt
      print '^C'
      println ':(', 2
    rescue ConsoleError => e
      print_raw _INTL("{1}: {2}",self.name,e.message)
      println ':(',2
    end
    @session.reset_context
    return ret
  end
  
  # Implemented in subclasses.
  def main(args)
    return 0
  end
  
  # Prints the given text.
  # @param text [String] text to print
  # @param align [Integer] text alignment
  #   0: left (default)
  #   1: center
  #   2: right
  # @param raw [Boolean] whether special codes like '\n' should be ignored
  #   This is false by default.
  def print(text,align=0,raw=false)
    @session.window.print(text,align,raw)
  end
  
  # Prints the given text and ignores special codes like '\n'.
  # Shorthand for self.print(text,align,true).
  # @param (see #print)
  def print_raw(text,align=0)
    @session.window.print(text,align,true)
  end
  
  # Prints the given text with a trailing newline.
  # @param (see #print)
  def println(text,align=0,raw=false)
    @session.window.print(text+'\n',align,raw)
  end
  
  # Replaces the text on the last line with the given text.
  # @param (see #print)
  def replace(text,align=0,raw=false)
    @session.window.replace(text,align,raw)
  end
  
  # Waits for the given amount of frames.
  # Can be interrupted.
  # @param frames [Integer] amount of frames to wait
  # @raise [ConsoleInterrupt] raised if interrupted
  def wait(frames)
    frames.times do
      wait_internal
    end
  end
  
  # Calls the given block for the specified amount of frames.
  # Can be interrupted.
  # @param frames [Integer] amount of times to call the block (1 per frame)
  # @raise (see #wait)
  def while(frames, &block)
    frames.times do
      block.call
      wait_internal
    end
  end
  
  # Asks for confirmation. Returns a boolean.
  # @param text [String] confirmation text
  # @return [Boolean] confirmed?
  def confirm?(text='')
    return self.run_cmd('confirm ' + text) == 0
  end
  
  # Processes the given input. Returns the exit code (0: success, 1: failure)
  # @param input [String] input to process
  # @param parse_aliases [Boolean] whether to parse aliases
  # @return [Integer] exit code (0: success, 1: failure)
  def process(input,parse_aliases=true)
    return @session.process(input,parse_aliases)
  end
  
  # Processes the given input without parsing aliases.
  # Shorthand for self.process(input,false).
  # @param input [String] input to process
  # @return (see #process)
  def run_cmd(input)
    return @session.process(input,false)
  end
  
  # Raises a ConsoleError with the given message.
  # @param message [String] error message
  # @raise [ConsoleError]
  def error(message)
    raise ConsoleError, message
  end
  
  # Checks whether the specified values are of the given type.
  # @param type [String] value type
  #   'i'   Integer
  #   'b'   Boolean
  #   'f'   Float
  # @param args [Array<String>] array of arguments
  # @param indexes [Integer] index(es) of arg to check
  def validate_values(type,args,*indexes)
    for i in indexes
      args[i] = validate_value(type,args[i])
    end
  end
  
  private
  
  # Calls Graphics.update and Input.update. Can raise ConsoleInterrupt.
  # @raise [ConsoleInterrupt] raised if CTRL + C is pressed
  def wait_internal
    Graphics.update
    Input.update
    if Input.triggerex?(0x43) && Input.triggerex?(0x11) # CTRL + C
      raise ConsoleInterrupt
    end
  end
end

# The ConsoleCommand class is the base class for all console commands.
# Properties and Aliases of subclasses are stored in their respective constants.
# Subclasses are configured using the following functions:
#
# name        [String]
#   command name
# description [String]
#   command description (short version)
# manual_desc [String]
#   command description (long version, visible when using help)
# argument    [String], [String], [*Symbol]
#   command argument (type, description, flags)
#   e.g. 's', _INTL('alias name'), :optional
# option      [String], [Symbol], [String], [*String]
#   command option (type, variable id, description, name(s))
#   e.g. 'i', :@align, _INTL('changes the alignment'), '--align', '-a'
# subcommand  [String], [String], [Symbol]
#   command subcommand (name, description, function)
#   e.g. 'load', _INTL('load a configuration'), :load_command
# aliases [*String]
#   command aliases
# session [String]
#   makes the command accessible only inside sessions with the given name
# hide
#   hides the command, making it inaccessible from the interactive shell
# debug_only
#   makes the command accessible as long as $DEBUG is true
# in_game
#   makes the command accessible only in a ConsoleSession_Ingame session
# outside_game
#   makes the command accessible only outside a ConsoleSession_Ingame session
# mkxp_only
#   makes the command accessible only in mkxp-z (checks if $MKXP is defined)
#
# Refer to the functions' own documentation for more information.
class ConsoleCommand < CommandBase
  # Contains properties of all ConsoleCommand subclasses.
  Properties = {}
  # Contains pre-defined aliases of ConsoleCommand subclasses.
  Aliases = {}
  
  # Returns the name of the command.
  # @return [String] command name
  def name
    Properties[self.class] ||= {}
    return Properties[self.class][:name] || ""
  end

  # Returns the description of the command.
  # @return [String] command description
  def description
    Properties[self.class] ||= {}
    return Properties[self.class][:desc] || ""
  end
  
  # Returns the command's in-depth manual description, or its regular
  # description if one isn't specified.
  # @return [String] command manual description (or normal description unset)
  def manual_description
    Properties[self.class] ||= {}
    return Properties[self.class][:man_desc] || self.description
  end
  
  # Returns the command's arguments.
  # @return [Array<CommandArgument>] command arguments
  def arguments
    Properties[self.class] ||= {}
    return Properties[self.class][:args] || []
  end
  
  # Returns the command's options.
  # @return [Array<CommandOption>] command options
  def options
    Properties[self.class] ||= {}
    return Properties[self.class][:opts] || []
  end
  
  # Returns the command's subcommands.
  # @return [Array<CommandSubcommand>] command options
  def subcommands
    Properties[self.class] ||= {}
    return Properties[self.class][:subcmds] || []
  end
  
  # The session this command can only be used in. Defaults to 'shell'.
  # @return [String] name of session command is exclusive to
  def session
    Properties[self.class] ||= {}
    return Properties[self.class][:session] || 'shell'
  end
  
  # Sets the name of the command.
  # @param name [String] command name
  def self.name(name)
    Properties[self] ||= {}
    Properties[self][:name] = name
  end

  # Sets the description of the command.
  # @param desc [String] command description
  def self.description(desc)
    Properties[self] ||= {}
    Properties[self][:desc] = desc
  end
  
  # Sets the more in-depth manual description of the command.
  # @param desc [String] command manual description
  def self.manual_desc(desc)
    Properties[self] ||= {}
    Properties[self][:man_desc] = desc
  end
  
  # Defines an argument. This is not used for validating them (yet?).
  # @param type ['i','b','f','s','*i','*b','*f','*s'] option type
  #   'i': integer
  #   'b': boolean (yes/no/y/n/true/false)
  #   'f': float
  #   's': string
  #   * at the beginning of the type means the argument is a
  #   'variable argument'.
  # @param description [String] argument description
  # @param flags [*Symbol] argument flags
  #     :optional - Argument is optional
  def self.argument(type,description,*flags)
    Properties[self] ||= {}
    Properties[self][:args] ||= []
    Properties[self][:args] << CommandArgument.new(description,type,flags)
  end
  
  # Adds a new option to the command.
  # If the type is set to 'x' or nil, the option is a flag and
  # doesn't take a value in the shell.
  # @param type [nil,'x','i','b','f','s'] option type
  #   nil / 'x': no type (option is a flag and doesn't take a value)
  #   'i': integer
  #   'b': boolean (yes/no/y/n/true/false)
  #   'f': float
  #   's': string
  # @param variableid [Symbol] instance variable to give a value
  #   e.g. :@value , where the given value is placed to @value
  # @param desc [String] option description
  # @param names [*String] name(s) for the command
  def self.option(type,variableid,desc,*names)
    Properties[self] ||= {}
    Properties[self][:opts] ||= []
    Properties[self][:opts] << CommandOption.new(names,desc,variableid,type)
  end
  
  # Adds a new subcommand to the command.
  # The is_subcommand?(arg) is used to check whether the input contains
  # a subcommand. parse_subcommands(args) is used to call the function
  # associated with the given subcommand.
  # @param name [String] subcommand name
  # @param description [String] subcommand description
  # @param function [Symbol] function to call (symbol)
  def self.subcommand(name,description,function)
    Properties[self] ||= {}
    Properties[self][:subcmds] ||= []
    Properties[self][:subcmds] << CommandSubcommand.new(name,description,function)
  end
  
  # Sets the command's aliases.
  # @param aliases [String] alias(es) for the command
  def self.aliases(*aliases)
    for ali in aliases
      Aliases[ali] = Properties[self][:name]
    end
  end
  
  # Makes the command available only in sessions with the given name.
  # @param name [String] session name
  def self.session(name)
    Properties[self] ||= {}
    Properties[self][:session] = name
  end
  
  # Hides the command, making it inaccessible in the interactive shell.
  def self.hide
    Properties[self] ||= {}
    Properties[self][:hidden] = true
  end
  
  # Makes the command accessible only if the $DEBUG variable is set to true.
  def self.debug_only
    Properties[self] ||= {}
    Properties[self][:debug_only] = true
  end
  
  # Makes the command accessible only inside a ConsoleSession_Ingame session.
  def self.in_game
    Properties[self] ||= {}
    Properties[self][:in_game] = true
  end
  
  # Makes the command accessible only outside a ConsoleSession_Ingame session.
  def self.outside_game
    Properties[self] ||= {}
    Properties[self][:outside_game] = true
  end

  # Makes the command accessible only in mkxp-z (checks whether $MKXP is defined).
  def self.mkxp_only
    Properties[self] ||= {}
    Properties[self][:mkxp_only] = true
  end
  
  # Prints out the command's manual text.
  def show_manual
    print self.name
    print ' ' unless self.arguments.empty?
    self.arguments.each_with_index do |arg,i| 
      print arg.manual_description
      print ' ' if i != self.arguments.length - 1
    end
    println '\h'
    println '\t' + self.manual_description
    unless self.subcommands.empty?
      println _INTL('\hSubcommands:')
      self.subcommands.each { |subcmd| println subcmd.manual_description }
    end
    unless self.options.empty?
      println _INTL('\hOptions:')
      self.options.each { |opt| println opt.manual_description }
    end
  end
  
  # Parses the given arguments.
  # Returns the argument array without parsed options.
  # e.g. if the user types in 'command --option foo bar'
  # and --option is a valid option, returns ["foo","bar"].
  # Raises a ConsoleError if parsing fails.
  # @param args [Array<String>] given arguments
  # @return [Array<String>] arguments without parsed options
  # @raise [ConsoleError] raised if parsing fails
  def parse_args(args)
    normal_args = []
    skip_next = false
    for i in 0...args.length
      if skip_next
        skip_next = false
        next
      end
      # Current argument
      c = args[i]
      # Next argument
      n = (i < args.length-1) ? args[i+1] : nil
      # Only check for options from the beginning
      unless normal_args.empty?
        normal_args.push(c)
        next
      end
      if c[0,1] == '-' && c[1,1] == '-'
        # Options with -- prefix
        option = self.options.find { |opt| opt.names.include? c }
        raise ConsoleError, _INTL('unknown option {1}', c) unless option
        skip_next = true if self.set_value(option,c,n) && option.value? 
      elsif c[0,1] == '-' && c[1,1] != '-'
        # Options with - prefix
        if c.length > 2
          # Multiple options in one (e.g. -ali)
          for j in 1...c.length
            name = "-" + c[j,1]
            option = self.options.find { |opt| opt.names.include? name }
            raise ConsoleError, _INTL('unknown option {1}',name) unless option
            skip_next = true if self.set_value(option,name,n) && option.value?
          end
        else
          # Single option (e.g. -a)
          option = self.options.find { |opt| opt.names.include? c }
          raise ConsoleError, _INTL('unknown option {1}', c) unless option
          skip_next = true if self.set_value(option,c,n) && option.value?
        end
      else
        normal_args.push(c)
      end
    end
    return normal_args
  end

  # Sets the option's instance variable's value.
  # The name of the called option is required for the
  # error message, since a single option can have multiple names.
  # @param option [CommandOption] called option
  # @param option_name [String] option name used
  # @param value [String] option's value
  # @raise [ConsoleError] raised if a required value is missing or
  #   if the value is of an incorrect type
  def set_value(option,option_name,value)
    if option.flag?
      self.instance_variable_set(option.var,true)
    elsif value
      self.instance_variable_set(option.var,validate_value(option.type,value))
    else
      raise ConsoleError, _INTL('option {1} lacks value',option_name)
    end
    return true
  end
  
  # Returns whether the given argument is a subcommand.
  # @param argument [String] argument
  # @return [Boolean] argument is a subcommand?
  def is_subcommand?(argument)
    return false if argument.nil?
    return self.subcommands.any? { |subcmd| subcmd.name == argument }
  end
  
  # Goes through the given arguments to find a subcommand and
  # calls its associated function, passing all trailing arguments
  # into it.
  # Returns the called function's return value.
  # @param args [Array<String>] arguments
  # @param pass_all_arguments [Boolean] whether all arguments should be passed, instead of only the trailing ones
  # @return [Integer] exit code of called function
  def parse_subcommands(args,pass_all_arguments = false)
    # Get the CommandSubcommand object of the invoked subcommand
    subcmd = self.subcommands.find do |cmd| 
      args.find { |arg| cmd.name == arg }
    end
    return 1 if subcmd.nil?
    if pass_all_arguments
      # Pass all arguments
      new_args = args
    else
      # Delete all arguments preceding the subcommand
      # (including the subcommand itself)
      new_args = args[args.index(subcmd.name)+1...args.length] || []
    end
    # Call the subcommand's function with the new arguments
    return self.method(subcmd.function).call(new_args)
  end
end

# The ConsoleLineSprite represents a line of text in the console.
class ConsoleLineSprite < Sprite
  # Creates a new ConsoleLineSprite.
  # @param window [ConsoleWindow] associated console window
  # @param text [String] pre-existing text
  # @param align [Integer] alignment of pre-existing text
  # @param highlight [Boolean] whether the pre-existing text is highlighted
  def initialize(window,text="",align=0,highlight=false)
    super(window.viewport)
    self.x = window.x + 4
    @window = window
    @text = Hash.new("")
    @highlight = [false,false,false]
    self.bitmap = Bitmap.new(@window.viewport.rect.width-self.x,CONSOLE_LINE_HEIGHT)
    self.bitmap.font.name = @window.fontName
    self.bitmap.font.size = CONSOLE_FONT_SIZE
    self.enable_highlight(align) if highlight
    self.write(text,align,highlight)
  end
  
  # Moves the line up by the given lines.
  # @param lines [Integer] amount of lines to move the line up by
  def move_up(lines=1)
    self.y -= CONSOLE_LINE_HEIGHT * lines
  end

  # Moves the line down by the given lines.
  # @param lines [Integer] amount of lines to move the line down by
  def move_down(lines=1)
    self.y += CONSOLE_LINE_HEIGHT * lines
  end
  
  # Writes the text into the bitmap.
  # @param text [String] text to write
  # @param align [Integer] text alignment
  #   0: left, 1: center, 2: right
  # @param highlight [Boolean] whether the text is highlighted
  def write(text,align=0,highlight=false)
    @text[align] += text
    self.enable_highlight(align) if highlight
    self.redraw
  end
  
  # Highlights the text in the given alignment.
  # @param align [Integer] text alignment
  def enable_highlight(align)
    @highlight[align] = true
  end
  
  # Replaces the text in the bitmap.
  # @param (see #write)
  def replace(text,align=0,highlight=false)
    @text[align] = text
    self.enable_highlight(align) if highlight
    self.redraw
  end
  
  # Returns the text written with the given alignment.
  # @param align [Integer] text alignment (0: left, 1: center, 2: right)
  # @return [String] written text
  def text(align=0)
    return @text[align]
  end
  
  # Returns the total width of the text with the given alignment (0 by default).
  # @param align [Integer] text alignment (0: left, 1: center, 2: right)
  # @return [Integer] total text width
  def text_width(align=0)
    return self.bitmap.text_size(self.text(align)).width
  end
  
  # Redraws the line.
  def redraw
    self.bitmap.clear
    self.bitmap.font.name = @window.fontName
    @text.each_key { |align| draw_internal(align) }
  end
  
  private
  
  # Draws the text with the given alignment.
  # @param align [Integer] alignment
  def draw_internal(align)
    return if @text[align].empty?
    self.bitmap.font.color = @window.textColor
    if @highlight[align]
      text_rect = Rect.new(0,0,self.bitmap.text_size(@text[align]).width+2,
        self.bitmap.height)
      text_rect.x = self.viewport.rect.width/2-text_rect.width/2-2 if align == 1
      text_rect.x = self.viewport.rect.width-text_rect.width-2 if align == 2
      self.bitmap.fill_rect(text_rect,@window.textColor)
      self.bitmap.font.color = @window.bgColor
    end
    self.bitmap.draw_text(self.bitmap.rect,@text[align],align)
  end
end

# Window_TextEntry_Console is an enhanced version of Window_TextEntry_Keyboard
# with some new features.
class Window_TextEntry_Console < Window_TextEntry_Keyboard
  # Returns the input history, which is an array of strings.
  # @return [Array<String>] input history
  attr_accessor :history
  
  # Creates a new Window_TextEntry_Console object.
  # @param window [ConsoleWindow] associated console window
  # @param text [String] pre-existing text
  # @param x [Integer] sprite's x coordinate
  # @param y [Integer] sprite's y coordinate
  # @param width [Integer] entry field width
  # @param height [Integer] entry field height
  def initialize(window,text,x,y,width,height)
    # Call initialize method of SpriteWindow_Base
    SpriteWindow_Base.instance_method(:initialize).bind(self).call(x,y,width,height)
    @window = window
    self.windowskin = nil
    self.contents.font.name = @window.fontName
    self.contents.font.size = 20
    @helper = CharacterEntryHelper.new(text)
    @heading = nil
    self.active = false
    @frame = 0
    self.refresh
    #self.recalculate_maxlength
    self.maxlength = 50
    @history_index = 0
    @history = []
  end
  
  # Gets an earlier value from history and sets it as the current input.
  def get_earlier
    # Do nothing if there is no history
    return if @history.empty?
    # If we're at the last value, return if the current text is the
    # same as that value. By doing this, we can avoid redrawing unnecessarily.
    if @history_index == 0
      return if @history[@history_index] == self.text
    else
      @history_index -= 1
    end
    self.text = @history[@history_index]
    # Drag the cursor to the very end of the input
    @helper.cursor = self.text.scan(/./m).length
    self.refresh
  end
  
  # Gets an later value from history and sets it as the current input.
  def get_later
    if @history.empty?
      # If there is no history, clear the current input.
      # If there is no input, return so that we don't refresh the text unnecessarily.
      return if self.text.empty?
      self.text = ""
    elsif @history_index < @history.length-1
      # Change the text accordingly
      @history_index += 1
      self.text = @history[@history_index]
      @helper.cursor = self.text.scan(/./m).length
    else
      # If we're reached the earliest item in history, clear the current input.
      @history_index = @history.length
      self.text = ""
    end
    self.refresh
  end
  
  # Shows the input field and resets the text.
  def show
    @history_index = @history.length
    self.text = ""
    self.visible = true
    self.active = true
    Input.text_input = true if $MKXP
  end
  
  # Hides the input field.
  def hide
    self.visible = false
    self.active = false
    Input.text_input = false if $MKXP
  end

  # Attempts to insert the given text.
  # @param text [String] text to insert
  def paste(text)
    can_refresh = false
    # Attempt to insert every character individually
    text.split("").each do |ch|
      break unless @helper.insert(ch)
      can_refresh = true
    end
    # Only refresh if characters were inserted
    self.refresh if can_refresh
  end
  
  # Updates the input field's font.
  def update_font
    self.contents.font.name = @window.fontName
    #self.recalculate_maxlength
    self.refresh
  end
  
  # Recalculates the maximum length of the input field. It is at least 50 characters.
  #def recalculate_maxlength
  #  self.maxlength = [self.width/self.contents.text_size('m').width,50].max
  #end
  
  # Refreshes the input field.
  def refresh
    self.contents=pbDoEnsureBitmap(self.contents,self.width-self.borderX,
       self.height-self.borderY)
    bitmap=self.contents
    bitmap.clear
    x=0
    y=0
    if @heading
      textwidth = bitmap.text_size(@heading).width
      pbDrawShadowText(bitmap,x,y,textwidth+4,32,@heading,@window.textColor,nil)
      y+=32
    end
    x+=4
    width=self.width-self.borderX
    height=self.height-self.borderY
    textscan=self.text.scan(/./m)
    scanlength=textscan.length
    @helper.cursor=scanlength if @helper.cursor>scanlength
    @helper.cursor=0 if @helper.cursor<0
    startpos=@helper.cursor
    fromcursor=0
    while (startpos>0)
      c=(@helper.passwordChar!="") ? @helper.passwordChar : textscan[startpos-1]
      fromcursor+=bitmap.text_size(c).width
      break if fromcursor>width-4
      startpos-=1
    end
    for i in startpos...scanlength
      c=(@helper.passwordChar!="") ? @helper.passwordChar : textscan[i]
      textwidth=bitmap.text_size(c).width
      next if c=="\n"
      # Draw text
      pbDrawShadowText(bitmap,x,y, textwidth+4, 32, c,@window.textColor,nil)
      # Draw cursor if necessary
      if ((@frame/10)&1) == 0 && i==@helper.cursor
        bitmap.fill_rect(x,y+4,2,24,@window.textColor)
      end
      # Add x to drawn text width
      x += textwidth
    end
    if ((@frame/10)&1) == 0 && textscan.length==@helper.cursor
      bitmap.fill_rect(x,y+4,2,24,@window.textColor)
    end
  end

  if $MKXP
    # Updates the text input field.
    # Overwritten for mkxp-z compatability. Code from Roza.
    def update
      @frame+=1
      @frame%=20
      self.refresh if ((@frame%10)==0)
      return if !self.active
      # Moving cursor
      # Left arrow key
      if Input.triggerex?(0x25) || Input.repeatex?(0x25)
        if @helper.cursor > 0
          @helper.cursor -= 1
          @frame = 0
          self.refresh
        end
        return
      end
      # Right arrow key
      if Input.triggerex?(0x27) || Input.repeatex?(0x27)
        if @helper.cursor < self.text.scan(/./m).length
          @helper.cursor += 1
          @frame = 0
          self.refresh
        end
        return
      end
      # Backspace
      if Input.triggerex?(0x08) || Input.repeatex?(0x08)
        self.delete if @helper.cursor > 0
        return
      end
      Input.gets.each_char do |ch|
        break unless self.insert(ch)
      end
    end
  end
end

# The ConsoleWindow handles the visual side of the shell. It contains
# an array of ConsoleLineSprite objects as well as an instance of the
# Window_TextEntry_Console class.
class ConsoleWindow < Sprite
  # Returns the current text color.
  # @return [Color] the current text color
  attr_reader :textColor
  # Returns the current background color.
  # @return [Color] the current background color
  attr_reader :bgColor
  # Returns the current font name.
  # @return [String] the current font name
  attr_reader :fontName
  # Returns an array of drawn lines.
  # @return [Array<ConsoleLineSprite>] drawn lines
  attr_reader :lines
  
  # Creates a new ConsoleWindow object.
  # @param session [ConsoleSession] associated session
  # @param viewport [Viewport] viewport to draw the window into
  def initialize(session,viewport)
    super(viewport)
    @session = session
    @background = BitmapSprite.new(
      viewport.rect.width,viewport.rect.height,viewport
    )
    # Get our background and text color from the config
    @bgColor ||= @session.config.bgColor
    @textColor ||= @session.config.textColor
    @fontName ||= @session.config.fontName
    # Draw the background color, and text entry field
    @background.bitmap.fill_rect(@background.bitmap.rect,@bgColor)
    @text_entry = Window_TextEntry_Console.new(
      self,"",0,0,self.viewport.rect.width,CONSOLE_LINE_HEIGHT*3
    )
    @text_entry.viewport = self.viewport
    @text_entry.visible = false
    # Initialize the window with a single line and set the maximum
    # amount of lines
    @lines = []
    @lines << ConsoleLineSprite.new(self)
    @max_lines = self.viewport.rect.height/CONSOLE_LINE_HEIGHT
    self.reposition_entry
  end
  
  # Changes the window's background color.
  # @param color [Color] color to change the background to
  def change_bg_color(color)
    @bgColor = color
    @background.bitmap.fill_rect(@background.bitmap.rect,color)
  end
  
  # Changes the window's text color.
  # @param color [Color] color to change the text to
  def change_text_color(color)
    @textColor = color
    @text_entry.refresh
    self.redraw
  end

  # Changes the current font.
  # @param fontname [String] new font
  def change_font_name(fontname)
    @fontName = fontname
    @text_entry.update_font
    self.redraw
  end
  
  # Prints the given text.
  # If raw is set to true, does not process \n and \t.
  # @param text [String] text to print
  # @param align [Integer] text alignment
  #   0: left, 1: center, 2: right
  # @param raw [Boolean] if true, do not process \n and \t
  def print(text,align=0,raw=false)
    draw_internal(text,align,false,raw)
    reposition_lines
  end
  
  # Replaces the last line with the given text.
  # If raw is set to true, does not process \n and \t.
  # @param (see #print)
  def replace(text,align=0,raw=false)
    draw_internal(text,align,true,raw)
    reposition_lines
  end
  
  # Returns the text entry field.
  # @return [Window_TextEntry_Console] text entry field
  def entry
    return @text_entry
  end
  
  # Repositions the text entry field.
  def reposition_entry
    prompt_width = @lines.last.text_width
    @text_entry.x = prompt_width - @text_entry.borderX/2
    @text_entry.y = @lines.last.y - 21
    @text_entry.width = self.viewport.rect.width-@text_entry.x
    #@text_entry.recalculate_maxlength
  end
  
  # Scrolls each line up by the specified amount.
  # @param lines [Integer] amount of lines to scroll each line up by
  def scroll_up(lines = 1)
    @lines.each { |spr| spr.move_up(lines) }
  end
  
  # Scrolls each line down by the specified amount.
  # @param lines [Integer] amount of lines to scroll each line down by
  def scroll_down(lines = 1)
    @lines.each { |spr| spr.move_down(lines) }
  end
  
  # Clears the window.
  def clear
    @lines.each { |spr| spr.dispose }
    @lines = []
    @lines << ConsoleLineSprite.new(self)
    reposition_lines
  end
  
  # Redraws each line.
  def redraw
    @lines.each { |spr| spr.redraw }
  end
  
  # Disposes the window.
  def dispose
    @lines.each { |spr| spr.dispose }
    @text_entry.dispose
    @background.dispose
    super
  end
  
  private
  
  # Does the actual drawing.
  # @param text [String] text to draw
  # @param align [Integer] text alignment
  # @param replace [Boolean] whether text should be replaced
  # @param raw [Boolean] whether \n and \t should be ignored
  def draw_internal(text,align=0,replace=false,raw=false)
    if raw
      print_lines = [text]
    else
      text.gsub!('\t','   ')
      print_lines = text.split('\n',-1)
      # Check for highlights in the first line
      if print_lines[0].include?('\\h')
        print_lines[0].gsub!('\\h','')
        @lines.last.enable_highlight(align)
      end
    end
    # Write the first line
    if replace
      @lines.last.replace(print_lines[0],align)
    else
      @lines.last.write(print_lines[0],align)
    end
    return if print_lines.length < 2
    for i in 1...print_lines.length
      # Check for highlights for all other lines
      if !raw && print_lines[i].include?('\\h')
        print_lines[i].gsub!('\\h','')
        highlight = true
      else
        highlight = false
      end
      # Create new line sprites for all new lines
      @lines << ConsoleLineSprite.new(self,print_lines[i],align,highlight)
    end
  end
  
  # Repositions each line.
  def reposition_lines
    @lines.each_with_index do |spr,i|
      spr.y = CONSOLE_LINE_HEIGHT * i
    end
    if @lines.length > @max_lines
      @lines.each { |spr| spr.move_up(@lines.length - @max_lines) }
      @lines.each_with_index do |spr,i|
        if spr.y < -CONSOLE_LINE_HEIGHT
          spr.dispose
          @lines.delete_at(i)
        end
      end
    end
  end
end

class ShellConfiguration
  # Returns the name of the configuration.
  # @return [String] config name
  attr_reader :name
  # Returns the config's saved background color.
  # @return [Color] saved background color
  attr_reader :bgColor
  # Returns the config's saved text color.
  # @return [Color] saved text color
  attr_reader :textColor
  # Returns the config's saved font name.
  # @return [String] saved font name
  attr_reader :fontName
  # Returns the config's saved prompt.
  # @return [String] saved prompt
  attr_reader :prompt
  
  # Creates a new ShellConfiguration object.
  # @param name [String] config name
  # @param bg_color [Color] saved background color
  # @param text_color [Color] saved text color
  # @param font_name [String] saved font name
  # @param prompt [String] saved prompt
  def initialize(name,bg_color,text_color,font_name,prompt)
    @name = name
    @bgColor = bg_color
    @textColor = text_color
    @fontName = font_name
    @prompt = prompt
    @active = false
  end
  
  # Returns whether the config is active.
  # An active config is automatically loaded when the shell boots up.
  # @return [Boolean] config is active?
  def active?
    return $ShellOptions.activeConfig == @name
  end
  
  # Sets the config as active.
  def activate
    $ShellOptions.activeConfig = @name
  end
  
  # Creates a new ShellConfiguration object from the values of the given session.
  # @param name [String] config name
  # @param session [ConsoleSession] session to take values from
  # @return [ShellConfiguration] ShellConfiguration object
  def self.newFromSession(name,session)
    return self.new(name,session.window.bgColor,session.window.textColor,
                    session.window.fontName,session.prompt)
  end

  # Creates a new ShellConfiguration object with default values.
  # @param name [String] config name ("default" by default)
  # @return [ShellConfiguration] ShellConfiguration object
  def self.newDefault(name="default")
    return self.new(name,Color.new(0,0,0),Color.new(255,255,255),
                    CONSOLE_DEFAULT_FONT,"#> ")
  end
end

# A bare-bones console session. Started with
#   ConsoleSession.new
class ConsoleSession
  # Contains the properties of ConsoleSession subclasses.
  Properties = {}

  # Returns the ConsoleWindow object associated with the session.
  # @return [ConsoleWindow] associated window
  attr_reader :window
  # Returns the available commands as a hash, where
  # command name => ConsoleCommand object
  # @return [Hash{String => ConsoleCommand}] available commands
  attr_reader :commands
  # Returns the current context. Returns nil if no command is running.
  # @return [ConsoleCommand, NilClass] current context
  attr_reader :context
  # Returns the active configuration.
  # @return [ShellConfiguration] current config
  attr_reader :config
  # Returns the active prompt.
  # @return [String] current prompt
  attr_reader :prompt
  # Returns the current aliases.
  # @return [Hash{String => String}] current aliases
  attr_reader :aliases
  
  # Sets the ConsoleSession's name.
  # @param name [String] session name
  def self.name(name)
    Properties[self] ||= {}
    Properties[self][:name] = name
  end
  
  # Starts a new console session.
  def initialize
    @viewport = Viewport.new(0,0,Graphics.width,Graphics.height)
    @viewport.z = 99999
    # Initialize shell options if not set
    $ShellOptions ||= ShellOptions.load
    # Get the active config. If none is found, use the default config.
    if !$ShellOptions.activeConfig || !$ShellOptions.shellConfigs.has_key?($ShellOptions.activeConfig)
      $ShellOptions.shellConfigs['default'] ||= ShellConfiguration.newDefault
      $ShellOptions.activeConfig = 'default'
    end
    @config = $ShellOptions.shellConfigs[$ShellOptions.activeConfig]
    # Create the console window and set the available commands.
    @window = ConsoleWindow.new(self,@viewport)
    @prompt = @config.prompt
    @aliases = $ShellOptions.shellAliases
    @commands = {}
    self.set_commands
    @context = nil
    self.main
  end
  
  # Sets the available commands.
  def set_commands
    ConsoleCommand::Properties.each do |cmd_class,data|
      next if data[:debug_only] && !$DEBUG
      next if data[:in_game]
      next if (data[:session] || 'shell') != self.name
      next if data[:mkxp_only] && !$MKXP
      @commands[data[:name]] = cmd_class.new(self) unless data[:hidden]
    end    
  end
  
  # The main logic of the session.
  def main
    loop do
      unless @context
        begin
          self.process(self.await_input)
        rescue ConsoleInterrupt
          self.replace '^C'
          self.println ':(', 2
        rescue ConsoleError => e
          self.print _INTL("{1}: {2}",self.name,e.message), 0, true
          self.println ':(', 2
        rescue ConsoleExit
          self.exit_session
          break
        end
      end
    end
  end
  
  # Called when the session ends. Disposes the associated sprites
  # and saves shell options.
  def exit_session
    @window.dispose
    @viewport.dispose
    ShellOptions.save
  end
  
  # Processes the given input. Returns exit code of the command (0 or 1)
  # or 1 if an error occurred. Can raise a ConsoleError.
  # @param input [String] input to process
  # @param parse_aliases [Boolean] whether aliases should be parsed.
  #   This is true by default.
  # @return [Integer] exit code (0: success, 1: failure)
  # @raise [ConsoleError] raised when an unknown command is passed
  def process(input,parse_aliases=true)
    ret = 1
    input_to_lines(input,parse_aliases).each do |args|
      # Get the command and arguments
      command, arguments = parse(args)
      # Run the command
      if @commands.has_key?(command)
        ret = call_internal(command,arguments || [])
      elsif !command.empty?
        raise ConsoleError, _INTL('unknown command {1}',command)
      end
    end
    ret ||= 1
    return ret
  end
  
  # Processes the given input without parsing aliases.
  # Shorthand for self.process(input,false).
  # @param input [String] input to process
  # @return (see #process)
  # @raise (see #process)
  def run_cmd(input)
    return self.process(input,false)
  end
  
  # Returns the ConsoleSession's name.
  # @return [String] session name
  def name
    Properties[self.class] ||= {}
    return Properties[self.class][:name] || 'shell'
  end
  
  # Returns whether the operation was confirmed.
  # @param text [String] operation to confirm
  # @return [Boolean] confirmed?
  def confirm?(text)
    return self.run_cmd('confirm ' + text) == 0
  end
  
  # Prints the given text.
  # @param text [String] text to print
  # @param align [Integer] text alignment
  #   0: left, 1: center, 2: right
  # @param raw [Boolean] whether \n or \t should be ignored
  def print(text,align=0,raw=false)
    @window.print(text,align,raw)
  end
  
  # Prints the given text with a trailing newline.
  # @param (see #print)
  def println(text,align=0,raw=false)
    @window.print(text+'\n',align,raw)
  end
  
  # Replaces the last line with the given text.
  # @param (see #print)
  def replace(text,align=0,raw=false)
    @window.replace(text,align,raw)
  end
  
  # Forces a wait for the given amount of frames.
  # This can not be interrupted.
  # @param frames [Integer] frames to wait
  def force_wait(frames)
    frames.times do
      Graphics.update
      Input.update
    end
  end
  
  # Returns the command with the given name.
  # @param name [String] command name
  # @return [ConsoleCommand] command object
  def command(name)
    return @commands[name]
  end
  
  # Changes the context.
  # @param context [ConsoleCommand] new context
  def change_context(context)
    @context = context
  end
  
  # Sets the context to nil.
  def reset_context
    @context = nil
  end
  
  # Changes the command prompt.
  # @param string [String] new prompt
  def set_prompt(string)
    @prompt = string
  end
  
  # Sets an alias.
  # @param name [String] alias name
  # @param value [String] alias value
  def set_alias(name,value)
    # Ensure escaped quotes work in aliases
    @aliases[name] = value.gsub(/"/) { |match| '\\' + match }
  end
  
  # Removes the given alias.
  # @param name [String] alias name
  def unset_alias(name)
    @aliases.delete(name)
  end
  
  # Switches the loaded configuration.
  # @param config [ShellConfiguration] config to switch to
  def switch_config(config)
    @config = config
    @window.change_bg_color(config.bgColor)
    @window.change_text_color(config.textColor)
    @window.change_font_name(config.fontName)
    self.set_prompt(config.prompt)
    config.activate
  end
  
  # Awaits for user input. Returns the input.
  # This can be interrupted.
  # @param show_prompt [Boolean] whether to show the command prompt (optional)
  #   This is true by default.
  # @param save_to_history [Boolean] whether to save the input to history
  #   This is true by default.
  # @return [String] user input
  # @raise [ConsoleInterrupt] raised when CTRL + C is pressed
  def await_input(show_prompt=true,save_to_history=true)
    input = ""
    self.print(@prompt) if show_prompt
    old_text = @window.lines.last.text
    @window.reposition_entry
    @window.entry.show
    loop do
      Graphics.update
      Input.update
      if Input.triggerex?(0x0D) # Enter
        # No string terminators in this household
        input = @window.entry.text.delete("\x00")
        @window.entry.history << input if save_to_history && !input.empty?
        break
      elsif Input.triggerex?(0x11) && Input.triggerex?(0x43) # CTRL + C
        raise ConsoleInterrupt
      elsif Input.triggerex?(0x09) || Input.repeatex?(0x09) # Tab
        @window.entry.paste('  ')
      elsif $MKXP && Input.pressex?(0x11) && Input.triggerex?(0x2D) # CTRL + INS
        # Copy
        unless @window.entry.text.strip.empty?
          Input.clipboard = @window.entry.text
        end
      elsif $MKXP && Input.pressex?(0x10) && Input.triggerex?(0x2D) # SHIFT + INS
        # Paste
        @window.entry.paste(Input.clipboard)
      elsif Input.repeat?(Input::UP)
        @window.entry.get_earlier
      elsif Input.repeat?(Input::DOWN)
        @window.entry.get_later
      else
        @window.entry.update
      end
    end
    self.replace(old_text + input,0,true)
    self.println("")
    @window.entry.hide
    return input
  end

  private
  
  # Runs the given command. Returns the exit code.
  # @param command [String] command name
  # @param args [Array<String>] arguments
  # @return [Integer] exit code (0: success, 1: failure)
  def call_internal(command,args)
    return @commands[command].clone.run(args)
  end
  
  # Parses the given input to separate lines.
  # Thanks to Marin for this.
  # @param input [String] input to parse
  # @param parse_aliases [Boolean] whether aliases should be parsed (true by default)
  # @return [Array<Array<String>>] parsed lines (nested array of strings)
  def input_to_lines(input,parse_aliases=true)
    # Array<Array<String>>
    lines = []
    # Array<String>
    args = []
    in_string = false
    current_word = ""
    skip_next = false
    for i in 0...input.length
      # If this character is set to be skipped, skip it
      if skip_next
        skip_next = false
        next
      end
      # Get previous character
      p = (i > 0) ? input[i-1, 1] : nil
      # Get current character
      c = input[i, 1]
      # Get next character
      n = (i < input.length-1) ? input[i+1, 1] : nil
      if c == '\\'
        # Escaped quotes & backwards slash
        if n == '"' || n == '\\'
          current_word += n
          skip_next = true
        else
          current_word += c
        end
      elsif c == '"'
        # Quotes
        in_string = !in_string
      elsif c == ' '
        # Whitespace
        if in_string
          current_word += c
        elsif !current_word.empty?
          args.push(current_word)
          current_word = ""
        end
      elsif c == '='
        # Equals sign
        if in_string
          current_word += c
        else
          args.push(current_word)
          current_word = ""
        end
      elsif !in_string && (c == '&' && n == '&' || c == ';')
        # && and ;
        skip_next = true if c != ';'
        args.push(current_word) unless current_word.empty?
        # Parse aliases if necessary
        if parse_aliases
          ali = parse_aliases(args)
        else
          ali = nil
        end
        lines.push(args.clone)
        lines.push(ali) if ali && !ali.empty?
        args.clear
        current_word = ""
      else
        current_word += c
      end
    end
    args.push(current_word) unless current_word.empty?
    # Parse aliases if necessary
    if parse_aliases
      ali = parse_aliases(args)
    else
      ali = nil
    end
    lines.push(args)
    lines.push(ali) if ali && !ali.empty?
    raise ConsoleError, _INTL('unterminated string') if in_string
    return lines
  end
  
  # Checks whether the first word of a line is an alias.
  # If it is, substitute it with the alias's contents.
  # New lines are returned. If no alias is found, returns an empty array.
  # @param args [Array<String>] line of arguments
  # @return [Array<String>] new lines
  def parse_aliases(args)
    return [] unless @aliases.has_key? args[0]
    ret = []
    parsed_lines = input_to_lines(@aliases[args[0]],false)
    passed_arguments = nil
    parsed_lines.each_with_index do |line,i|
      if i == 0
        # If the user types the following command: ALIAS arg1 arg2,
        # where ALIAS consists of multiple lines (e.g. echo hi ; echo hey),
        # the passed arguments must be moved to the end of the
        # last line. In this case, 'ALIAS arg1 arg2' becomes:
        #   echo hi ; echo hey arg1 arg2
        # The passed arguments are saved to the passed_arguments variable.
        args.delete_at(0)
        if parsed_lines.length > 1
          passed_arguments = args.clone
          args.clear
        end
        args.insert(0,*line)
      else
        if i == parsed_lines.length-1
          # The passed arguments are added to the end of the last parsed line.
          line += passed_arguments 
        end
        ret.push(*line)
      end
    end
    return ret
  end
  
  # Parses a line and returns an array [cmd,args], where cmd is the 
  # name of the invoked command and args is an array of arguments
  # @param args [Array<String>] line to parse
  # @return [Array<String>] parsed array
  def parse(args)
    rest = args.clone
    rest.delete_at(0)
    return args[0], rest
  end
end

# A class for storing shell options. The data can be loaded with
# ShellOptions.load and saved using ShellOptions.save.
class ShellOptions
  # Creates a new ShellOptions object.
  def initialize
    @configs = {}
    @active_config = nil
    @shell_aliases = ConsoleCommand::Aliases.clone
  end
  
  # Returns a hash of saved shell configurations.
  # @return [Hash{String => ShellConfiguration}] saved configurations
  def shellConfigs
    return @configs
  end
  
  # Returns the name of the active shell configuration.
  # @return [String] name of active configuration
  def activeConfig
    return @active_config
  end
  
  # Changes the active shell configuration.
  # @param config_name [String] name of configuration to switch to
  def activeConfig=(config_name)
    @active_config = config_name
  end
  
  # Returns all shell aliases.
  # @return [Hash{String => String}] shell aliases
  def shellAliases
    return @shell_aliases
  end
  
  # Saves $ShellOptions into a ShellOptions.rxdata file.
  # Returns whether the operation was successful.
  # @return [Boolean] saving was successful?
  def self.save
    return false if $ShellOptions.nil? # This shouldn't happen
    begin
      File.open(RTP.getSaveFileName("ShellOptions.rxdata"),"wb") do |f|
          Marshal.dump($ShellOptions,f)
      end
      Graphics.frame_reset
    rescue StandardError => e
      p "Shell options could not be saved. Make sure the game can write to the save data directory. Given error:\n#{e.message}"
      return false
    end
    return true
  end
  
  # Attempts to load the options from the ShellOptions.rxdata file and
  # return the fetched ShellOptions object.
  # If it fails, returns a new object.
  # @return [ShellOptions] ShellOptions object
  def self.load
    data = RTP.getSaveFileName("ShellOptions.rxdata")
    if safeExists?(data)
      ret = nil
      File.open(data) do |f|
        ret = Marshal.load(f)
      end
      raise "Corrupted shell options" if !ret.is_a?(ShellOptions)
    else
      ret = self.new
    end
    return ret
  end
end

# A namespace for various utility functions.
module SAASUtils
  module_function

  # Reboots the program.
  # @raise [SystemExit]
  def reboot
    if $MKXP
      # Code from Zoroark
      if System.platform[/Mac/]
        Thread.new {system('../MacOS/mkxp-z')}
      elsif System.platform[/Linux/]
        Thread.new {system('./mkxp-z.AppImage')}
      else
        Thread.new {system('mkxp-z')}
      end
    else
      Thread.new {system('Game' + ($DEBUG ? ' debug' : ''))}
    end
    exit
  end
end
