#
# mal (Make Lisp)
#
_TOP_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
include $(_TOP_DIR)types.mk
include $(_TOP_DIR)reader.mk
include $(_TOP_DIR)printer.mk
include $(_TOP_DIR)env.mk
include $(_TOP_DIR)core.mk

SHELL := /bin/bash
INTERACTIVE ?= yes
EVAL_DEBUG ?=

# READ: read and parse input
define READ
$(if $(READLINE_EOF)$(__ERROR),,$(call READ_STR,$(if $(1),$(1),$(call READLINE,"user> "))))
endef

# EVAL: evaluate the parameter
IS_PAIR = $(if $(call _EQ,list,$(call _obj_type,$(1))),$(if $(call _EQ,0,$(call _count,$(1))),,true),)

define QUASIQUOTE
$(strip \
  $(if $(call _NOT,$(call IS_PAIR,$(1))),\
    $(call _list,$(call _symbol,quote) $(1)),\
    $(if $(call _EQ,unquote,$($(call _nth,$(1),0)_value)),\
      $(call _nth,$(1),1),\
      $(if $(and $(call IS_PAIR,$(call _nth,$(1),0)),$(call _EQ,splice-unquote,$($(call _nth,$(call _nth,$(1),0),0)_value))),\
        $(call _list,$(call _symbol,concat) $(call _nth,$(call _nth,$(1),0),1) $(call QUASIQUOTE,$(call srest,$(1)))),\
        $(call _list,$(call _symbol,cons) $(call QUASIQUOTE,$(call _nth,$(1),0)) $(call QUASIQUOTE,$(call srest,$(1))))))))
endef

define LET
$(strip \
  $(word 1,$(2) \
    $(foreach var,$(call _nth,$(1),0),\
      $(foreach val,$(call _nth,$(1),1),\
        $(call ENV_SET,$(2),$($(var)_value),$(call EVAL,$(val),$(2)))\
        $(foreach left,$(call srest,$(call srest,$(1))),
          $(if $(call _EQ,0,$(call _count,$(left))),\
            ,\
            $(call LET,$(left),$(2))))))))
endef

define EVAL_AST
$(strip \
  $(and $(EVAL_DEBUG),$(info EVAL_AST: $(call _pr_str,$(1))))\
  $(if $(call _symbol?,$(1)),\
    $(foreach key,$($(1)_value),\
      $(call ENV_GET,$(2),$(key))),\
  $(if $(call _list?,$(1)),\
    $(call _smap,EVAL,$(1),$(2)),\
  $(if $(call _vector?,$(1)),\
    $(call _smap_vec,EVAL,$(1),$(2)),\
  $(if $(call _hash_map?,$(1)),\
    $(foreach new_hmap,$(call __new_obj,hmap),\
      $(foreach v,$(call __get_obj_values,$(1)),\
        $(eval $(v:$(1)_%=$(new_hmap)_%) := $(call EVAL,$($(v)),$(2))))\
      $(eval $(new_hmap)_size := $($(1)_size))\
      $(new_hmap)),\
  $(1))))))
endef

define EVAL_INVOKE
$(if $(__ERROR),,\
  $(and $(EVAL_DEBUG),$(info EVAL_INVOKE: $(call _pr_str,$(1))))
  $(foreach a0,$(call _nth,$(1),0),\
    $(if $(call _EQ,def!,$($(a0)_value)),\
      $(foreach a1,$(call _nth,$(1),1),\
        $(foreach a2,$(call _nth,$(1),2),\
          $(foreach res,$(call EVAL,$(a2),$(2)),\
            $(if $(call ENV_SET,$(2),$($(a1)_value),$(res)),$(res),)))),\
    $(if $(call _EQ,let*,$($(a0)_value)),\
      $(foreach a1,$(call _nth,$(1),1),\
        $(foreach a2,$(call _nth,$(1),2),\
          $(call EVAL,$(a2),$(call LET,$(a1),$(call ENV,$(2)))))),\
    $(if $(call _EQ,quote,$($(a0)_value)),\
      $(call _nth,$(1),1),\
    $(if $(call _EQ,quasiquote,$($(a0)_value)),\
      $(call EVAL,$(call QUASIQUOTE,$(call _nth,$(1),1)),$(2)),\
    $(if $(call _EQ,do,$($(a0)_value)),\
      $(call slast,$(call EVAL_AST,$(call srest,$(1)),$(2))),\
    $(if $(call _EQ,if,$($(a0)_value)),\
      $(foreach a1,$(call _nth,$(1),1),\
        $(foreach a2,$(call _nth,$(1),2),\
          $(foreach cond,$(call EVAL,$(a1),$(2)),\
            $(if $(or $(call _EQ,$(__nil),$(cond)),$(call _EQ,$(__false),$(cond))),\
              $(foreach a3,$(call _nth,$(1),3),$(call EVAL,$(a3),$(2))),\
              $(call EVAL,$(a2),$(2)))))),\
    $(if $(call _EQ,fn*,$($(a0)_value)),\
      $(foreach a1,$(call _nth,$(1),1),\
        $(foreach a2,$(call _nth,$(1),2),\
          $(call _function,$$(call EVAL,$(a2),$$(call ENV,$(2),$(a1),$$1))))),\
      $(foreach el,$(call EVAL_AST,$(1),$(2)),\
        $(and $(EVAL_DEBUG),$(info invoke: $(call _pr_str,$(el))))\
        $(foreach f,$(call sfirst,$(el)),\
          $(foreach args,$(call srest,$(el)),\
            $(call apply,$(f),$(args))))))))))))))
endef

define EVAL
$(strip $(if $(__ERROR),,\
  $(and $(EVAL_DEBUG),$(info EVAL: $(call _pr_str,$(1))))\
  $(if $(call _list?,$(1)),\
    $(word 1,$(strip $(call EVAL_INVOKE,$(1),$(2)) $(__nil))),\
    $(call EVAL_AST,$(1),$(2)))))
endef


# PRINT:
define PRINT
$(if $(__ERROR),Error: $(call _pr_str,$(__ERROR),yes),$(if $(1),$(call _pr_str,$(1),yes)))$(if $(__ERROR),$(eval __ERROR :=),)
endef

# REPL:
REPL_ENV := $(call ENV)
REP = $(call PRINT,$(strip $(call EVAL,$(strip $(call READ,$(1))),$(REPL_ENV))))
REPL = $(info $(call REP,$(call READLINE,"user> ")))$(if $(READLINE_EOF),,$(call REPL))

# Setup the environment
_ref = $(eval REPL_ENV := $(call ENV_SET,$(REPL_ENV),$(1),$(if $(2),$(2),$(1))))
_fref = $(eval REPL_ENV := $(call ENV_SET,$(REPL_ENV),$(1),$(call _function,$$(call $(2),$$1))))

# Import core namespace
_import_core = $(if $(strip $(1)),$(call _fref,$(word 1,$(1)),$(word 2,$(1)))$(call _import_core,$(wordlist 3,$(words $(1)),$(1))),)
$(call _import_core,$(core_ns))

$(call _ref,read-string,$(call _function,$$(call READ_STR,$$(1))))
$(call _ref,eval,$(call _function,$$(call EVAL,$$(1),$$(REPL_ENV))))

_slurp = $(call _string,$(call _read_file,$(1)))
$(call _ref,slurp,$(call _function,$$(call _slurp,$$(call str_decode,$$($$(1)_value)))))

# Defined in terms of the language itself
$(call do,$(call REP, (def! not (fn* (a) (if a false true))) ))
$(call do,$(call REP, (def! load-file (fn* (f) (eval (read-string (str "(do " (slurp f) ")"))))) ))

# Load and eval any files specified on the command line
$(if $(MAKECMDGOALS),\
  $(foreach file,$(MAKECMDGOALS),$(call do,$(call REP, (load-file "$(file)") )))\
  $(eval INTERACTIVE :=),)
.PHONY: none $(MAKECMDGOALS)
none $(MAKECMDGOALS):
	@true

# Call the read-eval-print loop
$(if $(strip $(INTERACTIVE)),$(call REPL))
