#!/usr/bin/env bash
# Sorry for using bash :(

. ./crawl.conf

export CRAWL_SOLR_HOSTNAME
export CRAWL_SOLR_PORT
export CRAWL_PORT

if [ "x$1" = "xcrawl" -o "x$1" = "x" ]; then
	exec ./crawl/crawl --directory data "${@:2}"
elif [ "x$1" = "xserver" -o "x$1" = "x" ]; then
	exec ./server/crawlserver --directory data "${@:2}"
elif [ "x$1" = "xsetup" ]; then
	if curl -f -X POST -H "Content-Type: application/json" "http://$CRAWL_HOSTNAME:$CRAWL_PORT/api/collections" -d '{
		"name": "crawl",
		"numShards": 1,
		"replicationFactor": 1
	}' >/dev/null 2>&1; then
		:
	else
		echo "Failed to create collection"
		exit 1
	fi
	if curl -f -X POST -H "Content-Type: application/json" "http://$CRAWL_HOSTNAME:$CRAWL_PORT/api/collections/crawl/schema" -d '{
		"add-field": [
			{"name": "project_id", "type": "pint"},
			{"name": "title", "type": "text_general", "multiValued": false},
			{"name": "description", "type": "text_general", "multiValued": false},
			{"name": "instructions", "type": "text_general", "multiValued": false},
			{"name": "author_id", "type": "pint"},
			{"name": "author_name", "type": "string"}
			{"name": "timestamp", "type": "string"}
		]
	}' >/dev/null 2>&1; then
		:
	else
		echo "Failed to create schema"
		exit 1
	fi

	echo "Created collection/schema successfully!"
fi
