.PHONY: serve new-post

serve:
	hugo server -D

new-post:
	./scripts/new-post.sh
