all: site

##################################
# Directories
##################################
TARGET_DIR = site
BUILD_DIR = build
TEMPLATE_DIR = template
V ?= @

CONFIG = site.yaml
POSTS = $(shell find _posts -name "*.md")
POSTS_MDHTML = $(POSTS_YAML:.yaml=.md.html)
POSTS_DEP = $(POSTS_YAML:.yaml=.d)

GPG = gpg2

RENDER = ./scripts/render.py

#################################
# Markdown to HTML
#################################
CDN_FILTER = ./scripts/cdn_filter.py
$(BUILD_DIR)/%.md.html: %.md $(CONFIG) $(CDN_FILTER)
	$(V)echo "[PANDOC]" "$<"
	$(V)mkdir -pv $(dir $@)
	$(V)pandoc $< -f markdown-auto_identifiers-implicit_figures \
		-t html --mathml -o $@
	$(V)$(CDN_FILTER) $@ $(CONFIG) 2> /dev/null

#################################
# GPG Sign content
#################################

$(BUILD_DIR)/%.md.asc: %.md
	$(V)echo "[GPG]" "$<" "..."
	$(V)$(GPG) --sign -a -o $@ $<

#################################
# Post Metadata
#################################
YAML_CALC_RELATED = ./scripts/posts_related.py
YAML_ADD_BODY = ./scripts/posts_addbody.py

POSTS_YAML = $(addprefix $(BUILD_DIR)/,$(POSTS:.md=.yaml))
POSTS_YAML_RAW = $(addprefix $(BUILD_DIR)/,$(POSTS:.md=.yaml.raw))
# Extract metadata from post source, and date from filename
$(BUILD_DIR)/%.yaml.raw: %.md $(BUILD_DIR)/%.md.html $(YAML_ADD_BODY)
	$(V)echo "[YAML]" "$<"
	$(V)mkdir -pv $(dir $@)
	$(V)echo "date: "$$(date -d $$(basename "$<" | cut -d - -f 1-3) +%Y-%m-%d 2> /dev/null) > $@
	$(V)echo "date_human: "$$(date -d $$(basename "$<" | cut -d - -f 1-3) "+%d %b %Y" 2> /dev/null) >> $@
	$(V)echo "date_rss: "$$(date -d $$(basename "$<" | cut -d - -f 1-3) "+%a, %d %b %Y %H:%M:%S %Z" 2> /dev/null) >> $@
	$(V)sed -e '1d' -e '/---/q' "$<" | sed -e 's/---//' >> $@
	$(V)$(YAML_ADD_BODY) $@ $(word 2,$^)

$(BUILD_DIR)/posts.yaml: $(POSTS_YAML_RAW) $(YAML_CALC_RELATED)
	$(V)echo "[YAML] All Posts"
	$(V)$(YAML_CALC_RELATED) $(POSTS_YAML_RAW) > $(BUILD_DIR)/posts.yaml

$(BUILD_DIR)/%.yaml: $(BUILD_DIR)/posts.yaml
	$(V)true

#################################
# Template Dependency
#################################

$(TEMPLATE_DIR)/index.html: $(TEMPLATE_DIR)/base.html
	$(V)touch $@

$(TEMPLATE_DIR)/post.html: $(TEMPLATE_DIR)/base.html
	$(V)touch $@

$(TEMPLATE_DIR)/friends.html: $(TEMPLATE_DIR)/base.html
	$(V)touch $@

#################################
# Friends Page
#################################
$(TARGET_DIR)/friends/index.html: $(TEMPLATE_DIR)/friends.html friends.yaml
	$(V)echo "[RENDER] Friends"
	$(V)mkdir -pv $(dir $@)
	$(V)$(RENDER) --dir $(TEMPLATE_DIR) \
		--data site:$(CONFIG) friends:friends.yaml \
		--template friends.html > $@

$(TARGET_DIR)/_pjax/friends/index.html: $(TEMPLATE_DIR)/friends.html friends.yaml
	$(V)echo "[RENDER PJAX] Friends"
	$(V)mkdir -pv $(dir $@)
	$(V)$(RENDER) --dir $(TEMPLATE_DIR) \
		--data site:$(CONFIG) friends:friends.yaml pjax: \
		--template friends.html > $@

indexpages: $(TARGET_DIR)/friends/index.html
indexpages: $(TARGET_DIR)/_pjax/friends/index.html

#################################
# Index Pages
#################################
define indexpagerule
$$(BUILD_DIR)/indexpage-$(1)-page.yaml:
	$$(V)mkdir -pv $$(dir $$@)
	$$(V)echo "classification: $(1)" > $$@

$$(TARGET_DIR)/$(1)/index.html: $$(CONFIG) $$(BUILD_DIR)/posts.yaml \
								$$(BUILD_DIR)/indexpage-$(1)-page.yaml \
								$$(TEMPLATE_DIR)/index.html $$(RENDER)
	$$(V)echo "[RENDER] Index" "$(1)"
	$$(V)mkdir -pv $$(dir $$@)
	$$(V)$(RENDER) --dir $(TEMPLATE_DIR) \
			--data site:$$(CONFIG) posts:$$(BUILD_DIR)/posts.yaml \
			page:$$(BUILD_DIR)/indexpage-$(1)-page.yaml \
			--template index.html > $$@

$$(TARGET_DIR)/_pjax/$(1)/index.html: $$(CONFIG) $$(BUILD_DIR)/posts.yaml \
									$$(BUILD_DIR)/indexpage-$(1)-page.yaml \
									$$(TEMPLATE_DIR)/index.html $$(RENDER)
	$$(V)echo "[RENDER PJAX] Index" "$(1)"
	$$(V)mkdir -pv $$(dir $$@)
	$$(V)$(RENDER) --dir $(TEMPLATE_DIR) \
			--data site:$$(CONFIG) posts:$$(BUILD_DIR)/posts.yaml \
			page:$$(BUILD_DIR)/indexpage-$(1)-page.yaml pjax: \
			--template index.html > $$@

indexpages: $$(TARGET_DIR)/$(1)/index.html $$(TARGET_DIR)/_pjax/$(1)/index.html
endef

$(eval $(call indexpagerule,))  # All
$(eval $(call indexpagerule,tech))
$(eval $(call indexpagerule,misc))
$(eval $(call indexpagerule,project))
$(eval $(call indexpagerule,life))

site: indexpages


define extrapagerule
$$(TARGET_DIR)/$(1)/index.html: $$(TEMPLATE_DIR)/$(1).html $$(RENDER) $$(CONFIG)
	$$(V)echo "[Render] Page" "$(1)"
	$$(V)mkdir -pv $$(dir $$@)
	$$(V)$$(RENDER) --dir $$(TEMPLATE_DIR) \
		--data site:$$(CONFIG) $(1): --template $(1).html > $$@

$$(TARGET_DIR)/_pjax/$(1)/index.html: $$(TEMPLATE_DIR)/$(1).html $$(RENDER) $$(CONFIG)
	$$(V)echo "[Render PJAX] Page" "$(1)"
	$$(V)mkdir -pv $$(dir $$@)
	$$(V)$$(RENDER) --dir $$(TEMPLATE_DIR) \
		--data site:$$(CONFIG) $(1): pjax: --template $(1).html > $$@

$$(TEMPLATE_DIR)/$(1).html: $$(TEMPLATE_DIR)/base.html
	$$(V)touch $$@

extrapages: $$(TARGET_DIR)/$(1)/index.html $$(TARGET_DIR)/_pjax/$(1)/index.html
endef

$(eval $(call extrapagerule,404))
$(eval $(call extrapagerule,search))

site: extrapages

#################################
# Feed XML
#################################
RSS_FEED = feeds/all.rss.xml
$(TARGET_DIR)/$(RSS_FEED): $(TEMPLATE_DIR)/all.rss.xml $(CONFIG) \
							$(BUILD_DIR)/posts.yaml $(RENDER)
	$(V)echo "[RENDER] all.rss.xml"
	$(V)mkdir -pv $(dir $@)
	$(V)$(RENDER) --dir $(TEMPLATE_DIR) \
		--data site:$(CONFIG) posts:$(BUILD_DIR)/posts.yaml \
		--template all.rss.xml > $@

site: $(TARGET_DIR)/$(RSS_FEED)

##################################
# Static Files
##################################
CSS_SRCS = css/syntax.css css/post.css css/main.css
CSS_TARGET = css/min.css
MINIFY = python -m csscompressor

$(TARGET_DIR)/$(CSS_TARGET): $(CSS_SRCS)
	$(V)echo "[MINIFY]" "$^" "->" "$@"
	$(V)mkdir -pv $(dir $@)
	$(V)$(MINIFY) $^ > $@

site: $(TARGET_DIR)/$(CSS_TARGET)

STATIC_FOLDERS = js files/ images/ favicon.png css/font-awesome-4.4.0 .well-known
define staticrule
$$(TARGET_DIR)/$(1): .FORCE
	$$(V)echo "[CP]" "$(1)"
	$$(V)mkdir -pv $$(dir $$@)
	$$(V)rm -rf $$@
	$$(V)cp -r $(1) $$@

site: $$(TARGET_DIR)/$(1)

endef

$(foreach folder,$(STATIC_FOLDERS),$(eval $(call staticrule,$(folder))))

#################################
# Posts
#################################
define postrule
$$(TARGET_DIR)/$(2): $$(BUILD_DIR)/$(1).html \
							$$(CONFIG) $$(BUILD_DIR)/$(3).yaml \
							$$(TEMPLATE_DIR)/post.html \
							$$(RENDER)
	$$(V)echo "[RENDER]" "$(2)"
	$$(V)mkdir -pv $$(dir $$@)
	$$(V)$$(RENDER) --dir $$(TEMPLATE_DIR) \
		--data site:$$(CONFIG) page:$$(BUILD_DIR)/$(3).yaml \
		--template post.html > $$@

$$(TARGET_DIR)/_pjax/$(2): $$(BUILD_DIR)/$(1).html \
							$$(CONFIG) $$(BUILD_DIR)/$(3).yaml \
							$$(TEMPLATE_DIR)/post.html \
							$$(RENDER)
	$$(V)echo "[RENDER PJAX]" "$(2)"
	$$(V)mkdir -pv $$(dir $$@)
	$$(V)$$(RENDER) --dir $$(TEMPLATE_DIR) \
		--data site:$$(CONFIG) page:$$(BUILD_DIR)/$(3).yaml pjax: \
		--template post.html > $$@

$$(TARGET_DIR)/_sig/$(2): $$(BUILD_DIR)/$(1).asc \
							$$(TEMPLATE_DIR)/sig.html \
							$$(RENDER)
	$$(V)echo "[RENDER SIG]" "$(2)"
	$$(V)mkdir -pv $$(dir $$@)
	$$(V)$$(RENDER) --dir $$(TEMPLATE_DIR) \
		--body $$< --template sig.html > $$@

site: $$(TARGET_DIR)/$(2) $$(TARGET_DIR)/_pjax/$(2) $$(TARGET_DIR)/_sig/$(2)

endef

postrule_wrap=$(call postrule,$(1),$(shell grep "permalink:" "$(1)" | sed -e "s/.*:[ ]*//" -e "s/\/\$$/\/index.html/"),$(shell dirname "$(1)")/$(shell basename "$(1)" .md))

$(foreach post,$(POSTS),$(eval $(call postrule_wrap,$(post))))

################################
# Badges
################################

BADGES = $(shell find badges -name "*.txt")
BADGES_SVG = $(addprefix $(TARGET_DIR)/,$(BADGES:.txt=.svg))

$(TARGET_DIR)/badges/%.svg: badges/%.txt
	$(V)echo "[WGET]" "$<"
	$(V)mkdir -pv $(dir $@)
	$(V)cat $< | xargs wget -O $@ 2> /dev/null
	$(V)touch $@

$(TARGET_DIR)/badges/posts-number.svg: $(BUILD_DIR)/posts.yaml $(RENDER) \
								       badges/posts-number.txt.jinja2
	$(V)echo "[WGET]" "badges/posts-number.txt"
	$(V)mkdir -pv $(dir $@)
	$(V)$(RENDER) --dir badges --data posts:$< \
		--template posts-number.txt.jinja2 | xargs wget -O $@ 2> /dev/null
	$(V)touch $@

site: $(BADGES_SVG) $(TARGET_DIR)/badges/posts-number.svg

#################################
# Other Rules
#################################

clean:
	rm -rf $(BUILD_DIR) $(TARGET_DIR)

SSH_PORT ?= 22
SSH_USER ?= blahgeek
SSH_HOST ?= blog.blahgeek.com
SSH_TARGET_DIR ?= /srv/http/blog.blahgeek.com/

love:
	rsync -e "ssh -p $(SSH_PORT)" -P -rvz --delete $(TARGET_DIR) $(SSH_USER)@$(SSH_HOST):$(SSH_TARGET_DIR)


.FORCE:

.PHONY: site indexpages clean all love .FORCE
