TOP_DIR = ../..
include $(TOP_DIR)/tools/Makefile.common

TARGET ?= /kb/deployment
DEPLOY_RUNTIME ?= /vol/kbase/runtime

all: bin

bin: $(BIN_PERL)

include $(TOP_DIR)/tools/Makefile.common.rules
