#===============================================================================
# Class Splash
# Before the title screen: a black screen where white text fades in and out.
# Shown once each time the game starts. Pressing a button skips ahead.
#===============================================================================
module ClassSplash
  TEXT      = "Made for Mr. Dawson's Bible class"
  FONT_SIZE = 36
  FADE_IN   = 1.0 # seconds
  HOLD      = 2.0
  FADE_OUT  = 1.0

  def self.show
    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = 99999
    back = Sprite.new(viewport)
    back.bitmap = Bitmap.new(Graphics.width, Graphics.height)
    back.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
    text = Sprite.new(viewport)
    text.bitmap = Bitmap.new(Graphics.width, Graphics.height)
    pbSetSystemFont(text.bitmap)
    text.bitmap.font.size = FONT_SIZE
    text.bitmap.font.color = Color.new(255, 255, 255)
    line_h = FONT_SIZE + 12
    text.bitmap.draw_text(0, (Graphics.height - line_h) / 2, Graphics.width, line_h, TEXT, 1)
    text.opacity = 0
    Graphics.transition(0)
    start = System.uptime
    total = FADE_IN + HOLD + FADE_OUT
    skipped_at = nil
    loop do
      Graphics.update
      Input.update
      t = System.uptime - start
      if skipped_at.nil? && t < FADE_IN + HOLD && (Input.trigger?(Input::USE) || Input.trigger?(Input::BACK))
        # jump to the fade out, from the current brightness
        skipped_at = t
        start -= (FADE_IN + HOLD) - t
        t = FADE_IN + HOLD
      end
      break if t >= total
      text.opacity = if t < FADE_IN
                       255 * (t / FADE_IN)
                     elsif t < FADE_IN + HOLD
                       255
                     else
                       255 * (1 - ((t - FADE_IN - HOLD) / FADE_OUT))
                     end
    end
    text.bitmap.dispose
    text.dispose
    back.bitmap.dispose
    back.dispose
    viewport.dispose
  end
end

class Scene_Intro
  alias rtj_splash_main main unless method_defined?(:rtj_splash_main)
  def main
    unless $rtj_class_splash_shown
      $rtj_class_splash_shown = true
      ClassSplash.show
    end
    rtj_splash_main
  end
end
