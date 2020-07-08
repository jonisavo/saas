#==============================================================================#
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■ SHELL AS A SERVICE ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ #
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ RESTORETOOL ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ #
#==============================================================================#
# The Restoretool is a special console application for making backups and
# restoring them. It has its own session class and is only accessible
# when booting up the game.

class ConsoleCommand_Restoretool < ConsoleCommand
  name          'restoretool'
  description   _INTL('Application for restoring save data.')
  manual_desc   _INTL('A console application for restoring and\nbacking up save and system data.')
  outside_game
  
  def main(args)
    ConsoleApplication_Restoretool.new
    return 0
  end
end

class ConsoleApplication_Restoretool < ConsoleSession
  name  'restoretool'
  
  def initialize
    @viewport = Viewport.new(0,0,Graphics.width,Graphics.height)
    @viewport.z = 99999
    # Get the active config. If none is found, use the default config.
    if !$ShellOptions.activeConfig || !$ShellOptions.shellConfigs.has_key?($ShellOptions.activeConfig)
      $ShellOptions.shellConfigs['default'] ||= ShellConfiguration.newDefault
      $ShellOptions.activeConfig = 'default'
    end
    @config = $ShellOptions.shellConfigs[$ShellOptions.activeConfig]
    # Create the console window and set the available commands.
    @window = ConsoleWindow.new(self,0,CONSOLE_LINE_HEIGHT*8,Graphics.width,Graphics.height-CONSOLE_LINE_HEIGHT*8)
    @info_window = ConsoleWindow.new(self,0,0,Graphics.width,CONSOLE_LINE_HEIGHT*8)
    @prompt = 'restoretool> '
    @aliases = {}
    @commands = {}
    self.set_commands
    @history = []
    @context = nil
    @restart = false
    self.main
  end
  
  def main
    # Write the static text onto the info window
    @info_window.print '\n'
    @info_window.print _INTL('\t######################\n')
    @info_window.print _INTL('\t# SHELL AS A SERVICE #\n')
    @info_window.print _INTL('\t# RESTORETOOL   v1.0 #\n')
    @info_window.print _INTL('\t######################\n')
    @info_window.print _INTL('\tType \'help\' to get help\n')
    @info_window.lines[1].write(_INTL('Save data         '), 2, true)
    @info_window.lines[3].write(_INTL('Backup files      '), 2, true)
    self.update_status
    super
  end
  
  # (see ConsoleSession#process)
  # A status update is done every time a command is processed.
  def process(input,parse_aliases=false)
    ret = super(input,parse_aliases)
    self.update_status
    return ret
  end
  
  # Rewrites various parts of the info window depending on the status
  # of the user's save data.
  def update_status
    # Get save data status
    if save_data?
      @info_window.lines[2].replace(_INTL('Found           '), 2)
    elsif save_backup?
      @info_window.lines[2].replace(_INTL('Can restore     '), 2)
    else
      @info_window.lines[2].replace(_INTL('Not found       '), 2)
    end
    # Get backup status
    if save_backup?
      @info_window.lines[4].replace(_INTL('Found           '), 2)
    else
      @info_window.lines[4].replace(_INTL('Not found       '), 2)
    end
    # Check whether the game should be restarted
    if @restart
      @info_window.lines[5].replace(_INTL('   Type \'exit\' to restart'))
    end
  end
  
  # Returns whether save data exists.
  # @return [Boolean] save data exists?
  def save_data?
    return safeExists?(RTP.getSaveFileName("Game.rxdata"))
  end
  
  # Returns whether backup files exist.
  # @return [Boolean] backup files exist?
  def save_backup?
    return Dir.get_files("SaveBackup/").map {
      |file| file.ends_with?(".rxdata")
    }.length > 0
  end
         
  # Ensures the game will restart upon exiting the session
  def enable_restart
    println _INTL('Changes have been made: the game must restart')
    @restart = true
  end
  
  # Returns whether the game must restart upon exiting the session
  # @return [Boolean] game must restart?
  def must_restart?
    return @restart
  end
  
  def exit_session
    super
    @info_window.dispose
  end
  
  # In addition to console commands with session set to 'restoretool',
  # the restoretool includes the clear and confirm commands.
  def set_commands
    super
    @commands['clear']    = ConsoleCommand_Clear.new(self)
    @commands['confirm']  = ConsoleCommand_Confirm.new(self)
  end
end

# Exits restoretool and restarts the game if necessary.
class RestoretoolCommand_Exit < ConsoleCommand
  session       'restoretool'
  name          'exit'
  description   _INTL('Exit restoretool.')
  manual_desc   _INTL('Exits restoretool. If changes to save or\nsystem data have been made, restarts the game.')
  
  def main(args)
    if @session.must_restart?
      println _INTL('Restarting...')
      wait 80
      SAASUtils.reboot
    else
      if !@session.save_data? && @session.save_backup?
        println _INTL('Save data was not found, but backups exist.')
        return 1 unless self.confirm? _INTL('Exit anyway?')
      end
      raise ConsoleExit
    end
    return 0
  end
end

# Restoretool's help command doesn't check for aliases or use 'more'.
class RestoretoolCommand_Help < ConsoleCommand
  session       'restoretool'
  name          'help'
  description   _INTL('Show help information.')
  manual_desc   _INTL('If a command name is passed as the argument,\nshows its help page. Otherwise lists all\navailable commands.')
  argument      's', _INTL('command'), :optional
  
  def main(args)
    if args.empty?
      # If no arguments were passed, display a list of commands
      println _INTL('\hRESTORETOOL COMMANDS')
      @session.commands.each_value do |command|
        print command.name
        println command.description, 2
      end
      println _INTL('View individual help with \'help [command]\'')
    elsif @session.commands.include?(args[0])
      # If the argument is a name of a command, show its manual
      @session.command(args[0]).show_manual
    else
      error _INTL('command not found: {1}',args[0])
    end
    return 0
  end
end

# A command for creating backups into SaveBackup.
class RestoretoolCommand_Backup < ConsoleCommand
  session       'restoretool'
  name          'backup'
  description   _INTL('Create a new backup.')
  manual_desc   _INTL('Creates a new backup and puts it in the\nSaveBackup folder. If the backup name is omitted,\nthe user is prompted to give one.')
  argument      '*s', _INTL('backup name'), :optional
  
  def main(args)
    error _INTL('save data not found') unless @session.save_data?
    Dir.create('SaveBackup')
    if args.empty?
      print _INTL('Backup name: ')
      name = @session.await_input(false,false)
      error _INTL('no name given') if name.strip.empty?
    else
      name = args.join(' ')
    end
    begin
      File.open(RTP.getSaveFileName('Game.rxdata'),  'rb') do |r|
        File.open("SaveBackup\\#{name}.rxdata", 'wb') do |w|
          while s = r.read(4096)
            w.write s
          end
        end
      end
    rescue Exception => e
      p e.message
      error _INTL('error encountered')
    end
    return 0
  end
end

# A command for restoring save and system data.
class RestoretoolCommand_Restore < ConsoleCommand
  session       'restoretool'
  name          'restore'
  description   _INTL('Restore save and system data.')
  manual_desc   _INTL('Restores save and system data from various\nbackups. If the backup name is omitted, the user\nis prompted to select the backup to restore.')
  argument      '*s', _INTL('backup name'), :optional
  
  def main(args)
    unless @session.save_backup?
      error _INTL('no save data backups found')
    end
    if args.empty?
      location = get_restore_location
      return 1 if location.nil?
    else
      location = 'SaveBackup/' + args.join(' ') + '.rxdata'
      unless File.file?(location)
        error _INTL('backup {1} not found',location)
      end
    end
    begin
      File.open(location,  'rb') {|r|
        File.open(RTP.getSaveFileName('Game.rxdata'), 'wb') {|w|
          while s = r.read(4096)
            w.write s
          end
        }
      }
    rescue Exception => e
      p e.message
      error _INTL('error encountered')
    end
    @session.enable_restart
    return 0
  end
  
  # Asks for a backup to load and returns its file path.
  # @param system_data [Boolean] whether we're restoring system data
  # @return [String] backup file path
  def get_restore_location
    backups = Dir.get_files('SaveBackup/').select do |file| 
      file.ends_with?('.rxdata')
    end
    println _INTL('Restore save data from which backup?') if backups.length > 1
    if backups.length == 1
      print_backup_info(0,backups[0])
      return nil unless self.confirm? _INTL('Load this backup?')
      return backups[0]
    else
      backups.each_with_index { |path,i| print_backup_info(i+1,path) }
      print _INTL('Load backup 1-{1}: ',backups.length)
      input = validate_value 'i', @session.await_input(false,false)
      validate_range 1..backups.length, input
      return backups[input-1]
    end
  end
  
  # Prints the size and modification date of the given backup.
  # @param id [Integer] backup id (0 if it should be omitted)
  # @param path [String] backup file path
  def print_backup_info(id,path)
    mtime = nil
    size = nil
    File.open(path, 'rb') do |f|
      mtime = f.stat.mtime.strftime("%m/%d/%Y %I:%M%p")
      size = f.stat.size
    end
    name = File.basename(path,'.rxdata')
    name = "#{id}: #{name}" if id > 0
    println _INTL('{1} ({2}kb) {3}',name, size/1000, mtime)
  end
end