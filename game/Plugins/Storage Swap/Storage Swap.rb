#===============================================================================
# Storage Swap: when your party is full and you take a Pokémon out of a box,
# you pick a party Pokémon to trade places with it, right there. No more
# "Your party's full!", going back, putting one away, and taking out again.
# Works in "Take out" and in "Move Pokémon" (Withdraw).
#===============================================================================
class PokemonStorageScreen
  alias __storageswap__pbWithdraw pbWithdraw unless method_defined?(:__storageswap__pbWithdraw)

  def pbWithdraw(selected, heldpoke)
    box, index = selected
    if heldpoke || box.nil? || box < 0 || !@storage.party_full? || !@storage[box, index]
      return __storageswap__pbWithdraw(selected, heldpoke)
    end
    incoming = @storage[box, index]
    pbDisplay(_INTL("Your party is full. Pick a Pokémon to trade places with {1}.", incoming.name))
    sprites = @scene.instance_variable_get(:@sprites)
    boxsel = @scene.instance_variable_get(:@selection)
    @scene.pbShowPartyTab
    @scene.instance_variable_set(:@selection, 0)
    pidx = @scene.pbSelectParty(@storage.party)
    @scene.pbHidePartyTab
    @scene.instance_variable_set(:@selection, boxsel)
    @scene.pbSetArrow(sprites["arrow"], boxsel)
    @scene.pbUpdateOverlay(boxsel)
    return false if pidx.nil? || pidx < 0 || pidx >= @storage.party.length
    outgoing = @storage.party[pidx]
    if pbAble?(outgoing) && pbAbleCount <= 1 && !pbAble?(incoming)
      pbPlayBuzzerSE
      pbDisplay(_INTL("That's your last Pokémon!"))
      return false
    end
    if outgoing.mail
      pbDisplay(_INTL("Please remove the Mail."))
      return false
    end
    outgoing.heal if Settings::HEAL_STORED_POKEMON
    @storage[box, index] = outgoing
    @storage.party[pidx] = incoming
    pbSEPlay("GUI storage put down")
    @scene.pbHardRefresh
    @scene.pbUpdateOverlay(boxsel)
    pbDisplay(_INTL("{1} went into the box. {2} joined your party!", outgoing.name, incoming.name))
    return true
  end
end
