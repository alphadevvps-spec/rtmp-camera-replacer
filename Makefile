ARCHS = arm64
TARGET = iphone:clang:16.5:15.0
INSTALL_TARGET_PROCESSES = Camera

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = RTMPCameraReplacer

RTMPCameraReplacer_FILES = Tweak.x
RTMPCameraReplacer_CFLAGS = -fobjc-arc
RTMPCameraReplacer_FRAMEWORKS = UIKit MediaPlayer AVFoundation IOKit

include $(THEOS_MAKE_PATH)/tweak.mk
