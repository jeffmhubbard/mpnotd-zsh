NAME = mpnotd

PREFIX ?= /usr
XDG ?= /etc/xdg
DOCS ?= $(PREFIX)/share/doc/$(NAME)
LICENSE ?= $(PREFIX)/share/licenses/$(NAME)

install-bin:
	@echo installing $(NAME)...
	install -Dm 755 $(NAME).zsh $(PREFIX)/bin/$(NAME)

install-autostart:
	install -Dm 644 autostart/$(NAME).desktop $(XDG)/autostart/$(NAME).desktop

install-docs:
	install -Dm 644 docs/config.example $(DOCS)/config.example
	install -Dm 644 README.md $(DOCS)/README.md
	install -Dm 644 LICENSE $(LICENSE)/LICENSE

uninstall:
	@echo removing $(NAME)...
	rm -f $(PREFIX)/bin/$(NAME)
	rm -rf $(DOCS)/mpnotd
	rm -f $(LICENSE)/LICENSE
	rm -f $(XDG)/autostart/$(NAME).desktop

install: install-bin install-autostart install-docs
