#===============================================================================
# Trainer Card Seals
# Essentials picks which badges to show on the Trainer Card by the region of
# the current map. Our Town Map regions don't match, so earned seals never
# showed. This always shows the 8 seals (badges 0-7) from the first row of
# Graphics/UI/Trainer Card/icon_badges.png.
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
      imagePositions.push(["Graphics/UI/Trainer Card/icon_badges", 72 + (i * 48), 310, i * 32, 0, 32, 32])
    end
    pbDrawImagePositions(overlay, imagePositions)
  end
end
