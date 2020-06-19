#==============================================================================#
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■ SHELL AS A SERVICE ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ #
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ WIPETOOL ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ #
#==============================================================================#
# The rm -rf of Shell as a Service

class ConsoleCommand_Wipetool < ConsoleCommand
  name          'wipetool'
  description   _INTL('Application for removing save data.')
  manual_desc   _INTL('A console application for removing save data.')
  outside_game
  
  def main(args)
    ConsoleApplication_Wipetool.new
    return 0
  end
end

class ConsoleApplication_Wipetool < ConsoleSession
  name  'wipetool'
  
  def initialize
    @viewport = Viewport.new(0,CONSOLE_LINE_HEIGHT*13,Graphics.width,Graphics.height-CONSOLE_LINE_HEIGHT*13)
    @viewport.z = 99999
    @info_port = Viewport.new(0, 0, Graphics.width, CONSOLE_LINE_HEIGHT*13)
    @info_port.z = 99999
    # Get the active config. If none is found, use the default config.
    if !$ShellOptions.activeConfig || !$ShellOptions.shellConfigs.has_key?($ShellOptions.activeConfig)
      $ShellOptions.shellConfigs['default'] ||= ShellConfiguration.newDefault
      $ShellOptions.activeConfig = 'default'
    end
    @config = $ShellOptions.shellConfigs[$ShellOptions.activeConfig]
    # Create the console window and set the available commands.
    @window = ConsoleWindow.new(self,@viewport)
    @info_window = ConsoleWindow.new(self, @info_port)
    @prompt = 'wipetool> '
    @aliases = {}
    @commands = {}
    self.set_commands
    @history = []
    @context = nil
    @must_reset = false
    self.main
  end
  
  def main
    # Write the static text onto the info window
    @info_window.print '\n' * 4
    @info_window.print _INTL('######################\n'), 1
    @info_window.print _INTL('# SHELL AS A SERVICE #\n'), 1
    @info_window.print _INTL('# WIPETOOL      v1.0 #\n'), 1
    @info_window.print _INTL('######################\n'), 1
    @info_window.print _INTL('Type \'exit\' to leave\n'), 1
    @info_window.print _INTL('or \'wipe\' to begin deletion\n'), 1
    super
    SAASUtils.reboot if @must_reset
  end
  
  # (see ConsoleSession#process)
  def process(input,parse_aliases=false)
    return super(input,parse_aliases)
  end
  
  def exit_session
    super
    @info_window.dispose
    @info_port.dispose
  end
  
  def enable_reset
    @must_reset = true
    @info_window.lines[8].replace _INTL('Type \'exit\' to restart'), 1
  end
  
  def set_commands
    super
    @commands['confirm']  = ConsoleCommand_Confirm.new(self)
    @commands['exit']     = ConsoleCommand_Exit.new(self)
  end
end

# A command for Deleting save and system data
class WipetoolCommand_Wipe < ConsoleCommand
  session       'wipetool'
  name          'wipe'
  description   _INTL('Delete save data.')
  
  def main(args)
    save_file = RTP.getSaveFileName('Game.rxdata')
    if safeExists?(save_file)
      @session.enable_reset if prompt_wipe('Game.rxdata',save_file)
    else
      println _INTL('Game.rxdata was not found')
    end
    prompt_wipe('Game.rxdata.bak',save_file+'.bak') if safeExists?(save_file+'.bak')
    return 0 unless File.exist?('SaveBackup/')
    backups = Dir.get_files('SaveBackup/').select do |file| 
      file.ends_with?(".rxdata")
    end
    backups.each do |path|
      prompt_wipe(File.basename(path),path)
    end
    return 0
  end
  
  private
  
  def prompt_wipe(name,path) 
    return false unless self.confirm? _INTL('Delete {1}?',name)
    begin
      File.delete(path)
    rescue Exception => e
      println e.message
      println _INTL('{1} was not deleted',name)
      return false
    end
    return true
  end
end