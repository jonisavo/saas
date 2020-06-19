#==============================================================================#
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■ SHELL AS A SERVICE ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ #
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONSOLE SESSIONS ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ #
#==============================================================================#

# A version of ConsoleSession with added information upon logging in.
class ConsoleSession_Interactive < ConsoleSession
  def main
    println _INTL('SHELL AS A SERVICE {1}',SHELL_VERSION)
    println _INTL('Interactive session: enter \'exit\' to leave')
    unless $Trainer.nil?
      println _INTL('\nLogged in as {1}',$Trainer.name)
    end
    force_wait 10
    super
  end
end

# A version of ConsoleSession with additional in-game only commands.
# Accessible from anywhere with CTRL + S.
class ConsoleSession_Ingame < ConsoleSession
  def main
    println _INTL('SHELL AS A SERVICE {1}',SHELL_VERSION)
    println _INTL('In-Game Session')
    println _INTL('\nLogged in as {1}',$Trainer.name)
    force_wait 10
    super
    Input.update
  end
  
  # Sets the available commands.
  def set_commands
    ConsoleCommand::Properties.each do |cmd_class,data|
      next if data[:debug_only] && !$DEBUG
      next if data[:outside_game]
      next if (data[:session] || 'shell') != self.name
      next if data[:mkxp_only] && !$MKXP
      @commands[data[:name]] = cmd_class.new(self) unless data[:hidden]
    end    
  end
end

# Input.update is modified to include a check for CTRL + S, which
# boots up ConsoleSession_Ingame.
module Input
  class << self
    alias __shell_update update
  end
  
  def self.update
    __shell_update
    # CTRL + S
    if $scene.is_a?(Scene_Map) && $DEBUG && 
       self.triggerex?(0x11) && self.triggerex?(0x53)
      ConsoleSession_Ingame.new
    end
  end
end