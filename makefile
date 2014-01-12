SSH_PORT=22
OUTPUTDIR=_site
SSH_USER=blahgeek
SSH_HOST=node0.blahgeek.com
SSH_TARGET_DIR=/home/blahgeek/sites/blog

all:
	rsync -e "ssh -p $(SSH_PORT)" -P -rvz --delete $(OUTPUTDIR) $(SSH_USER)@$(SSH_HOST):$(SSH_TARGET_DIR)

.PHONY: all
