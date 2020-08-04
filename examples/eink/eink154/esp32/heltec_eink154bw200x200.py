# ESP32 micropython

# display-specific constants
# for Heltec BW 1.54" 200x200 IL3829
# Markings on flat cable:
# HINK-E0154A07-A1
# Date:2017-02-28
# SYX 1942

class specific:
  def __init__(self):
    # display resolution
    self.width  = 200
    self.height = 200
    # chip, differs in initialization
    self.IL = 3829
    # this display doesn't need LUTs for partial refresh
    self.lut_full_refresh = None
    self.lut_partial_refresh = None
    # refresh_frame(parameter)
    self.full_refresh    = 0xF7
    self.partial_refresh = 0xFF
