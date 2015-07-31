all: site

##################################
# Directories
##################################
TARGET_DIR = site
BUILD_DIR = build
TEMPLATE_DIR = template

CONFIG = site.yaml
POSTS = $(shell find _posts -name "*.md")
POSTS_MDHTML = $(POSTS_YAML:.yaml=.md.html)
POSTS_DEP = $(POSTS_YAML:.yaml=.d)

RENDER = ./scripts/render.py

#################################
# Markdown to HTML
#################################
CDN_FILTER = ./scripts/cdn_filter.py
$(BUILD_DIR)/%.md.html: %.md $(CONFIG)
	@mkdir -pv $(dir $@)
	pandoc $< -f markdown-auto_identifiers-implicit_figures \
		-t html -o $@
	$(CDN_FILTER) $@ $(CONFIG) 2> /dev/null

#################################
# Post Metadata
#################################
YAML_CALC_RELATED = ./scripts/posts_related.py
YAML_ADD_BODY = ./scripts/posts_addbody.py

POSTS_YAML = $(addprefix $(BUILD_DIR)/,$(POSTS:.md=.yaml))
POSTS_YAML_RAW = $(addprefix $(BUILD_DIR)/,$(POSTS:.md=.yaml.raw))
# Extract metadata from post source, and date from filename
$(BUILD_DIR)/%.yaml.raw: %.md $(BUILD_DIR)/%.md.html $(YAML_ADD_BODY)
	@mkdir -pv $(dir $@)
	echo "date: "$$(date -j -f %Y-%m-%d $$(basename "$<") +%Y-%m-%d 2> /dev/null) > $@
	echo "date_human: "$$(date -j -f "%Y-%m-%d" $$(basename "$<") "+%d %b %Y" 2> /dev/null) >> $@
	sed -e '1d' -e '/---/q' "$<" | sed -e 's/---//' >> $@
	$(YAML_ADD_BODY) $@ $(word 2,$^)

$(BUILD_DIR)/posts.yaml: $(POSTS_YAML_RAW) $(YAML_CALC_RELATED)
	$(YAML_CALC_RELATED) $(POSTS_YAML_RAW) > $(BUILD_DIR)/posts.yaml

$(BUILD_DIR)/%.yaml: $(BUILD_DIR)/posts.yaml
	@true

#################################
# Index Pages
#################################
define indexpagerule
$$(BUILD_DIR)/indexpage-$(1)-page.yaml:
	@mkdir -pv $$(dir $$@)
	echo "classification: $(1)" > $$@

$$(TARGET_DIR)/$(1)/index.html: $$(CONFIG) $$(BUILD_DIR)/posts.yaml \
								$$(BUILD_DIR)/indexpage-$(1)-page.yaml \
								$$(TEMPLATE_DIR)/index.html $$(RENDER)
	@mkdir -pv $$(dir $$@)
	$(RENDER) --data site:$$(CONFIG) posts:$$(BUILD_DIR)/posts.yaml \
			page:$$(BUILD_DIR)/indexpage-$(1)-page.yaml \
			--template $$(TEMPLATE_DIR)/index.html > $$@

indexpages: $$(TARGET_DIR)/$(1)/index.html
endef

$(eval $(call indexpagerule,))  # All
$(eval $(call indexpagerule,tech))
$(eval $(call indexpagerule,misc))
$(eval $(call indexpagerule,project))
$(eval $(call indexpagerule,life))

site: indexpages

#################################
# Feed XML
#################################
RSS_FEED = feeds/all.rss.xml
$(TARGET_DIR)/$(RSS_FEED): template/all.rss.xml $(CONFIG) \
							$(BUILD_DIR)/posts.yaml $(RENDER)
	@mkdir -pv $(dir $@)
	$(RENDER) --data site:$(CONFIG) posts:$(BUILD_DIR)/posts.yaml \
		--template "$<" > $@

site: $(TARGET_DIR)/$(RSS_FEED)

##################################
# Static Files
##################################
CSS_SRCS = css/syntax.css css/post.css css/main.css
CSS_TARGET = css/min.css

$(TARGET_DIR)/$(CSS_TARGET): $(CSS_SRCS)
	@mkdir -pv $(dir $@)
	minify $^ > $@

site: $(TARGET_DIR)/$(CSS_TARGET)

STATIC_FOLDERS = js files images favicon.png
define staticrule
$$(TARGET_DIR)/$(1): $(1)
	@mkdir -pv $$(dir $$@)
	cp -r $$< $$@

site: $$(TARGET_DIR)/$(1)

endef

$(foreach folder,$(STATIC_FOLDERS),$(eval $(call staticrule,$(folder))))

#################################
# Posts
#################################
define postrule
$$(TARGET_DIR)/$(2): $$(BUILD_DIR)/$(1).html \
							$$(CONFIG) $$(BUILD_DIR)/$(3).yaml \
							$$(TEMPLATE_DIR)/post.html $$(RENDER)
	@echo "Building" $(2) $(3)
	@mkdir -pv $$(dir $$@)
	$$(RENDER) --data site:$$(CONFIG) page:$$(BUILD_DIR)/$(3).yaml \
		--template $$(TEMPLATE_DIR)/post.html > $$@

site: $$(TARGET_DIR)/$(2)

endef

postrule_wrap=$(call postrule,$(1),$(shell grep "permalink:" "$(1)" | sed -e "s/.*:[ ]*//" -e "s/\/\$$/\/index.html/"),$(shell dirname "$(1)")/$(shell basename "$(1)" .md))

$(foreach post,$(POSTS),$(eval $(call postrule_wrap,$(post))))


#################################
# Other Rules
#################################

clean:
	rm -rf $(BUILD_DIR) $(TARGET_DIR)

SSH_PORT=22
SSH_USER=blahgeek
SSH_HOST=blog.blahgeek.com
SSH_TARGET_DIR=/srv/http/blog.blahgeek.com/

love:
	rsync -e "ssh -p $(SSH_PORT)" -P -rvz --delete $(TARGET_DIR) $(SSH_USER)@$(SSH_HOST):$(SSH_TARGET_DIR)


.PHONY: site indexpages clean all love
