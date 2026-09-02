SHELL    := /bin/bash
SITE     := _site
TMPL     := templates

PANDOC       := pandoc --from=markdown+smart+raw_html --to=html
PANDOC_PAGE  := $(PANDOC) --template=$(TMPL)/page.html
PANDOC_POST  := $(PANDOC) --template=$(TMPL)/post.html --highlight-style=breezedark

IMAGES := $(shell find img -type f 2>/dev/null)
SITE_IMAGES := $(patsubst img/%,$(SITE)/img/%,$(IMAGES))

.PHONY: all pages posts assets clean serve

all: assets pages posts

# ─── WEBSITE ASSETS ────────────────────────────────────────────────────────────

assets: $(SITE)/css/main.css $(SITE)/favicon.ico $(SITE_IMAGES)

$(SITE)/css/main.css: css/main.css | $(SITE)/css
	cp $< $@

$(SITE)/css:
	mkdir -p $@

define copy-image
$(SITE)/img/$(1): img/$(1)
	@echo "  [ASSETS] copying $$<"
	@mkdir -p $$(dir $$@)
	@cp $$< $$@
endef

# Generate rules for each image
$(foreach img,$(IMAGES:img/%=%),$(eval $(call copy-image,$(img))))

$(SITE)/favicon.ico: favicon.ico | $(SITE)
	cp $< $@

$(SITE):
	mkdir -p $@

# ─── PAGES ─────────────────────────────────────────────────────────────────────

pages: $(SITE)/index.html $(SITE)/resume/index.html $(SITE)/articles/index.html

$(SITE)/index.html: index.md $(TMPL)/page.html | $(SITE)
	@echo "  [PAGE] index"
	@$(PANDOC_PAGE) $< -o $@

$(SITE)/resume/index.html: resume.md $(TMPL)/page.html | $(SITE)/resume
	@echo "  [PAGE] resume"
	@$(PANDOC_PAGE) $< -o $@

$(SITE)/articles/index.html: articles.md $(TMPL)/page.html | $(SITE)/articles
	@echo "  [PAGE] articles"
	@$(PANDOC_PAGE) $< -o $@

$(SITE)/resume $(SITE)/articles:
	mkdir -p $@

# ─── POSTS ─────────────────────────────────────────────────────────────────────
# Filename format: _posts/YYYY-MM-DD-slug-text.md
# Output:          _site/projects/YYYY/MM/DD/slug-text/index.html
# Prev/next nav:   passed as --variable prev_url=... etc. (sorted by filename)

posts: $(TMPL)/post.html
	@bash tools/build-posts.sh $(SITE) $(TMPL)/post.html

# ─── DEV SERVER ────────────────────────────────────────────────────────────────

serve: all
	@echo "Serving at http://localhost:8000"
	@cd $(SITE) && python3 -m http.server 8000

# ─── CLEAN ─────────────────────────────────────────────────────────────────────

clean:
	rm -rf $(SITE)
