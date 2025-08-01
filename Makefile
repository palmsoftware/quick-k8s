# Makefile for quick-k8s GitHub Action

.PHONY: lint help clean

# Default target
help:
	@echo "Available targets:"
	@echo "  lint     - Run shellcheck on all shell scripts"
	@echo "  clean    - Remove temporary files"
	@echo "  help     - Show this help message"

# Lint all shell scripts using shellcheck
lint:
	@echo "🔍 Running shellcheck on shell scripts..."
	@failed=0; \
	for script in $$(find scripts/ -name "*.sh" -type f); do \
		echo "Checking: $$script"; \
		if shellcheck "$$script"; then \
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