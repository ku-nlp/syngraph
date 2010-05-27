# $Id$

CURDIR = $(shell pwd)
DATE = $(shell date '+%y%m%d')

SYNGRAPHDIR = ..
ABS_SYNGRAPHDIR = $(CURDIR)/$(SYNGRAPHDIR)

DICDIR = $(SYNGRAPHDIR)/dic/rsk_iwanami
ABS_DICDIR = $(CURDIR)/$(DICDIR)

GXP3DIR = $(HOME)/work/gxp3
TASKSFILTERSYN = $(GXP3DIR)/tasks/tasks-calc-sim-synonym
TASKSFILTERISA = $(GXP3DIR)/tasks/tasks-calc-sim-isa

SYNONYM_TXT = $(DICDIR)/synonym.txt
SYNONYM_FILTERED = $(DICDIR)/synonym.txt.filtered
ISA_TXT = $(DICDIR)/isa.txt
ISA_FILTERED = $(DICDIR)/isa.txt.filtered

$(SYNONYM_FILTERED): splitsyn $(SYNONYM_TXT)
	perl generate_tasks_calc_sim.pl -exedate $(DATE) -syngraphdir $(ABS_SYNGRAPHDIR) > $(TASKSFILTERSYN)
	./calc-similarity-synonym-gxp3.sh -t $(TASKSFILTERSYN) -e $(DATE) -s $(ABS_SYNGRAPHDIR) -d $(ABS_DICDIR)

splitsyn: $(SYNONYM_TXT)
	mkdir -p $(SYNGRAPHDIR)/dic/calcsim/div
	rm -f $(SYNGRAPHDIR)/dic/calcsim/div/synonym*.orig
	perl div_synonym_dic.pl -outdir $(SYNGRAPHDIR)/dic/calcsim/div $(SYNONYM_TXT)

$(ISA_FILTERED): splitisa $(ISA_TXT)
	perl generate_tasks_calc_sim.pl -isa -exedate $(DATE) -syngraphdir $(ABS_SYNGRAPHDIR) > $(TASKSFILTERISA)
	./calc-similarity-synonym-gxp3.sh -i -t $(TASKSFILTERISA) -e $(DATE) -s $(ABS_SYNGRAPHDIR) -d $(ABS_DICDIR)

splitisa: $(ISA_TXT)
	mkdir -p $(SYNGRAPHDIR)/dic/calcsim/div
	rm -f $(SYNGRAPHDIR)/dic/calcsim/div/isa*.orig
	perl div_synonym_dic.pl -outdir $(SYNGRAPHDIR)/dic/calcsim/div $(ISA_TXT)
