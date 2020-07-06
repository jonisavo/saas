#==============================================================================#
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■ SHELL AS A SERVICE ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ #
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ APPLICATIONS ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ #
#==============================================================================#

# ApplicationWindow an enhanced version of ConsoleWindow.
class ApplicationWindow < ConsoleWindow
  # Creates a new ApplicationWindow object.
  # @param session [ConsoleApplication] associated application session
  # @param smth [Viewport,Rect,Array<Integer>] window dimensions (x, y, width, height or Rect) or a Viewport
  def initialize(session,*smth)
    if smth[0].is_a?(Viewport)
      viewport = smth[0]
    elsif smth[0].is_a?(Rect)
      viewport = Viewport.new(smth[0])
    elsif smth[0].is_a?(Integer) && smth[1].is_a?(Integer) && smth[2].is_a?(Integer) && smth[3].is_a?(Integer)
      viewport = Viewport.new(smth[0],smth[1],smth[2],smth[3])
    else
      raise ArgumentError, 'invalid argument(s) for ApplicationWindow'
    end
    viewport.z = 9999
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

  # Returns the width of the application window.
  # @return [Integer] window width
  def width
    return self.viewport.rect.width
  end

  # Returns the height of the application window.
  # @return [Integer] window height
  def height
    return self.viewport.rect.height
  end

  # Disposes the window.
  def dispose
    super
    @border_sprite.dispose
    @viewport.dispose
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

class Window_CommandApplication < Window_CommandPokemonEx
  # Creates a new Window_CommandConsole object.
  # @param window [ApplicationWindow] window to bind to
  # @param choices [*String] window choices
  def initialize(window,*choices)
    @window = window
    super(build_list(choices),window.width)
    self.viewport = @window.viewport
    self.windowskin = nil
    self.contents.font.name = @window.fontName
    self.contents.font.size = 20
  end

  # Changes the command window's choices.
  # @param choices [Array<String>] new choices
  def setChoices(*choices)
    self.commands = build_list(choices)
  end

  def drawItem(index,count,rect)
    rect = drawCursor(index,rect)
    if index == self.index
      self.contents.fill_rect(rect,@window.textColor)
      text_col = @window.bgColor
    else
      text_col = @window.textColor
    end
    pbDrawShadowText(self.contents,rect.x,rect.y,rect.width,rect.height,@commands[index],text_col,nil)
  end

  private

  # Builds the list of choices.
  # This function should be overwritten by subclasses.
  # @param [Array<String>] choices
  # @return [Array<String>] list of choices
  def build_list(choices)
    return choices
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
      @config = $ShellOptions.shellConfigs['default']
    else
      @config = $ShellOptions.shellConfigs[$ShellOptions.activeConfig]
    end
    @prompt = @config.prompt
    @aliases = $ShellOptions.shellAliases
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
    end
    self.app_exit
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

class ConsoleApplication_Menu < ConsoleApplication
  name 'menu'
  force_default_config

  def app_start
    @list_window = ApplicationWindow.new(self,Graphics.width/2-128,Graphics.height/2-128,128,128)
    @list_window.drawBorder(2)
    @list = Window_CommandApplication.new(@list_window,_INTL('Start game'),_INTL('Continue'),_INTL('Options'),_INTL('Exit'))
    @msg_window = ApplicationWindow.new(self,Graphics.width/2-128,Graphics.height-180,128,180)
  end

  def app_main
    loop do
      Graphics.update
      Input.update
      @list.update
      next unless Input.trigger?(Input::C)
      case @list.index
      when 0
        @msg_window.print("Start game was pressed!")
      when 1
        @msg_window.print("Continue was pressed!")
      when 2
        @msg_window.print("Options was pressed!")
      else
        break
      end
    end
  end

  def app_exit
    @list.dispose
    @list_window.dispose
    @msg_window.dispose
  end
end

class ConsoleApplication_Jukebox < ConsoleApplication
  name 'jukebox'
  force_default_config

  def app_start
    # create sprites etc
    @header_window = ApplicationWindow.new(self,0,0,Graphics.width,CONSOLE_LINE_HEIGHT*4)
    @header_window.drawBorder(2)
    @list_window = ApplicationWindow.new(self,0,CONSOLE_LINE_HEIGHT*4,Graphics.width,CONSOLE_LINE_HEIGHT * 8)
    @list_window.drawBorder(2)
    @command_window = ApplicationWindow.new(self, 0,CONSOLE_LINE_HEIGHT * 12,Graphics.width,Graphics.height-CONSOLE_LINE_HEIGHT * 12)
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
