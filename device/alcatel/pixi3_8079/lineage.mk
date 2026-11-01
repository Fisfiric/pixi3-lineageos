# Release name
PRODUCT_RELEASE_NAME := pixi3_8079

# Inherit device configuration
$(call inherit-product, device/alcatel/pixi3_8079/full_pixi3_8079.mk)

# Inherit some common CM stuff.
$(call inherit-product, vendor/cm/config/common_full_tablet_wifionly.mk)


## Device identifier. This must come after all inclusions
PRODUCT_DEVICE := pixi3_8079
PRODUCT_NAME := lineage_pixi3_8079
PRODUCT_BRAND := alcatel
PRODUCT_MODEL := Pixi 3 (10)
PRODUCT_MANUFACTURER := TCL
PRODUCT_RELEASE_NAME := pixi3_8079
PRODUCT_GMS_CLIENTID_BASE := android-alcatel
