ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = RTMPCameraReplacer

RTMPCameraReplacer_FILES = Tweak.x RTMPStreamManager.m RTMPSettingsViewController.m
RTMPCameraReplacer_CFLAGS = -fobjc-arc
RTMPCameraReplacer_FRAMEWORKS = UIKit Foundation AVFoundation VideoToolbox
RTMPCameraReplacer_PRIVATE_FRAMEWORKS = CameraUI

include $(THEOS)/makefiles/tweak.mk
