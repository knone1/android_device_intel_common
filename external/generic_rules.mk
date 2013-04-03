# prevent re-entrency (metatargets are calling them selves, e.g COPY_HEADERS)
ifeq ($(_metatarget),)
# get the name of the metatarget (which is the name of our symlink)
# it has to be very first place, because include will alter the MAKEFILE_LIST)
_metatarget := $(basename $(notdir $(call original-metatarget)))
_need_prebuilts :=
$(foreach project, $(_prebuilt_projects),\
  $(if $(findstring $(project), $(LOCAL_MODULE_MAKEFILE)),\
    $(eval _need_prebuilts := true)))

ifneq (,$(_need_prebuilts))
# multi_prebuilt actually a shortcut to prebuilts, we support it to have a simpler output Android.mk
# but dont support all the flavors of multi_prebuilt
# we dont support the multi_prebuilt ':' syntax, fallback to normal prebuilt
# i.e. in multi_prebuilts, you can set LOCAL_PREBUILT_LIBS := <MODULE1>:<file1> <MODULE2>:<file2>
# this complexifies the implementation too much, so we fallback on the prebuilt backend we already implement
ifeq (multi_prebuilt,$(_metatarget))
 $(foreach var, LIBS EXECUTABLES LIBRARIES STATIC_JAVA_LIBRARIES,\
   $(if $(findstring :,$(LOCAL_PREBUILT_$(var))),\
	$(eval _metatarget:=)\
	))
endif
# if we are still multiprebuilt
ifeq (multi_prebuilt,$(_metatarget))
# if multi_prebuilt, we need to save the variables, because the original metatarget will
# call CLEAR_VARS
 $(foreach var, LIBS EXECUTABLES LIBRARIES STATIC_JAVA_LIBRARIES,\
   $(if $(LOCAL_PREBUILT_$(var)),\
     $(if $(IS_HOST_MODULE),\
       $(eval SAVED_HOST_$(var) := $(LOCAL_PREBUILT_$(var))),\
       $(eval SAVED_$(var) := $(LOCAL_PREBUILT_$(var)))\
     ))\
   )
endif
endif

########################################################################################
ifneq (custom_external, $(_metatarget))
include $(call original-metatarget)
endif
########################################################################################

# do nothing more if we are not in a PRIVATE dir
ifneq (,$(_need_prebuilts))

# device/intel/PRIVATE/ipp -> device/intel/prebuilts/blackbay/ipp
# src makefile is renamed Android.mk in prebuilts out directory
LOCAL_MODULE_PREBUILT_MAKEFILE := $(TARGET_OUT_prebuilts)/$(subst /PRIVATE/,/prebuilts/$(REF_PRODUCT_NAME)/,$(dir $(LOCAL_MODULE_MAKEFILE)))Android.mk
# local shortcut
my := $(LOCAL_MODULE_PREBUILT_MAKEFILE)

# we only define the commands once, even LOCAL_MODULE_PREBUILT_MAKEFILE may be defined
# via several metatargets (because the original Android.mk builds several things)

ifeq (,$($(LOCAL_MODULE_PREBUILT_MAKEFILE).ORIG_MAKEFILE))
$(LOCAL_MODULE_PREBUILT_MAKEFILE).ORIG_MAKEFILE := $(LOCAL_MODULE_MAKEFILE)
$(LOCAL_MODULE_PREBUILT_MAKEFILE).REF_PRODUCT_NAME := $(REF_PRODUCT_NAME)
# this variable in needed for substitution of ':' into a ',', as there is no escape in gnumake :-/
# http://blog.jgc.org/2007/06/escaping-comma-and-space-in-gnu-make.html
,:=,
# We only make one target to build the makefile (the ACPs are done in this target)
$(LOCAL_MODULE_PREBUILT_MAKEFILE): $(ACP) $(EXTERNAL_BUILD_SYSTEM)/generic_rules.mk
# cannot use $(LOCAL_MODULE_PREBUILT_MAKEFILE) or $(my) inside the rules, as they are expanded at rule running time
# while those two variables, are overriden at makefile parsing time
# we rebuild the whole directory every time to make sure there is no remaining files from previous build
# We don't remove the whole directory but only the files at first level, else we might have conflicts between
# cascaded Android.mk, when building with -j x option
	@mkdir -p $(dir $@)
	@find $(dir $@) -maxdepth 1 -type f -exec rm -f {} +
	@$(if $($@.copyfiles),\
		$(call copy-several-files, $($@.copyfiles)),)
	@echo '# autogenerated Android.mk' > $@
	@echo 'ifeq ($($@.REF_PRODUCT_NAME),$$(wildcard $($@.ORIG_MAKEFILE))$$(REF_PRODUCT_NAME))# test inexistance of original makefile, and correct ref product' >> $@
	@echo 'LOCAL_PATH := $$(call my-dir)' >> $@
	@echo 'include $$(CLEAR_VARS)' >> $@
	@echo '# TARGET multi prebuilt binaries' >> $@
	@echo 'LOCAL_IS_HOST_MODULE:=' >> $@
	@$(foreach class, LIBS EXECUTABLES JAVA_LIBRARIES STATIC_JAVA_LIBRARIES, \
		$(call external-echo-prebuilt,$(class)))
	@echo 'include $$(BUILD_MULTI_PREBUILT)' >> $@
	@$(if $($@.MULTI_PREBUILTS.hashosts), \
		$(call external-echo-makefile, 'include $$(CLEAR_VARS)') \
		$(call external-echo-makefile, '# HOST multi prebuilt binaries' ) \
		$(call external-echo-makefile, 'LOCAL_IS_HOST_MODULE:=true' ) \
		$(foreach class, LIBS EXECUTABLES JAVA_LIBRARIES STATIC_JAVA_LIBRARIES, \
			$(call external-echo-prebuilt,$(class),HOST_)) \
		$(call external-echo-makefile, 'include $$(BUILD_MULTI_PREBUILT)'))
	@$(foreach class, LIBS EXECUTABLES JAVA_LIBRARIES STATIC_JAVA_LIBRARIES HOST_LIBS HOST_EXECUTABLES HOST_JAVA_LIBRARIES HOST_STATIC_JAVA_LIBRARIES, \
		$(foreach module, $($@.$(class).LOCAL_INSTALLED_STEM_MODULES), \
			$(call external-auto-prebuilt-boilerplate,$(module),$($@.$(class).$(module).LOCAL_IS_HOST_MODULE),$($@.$(class).$(module).LOCAL_MODULE_CLASS),$($@.$(class).$(module).LOCAL_MODULE_TAGS),$($@.$(class).$(module).OVERRIDE_BUILT_MODULE_PATH),$($@.$(class).$(module).LOCAL_UNINSTALLABLE_MODULE),$($@.$(class).$(module).LOCAL_BUILT_MODULE_STEM),$($@.$(class).$(module).LOCAL_STRIP_MODULE),$($@.$(class).$(module).LOCAL_MODULE),$($@.$(class).$(module).LOCAL_INSTALLED_MODULE_STEM),$($@.$(class).$(module).LOCAL_CERTIFICATE),$($@.$(class).$(module).LOCAL_MODULE_PATH),$($@.$(class).$(module).LOCAL_REQUIRED_MODULES))))
	@$(foreach to, $($@.headers_to), \
		$(if $(filter _none_,$(to)), \
			$(eval _to_:=),\
			$(eval _to_:=$(to))) \
		$(if $(strip $($@.headers.$(to))), \
			$(call external-echo-makefile, 'include $$(CLEAR_VARS)') \
			$(call external-echo-makefile, 'LOCAL_COPY_HEADERS:=$($@.headers.$(to))') \
			$(call external-echo-makefile, 'LOCAL_COPY_HEADERS_TO:=$(_to_)') \
			$(call external-echo-makefile, 'include $$(BUILD_COPY_HEADERS)')))
	@$(foreach module, $($@.prebuilt), \
		$(call external-auto-prebuilt-boilerplate,$($@.prebuilt.$(module).LOCAL_SRC_FILES),$($@.prebuilt.$(module).LOCAL_IS_HOST_MODULE),$($@.prebuilt.$(module).LOCAL_MODULE_CLASS),$($@.prebuilt.$(module).LOCAL_MODULE_TAGS),$($@.prebuilt.$(module).OVERRIDE_BUILT_MODULE_PATH),$($@.prebuilt.$(module).LOCAL_UNINSTALLABLE_MODULE),$($@.prebuilt.$(module).LOCAL_BUILT_MODULE_STEM),$($@.prebuilt.$(module).LOCAL_STRIP_MODULE),$(module),$($@.prebuilt.$(module).LOCAL_INSTALLED_MODULE_STEM),$($@.prebuilt.$(module).LOCAL_CERTIFICATE),$($@.prebuilt.$(module).LOCAL_MODULE_PATH),$($@.prebuilt.$(module).LOCAL_REQUIRED_MODULES)))
	@$(foreach module, $($@.PACKAGES.LOCAL_INSTALLED_STEM_MODULES), \
		$(call external-auto-prebuilt-boilerplate,$(module),,APPS,optional,,,,,$($@.PACKAGES.$(module).LOCAL_MODULE),$($@.PACKAGES.$(module).LOCAL_INSTALLED_MODULE_STEM),$($@.PACKAGES.$(module).LOCAL_CERTIFICATE)))
	@$(foreach mk, $($@.extramakefile), \
		cat $(mk) >> $@;)
	@$(foreach module, $($@.phony), \
		$(call external-phony-package-boilerplate, $(module), $($@.phony.$(module).LOCAL_REQUIRED_MODULES)))
	@echo 'endif' >> $@

endif
# this implement mapping between metatarget names, and what multi_prebuilt is waiting for
$(call external-gather-files,executable,EXECUTABLES)
$(call external-gather-files,shared_library,LIBS)
$(call external-gather-files,static_library,LIBS)
$(call external-gather-files,host_executable,HOST_EXECUTABLES)
$(call external-gather-files,host_shared_library,HOST_LIBS)
$(call external-gather-files,host_static_library,HOST_LIBS)
$(call external-gather-files,java_library,JAVA_LIBRARIES,.dex)
$(call external-gather-files,static_java_library,STATIC_JAVA_LIBRARIES)
$(call external-gather-files,package,PACKAGES,.dex)

# some metatargets also include copy_headers implicitly
ifneq ($(filter copy_headers executable shared_library static_library,$(_metatarget)),)
   $(my).copyfiles := $($(my).copyfiles) $(foreach h,$(LOCAL_COPY_HEADERS),$(LOCAL_PATH)/$(h):$(dir $(my))$(notdir $(h)))
ifeq ($(LOCAL_COPY_HEADERS_TO),)
   LOCAL_COPY_HEADERS_TO := _none_
endif
   $(my).headers_to := $($(my).headers_to) $(LOCAL_COPY_HEADERS_TO)
   $(my).headers.$(LOCAL_COPY_HEADERS_TO) := $($(my).headers.$(LOCAL_COPY_HEADERS_TO)) $(foreach h,$(LOCAL_COPY_HEADERS),$(notdir $(h)))
endif

# prebuilt is a bit special, it has a lot of arguments...
# we'll use intel-auto-prebuilt-boilerplate, which is a macro defined by external.mk
ifneq ($(filter prebuilt,$(_metatarget)),)
   $(if $(word 2,$(LOCAL_SRC_FILES)), \
     $(error $(LOCAL_PATH): external script does not support multiple src files for BUILD_PREBUILT metatarget))
   $(my).copyfiles := $($(my).copyfiles) $(LOCAL_PATH)/$(LOCAL_SRC_FILES):$(dir $(my))$(notdir $(LOCAL_SRC_FILES))
   $(if $(word 2,$(LOCAL_MODULE_TAGS)), \
     $(info $(LOCAL_PATH): external script does not support multiple tags: $(LOCAL_MODULE_TAGS) in prebuilt using optional instead) $(eval LOCAL_MODULE_TAGS:=optional))
   # maintain a list of all possible combinations of parameters
   $(my).prebuilt := $($(my).prebuilt) $(LOCAL_MODULE)
   $(my).prebuilt.$(LOCAL_MODULE).LOCAL_SRC_FILES := $(notdir $(LOCAL_SRC_FILES))
   $(my).prebuilt.$(LOCAL_MODULE).LOCAL_IS_HOST_MODULE := $(strip $(LOCAL_IS_HOST_MODULE))
   $(my).prebuilt.$(LOCAL_MODULE).LOCAL_MODULE_CLASS := $(strip $(LOCAL_MODULE_CLASS))
   $(my).prebuilt.$(LOCAL_MODULE).LOCAL_MODULE_TAGS := $(strip $(LOCAL_MODULE_TAGS))
   $(my).prebuilt.$(LOCAL_MODULE).OVERRIDE_BUILT_MODULE_PATH := $(strip $(subst $(HOST_OUT),$$(HOST_OUT),$(subst $(PRODUCT_OUT),$$(PRODUCT_OUT),$(OVERRIDE_BUILT_MODULE_PATH))))
   $(my).prebuilt.$(LOCAL_MODULE).LOCAL_UNINSTALLABLE_MODULE := $(strip $(LOCAL_UNINSTALLABLE_MODULE))
   $(my).prebuilt.$(LOCAL_MODULE).LOCAL_BUILT_MODULE_STEM := $(strip $(LOCAL_BUILT_MODULE_STEM))
   $(my).prebuilt.$(LOCAL_MODULE).LOCAL_STRIP_MODULE := $(strip $(LOCAL_STRIP_MODULE))
   $(my).prebuilt.$(LOCAL_MODULE).LOCAL_INSTALLED_MODULE_STEM := $(strip $(LOCAL_INSTALLED_MODULE_STEM))
   $(my).prebuilt.$(LOCAL_MODULE).LOCAL_CERTIFICATE := $(strip $(notdir $(LOCAL_CERTIFICATE)))
   $(my).prebuilt.$(LOCAL_MODULE).LOCAL_REQUIRED_MODULES := $(strip $(LOCAL_REQUIRED_MODULES))
   $(my).prebuilt.$(LOCAL_MODULE).LOCAL_MODULE_PATH := $(strip $(subst $(HOST_OUT),$$(HOST_OUT),$(subst $(PRODUCT_OUT),$$(PRODUCT_OUT),$(LOCAL_MODULE_PATH))))
endif
ifneq ($(filter custom_external,$(_metatarget)),)
   $(my).copyfiles := $($(my).copyfiles) $(LOCAL_BUILT_MODULE):$(dir $(my))$(notdir $(LOCAL_BUILT_MODULE))
   $(my).extramakefile := $($(my).extramakefile) $(LOCAL_PATH)/external_Android.mk
endif
# another special case with phony_package, which is a way to define a metapackage that justs
# depends on other packages
ifneq ($(filter phony_package,$(_metatarget)),)
   $(my).phony := $($(my).phony) $(LOCAL_MODULE)
   $(my).phony.$(LOCAL_MODULE).LOCAL_REQUIRED_MODULES := $(LOCAL_REQUIRED_MODULES)
endif

###################################### dependencies #########################################
$(LOCAL_MODULE_PREBUILT_MAKEFILE): $(LOCAL_MODULE_MAKEFILE)
$(LOCAL_MODULE_PREBUILT_MAKEFILE): $(call several-files-deps, $($(LOCAL_MODULE_PREBUILT_MAKEFILE).copyfiles))
# If the module is installable, we store the prebuilt makefile to ALL_MODULES.$(LOCAL_INSTALLED_MODULE).PREBUILT_MAKEFILE.
# This will allow to filter dependencies of intel_prebuilts target, based on what is installed.
# For other modules like static or host classes, which are not installable, we store the prebuilt makefile to a single variable.
# This is the same for copy_headers metatarget which does not define a module.
# We use the sort function to remove duplicates from dependencies list.
ifneq ($(filter shared_library executable raw_executable package java_library native_test prebuilt multi_prebuilt,$(_metatarget)),)
    ifndef LOCAL_UNINSTALLABLE_MODULE
        ALL_MODULES.$(LOCAL_INSTALLED_MODULE).PREBUILT_MAKEFILE := \
            $(sort $(strip $(ALL_MODULES.$(LOCAL_INSTALLED_MODULE).PREBUILT_MAKEFILE)) $(LOCAL_MODULE_PREBUILT_MAKEFILE))
    else
        INTEL_PREBUILTS_MAKEFILE := $(sort $(strip $(INTEL_PREBUILTS_MAKEFILE)) $(LOCAL_MODULE_PREBUILT_MAKEFILE))
    endif
else
    INTEL_PREBUILTS_MAKEFILE := $(sort $(strip $(INTEL_PREBUILTS_MAKEFILE)) $(LOCAL_MODULE_PREBUILT_MAKEFILE))
endif

###################################### cleanups of local variables #########################################

# cleanup local shortcut for LOCAL_MODULE_PREBUILT_MAKEFILE
my :=
endif # is /PRIVATE/
_metatarget :=
_need_prebuilts :=
else # metatarget neq ''
include $(call original-metatarget)
endif
