#==============================================================================#
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■ SHELL AS A SERVICE ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ #
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ COMMANDS ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ #
#==============================================================================#

# Echoes the given input.
class ConsoleCommand_Echo < ConsoleCommand
  name          'echo'
  description   _INTL('Echo the given input.')
  manual_desc   _INTL('Echoes the given input with optional alignment:\n0: left, 1: center, 2: right.')
  argument      '*s', _INTL('text')
  option        'i', :@align, _INTL('changes the alignment'), '--align', '-a'
  option        'x', :@raw, _INTL('doesn\'t parse special codes'), '--raw', '-r'
  option        'x', :@no_newline, _INTL('omits the trailing newline'), '-n'
  aliases       'print'

  def main(args)
    @align ||= 0
    @raw ||= false
    validate_range 0..2, @align
    error _INTL('nothing to echo') if args.empty?
    print args.join(' '), @align, @raw
    print '\n' if @no_newline.nil?
    return 0
  end
end

# A tool for viewing and setting aliases.
class ConsoleCommand_Alias < ConsoleCommand
  name          'alias'
  description   _INTL('View and modify aliases.')
  manual_desc   _INTL('Views or modifies aliases. If no alias name\nis passed, lists all aliases.')
  argument      's', _INTL('alias name'), :optional
  argument      's', _INTL('aliased string'), :optional
  
  def main(args)
    if args.empty? # No arguments: list aliases
      @session.aliases.each do |name,str|
        print_raw _INTL("'{1}' => '{2}'",name,str)
        println ''
      end
    elsif args[1] # Aliased string exists
      # Can't create alias called "alias"
      if args[0] == self.name
        error _INTL("cannot use name '{1}'",self.name)
      end
      # Can't use an empty string as name
      if args[0].empty?
        error _INTL('name cannot be empty')
      end
      # Alias name can not contain && or ;
      if args[0].match(/&&|;/)
        error _INTL('{1} in alias name',$~[0])
      end
      operation = (@session.aliases.has_key?(args[0])) ? 
                  _INTL('Overwrite') : _INTL('Set')
      print_raw _INTL("{1} '{2}' to '{3}'?",operation,args[0],args[1])
      return 1 unless self.confirm?
      @session.set_alias(args[0],args[1])
    else # Only alias name was given
      if @session.aliases.has_key?(args[0])
        print_raw _INTL("'{1}' => '{2}'",args[0],@session.aliases[args[0]])
        println ''
      else
        error _INTL("no alias set for '{1}'",args[0])
      end
    end
    return 0
  end
end

# A tool for removing aliases.
class ConsoleCommand_Unalias < ConsoleCommand
  name          'unalias'
  description   _INTL('Remove aliases.')
  manual_desc   _INTL('Removes the given alias.')
  argument      's', _INTL('alias name')
  option        'x', :@force, _INTL('skip confirmation'), '--force', '-f'
  
  def main(args)
    error _INTL('no alias given') if args.empty?
    if @session.aliases.has_key? args[0]
      # Don't ask for confirmation if the --force option is set
      unless @force
        print_raw _INTL("'{1}' => '{2}'",args[0],@session.aliases[args[0]])
        println ''
        return 1 unless self.confirm?(_INTL('Delete this alias?'))
      end
      @session.unset_alias(args[0])
    else
      error _INTL("no alias set for '{1}'",args[0])
    end
    return 0
  end
end

# Allows for paging through text.
class ConsoleCommand_More < ConsoleCommand
  name          'more'
  description   _INTL('Filter for paging through text.')
  manual_desc   _INTL('Offers a filter for paging through text one\nscreenful at a time.')
  argument      '*s', _INTL('text')
  
  def main(args)
    error _INTL('no string given') if args.empty?
    ConsoleApplication_More.new(args.join(" "))
  end
end

# The separate console session launched when running more.
class ConsoleApplication_More < ConsoleSession
  name  'more'
  
  def initialize(text)
    text.gsub!('\n',"\n") # this wouldn't be necessary if i didn't suck
    @text_lines = text.split("\n")
    super()
  end
  
  def main
    # Show up to 16 lines at once
    [16,@text_lines.length].min.times do
      println @text_lines[0]
      @text_lines.delete_at(0)
    end
    @text_lines.empty? ? show_quit : show_continue
    # Go through the rest of the text
    loop do
      Graphics.update
      Input.update
      if (@text_lines.empty? && Input.triggerex?(0x0D)) ||
         (!@text_lines.empty? && (Input.triggerex?(0x0D) || Input.repeatex?(0x0D)))
        break if @text_lines.empty?
        replace @text_lines[0] + '\n'
        @text_lines.delete_at(0)
        @text_lines.empty? ? show_quit : show_continue
      elsif Input.triggerex?(0x11) && Input.triggerex?(0x43) # CTRL + C
        break
      elsif Input.triggerex?(0x51) # Q
        break
      end
    end
    self.exit_session
  end
  
  def show_continue
    self.replace(_INTL('--- ENTER ---'))
  end
  
  def show_quit
    self.print(_INTL('--- PRESS ENTER OR Q TO QUIT ---'))
  end
end

# Waits for the specified amount of time.
class ConsoleCommand_Sleep < ConsoleCommand
  name          'sleep'
  description   _INTL('Sleep for x seconds.')
  manual_desc   _INTL('Sleeps for the given duration.')
  argument      'i', _INTL('duration')
  
  def main(args)
    duration = validate_value 'i', args[0]
    if duration < 0
      error _INTL('can not sleep for a negative duration')
    end
    wait Graphics.frame_rate * duration
    return 0
  end
end

# Asks for confirmation. Used in various other commands & applications.
# Can be accessed by the shorthand #confirm?(text) in ConsoleCommand.
class ConsoleCommand_Confirm < ConsoleCommand
  name          'confirm'
  description   _INTL('Confirm a choice.')
  manual_desc   _INTL('Asks for confirmation. Used by other programs.')
  argument      '*s', _INTL('text'), :optional
  
  def main(args)
    ret = 1
    print args.join(" ") unless args.empty?
    print _INTL(' (y/n) ')
    println "" if @session.window.lines.last.text_width > Graphics.width - 100
    input = @session.await_input(false)
    ret = 0 if ['true','yes','y'].include?(input.downcase)
    return ret
  end
end

# Shows all available commands or a manual page of a single command.
class ConsoleCommand_Help < ConsoleCommand
  name          'help'
  description   _INTL('Show help information.')
  manual_desc   _INTL('If a command name is passed as the argument,\nshows its help page. Otherwise lists all\navailable commands.')
  argument      's', _INTL('command'), :optional
  aliases       'man'
  
  def main(args)
    if args.empty?
      # If no arguments were passed, display a list of commands
      txt = _INTL('\hSHELL AS A SERVICE COMMANDS\nView individual help with \'help [command]\'\n')
      @session.commands.each_value do |command|
        txt += _INTL('\n{1}: {2}',command.name,command.description)
      end
      if @session.commands.length > 13
        run_cmd 'more ' + txt
      else
        println txt
      end
    elsif @session.commands.include?(args[0])
      # If the argument is a name of a command, show its manual
      @session.command(args[0]).show_manual
    elsif @session.aliases.has_key?(args[0]) &&
          @session.commands.include?(@session.aliases[args[0]])
      # Show the manual of the alias
      cmd = @session.aliases[args[0]]
      print_raw _INTL('{1} is an alias of {2}:',args[0],cmd)
      println ''
      @session.command(cmd).show_manual
    else
      error _INTL('command not found: {1}',args[0])
    end
    return 0
  end
end

class ConsoleCommand_Clear < ConsoleCommand
  name          'clear'
  description   _INTL('Clears the screen.')
  
  # Clears the screen.
  def main(args)
    @session.window.clear
    return 0
  end
end

# Changes the background color.
class ConsoleCommand_Bgcol < ConsoleCommand
  name          'bgcol'
  description   _INTL('Change the background color.')
  manual_desc   _INTL('Changes the background color.')
  argument      'i', _INTL('red')
  argument      'i', _INTL('green')
  argument      'i', _INTL('blue')
  
  def main(args)
    validate_values 'i', args, 0, 1, 2
    validate_range 0..255, args[0], args[1], args[2]
    @session.window.change_bg_color(Color.new(args[0],args[1],args[2]))
    return 0
  end
end

# Changes the text color.
class ConsoleCommand_Txtcol < ConsoleCommand
  name          'txtcol'
  description   _INTL('Change the text color.')
  manual_desc   _INTL('Changes the text color.')
  argument      'i', _INTL('red')
  argument      'i', _INTL('green')
  argument      'i', _INTL('blue')
  
  def main(args)
    validate_values 'i', args, 0, 1, 2
    validate_range 0..255, args[0], args[1], args[2]
    @session.window.change_text_color(Color.new(args[0],args[1],args[2]))
    return 0
  end
end

# A utility for modifying and switching shell configurations.
class ConsoleCommand_Config < ConsoleCommand
  name          'config'
  description   _INTL('Save, load and view shell configurations.')
  manual_desc   _INTL('Application for modifying and loading shell\nconfigurations. \'list\' and \'active\' don\'t\nrequire an additional argument.')
  argument      's', _INTL('subcommand')
  argument      's', _INTL('config name'), :optional
  option        'x', :@force, _INTL('skip confirmation'), '--force', '-f'
  subcommand    'load',  _INTL('load a configuration'),         :load_command
  subcommand    'save',  _INTL('save a configuration'),         :save_command
  subcommand    'delete',_INTL('delete a configuration'),       :delete_command
  subcommand    'list',  _INTL('list all saved configurations'),:list_command
  subcommand    'active',_INTL('view the active configuration'),:active_command
  
  def main(args)
    ret = 1
    if is_subcommand?(args[0])
      ret = parse_subcommands(args)
    else
      show_manual
    end
    return ret
  end

  def load_command(args)
    if args[0].nil?
      error _INTL('no config specified')
    elsif $ShellOptions.shellConfigs.has_key?(args[0])
      config = $ShellOptions.shellConfigs[args[0]]
      unless @force
        println conf_info(config)
        return 1 unless self.confirm?(_INTL('Load config {1}?',config.name))
      end
      @session.switch_config(config)
    else
      error _INTL('config {1} not found',args[0])
    end
    return 0
  end
  
  def save_command(args)
    if args[0].nil?
      error _INTL('no config specified')
    else
      # Remove control codes from config names
      name = args[0].gsub(/\\[nht]/,'')
      config = ShellConfiguration.newFromSession(name,@session)
      unless @force
        # Confirm save if the --force option is not passed
        println conf_info(config)
        operation = $ShellOptions.shellConfigs.has_key?(name) ?
                    _INTL('Overwrite') : _INTL('Save')
        return 1 unless self.confirm?(_INTL('{1} config {2}?',operation,name))
      end
      save_conf(name,config)
      unless @session.config.name == name
        # Prompt to switch to the newly created config
        if self.confirm?(_INTL('Switch to {1}?',name))
          @session.switch_config(config)
        end
      end
    end
    return 0
  end
  
  def delete_command(args)
    if args[0].nil?
      error _INTL('no config specified')
    elsif args[0] == 'default'
      error _INTL("can't delete default config")
    elsif $ShellOptions.shellConfigs.has_key?(args[0])
      config = $ShellOptions.shellConfigs[args[0]]
      unless @force
        # Confirm deletion if --force option is not passed
        println conf_info(config)
        return 1 unless self.confirm?(_INTL('Delete config {1}?',args[0]))
      end
      delete_conf(config)
    else
      error _INTL('config {1} not found',args[0])
    end
    return 0
  end

  def list_command(args)
    if $ShellOptions.shellConfigs.empty?
      println _INTL('There are no saved configurations')
    else
      if $ShellOptions.shellConfigs.length < 4
        $ShellOptions.shellConfigs.each_value { |config| println conf_info(config) }
      else
        txt = _INTL('SAVED CONFIGURATIONS')
        $ShellOptions.shellConfigs.each_value do |config|
          txt += '\n' + conf_info(config)
        end
        ConsoleApplication_More.new(txt)
      end
    end
    return 0
  end
  
  def active_command(args)
    println conf_info($ShellOptions.shellConfigs[$ShellOptions.activeConfig])
    return 0
  end

  # Prints the information of the given shell configuration.
  # @param config [ShellConfiguration] config to show info of
  def conf_info(config)
    bc = config.bgColor
    tc = config.textColor
    txt = config.name
    if config.active?
      txt += _INTL(' [ACTIVE]\n')
    else
      txt += '\n'
    end
    txt += _INTL('\tBackground color  {1}, {2}, {3}\n',bc.red,bc.green,bc.blue)
    txt += _INTL('\tText color        {1}, {2}, {3}\n',tc.red,tc.green,tc.blue)
    txt += _INTL('\tFont name         {1}\n',config.fontName)
    txt += _INTL('\tPrompt            \'{1}\'',config.prompt)
    return txt
  end
  
  def save_conf(name,config)
    $ShellOptions.shellConfigs[name] = config
  end
  
  def delete_conf(config)
    if config.active?
      $ShellOptions.shellConfigs['default'].activate
      println _INTL('The default config was set as active.')
    end
    $ShellOptions.shellConfigs.delete(config.name)
  end
end

# Changes the font used in the shell.
class ConsoleCommand_Setfont < ConsoleCommand
  name          'setfont'
  description   _INTL('Change the font.')
  manual_desc   _INTL('Changes the font.')
  argument      '*s', _INTL('font name')
  
  def main(args)
    error _INTL('no font name given') if args.empty?
    font = args.join(" ")
    unless Font.exist?(font)
      error _INTL('font {1} doesn\'t exist',font)
    end
    @session.window.change_font_name(font)
    return 0
  end
end

# Prints out version information.
class ConsoleCommand_Version < ConsoleCommand
  name          'version'
  description   _INTL('Show version information.')
  manual_desc   _INTL('Prints the version of SAAS, Pokémon Essentials\nand Ruby.')

  def main(args)
    print     _INTL('Shell As A Service')
    println   SHELL_VERSION.to_s, 2
    print     _INTL('Pokémon Essentials')
    if defined?(ESSENTIALSVERSION)
      println ESSENTIALSVERSION, 2
    else
      println _INTL('something old'), 2
    end
    print     _INTL('Ruby')
    print     RUBY_VERSION, 2
    if $MKXP
      print   sprintf('-p%s', RUBY_PATCHLEVEL), 2
    end
    println   sprintf(' (%s)', RUBY_PLATFORM), 2
    return 0
  end
end

# Reboots the game.
class ConsoleCommand_Reboot < ConsoleCommand
  name          'reboot'
  option        'x', :@force, _INTL('skip confirmation'), '--force', '-f'
  description   _INTL('Reboot the system.')
  manual_desc   _INTL('Reboots the system.')
  
  def main(args)
    if @force || self.confirm?(_INTL('Reboot the system?'))
      println _INTL('Rebooting system...')
      wait 60
      SAASUtils.reboot
    end
    return 1
  end
end

# Shuts the game down.
class ConsoleCommand_Poweroff < ConsoleCommand
  name          'poweroff'
  option        'x', :@force, _INTL('skip confirmation'), '--force', '-f'
  description   _INTL('Power the system off.')
  manual_desc   _INTL('Powers the system off.')
  
  def main(args)
    if @force || self.confirm?(_INTL('Power off the system?'))
      println _INTL('Powering off...')
      wait 60
      exit
    end
    return 1
  end
end

# Raises ConsoleExit.
class ConsoleCommand_Exit < ConsoleCommand
  name          'exit'
  description   _INTL('Exit the shell.')
  manual_desc   _INTL('Exits the shell.')
  
  def main(args)
    raise ConsoleExit
  end
end

# Evaluates code.
class ConsoleCommand_Eval < ConsoleCommand
  name          'eval'
  argument      '*s', _INTL('code')
  description   _INTL('Evaluate code.')
  manual_desc   _INTL('Evaluates the given code.')
  option        'x', :@top, _INTL('use top level binding'), '--top', '-t'
  option        'x', :@omit,_INTL('omit returned value'),   '--omit','-o'
  debug_only
  
  def main(args)
    error _INTL('no code given') if args.empty?
    begin
      if @top
        ret = eval(args.join(" "), TOPLEVEL_BINDING)
      else
        ret = eval(args.join(" "))
      end
    rescue Exception => e
      Kernel.print(e.message)
      error _INTL('{1} raised',e.class)
    end
    println '=> ' + ret.inspect if @omit.nil?
    return 0
  end
end

# Evaluate multi-line code.
class ConsoleCommand_Multieval < ConsoleCommand
  name          'multieval'
  description   _INTL('Evaluate multi-line code.')
  manual_desc   _INTL('Evaluates the given multi-line code. Top level\nbinding is always used.')
  option        'x', :@omit,_INTL('omit returned value'), '--omit', '-o'
  debug_only
  
  def main(args)
    println _INTL("You've entered multiline eval. Exit with CTRL + C.")
    input = ""
    # Start building the input
    begin
      loop do
        input += @session.await_input(false,false) + ';'
      end
    rescue ConsoleInterrupt
      # ignored
    end
    error _INTL('no code given') if input.delete(';').strip.empty?
    # Ask for confirmation, then run the code
    return 1 unless confirm? _INTL('Run the given code?')
    begin
      ret = eval(input, TOPLEVEL_BINDING)
    rescue Exception => e
      Kernel.print(e.message)
      error _INTL('{1} raised',e.class)
    end
    println '=> ' + ret.inspect if @omit.nil?
    return 0
  end
end

# Changes the command prompt.
class ConsoleCommand_Setprompt < ConsoleCommand
  name          'setprompt'
  argument      's', _INTL('new prompt')
  description   _INTL('Change the command prompt.')
  manual_desc   _INTL('Changes the command prompt.')
  
  def main(args)
    error _INTL('no prompt given') unless args[0]
    prompt = args[0].gsub(/\\[nht]/,'')
    @session.set_prompt(prompt)
    return 0
  end
end

# Compile PBS files
class ConsoleCommand_Compile < ConsoleCommand
  name          'compile'
  description   _INTL('Compile all data.')
  manual_desc   _INTL('If --essentials and --marin flags are not\ngiven, compiles all data. Otherwise only compiles\nthe specified data.')
  option        'x',:@essentials,_INTL('compile Essentials PBS only'),'--essentials','-e'
  option        'x',:@marin,_INTL('compile MarinCompiler PBS only'),'--marin','-m'
  option        'x',:@reboot,_INTL('reboot after compilation'),'--reboot','-r'
  option        'x',:@poweroff,_INTL('poweroff after compilation'),'--poweroff','-p'
  option        'x',:@silent,_INTL('compile silently'),'--silent','-s'
  debug_only
  
  def main(args)
    if !@essentials && !@marin
      @essentials = true
      @marin = true
    end
    # Compile Essentials PBS files
    if @essentials
      pbCompileAllData(true) do |msg|
        unless @silent
          replace msg
          Graphics.update
        end
      end
      replace _INTL('Essentials data compiled.\n') unless @silent
    end
    # Compile MarinCompiler PBS files
    if @marin
      unless defined?(MarinCompiler)
        error _INTL('MarinCompiler not found')
      end
      unless @silent
        println _INTL('Compiling MarinCompiler PBS files...')
        Graphics.update
      end
      MarinCompiler.compile_where_necessary(true)
    end    
    # Reboot or poweroff if necessary
    run_cmd 'reboot -f' if @reboot
    run_cmd 'poweroff -f' if @poweroff
    return 0
  end
end

class ConsoleCommand_Exportmap < ConsoleCommand
  name          'exportmap'
  description   _INTL('Export the given map as an image.')
  manual_desc   _INTL('Exports the given map as an image to the\nSavedMaps folder. Accepts map ids and names.\nThe --player and --events options can be set to\ninclude them in the image. They only work\nwhile in the map scene. Requires MarinMapExporter.')
  argument      'i', _INTL('map id'), :optional
  argument      's', _INTL('map name'), :optional
  option        'x',:@events,_INTL('display events'),'--events','-e'
  option        'x',:@player,_INTL('display player'),'--player','-p'
  debug_only
  
  def main(args)
    unless defined?(ExportedMapFilename)
      error _INTL('MarinMapExporter not found')
    end
    error _INTL('no map id/name given') if args.empty?
    # Set up the options. They only work in-game
    opts = []
    if $scene.is_a?(Scene_Map)
      opts << :events if @events
      opts << :player if @player
    end
    # Load mapinfo data
    map_infos = load_data("Data/MapInfos.rxdata")
    # Get the map id
    if value_is_integer? args[0]
      map_id = args[0].to_i
      unless map_infos.has_key? map_id
        error _INTL('unknown map id {1}',map_id)
      end
    else
      # find returns an array [key,value], so we can use info[0] later
      info = map_infos.find { |_,infos| infos.name == args[0] }
      if info.nil?
        error _INTL('unknown map name {1}',args[0])
      end
      map_id = info[0]
    end
    pbExportMap(map_id,opts)
    println _INTL('exported map {1} (id {2})',map_infos[map_id].name,map_id)
  end
end

class ConsoleCommand_Sysinfo < ConsoleCommand
  name        'sysinfo'
  description _INTL('Print information about your system.')
  manual_desc _INTL('Prints various bits of information about\nyour system, like platform, locale and\navailable memory.')
  mkxp_only

  def main(args)
    print _INTL('Platform')
    println System.platform, 2
    print _INTL('Locale')
    println System.user_language, 2
    print _INTL('Processor threads')
    println System.nproc.to_s, 2
    print _INTL('Available memory')
    println sprintf('%d MB', System.memory), 2
    # Print power state values
    if System.power_state.values.any? { |value| !value.nil? }
      print _INTL('Power state')
      unless System.power_state[:percent].nil?
        print sprintf('%d%%',System.power_state[:percent]), 2
      end
      if System.power_state[:discharging] == false
        if System.power_state[:seconds].nil?
          print _INTL(' Connected to power'), 2
        else
          t = Timer.new(System.power_state[:seconds])
          print sprintf(' Charging, %s', t.formatRemaining), 2
        end
      end
      println '', 2
    end
    return 0
  end
end