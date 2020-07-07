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
    viewport.z = 99999
    super(session, viewport)
    @border_sprite = BitmapSprite.new(self.width,self.height,self.viewport)
    @border_sprite.z = 9999
  end

  # Draws a border with the given thickness and color.
  # @param thickness [Integer] border thickness (in pixels)
  # @param color [Color] border color (optional, text color by default)
  def drawBorder(thickness = 2,color = @textColor)
    @border_sprite.bitmap.clear
    # Top line
    @border_sprite.bitmap.fill_rect(0,0,self.width,thickness,color)
    # Bottom line
    @border_sprite.bitmap.fill_rect(0,self.height-thickness,self.width,thickness,color)
    # Left line
    @border_sprite.bitmap.fill_rect(0,0,thickness,self.height,color)
    # Right line
    @border_sprite.bitmap.fill_rect(self.width-thickness,0,thickness,self.height,color)
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
  end
end

# A version of SpriteWindow_Selectable that removes the cursor sound effects.
class SpriteWindow_Selectable_Console < SpriteWindow_Selectable
  def update
    super
    if self.active and @item_max > 0 and @index >= 0 and !@ignore_input
      if Input.repeat?(Input::UP)
        if (Input.trigger?(Input::UP) && (@item_max%@column_max)==0) or
            @index >= @column_max
          oldindex = @index
          @index = (@index - @column_max + @item_max) % @item_max
          if @index != oldindex
            update_cursor_rect
          end
        end
      elsif Input.repeat?(Input::DOWN)
        if (Input.trigger?(Input::DOWN) && (@item_max%@column_max)==0) or
            @index < @item_max - @column_max
          oldindex = @index
          @index = (@index + @column_max) % @item_max
          if @index != oldindex
            update_cursor_rect
          end
        end
      elsif Input.repeat?(Input::LEFT)
        if @column_max >= 2 and @index > 0
          oldindex = @index
          @index -= 1
          if @index != oldindex
            update_cursor_rect
          end
        end
      elsif Input.repeat?(Input::RIGHT)
        if @column_max >= 2 and @index < @item_max - 1
          oldindex = @index
          @index += 1
          if @index != oldindex
            update_cursor_rect
          end
        end
      elsif Input.repeat?(Input::L)
        if self.index > 0
          oldindex = @index
          @index = [self.index-self.page_item_max, 0].max
          if @index != oldindex
            self.top_row -= self.page_row_max
            update_cursor_rect
          end
        end
      elsif Input.repeat?(Input::R)
        if self.index < @item_max-1
          oldindex = @index
          @index = [self.index+self.page_item_max, @item_max-1].min
          if @index != oldindex
            self.top_row += self.page_row_max
            update_cursor_rect
          end
        end
      end
    end
  end
end

# A version of Window_DrawableCommand that does not have any animated arrows.
# Also, the cursor is disabled by default, and can be set with the setCursor command.
class Window_DrawableCommand_Console < SpriteWindow_Selectable_Console
  attr_reader :baseColor
  attr_reader :shadowColor

  def textWidth(bitmap,text)
    return tmpbitmap.text_size(i).width
  end

  def getAutoDims(commands,dims,width=nil)
    rowMax = ((commands.length + self.columns - 1) / self.columns).to_i
    windowheight = (rowMax*self.rowHeight)
    windowheight += self.borderY
    if !width || width<0
      width=0
      tmpbitmap = BitmapWrapper.new(1,1)
      pbSetSystemFont(tmpbitmap)
      for i in commands
        width = [width,tmpbitmap.text_size(i).width].max
      end
      width += 16+SpriteWindow_Base::TEXTPADDING
      width += 16 if self.hasCursor?
      tmpbitmap.dispose
    end
    # Store suggested width and height of window
    dims[0] = [self.borderX+1,(width*self.columns)+self.borderX+
        (self.columns-1)*self.columnSpacing].max
    dims[1] = [self.borderY+1,windowheight].max
    dims[1] = [dims[1],Graphics.height].min
  end

  def initialize(x,y,width,height,viewport=nil)
    super(x,y,width,height)
    self.viewport = viewport if viewport
    @index = 0
    colors = getDefaultTextColors(self.windowskin)
    @baseColor   = colors[0]
    @shadowColor = colors[1]
    refresh
  end

  def setCursor(filepath)
    @selarrow.dispose unless @selarrow.disposed?
    @selarrow = AnimatedBitmap.new(filepath)
    refresh
  end

  def hasCursor?
    return !(@selarrow.nil? || @selarrow.disposed?)
  end

  def drawCursor(index,rect)
    if self.index==index && !@selarrow.nil?
      pbCopyBitmap(self.contents,@selarrow.bitmap,rect.x,rect.y)
      extra_width = 16
    else
      extra_width = 0
    end
    return Rect.new(rect.x+extra_width,rect.y,rect.width-extra_width,rect.height)
  end

  def dispose
    @selarrow.dispose if !@selarrow.nil? && !@selarrow.disposed?
    super
  end

  def baseColor=(value)
    @baseColor = value
    refresh
  end

  def shadowColor=(value)
    @shadowColor = value
    refresh
  end

  def itemCount # to be implemented by derived classes
    return 0
  end

  def drawItem(index,count,rect) # to be implemented by derived classes
  end

  def refresh
    @item_max = self.itemCount
    dwidth  = self.width - self.borderX
    dheight = self.height - self.borderY
    self.contents = pbDoEnsureBitmap(self.contents,dwidth,dheight)
    self.contents.clear
    for i in 0...@item_max
      if i<self.top_item || i>self.top_item+self.page_item_max
        next
      end
      drawItem(i,@item_max,itemRect(i))
    end
  end

  def update
    oldindex = self.index
    super
    refresh if self.index!=oldindex
  end
end

class Window_CommandConsole < Window_DrawableCommand_Console
  attr_reader :commands

  # Creates a new Window_CommandConsole object.
  # @param window [ApplicationWindow] window to bind to
  # @param choices [*String] window choices
  def initialize(window,*choices)
    @window = window
    @starting = true
    super(0,0,32,32)
    self.viewport = @window.viewport
    self.width = @window.width
    self.height = @window.height
    @commands = list_filter(choices)
    self.active = true
    self.windowskin = nil
    self.baseColor = @window.textColor
    self.shadowColor = nil
    self.contents.font.name = @window.fontName
    self.contents.font.size = 20
    refresh
    @starting = false
  end

  # Changes the command window's choices.
  # @param choices [Array<String>] new choices
  def setChoices(*choices)
    self.commands = list_filter(choices)
  end

  def index=(value)
    super
    refresh if !@starting
  end

  def commands=(value)
    @commands = value
    @item_max = commands.length
    self.update_cursor_rect
    self.refresh
  end

  def width=(value)
    super
    unless @starting
      self.index = self.index
      self.update_cursor_rect
    end
  end

  def height=(value)
    super
    unless @starting
      self.index = self.index
      self.update_cursor_rect
    end
  end

  def itemCount
    return @commands ? @commands.length : 0
  end

  def drawItem(index,count,rect)
    rect = drawCursor(index,rect)
    if index == self.index
      self.contents.fill_rect(rect,@window.textColor)
      text_col = @window.bgColor
    else
      text_col = @window.textColor
    end
    pbDrawShadowText(self.contents,rect.x,rect.y,rect.width,rect.height,@commands[index],text_col,self.shadowColor)
  end

  private

  # Takes the array of strings that was passed into the class's constructor, and
  # returns a new, formatted array of strings.
  # This function should be overwritten by subclasses, if necessary.
  # @param choices [Array<String>] passed choices
  # @return [Array<String>] formatted choices
  def list_filter(choices)
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

class ConsoleCommand_Exampleapp < ConsoleCommand
  name 'exampleapp'

  def main(args)
    ConsoleApplication_Example.new
    return 0
  end
end

class ConsoleApplication_Example < ConsoleApplication
  name 'example_app'
  force_default_config

  def app_start
    @list_window = ApplicationWindow.new(self,Graphics.width/2-98,Graphics.height/2-128,196,160)
    @list_window.drawBorder(2)
    @list = Window_CommandConsole.new(@list_window,_INTL('Start game'),_INTL('Continue'),_INTL('Options'),_INTL('Exit'))
    @msg_window = ApplicationWindow.new(self,Graphics.width/2-90,Graphics.height-160,180,160)
  end

  def app_main
    loop do
      Graphics.update
      Input.update
      @list.update
      next unless Input.trigger?(Input::C)
      case @list.index
      when 0
        @msg_window.print('Start game was pressed!\n')
      when 1
        @msg_window.print('Continue was pressed!\n')
      when 2
        @msg_window.print('Options was pressed!\n')
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