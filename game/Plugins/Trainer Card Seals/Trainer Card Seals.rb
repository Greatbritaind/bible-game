#===============================================================================
# Trainer Card Seals
# Essentials picks which badges to show on the Trainer Card by the region of
# the current map. Our Town Map regions don't match, so earned seals never
# showed. This always shows the 8 seals (badges 0-7) from
# Graphics/UI/Trainer Card/icon_badges.png: one row of 48x48 cells, each seal
# a little off-center and bigger than its box, like real wax.
#===============================================================================
class PokemonTrainerCard_Scene
  alias __seals__pbDrawTrainerCardFront pbDrawTrainerCardFront unless method_defined?(:__seals__pbDrawTrainerCardFront)

  def pbDrawTrainerCardFront
    __seals__pbDrawTrainerCardFront
    overlay = @sprites["overlay"].bitmap
    region = pbGetCurrentRegion(0)
    # Clear anything the original drew in the seal row, then draw the seals
    overlay.clear_rect(72, 310, 8 * 48, 32) if region != 0
    imagePositions = []
    8.times do |i|
      next if !$player.badges[i]
      imagePositions.push(["Graphics/UI/Trainer Card/icon_badges", 64 + (i * 48), 302, i * 48, 0, 48, 48])
    end
    pbDrawImagePositions(overlay, imagePositions)
  end
end
