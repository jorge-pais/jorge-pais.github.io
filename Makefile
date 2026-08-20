SHELL    := /bin/bash
SITE     := _site
TMPL     := templates

PANDOC       := pandoc --from=markdown+smart+raw_html --to=html
PANDOC_PAGE  := $(PANDOC) --template=$(TMPL)/page.html
PANDOC_POST  := $(PANDOC) --template=$(TMPL)/post.html --highlight-style=breezedark

.PHONY: all pages posts assets clean serve

all: assets pages posts

# ─── WEBSITE ASSETS ────────────────────────────────────────────────────────────

assets: $(SITE)/css/main.css $(SITE)/img $(SITE)/favicon.ico

$(SITE)/css/main.css: css/main.css | $(SITE)/css
	cp $< $@

$(SITE)/css:
	mkdir -p $@

$(SITE)/img: img | $(SITE)
	cp -r $< $@

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
