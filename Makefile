DEST ?= /usr/local/bin

all:
	@echo \'make install\' to install mpnotd

install:
	@install -Dm 755 mpnotd.zsh $(DEST)/mpnotd
	@echo mpnotd installed

uninstall:
	@rm -f $(DEST)/mpnotd
	@echo mpnotd.zsh uninstalled
