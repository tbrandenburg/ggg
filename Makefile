.DEFAULT_GOAL := help

UV ?= uv
GAME ?=
DIMENSION ?= 2d
PLATFORM ?= linux
ARGS ?=

.PHONY: help sync setup setup-templates doctor list gallery new play edit check smoke test lint format build

help: ## Show available targets and examples
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@printf '\nExamples:\n  make new GAME=moon-jumper DIMENSION=2d\n  make play GAME=moon-jumper\n  make build PLATFORM=linux\n  make check ARGS=--smoke\n'

sync: ## Install Python, the editable CLI, and locked development tools
	$(UV) sync --locked

setup: sync ## Sync the environment and download the pinned Godot engine
	$(UV) run ggg setup $(ARGS)

setup-templates: sync ## Set up Godot and export templates (about 1.3 GB extra)
	$(UV) run ggg setup --templates $(ARGS)

doctor: ## Check Python, manifests, and Godot
	$(UV) run ggg doctor $(ARGS)

list: ## List discovered games
	$(UV) run ggg list $(ARGS)

gallery: ## Open the native game gallery
	$(UV) run ggg gallery $(ARGS)

new: ## Create a game: GAME=name DIMENSION=2d or 3d
	@test -n "$(GAME)" || { printf 'Usage: make new GAME=moon-jumper DIMENSION=2d\n' >&2; exit 2; }
	$(UV) run ggg new "$(GAME)" --dimension "$(DIMENSION)" $(ARGS)

play: ## Run a game: GAME=name
edit: ## Open a game in Godot: GAME=name
play edit:
	@test -n "$(GAME)" || { printf 'Usage: make $@ GAME=moon-jumper\n' >&2; exit 2; }
	$(UV) run ggg $@ "$(GAME)" $(ARGS)

check: ## Validate manifests and required files without Godot
	$(UV) run ggg check $(ARGS)

smoke: ## Import and smoke-test the gallery, games, and templates with Godot
	$(UV) run ggg check --smoke $(ARGS)

test: ## Run Python behavioral tests
	$(UV) run python -m unittest discover -s tests -v

lint: ## Check Python lint and Python/GDScript formatting
	$(UV) run ruff check .
	$(UV) run ruff format --check .
	$(UV) run gdformat --check launcher templates games tools/*.gd

format: ## Format Python and GDScript
	$(UV) run ruff format .
	$(UV) run gdformat launcher templates games tools/*.gd

build: ## Export games and gallery: PLATFORM=linux or macos
	$(UV) run ggg build --platform "$(PLATFORM)" $(ARGS)
