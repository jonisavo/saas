#==============================================================================#
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■ SHELL AS A SERVICE ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ #
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ APPLICATIONS ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ #
#==============================================================================#

# ApplicationWindow an enhanced version of ConsoleWindow.
class ApplicationWindow < ConsoleWindow
  # Creates a new ApplicationWindow object.
  # @param session [ConsoleApplication] associated application session
  # @param viewport [Viewport] viewport to attach the window into
  def initialize(session, viewport)
    super(session, viewport)
    @border_sprite = BitmapSprite.new(viewport.rect.width, viewport.rect.height,@viewport)
  end

  # Draws a border with the given thickness and color.
  # @param thickness [Integer] border thickness (in pixels)
  # @param color [Color] border color (optional, text color by default)
  def drawBorder(thickness = 2,color = @textColor)
    @border_sprite.bitmap.clear
    # Top line
    @border_sprite.bitmap.fill_rect(0,0,self.viewport.width,thickness,color)
    # Bottom line
    @border_sprite.bitmap.fill_rect(0,self.viewport.height-thickness,self.viewport.width,thickness,color)
    # Left line
    @border_sprite.bitmap.fill_rect(0,0,thickness,self.viewport.height,color)
    # Right line
    @border_sprite.bitmap.fill_rect(self.viewport.width-thickness,0,thickness,self.viewport.height,color)
  end

  # Moves the text entry sprite to the given coordinates.
  # @param x [Integer] x coordinate
  # @param y [Integer] y coordinate
  def move_entry(x,y)
    @text_entry.x = x
    @text_entry.y = y - 21
    @text_entry.width = self.viewport.rect.width-@text_entry.x
  end

  # Disposes the window.
  def dispose
    @border_sprite.dispose
    super
  end

  private

  # TODO Modify these functions.

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

# Application commands are a different type of console command with some minor differences.
class ApplicationCommand < CommandBase
  # Contains properties of all ApplicationCommand subclasses.
  Properties = {}
  # Contains pre-defined aliases of ApplicationCommand subclasses.
  Aliases = {}

  # Sets the name of the command.
  # @param name [String] command name
  def self.name(name)
    Properties[self] ||= {}
    Properties[self][:name] = name
  end

  # Returns the name of the command.
  # @return [String] command name
  def name
    Properties[self.class] ||= {}
    return Properties[self.class][:name] || ""
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

  # Returns the command's arguments.
  # @return [Array<CommandArgument>] command arguments
  def arguments
    Properties[self.class] ||= {}
    return Properties[self.class][:args] || []
  end

  # Sets the command's aliases.
  # @param aliases [*String] alias(es) for the command
  def self.aliases(*aliases)
    for ali in aliases
      Aliases[ali] = Properties[self][:name]
    end
  end

  # Makes the command accessible only if the $DEBUG variable is set to true.
  def self.debug_only
    Properties[self] ||= {}
    Properties[self][:debug_only] = true
  end
end

# Console applications are a form of ConsoleSession with wildly different logic.
# Instead of everything running in a loop in main, the processing is done throughout
# three functions: app_start, app_main and app_exit. By default, ConsoleInterrupt
# and ConsoleError exceptions will result in app_exit being called. Those exceptions
# should be caught inside app_main if it is necessary to process them.
class ConsoleApplication < ConsoleSession
  name 'app'

  # The Commands constant contains the app commands of every
  # application. It is a hash of arrays:
  # application class => Array<ApplicationCommand>
  Commands = Hash.new([])

  # Starts a new application session.
  def initialize
    @viewport = Viewport.new(0,0,Graphics.width,Graphics.height)
    @viewport.z = 99999
    # Force the default config if the setting is set, otherwise get the active configuration.
    if self.force_default_config?
      @config = $SystemData.shellConfigs['default']
    else
      @config = $SystemData.shellConfigs[$SystemData.activeConfig]
    end
    @prompt = @config.prompt
    @aliases = $SystemData.shellAliases
    @commands = {}
    self.set_commands
    @context = nil
    self.main
  end

  # The main logic of the application.
  def main
    begin
      self.app_start
      self.app_main
    rescue ConsoleInterrupt
      # ignored
    rescue ConsoleError
      # ignored
    ensure
      self.app_exit
    end
    self.exit_session
  end

  # Called when the application session ends. Disposes the viewport.
  def exit_session
    @viewport.dispose
  end

  def set_commands
    return unless ConsoleApplication::Commands.has_key?(self.class)
    ConsoleApplication::Commands[self.class].each do |cmd_class,data|
      next if data[:debug_only] && !$DEBUG
      next if data[:in_game]
      @commands[data[:name]] = cmd_class.new(self) unless data[:hidden]
    end
  end

  def app_start
    raise NotImplementedError
  end

  def app_main
    raise NotImplementedError
  end

  def app_exit
    raise NotImplementedError
  end

  # Takes a block of code and inserts into the application as an ApplicationCommand subclass.
  # @param name [String] command name
  def self.command(name,&block)
    klass = Class.new(ApplicationCommand)
    ApplicationCommand::Properties[klass] ||= {}
    ApplicationCommand::Properties[klass][:name] = name
    klass.class_eval(&block)
    Commands[self] << klass
  end

  # Returns whether the application will always use the default config.
  # @return [Boolean] application uses default config?
  def force_default_config?
    Properties[self.class] ||= {}
    return Properties[self.class][:default_conf] == true
  end

  # Makes the application use the default config.
  def self.force_default_config
    Properties[self] ||= {}
    Properties[self][:default_conf] = true
  end
end

class ConsoleApplication_Jukebox < ConsoleApplication
  name 'jukebox'
  force_default_config

  def app_start
    # create sprites etc
    @header_viewport = Viewport.new(0,0,Graphics.width,CONSOLE_LINE_HEIGHT*4)
    @header_window = ApplicationWindow.new(self,@header_viewport)
    @header_window.drawBorder(2)
    @list_viewport = Viewport.new(0,CONSOLE_LINE_HEIGHT*4,Graphics.width,CONSOLE_LINE_HEIGHT * 8)
    @list_window = ApplicationWindow.new(self,@list_viewport)
    @list_window.drawBorder(2)
    @command_viewport = Viewport.new(0,CONSOLE_LINE_HEIGHT * 12,Graphics.width,Graphics.height-CONSOLE_LINE_HEIGHT * 12)
    @command_window = ApplicationWindow.new(self, @command_viewport)
    @command_window.drawBorder(2)
    # create variables
    @volume = $PokemonSystem.bgmvolume
  end

  def app_main
    # main loop
  end

  def app_exit
    # dispose sprites etc
  end

  # Changes volume.
  # @param vol [Integer] new volume
  def change_volume(vol)
    @volume = vol
  end

  command('help') do
    aliases 'h'

    def main(args)
      ConsoleApplication_More.new('help text')
      return 0
    end
  end

  command('volume') do
    aliases 'vol'

    def main(args)
      error _INTL('no volume given') if args.empty?
      volume = validate_value 'i', args[0]
      validate_range 0..100, volume
      @session.change_volume(volume)
      return 0
    end
  end
end
