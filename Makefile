# Makefile for quick-k8s GitHub Action

.PHONY: lint test help clean tool-precheck bats-precheck

# Default target
help:
	@echo "Available targets:"
	@echo "  lint          - Run shellcheck on all shell scripts"
	@echo "  test          - Run Docker-free BATS tests for shell helpers"
	@echo "  tool-precheck - Check for shellcheck"
	@echo "  bats-precheck - Check for BATS"
	@echo "  clean         - Remove temporary files"
	@echo "  help          - Show this help message"

# Check for required tools
tool-precheck:
	@echo "🔍 Checking for shellcheck installation..."
	@if ! command -v shellcheck >/dev/null 2>&1; then \
		echo "❌ shellcheck is not installed!"; \
		echo ""; \
		echo "📦 To install shellcheck:"; \
		echo "  • macOS:    brew install shellcheck"; \
		echo "  • Ubuntu:   sudo apt-get install shellcheck"; \
		echo "  • RHEL/CentOS: sudo yum install ShellCheck"; \
		echo "  • Arch:     sudo pacman -S shellcheck"; \
		echo "  • Or visit: https://github.com/koalaman/shellcheck#installing"; \
		echo ""; \
		exit 1; \
	fi
	@echo "✅ shellcheck found"

# Check for required test runner
bats-precheck:
	@echo "🔍 Checking for BATS installation..."
	@if ! command -v bats >/dev/null 2>&1; then \
		echo "❌ BATS is not installed!"; \
		echo ""; \
		echo "📦 To install BATS:"; \
		echo "  • macOS:  brew install bats"; \
		echo "  • Ubuntu: sudo apt-get install bats"; \
		echo "  • Or visit: https://bats-core.readthedocs.io/"; \
		echo ""; \
		exit 1; \
	fi
	@echo "✅ BATS found"

# Run fast tests for sourceable shell helpers
test: bats-precheck
	@bats tests/*.bats

# Lint all shell scripts using shellcheck
lint: tool-precheck
	@echo "🔍 Running shellcheck on shell scripts..."
	@failed=0; \
	for script in $$(find scripts/ -name "*.sh" -type f); do \
		echo "Checking: $$script"; \
		if shellcheck -x --source-path=scripts "$$script"; then \
			echo "✅ $$script passed"; \
		else \
			echo "❌ $$script failed"; \
			failed=$$((failed + 1)); \
		fi; \
		echo ""; \
	done; \
	if [ $$failed -eq 0 ]; then \
		echo "🎉 All shell scripts passed shellcheck!"; \
	else \
		echo "⚠️  $$failed script(s) failed shellcheck - see output above"; \
		echo "Run 'shellcheck scripts/<script>' to see detailed issues"; \
		exit 1; \
	fi

# Clean up temporary files
clean:
	@echo "🧹 Cleaning up temporary files..."
	@rm -f kind-config.yaml || true
	@rm -f oc.tar.gz kind || true
	@echo "✅ Cleanup completed"
