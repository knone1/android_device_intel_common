ifneq (,$(findstring intel_prebuilts,$(MAKECMDGOALS)))
# at the moment we only generate prebuilts for userdebug builds
# this is a safety feature, eng, user, and userdebug binaries should be the same
# so intel_prebuilts should be used only for one variant anyway.
ifneq (,$(findstring userdebug,$(TARGET_BUILD_VARIANT)))

# for easy porting to legacy branches, we setup REF_PRODUCT_NAME
ifeq ($(REF_PRODUCT_NAME),)
REF_PRODUCT_NAME:=$(TARGET_PRODUCT)
endif

# Projects that require prebuilt are defined in manifest as follow:
# - project belongs to bsp-priv manifest group
# - and project has g_external annotation set to 'bin' ('g' meaning 'generic' customer)
$(eval _prebuilt_projects := $(shell repo forall -g bsp-priv -a g_external=bin -c 'echo $$REPO_PATH'))

# get the original path of the hooked build makefiles
define original-metatarget
$(strip \
  $(eval _LOCAL_BUILD_MAKEFILE := $$(lastword $$(MAKEFILE_LIST))) \
  $(BUILD_SYSTEM)/$(notdir $(_LOCAL_BUILD_MAKEFILE)))
endef

# $(1) : line to echo to the makefile
define external-echo-makefile
       echo $(1) >>$@;
endef

# $(1) : metatarget
# $(2) : MULTI_PREBUILT variable
# $(3) : LOCAL_BUILT_MODULE suffix variable
#
# .LOCAL_STRIP_MODULE is forced to false
#
# For a built module, file copied to prebuilt out is LOCAL_INSTALLED_MODULE_STEM
# For a prebuilt module, file copied to prebuilt out is LOCAL_SRC_FILES
#
# Two modules can have identical LOCAL_MODULE (e.g. target and host modules)
# or same LOCAL_MODULE_STEM with 2 different LOCAL_MODULE.
# To be sure to use a unique key when gathering files,
# the key used is $(LOCAL_MODULE).$(LOCAL_INSTALLED_MODULE_STEM)
#
define external-gather-files
$(if $(filter $(1),$(_metatarget)), \
    $(eval $(my).$(module_type).$(2).LOCAL_INSTALLED_STEM_MODULES := $($(my).$(module_type).$(2).LOCAL_INSTALLED_STEM_MODULES) $(LOCAL_MODULE).$(LOCAL_INSTALLED_MODULE_STEM)) \
    $(eval $(my).$(module_type).$(2).$(LOCAL_MODULE).$(LOCAL_INSTALLED_MODULE_STEM).LOCAL_MODULE := $(strip $(LOCAL_MODULE))) \
    $(eval $(my).$(module_type).$(2).$(LOCAL_MODULE).$(LOCAL_INSTALLED_MODULE_STEM).LOCAL_IS_HOST_MODULE := $(strip $(LOCAL_IS_HOST_MODULE))) \
    $(eval $(my).$(module_type).$(2).$(LOCAL_MODULE).$(LOCAL_INSTALLED_MODULE_STEM).LOCAL_MODULE_CLASS := $(strip $(LOCAL_MODULE_CLASS))) \
    $(eval $(my).$(module_type).$(2).$(LOCAL_MODULE).$(LOCAL_INSTALLED_MODULE_STEM).LOCAL_MODULE_TAGS := $(strip $(LOCAL_MODULE_TAGS))) \
    $(eval $(my).$(module_type).$(2).$(LOCAL_MODULE).$(LOCAL_INSTALLED_MODULE_STEM).OVERRIDE_BUILT_MODULE_PATH := $(strip $(subst $(HOST_OUT),$$$$(HOST_OUT),$(subst $(PRODUCT_OUT),$$$$(PRODUCT_OUT),$(OVERRIDE_BUILT_MODULE_PATH))))) \
    $(eval $(my).$(module_type).$(2).$(LOCAL_MODULE).$(LOCAL_INSTALLED_MODULE_STEM).LOCAL_UNINSTALLABLE_MODULE := $(strip $(LOCAL_UNINSTALLABLE_MODULE))) \
    $(eval $(my).$(module_type).$(2).$(LOCAL_MODULE).$(LOCAL_INSTALLED_MODULE_STEM).LOCAL_BUILT_MODULE_STEM := $(strip $(LOCAL_BUILT_MODULE_STEM))) \
    $(eval $(my).$(module_type).$(2).$(LOCAL_MODULE).$(LOCAL_INSTALLED_MODULE_STEM).LOCAL_STRIP_MODULE := ) \
    $(eval $(my).$(module_type).$(2).$(LOCAL_MODULE).$(LOCAL_INSTALLED_MODULE_STEM).LOCAL_REQUIRED_MODULES := $(strip $(LOCAL_REQUIRED_MODULES))) \
    $(eval $(my).$(module_type).$(2).$(LOCAL_MODULE).$(LOCAL_INSTALLED_MODULE_STEM).LOCAL_SHARED_LIBRARIES := $(strip $(LOCAL_SHARED_LIBRARIES))) \
    $(eval $(my).$(module_type).$(2).$(LOCAL_MODULE).$(LOCAL_INSTALLED_MODULE_STEM).LOCAL_INSTALLED_MODULE_STEM := $(strip $(LOCAL_INSTALLED_MODULE_STEM))) \
    $(eval $(my).$(module_type).$(2).$(LOCAL_MODULE).$(LOCAL_INSTALLED_MODULE_STEM).LOCAL_CERTIFICATE := $(strip $(notdir $(LOCAL_CERTIFICATE)))) \
    $(eval $(my).$(module_type).$(2).$(LOCAL_MODULE).$(LOCAL_INSTALLED_MODULE_STEM).LOCAL_MODULE_PATH := $(strip $(subst $(HOST_OUT),$$$$(HOST_OUT),$(subst $(PRODUCT_OUT),$$$$(PRODUCT_OUT),$(LOCAL_MODULE_PATH))))) \
    $(eval $(my).$(module_type).$(2).$(LOCAL_MODULE).$(LOCAL_INSTALLED_MODULE_STEM).LOCAL_SRC_FILES := $(notdir $(LOCAL_SRC_FILES))) \
    $(if $(filter prebuilt,$(_metatarget)), \
        $(eval $(my).copyfiles := $($(my).copyfiles) $(foreach h,$(LOCAL_SRC_FILES),$(LOCAL_PATH)/$(LOCAL_SRC_FILES):$(dir $(my))$(module_type)/$(notdir $(h)))), \
        $(eval $(my).copyfiles := $($(my).copyfiles) $(LOCAL_BUILT_MODULE)$(3):$(dir $(my))$(module_type)/$(LOCAL_INSTALLED_MODULE_STEM)) \
    ) \
)
endef

define external-phony-package-boilerplate
  $(call external-echo-makefile, '') \
  $(call external-echo-makefile,'include $$(CLEAR_VARS)') \
  $(call external-echo-makefile,'LOCAL_MODULE:=$(strip $(1))') \
  $(call external-echo-makefile,'LOCAL_MODULE_TAGS:=optional') \
  $(call external-echo-makefile,'LOCAL_REQUIRED_MODULES:=$(strip $(2))') \
  $(call external-echo-makefile,'include $$(BUILD_PHONY_PACKAGE)')
endef

# $(1): file list
# $(2): IS_HOST_MODULE
# $(3): MODULE_CLASS
# $(4): MODULE_TAGS
# $(5): OVERRIDE_BUILT_MODULE_PATH
# $(6): UNINSTALLABLE_MODULE
# $(7): BUILT_MODULE_STEM
# $(8): LOCAL_STRIP_MODULE
# $(9): LOCAL_MODULE
# $(10): LOCAL_MODULE_STEM
# $(11): LOCAL_CERTIFICATE
# $(12): LOCAL_MODULE_PATH
# $(13): LOCAL_REQUIRED_MODULES
# $(14): LOCAL_SHARED_LIBRARIES
#
define external-auto-prebuilt-boilerplate
$(if $(filter %: :%,$(1)), \
  $(error $(LOCAL_PATH): Leading or trailing colons in "$(1)")) \
$(foreach t,$(1), \
  $(call external-echo-makefile, '') \
  $(call external-echo-makefile, 'include $$(CLEAR_VARS)') \
  $(call external-echo-makefile, 'LOCAL_IS_HOST_MODULE:=$(strip $(2))') \
  $(call external-echo-makefile, 'LOCAL_MODULE_CLASS:=$(strip $(3))') \
  $(call external-echo-makefile, 'LOCAL_MODULE_TAGS:=$(strip $(4))') \
  $(call external-echo-makefile, 'OVERRIDE_BUILT_MODULE_PATH:=$(strip $(5))') \
  $(call external-echo-makefile, 'LOCAL_UNINSTALLABLE_MODULE:=$(strip $(6))') \
  $(call external-echo-makefile, 'LOCAL_SRC_FILES:=$(strip $(t))') \
  $(if $(7), \
    $(call external-echo-makefile, 'LOCAL_BUILT_MODULE_STEM:=$(strip $(7))') \
   , \
    $(call external-echo-makefile, 'LOCAL_BUILT_MODULE_STEM:=$(strip $(notdir $(t)))') \
   ) \
  $(call external-echo-makefile, 'LOCAL_STRIP_MODULE:=$(strip $(8))') \
  $(call external-echo-makefile, 'LOCAL_MODULE:=$(strip $(9))') \
  $(call external-echo-makefile, 'LOCAL_MODULE_STEM:=$(strip $(10))') \
  $(call external-echo-makefile, 'LOCAL_CERTIFICATE:=$(strip $(11))') \
  $(call external-echo-makefile, 'LOCAL_MODULE_PATH:=$(strip $(12))') \
  $(call external-echo-makefile, 'LOCAL_REQUIRED_MODULES:=$(strip $(13))') \
  $(call external-echo-makefile, 'LOCAL_SHARED_LIBRARIES:=$(strip $(14))') \
  $(call external-echo-makefile, 'include $$(BUILD_PREBUILT)') \
 )
endef

# Copy several files.
# $(1): The files to copy.  Each entry is a ':' separated src:dst pair
define copy-several-files
$(foreach f, $(1), \
    $(eval _cmf_tuple := $(subst :, ,$(f))) \
    $(eval _cmf_src := $(word 1,$(_cmf_tuple))) \
    $(eval _cmf_dest := $(word 2,$(_cmf_tuple))) \
    mkdir -p $(dir $(_cmf_dest)); \
    $(ACP) $(_cmf_src) $(_cmf_dest);)
endef

# List several files dependencies.
# $(1): The files to compute.  Each entry is a ':' separated src:dst pair
define several-files-deps
$(foreach f, $(1), $(strip \
    $(eval _cmf_tuple := $(subst :, ,$(f))) \
    $(eval _cmf_src := $(word 1,$(_cmf_tuple))) \
    $(_cmf_src)))
endef

EXTERNAL_BUILD_SYSTEM=device/intel/common/external

TARGET_OUT_prebuilts := $(PRODUCT_OUT)/prebuilts/intel

# hook all the build makefiles with our own version
# most of them are only symlinks to "unsupported.mk", which will generate an
# error if included from a "PRIVATE" dir
# others are symlink to generic_rules.mk
# we cannot directly point to unsupported or generic_rules, because we would loose
# the information on what we are building
BUILD_HOST_STATIC_LIBRARY:= $(EXTERNAL_BUILD_SYSTEM)/symlinks/host_static_library.mk
BUILD_HOST_SHARED_LIBRARY:= $(EXTERNAL_BUILD_SYSTEM)/symlinks/host_shared_library.mk
BUILD_STATIC_LIBRARY:= $(EXTERNAL_BUILD_SYSTEM)/symlinks/static_library.mk
BUILD_RAW_STATIC_LIBRARY := $(EXTERNAL_BUILD_SYSTEM)/symlinks/raw_static_library.mk
BUILD_SHARED_LIBRARY:= $(EXTERNAL_BUILD_SYSTEM)/symlinks/shared_library.mk
BUILD_EXECUTABLE:= $(EXTERNAL_BUILD_SYSTEM)/symlinks/executable.mk
BUILD_RAW_EXECUTABLE:= $(EXTERNAL_BUILD_SYSTEM)/symlinks/raw_executable.mk
BUILD_HOST_EXECUTABLE:= $(EXTERNAL_BUILD_SYSTEM)/symlinks/host_executable.mk
BUILD_PACKAGE:= $(EXTERNAL_BUILD_SYSTEM)/symlinks/package.mk
BUILD_PHONY_PACKAGE:= $(EXTERNAL_BUILD_SYSTEM)/symlinks/phony_package.mk
BUILD_HOST_PREBUILT:= $(EXTERNAL_BUILD_SYSTEM)/symlinks/host_prebuilt.mk
BUILD_PREBUILT:= $(EXTERNAL_BUILD_SYSTEM)/symlinks/prebuilt.mk
BUILD_MULTI_PREBUILT:= $(EXTERNAL_BUILD_SYSTEM)/symlinks/multi_prebuilt.mk
BUILD_JAVA_LIBRARY:= $(EXTERNAL_BUILD_SYSTEM)/symlinks/java_library.mk
BUILD_STATIC_JAVA_LIBRARY:= $(EXTERNAL_BUILD_SYSTEM)/symlinks/static_java_library.mk
BUILD_HOST_JAVA_LIBRARY:= $(EXTERNAL_BUILD_SYSTEM)/symlinks/host_java_library.mk
BUILD_COPY_HEADERS := $(EXTERNAL_BUILD_SYSTEM)/symlinks/copy_headers.mk
BUILD_NATIVE_TEST := $(EXTERNAL_BUILD_SYSTEM)/symlinks/native_test.mk
BUILD_HOST_NATIVE_TEST := $(EXTERNAL_BUILD_SYSTEM)/symlinks/host_native_test.mk
BUILD_CUSTOM_EXTERNAL := $(EXTERNAL_BUILD_SYSTEM)/symlinks/custom_external.mk

endif # userdebug
endif # intel_prebuilt