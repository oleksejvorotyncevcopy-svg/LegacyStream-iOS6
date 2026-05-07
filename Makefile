export THEOS_DEVICE_IP = 192.168.X.X  
export THEOS_DEVICE_PORT = 22
THEOS = /Users/vorotyntsev/theos
ARCHS = armv7
TARGET = iphone:clang:6.1:6.1
INSTALL_TARGET_PROCESSES = RetroMusic

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = RetroMusic

RetroMusic_FILES = main.m XXRootViewController.m XXAppDelegate.m
# ВАЖНО: Добавили CoreMedia в конец этой строки!
RetroMusic_FRAMEWORKS = UIKit CoreGraphics AVFoundation Foundation CoreMedia MediaPlayer
RetroMusic_CFLAGS = -fobjc-arc

RetroMusic_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/application.mk