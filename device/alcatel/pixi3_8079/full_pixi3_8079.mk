DEVICE_DIR := device/alcatel/pixi3_8079

# Inherit from those products. Most specific first.
$(call inherit-product, $(DEVICE_DIR)/device.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)

PRODUCT_CHARACTERISTICS := tablet

PRODUCT_DEVICE := pixi3_8079
PRODUCT_NAME := pixi3_8079
PRODUCT_BRAND := alcatel
PRODUCT_MANUFACTURER := TCL
PRODUCT_MODEL := Pixi 3 (10)
