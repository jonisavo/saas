#==============================================================================#
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■ SHELL AS A SERVICE ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ #
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ IN-GAME COMMANDS ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ #
#==============================================================================#

# A tool for changing money
class ConsoleCommand_Money < ConsoleCommand
  name          'money'
  description   _INTL('Set, add or remove money.')
  manual_desc   _INTL('A tool for changing and showing your current\nbalance.')
  argument      's', _INTL('subcommand')
  argument      'i', _INTL('amount'), :optional
  subcommand    'add',    _INTL('adds the given amount of money'),       :add_command 
  subcommand    'remove', _INTL('removes the given amount of money'),    :remove_command
  subcommand    'set',    _INTL('sets your balance to the given amount'),:set_command
  subcommand    'show',   _INTL('prints out your current balance'),      :show_command
  in_game
  debug_only
  
  def main(args)
    ret = 1
    if is_subcommand?(args[0])
      ret = parse_subcommands(args)
    else
      show_manual
    end
    return ret
  end
  
  # Adds the given amount of money to your balance
  def add_command(args)
    error _INTL('no value given') if args.empty?
    value = validate_value('i',args[0])
    error _INTL('value must be positive') if value < 0
    $Trainer.money += value
    return 0
  end
  
  # Removes the given amount of money from your balance
  def remove_command(args)
    error _INTL('no value given') if args.empty?
    value = validate_value('i',args[0])
    error _INTL('value must be positive') if value < 0
    $Trainer.money -= value
    return 0
  end
  
  # Sets your balance to the given amount
  def set_command(args)
    error _INTL('no value given') if args.empty?
    value = validate_value('i',args[0])
    error _INTL('value must be positive') if value < 0
    $Trainer.money = value
    return 0
  end
  
  # Shows your current balance
  def show_command(args)
    println _INTL('${1}',$Trainer.money)
    return 0
  end
end

# Tool for modifying the bag
class ConsoleCommand_Item < ConsoleCommand
  name          'item'
  description   _INTL('Add or remove items from inventory.')
  manual_desc   _INTL('A tool for modifying your inventory and\nshowing the quantity of a specific item.')
  argument      's', _INTL('subcmd')
  argument      's', _INTL('item id')
  argument      'i', _INTL('quantity'), :optional
  subcommand    'add',    _INTL('add items to inventory'),      :add_command
  subcommand    'remove', _INTL('remove items from inventory'), :remove_command
  subcommand    'show',   _INTL('show item information'),       :show_command
  in_game
  debug_only
  
  def main(args)
    ret = 1
    if is_subcommand?(args[0])
      ret = parse_subcommands(args)
    else
      show_manual
    end
    return ret
  end
  
  # Adds x of item y
  def add_command(args)
    error _INTL('no item id given') if args.empty?
    item_id, quantity = parse_item(args)
    unless $PokemonBag.pbStoreItem(item_id,quantity)
      println _INTL('Bag is full: all items were not stored')
    end
    return 0
  end
  
  # Removes x of item y
  def remove_command(args)
    error _INTL('no item id given') if args.empty?
    item_id, quantity = parse_item(args)
    unless $PokemonBag.pbDeleteItem(item_id,quantity)
      println _INTL('All items were not deleted')
    end
    return 0
  end

  def parse_item(args)
    unless hasConst?(PBItems,args[0].upcase.to_sym)
      error _INTL('unknown item id :{1}',args[0].upcase)
    end
    item_id = getID(PBItems,args[0].upcase.to_sym)
    if args[1]
      quantity = validate_value('i',args[1])
      error _INTL('negative quantity') if quantity < 0
    else
      quantity = 1
    end
    return item_id, quantity
  end
  
  # Shows information about item y
  def show_command(args)
    error _INTL('no item id given') if args.empty?
    unless hasConst?(PBItems,args[0].upcase.to_sym)
      error _INTL('unknown item id :{1}',args[0].upcase)
    end
    itemid = getID(PBItems,args[0].upcase.to_sym)
    print _INTL(':{1}\t{2}',args[0].upcase,PBItems.getName(itemid))
    println _INTL('{1} in inventory',$PokemonBag.pbQuantity(itemid)), 2
    return 0
  end
end

class ConsoleCommand_Egg < ConsoleCommand
  name          'egg'
  description   _INTL('Generate eggs.')
  manual_desc   _INTL('Generates an egg and places it in your\nparty. The passed argument can be an integer\n(species id) or string (species internal name)')
  argument      's', _INTL('species')
  argument      's', _INTL('obtain text'), :optional
  in_game
  debug_only

  def main(args)
    error _INTL('no argument') if args.empty?
    error _INTL('party is full') if $Trainer.party.length == 6
    # Validate species
    if args[0].numeric?
      species = args[0].to_i
      validate_range 1..PBSpecies.maxValue, species
    else
      species = args[0].upcase.to_sym
      unless hasConst?(PBSpecies,args[0].upcase.to_sym)
        error _INTL('unknown species :{1}', args[0].upcase.to_sym)
      end
    end
    Kernel.pbGenerateEgg(species,args[1] || "")
  end
end

class ConsoleCommand_Pkmn < ConsoleCommand
  name          'pkmn'
  description   _INTL('Generate Pokémon.')
  manual_desc   _INTL('Generates a Pokémon and places it in your party\nor the storage system.')
  argument      's', _INTL('species')
  argument      'i', _INTL('level')
  option        'x', :@shiny, _INTL('make shiny'), '--shiny', '-s'
  option        'x', :@ability, _INTL('give hidden ability'), '--ability', '-a'
  option        'i', :@form, _INTL('set form'), '--form', '-f'
  in_game
  debug_only

  def main(args)
    error _INTL('no argument') if args.empty?
    error _INTL('no space for Pokémon') if pbBoxesFull?
    # Validate species
    if args[0].numeric?
      species = args[0].to_i
      validate_range 1..PBSpecies.maxValue, species
    else
      species = args[0].upcase.to_sym
      unless hasConst?(PBSpecies,args[0].upcase.to_sym)
        error _INTL('unknown species :{1}', args[0].upcase.to_sym)
      end
    end
    # Validate level
    level = validate_value('i', args[1])
    validate_range 1..PBExperience::MAXLEVEL, level
    pkmn = pbGenPkmn(species,level)
    pkmn.makeShiny if @shiny
    pkmn.setAbility(2) if @ability
    pkmn.form = @form unless @form.nil?
    pbAddPokemonSilent(pkmn)
  end
end